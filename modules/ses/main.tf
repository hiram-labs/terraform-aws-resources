#######################################################################
# Simple Email Service (SES) Domain Configuration                     #
#                                                                     #
# Configures AWS SES to use our domain for sending emails. This       #
# includes domain identity verification, enabling DKIM (to prevent    #
# email spoofing), and setting up a custom "Mail From" domain for     #
# handling bounced emails properly.                                   #
#######################################################################
resource "aws_ses_domain_identity" "domain_identity" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "ses_dkim" {
  domain = aws_ses_domain_identity.domain_identity.domain
}

resource "aws_ses_domain_mail_from" "domain_mail_from" {
  domain           = aws_ses_domain_identity.domain_identity.domain
  mail_from_domain = "bounce.${aws_ses_domain_identity.domain_identity.domain}"
}

#######################################################################
# Route 53 Records for Email                                          #
#                                                                     #
# Creates essential DNS records required for email functionality:     #
# - MX Record: Routes emails for specific addresses through SES.      #
# - SPF Record: Prevents spoofing by specifying allowed senders.      #
# - DMARC Record: Defines email handling policy for failed auth.      #
# - DKIM Records: Adds cryptographic signatures for email integrity.  #
# - SES Verification Record: Verifies domain ownership with AWS.      #
#######################################################################
# used to receive email sent to [email]@webmaster.domain-name-dot-com
resource "aws_route53_record" "inbound_mx_record" {
  zone_id = var.route53_zone_id
  name    = "webmaster.${var.domain_name}"
  type    = "MX"
  ttl     = "300"
  records = ["10 inbound-smtp.${var.aws_region}.amazonaws.com"]
}

resource "aws_route53_record" "mail_from_mx_record" {
  zone_id = var.route53_zone_id
  name    = aws_ses_domain_mail_from.domain_mail_from.mail_from_domain
  type    = "MX"
  ttl     = "300"
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

resource "aws_route53_record" "mail_from_txt_record" {
  zone_id = var.route53_zone_id
  name    = aws_ses_domain_mail_from.domain_mail_from.mail_from_domain
  type    = "TXT"
  ttl     = "300"
  records = ["v=spf1 include:amazonses.com ~all"]
}

resource "aws_route53_record" "dmarc_txt_record" {
  zone_id = var.route53_zone_id
  name    = "_dmarc.${var.domain_name}"
  type    = "TXT"
  ttl     = "300"
  records = ["v=DMARC1; p=quarantine; rua=mailto:dmarc-reports@${aws_route53_record.inbound_mx_record.name};"]
}

resource "aws_route53_record" "dkim_cname_record" {
  count   = 3
  zone_id = var.route53_zone_id
  name    = "${aws_ses_domain_dkim.ses_dkim.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_ses_domain_dkim.ses_dkim.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "ses_verification_record" {
  zone_id = var.route53_zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = "300"
  records = [aws_ses_domain_identity.domain_identity.verification_token]
}

#######################################################################
# SES Domain Verification                                             #
#                                                                     #
# Ensures AWS SES completes domain verification before proceeding.    #
# This step is dependent on the TXT record that proves domain         #
# ownership. Without this, SES cannot send emails on our behalf.      #
#######################################################################
resource "aws_ses_domain_identity_verification" "ses_verification" {
  depends_on = [aws_route53_record.ses_verification_record]
  domain     = aws_ses_domain_identity.domain_identity.id
}

#######################################################################
# SES Configuration Set and Event Destination for CloudWatch          #
#                                                                     #
# This configuration sets up an SES Configuration Set to enforce      #
# delivery options such as TLS policy. It also defines an event       #
# destination to send SES events (e.g., send, bounce, complaint, etc.)#
# to CloudWatch for monitoring and analysis. Events such as delivery, #
# open, and click are captured and sent to CloudWatch for further     #
# processing and visualization.                                       #
#######################################################################
# -- IMPORTANT -- 
# add X-SES-CONFIGURATION-SET: <config-set-name> as header when sending email to use this config set
# or there is a way to select and identity and add a default config set
resource "aws_ses_configuration_set" "default" {
  name = "${var.project_name}-default-config-set"

  delivery_options {
    tls_policy = "Require"
  }
}
resource "aws_ses_event_destination" "cloudwatch" {
  name                   = "${var.project_name}-event-destination-cloudwatch"
  configuration_set_name = aws_ses_configuration_set.default.name
  enabled                = true
  matching_types         = ["send", "reject", "bounce", "complaint", "delivery", "open", "click", "renderingFailure"]

  cloudwatch_destination {
    default_value  = "default"
    dimension_name = "dimension"
    value_source   = "emailHeader"
  }
}

#######################################################################
# S3 Storage for Email Archiving                                      #
#                                                                     #
# Configures an S3 bucket to store incoming emails sent to the        #
# webmaster email address. This enables email archiving and further   #
# processing (e.g., forwarding, analytics). A bucket policy is set    #
# to allow SES to write emails directly into this bucket.             #
#######################################################################
resource "aws_s3_bucket" "webmaster_emails_bucket" {
  bucket = "${var.project_name}-webmaster-email-bucket"
  force_destroy = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-webmaster-email-bucket"
    }
  )
}

resource "aws_s3_bucket_policy" "webmaster_emails_policy" {
  bucket = aws_s3_bucket.webmaster_emails_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.webmaster_emails_bucket.arn}/*"
        Principal = {
          Service = "ses.amazonaws.com"
        }
      }
    ]
  })
}

#######################################################################
# Deactivate SES Receipt Rule Set                                     #
#                                                                     #
# Ensures that the active SES rule set is deactivated before deletion.#
# This is required because AWS does not allow deletion of an active   #
# rule set, so we must clear the active rule set first.               #
#######################################################################
resource "null_resource" "deactivate_rule_set" {
  provisioner "local-exec" {
    when    = destroy
    command = "aws ses set-active-receipt-rule-set"
  }
}

#######################################################################
# SES Email Receipt Rules                                             #
#                                                                     #
# Defines rules for processing incoming emails:                       #
# - "store"         : Directs emails sent to webmaster@<domain> to    #
#                    an S3 bucket for archiving.                      #
# - "bounce-other"  : Rejects all emails not addressed to             #
#                    webmaster@<domain>, responding with a bounce     #
#                    message. The bounce sender dynamically uses the  #
#                    configured MAIL FROM domain.                     #
# Additional rules can be added later (e.g., forwarding, SNS, Lambda).#
#######################################################################
resource "aws_ses_receipt_rule_set" "default" {
  rule_set_name = "${var.project_name}-default-rule-set"

  depends_on = [null_resource.deactivate_rule_set]
}
resource "aws_ses_receipt_rule" "store" {
  name          = "store"
  rule_set_name = aws_ses_receipt_rule_set.default.rule_set_name
  recipients    = [aws_route53_record.inbound_mx_record.name]
  enabled       = true
  scan_enabled  = true

  s3_action {
    bucket_name = aws_s3_bucket.webmaster_emails_bucket.bucket
    position    = 1
  }

  stop_action {
    position = 2
    scope    = "RuleSet"
  }
}
resource "aws_ses_receipt_rule" "bounce" {
  name          = "bounce"
  rule_set_name = aws_ses_receipt_rule_set.default.rule_set_name
  recipients    = []
  enabled       = true
  scan_enabled  = true

  bounce_action {
    sender          = "no-reply@${aws_ses_domain_mail_from.domain_mail_from.mail_from_domain}"
    smtp_reply_code = "550"
    status_code     = "5.1.1"
    message         = "This email address is not monitored."
    position        = 1
  }
}

#######################################################################
# Activate SES Receipt Rule Set                                       #
#                                                                     #
# Ensures that the newly created SES rule set is activated. This is   #
# required because SES does not automatically enable rule sets.       #
#######################################################################
resource "null_resource" "activate_rule_set" {
  provisioner "local-exec" {
    when = create
    command = "aws ses set-active-receipt-rule-set --rule-set-name ${aws_ses_receipt_rule_set.default.rule_set_name}"
  }

  depends_on = [aws_ses_receipt_rule.store]
}

#######################################################################
# IAM Configuration for SES Sending                                   #
#                                                                     #
# Creates an IAM user and group with permissions to send emails via   #
# AWS SES. This is required for programmatic email sending, such as   #
# through SMTP authentication or AWS SDKs.                            #
#######################################################################
data "aws_iam_policy_document" "ses_user_policy" {
  statement {
    actions   = ["ses:SendRawEmail"]
    resources = ["*"]
    effect    = "Allow"
  }
}

resource "aws_iam_user" "ses_user" {
  name = "ses-smtp-user"
  force_destroy = true
}

resource "aws_iam_group" "ses_group" {
  name = "AWSSESSendingGroupDoNotRename"
}

resource "aws_iam_policy" "ses_user_policy" {
  name        = "AmazonSesSendingAccess"
  description = "Allows sending of e-mails via Simple Email Service"
  policy      = data.aws_iam_policy_document.ses_user_policy.json
}

resource "aws_iam_user_group_membership" "group_membership" {
  user = aws_iam_user.ses_user.name

  groups = [
    aws_iam_group.ses_group.name
  ]
}

resource "aws_iam_group_policy_attachment" "group_policy_attachment" {
  group      = aws_iam_group.ses_group.name
  policy_arn = aws_iam_policy.ses_user_policy.arn
}

resource "aws_iam_access_key" "ses_access_key" {
  user = aws_iam_user.ses_user.name
}

#######################################################################
# SMTP Credentials Generation                                         #
#                                                                     #
# AWS SES requires SMTP credentials for sending emails via SMTP.      #
# This external data source runs a Python script to generate the      #
# required credentials using the IAM access key.                      #
#######################################################################
# https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html
data "external" "execute_python" {
  program = ["python", "scripts/ses-access-key-gen.py", aws_iam_access_key.ses_access_key.secret, var.aws_region]
}
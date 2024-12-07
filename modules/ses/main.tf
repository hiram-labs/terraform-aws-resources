######
# ses
######
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

#############
# r53 records
#############
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

##############
# verification
##############
resource "aws_ses_domain_identity_verification" "ses_verification" {
  depends_on = [aws_route53_record.ses_verification_record]
  domain     = aws_ses_domain_identity.domain_identity.id
}

##########
# s3 inbox
##########
resource "aws_s3_bucket" "webmaster_emails_bucket" {
  bucket = "${var.project_name}-webmaster-email-bucket"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-webmaster-email-bucket"
  }
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

##############
# receipt_rule
##############
resource "aws_ses_receipt_rule_set" "default" {
  rule_set_name = "${var.project_name}-default-rule-set"
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
}
resource "null_resource" "activate_rule_set" {
  depends_on = [aws_ses_receipt_rule.store]

  provisioner "local-exec" {
    when = create
    command = "aws ses set-active-receipt-rule-set --rule-set-name ${aws_ses_receipt_rule_set.default.rule_set_name}"
  }
}

#####
# iam
#####
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

##########
# smtp key
##########
# https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html
data "external" "execute_python" {
  program = ["python", "scripts/ses-access-key-gen.py", aws_iam_access_key.ses_access_key.secret, var.aws_region]
}
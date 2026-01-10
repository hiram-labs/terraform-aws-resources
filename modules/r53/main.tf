#######################################################################
# Route 53 Hosted Zone Configuration                                  #
#                                                                     #
# This creates a dedicated DNS zone in AWS Route 53, acting as        #
# the authoritative name server for the domain. All DNS records       #
# related to the domain will be managed within this zone.             #
#######################################################################
resource "aws_route53_zone" "primary" {
  name = var.domain_name

  tags = merge(
    var.common_tags,
    {
      Name = var.domain_name
    }
  )
}

#######################################################################
# Route 53 Name Server (NS) Record                                    #
#                                                                     #
# Defines the NS (Name Server) record, which tells the internet       #
# where to find authoritative DNS servers for this domain. AWS        #
# assigns these name servers automatically, and they must be used     #
# at the domain registrar to delegate DNS resolution to Route 53.     #
#######################################################################
resource "aws_route53_record" "primary" {
  allow_overwrite = false
  zone_id         = aws_route53_zone.primary.zone_id
  name            = aws_route53_zone.primary.name
  ttl             = 1800
  type            = "NS"

  records = [
    aws_route53_zone.primary.name_servers[0],
    aws_route53_zone.primary.name_servers[1],
    aws_route53_zone.primary.name_servers[2],
    aws_route53_zone.primary.name_servers[3],
  ]
}

#######################################################################
# AWS Certificate Manager (ACM) SSL                                   #
#                                                                     #
# Requests an SSL/TLS certificate for the domain. This certificate    #
# will be used to enable HTTPS and encrypt traffic. DNS validation    #
# is chosen because it allows automation and eliminates the need for  #
# manual approval.                                                    #
#######################################################################
resource "aws_acm_certificate" "cert" {
  domain_name       = aws_route53_zone.primary.name
  validation_method = "DNS"

  subject_alternative_names = [
    "*.${aws_route53_zone.primary.name}"
  ]

  tags = merge(
    var.common_tags,
    {
      Name = aws_route53_zone.primary.name
    }
  )
}

#######################################################################
# DNS Validation Record for ACM SSL                                   #
#                                                                     #
# Since AWS requires proof of domain ownership before issuing a       #
# certificate, this creates the necessary DNS records automatically.  #
# These records allow ACM to verify that we control the domain.       #
# The short TTL (60s) ensures that updates propagate quickly.         #
#######################################################################
resource "aws_route53_record" "cert_validation" {
  allow_overwrite = true
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

#######################################################################
# Manual Validation Output (Commented Out)                            #
#                                                                     #
# Normally, validation is automated using Route 53. However, if the   #
# domain is registered elsewhere, you may need to manually add the    #
# validation records to your DNS provider. Uncomment this block if    #
# manual validation is required.                                      #
#######################################################################
# resource "null_resource" "force_dns_output" {
#   provisioner "local-exec" {
#     command = <<EOT
#       echo "Add these DNS validation records to your DNS provider to validate the certificate:"
#       %{ for dvo in aws_acm_certificate.cert.domain_validation_options }
#       echo "Domain: ${dvo.domain_name}\nName: ${dvo.resource_record_name}\nType: ${dvo.resource_record_type}\nValue: ${dvo.resource_record_value}"
#       %{ endfor }
#       sleep 300
#     EOT
#   }

#   triggers = {
#     cert_arn = aws_acm_certificate.cert.arn
#   }
# }

#######################################################################
# ACM Certificate Validation Finalization                             #
#                                                                     #
# Waits for ACM to complete domain validation. This ensures that      #
# the SSL certificate is actually issued before Terraform proceeds.   #
# Without this, services relying on the certificate might fail.       #
#######################################################################
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.resource_record_name]

  depends_on = [aws_route53_record.cert_validation]
}
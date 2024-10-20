#########
# route53
#########
resource "aws_route53_zone" "primary" {
  name = var.domain_name
}
resource "aws_route53_record" "primary" {
  allow_overwrite = true
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

#############
# certificate
#############
resource "aws_acm_certificate" "cert" {
  domain_name       = aws_route53_zone.primary.name
  validation_method = "DNS"
}
resource "aws_route53_record" "cert_validation" {
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
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.resource_record_name]

  depends_on = [aws_route53_record.cert_validation]
}
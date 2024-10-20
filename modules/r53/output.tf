output "certificate_arn" {
  value = aws_acm_certificate_validation.cert_validation.certificate_arn
}

output "route53_zone_id" {
  value = aws_route53_zone.primary.zone_id
}

output "route53_zone_name" {
  value = aws_route53_zone.primary.name
}


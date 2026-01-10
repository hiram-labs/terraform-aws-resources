output "certificate_arn" {
  description = "ARN of the ACM SSL/TLS certificate"
  value       = aws_acm_certificate_validation.cert_validation.certificate_arn
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = aws_route53_zone.primary.zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = aws_route53_zone.primary.name
}

output "route53_name_servers" {
  description = "Name servers for the Route53 hosted zone"
  value       = aws_route53_zone.primary.name_servers
}


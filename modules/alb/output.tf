output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.alb.dns_name
}

output "web_ip_tg_arn" {
  description = "ARN of the web target group"
  value       = aws_lb_target_group.web_ip_tg.arn
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.alb.arn
}

output "alb_zone_id" {
  description = "Zone ID of the ALB (for Route53 alias records)"
  value       = aws_lb.alb.zone_id
}

output "alb_https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = aws_lb_listener.https_alb_listener.arn
}

output "alb_http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http_alb_listener.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group for CloudWatch metrics"
  value       = aws_lb_target_group.web_ip_tg.arn_suffix
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL (if enabled)"
  value       = var.use_alb_waf ? aws_wafv2_web_acl.alb_waf[0].arn : null
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}
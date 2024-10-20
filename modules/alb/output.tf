output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "web_ip_tg_arn" {
  value = aws_lb_target_group.web_ip_tg.arn
}
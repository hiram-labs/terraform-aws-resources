output "ec2_public_ip" {
  value = module.ec2.instance_public_ips
}

output "s3_website_endpoint" {
  value = module.s3.website_endpoint
}

output "ses_smtp_username" {
  value = module.ses.smtp_username
}

output "ses_smtp_password" {
  value     = module.ses.smtp_password
  sensitive = true
}

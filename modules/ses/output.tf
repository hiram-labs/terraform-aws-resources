output "smtp_username" {
  description = "SMTP username for SES email sending"
  value       = aws_iam_access_key.ses_access_key.id
}

output "smtp_password" {
  description = "SMTP password for SES email sending"
  value       = data.external.execute_python.result.smtp_password
  sensitive   = true
}
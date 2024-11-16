output "smtp_username" {
  value = aws_iam_access_key.ses_access_key.id
}

output "smtp_password" {
  value     = aws_iam_access_key.ses_access_key.secret
}
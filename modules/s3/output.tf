output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.website_bucket_conf.website_endpoint
}
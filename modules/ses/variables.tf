variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in."
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 hosted zoned id"
}
variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}
variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "domain_name" {
  type        = string
  description = "Domain name for the application"
}
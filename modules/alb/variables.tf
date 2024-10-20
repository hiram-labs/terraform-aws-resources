variable "vpc_id" {
  type        = string
  description = "VPC ID for the ALB"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets for the ALB"
}

variable "security_groups" {
  type        = list(string)
  description = "Security groups for the ALB"
}

variable "certificate_arn" {
  type        = string
  description = "Certificate ARN for HTTPS"
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 hosted zoned id"
}

variable "route53_zone_name" {
  type        = string
  description = "Route53 hosted zoned id"
}

variable "project_name" {
  type        = string
  description = "Name of the project"
}

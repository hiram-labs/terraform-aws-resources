variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for the ALB and VPC endpoints"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets for the ALB and VPC endpoints"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets for the ALB and VPC endpoints"
}

variable "public_route_table_id" {
  type        = string
  description = "ID of the public route table used for routing public traffic."
}

variable "private_route_table_id" {
  type        = string
  description = "ID of the private route table used for routing public traffic."
}

variable "security_groups" {
  type        = list(string)
  description = "Security groups for the ALB and VPC endpoints"
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

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}

variable "use_alb_waf" {
  type        = bool
  description = "Enable AWS WAF for the Application Load Balancer"
  default     = false
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for CloudWatch alarms"
  default     = ""
}

variable "enable_monitoring" {
  type        = bool
  description = "Enable CloudWatch monitoring and alarms"
  default     = false
}

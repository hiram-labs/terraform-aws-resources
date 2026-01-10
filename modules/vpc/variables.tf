variable "use_nat_gateway" {
  type        = bool
  description = "Create a NAT Gateway for private subnets"
}

variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in."
}

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}
variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days"
  default     = 7
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

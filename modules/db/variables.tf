variable "security_groups" {
  type        = list(string)
  description = "Security groups for the DB clusters"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets for the DB clusters"
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
variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for CloudWatch alarms"
  default     = ""
}

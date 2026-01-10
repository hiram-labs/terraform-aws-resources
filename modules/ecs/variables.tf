variable "vpc_id" {
  type        = string
  description = "VPC ID for the ALB"
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets for the ECS services"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets for the ECS services"
}

variable "public_td_security_groups" {
  type        = list(string)
  description = "Security groups for the public ECS task definitions"
}

variable "private_td_security_groups" {
  type        = list(string)
  description = "Security groups for the private ECS task definitions"
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}

variable "web_ip_tg_arn" {
  type        = string
  description = "LB web ports target group"
}

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in"
}

variable "autoscale_max_capacity" {
  description = "The maximum number of compute units to add when fully scaled up"
  type        = number
}

variable "public_task_definitions" {
  type = map(object({
    path                 = string
    cpu                  = number
    memory               = number
    entry_container_name = string
    entry_container_port = number
    is_entry_container   = bool
  }))
  description = "A map of public task definitions along with required attributes"
}

variable "private_task_definitions" {
  type = map(object({
    path   = string
    cpu    = number
    memory = number
  }))
  description = "A map of private task definitions along with required attributes"
}
variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days"
  default     = 3
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

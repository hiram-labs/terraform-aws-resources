variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "alert_email" {
  type        = string
  description = "Email address to receive CloudWatch alarm notifications"
  default     = ""
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}

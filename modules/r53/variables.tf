variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "domain_name" {
  type        = string
  description = "Domain name for the application"
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}

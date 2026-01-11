variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "repositories" {
  type = map(object({
    keep_image_count = number
    untagged_days    = number
  }))
  description = "Map of ECR repositories with lifecycle settings"
  default     = {}
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}

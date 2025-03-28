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
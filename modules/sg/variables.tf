variable "vpc_id" {
  type        = string
  description = "VPC ID for the security groups"
}

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "db_sg_attr" {
  type        = map(number)
  description = "Map of DB security group attributes where key is the name and value is the port"
}

variable "web_sg_attr" {
  type        = map(number)
  description = "Map of Web security group attributes where key is the name and value is the port"
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}

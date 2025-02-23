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
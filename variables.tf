variable "project_name" {
  type        = string
  description = "The name of the project."
}

variable "domain_name" {
  type        = string
  description = "The domain name for the application services."
}

variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in."
}

variable "ssh_public_key" {
  type        = string
  description = "A string / file path to a public key for EC2 ssh authentication."
}

variable "autoscale_max_capacity" {
  description = "The maximum number of compute units to add when fully scaled up"
  type        = number
}

variable "ecs_task_cpu" {
  description = "The amount of CPU for the ECS task definition"
  type        = number
}

variable "ecs_task_memory" {
  description = "The amount of memory (in MiB) for the ECS task definition"
  type        = number
}

variable "web_sg_attr" {
  type = map(string)
  description = "Security group attributes for the web service, including HTTP and HTTPS ports."
}

variable "db_sg_attr" {
  type = map(string)
  description = "Security group attributes for database services, mapping each service to its port."
}

variable "access_policies" {
  type = map(map(string))
  description = "A map of access policies, where each policy includes its path."
}

variable "public_task_definitions" {
  type = map(map(string))
  description = "A map of public task definitions, where each service includes its path, entry container name, and entry container port."
}

variable "private_task_definitions" {
  type = map(map(string))
  description = "A map of private task definitions, where each service includes its path, entry container name, and entry container port."
}


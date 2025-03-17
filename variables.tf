variable "project_name" {
  type        = string
  description = "The name of the project."
  default     = "playground"
}

variable "domain_name" {
  type        = string
  description = "The domain name for the application services."
  default     = "cloud.hiramlabs.com"
}

variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in."
  default     = "eu-west-2"
}

variable "ssh_public_key" {
  type        = string
  description = "A string / file path to a public key for EC2 ssh authentication."
  default     = "~/.ssh/shared/id_ed25519.pub"
}

variable "use_nat_gateway" {
  type        = bool
  description = "Specify whether to create a NAT Gateway for private subnets."
  default     = true
}

variable "autoscale_max_capacity" {
  description = "The maximum number of compute units to add when fully scaled up."
  type        = number
  default     = 5
}

variable "web_sg_attr" {
  type = map(string)
  description = "Security group attributes for the web service, including HTTP and HTTPS ports."
  default = {
    http  = "80"
    https = "443"
  }
}

variable "db_sg_attr" {
  type = map(string)
  description = "Security group attributes for database services, mapping each service to its port."
  default = {
    mongo    = "27017"
    postgres = "5432"
    redis    = "6379"
  }
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
  description = "A map of public task definitions, where each key represents a service, and the value includes the task definition parameters such as path, CPU, memory, entry container name, entry container port and is entry container flag."
  default = {
    public_service_01 = {
      path                 = "modules/ecs/task-definitions/public/service_01.json"
      cpu                  = 256
      memory               = 512
      entry_container_name = "nginx"
      entry_container_port = 80
      is_entry_container   = true
    }
  }
}

variable "private_task_definitions" {
  type = map(object({
    path   = string
    cpu    = number
    memory = number
  }))
  description = "A map of private task definitions, where each key represents a service, and the value includes the task definition parameters such as path, CPU, and memory."
  default = {
    private_service_01 = {
      path   = "modules/ecs/task-definitions/private/service_01.json"
      cpu    = 256
      memory = 512
    }
  }
}

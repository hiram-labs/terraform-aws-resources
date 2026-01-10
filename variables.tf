variable "project_name" {
  type        = string
  description = "The name of the project."
  default     = "playground"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name)) && length(var.project_name) >= 3 && length(var.project_name) <= 32
    error_message = "Project name must be lowercase alphanumeric with hyphens, between 3 and 32 characters."
  }
}

variable "environment" {
  type        = string
  description = "The deployment environment (e.g., dev, staging, prod)."
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  type        = string
  description = "The owner or team responsible for the infrastructure."
  default     = "DevOps"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC."
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "domain_name" {
  type        = string
  description = "The domain name for the application services."
  default     = ""

  validation {
    condition     = var.domain_name == "" || can(regex("^([a-z0-9]+(-[a-z0-9]+)*\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain (e.g., example.com) or empty string."
  }
}

variable "aws_region" {
  type        = string
  description = "The AWS region to deploy resources in."
  default     = "eu-west-2"

  validation {
    condition = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1", "eu-north-1",
      "ap-south-1", "ap-northeast-1", "ap-northeast-2", "ap-southeast-1", "ap-southeast-2",
      "ca-central-1", "sa-east-1"
    ], var.aws_region)
    error_message = "AWS region must be a valid AWS region identifier."
  }
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

variable "use_alb_waf" {
  type        = bool
  description = "Enable AWS WAF for Application Load Balancer."
  default     = false
}

variable "autoscale_max_capacity" {
  description = "The maximum number of compute units to add when fully scaled up."
  type        = number
  default     = 5

  validation {
    condition     = var.autoscale_max_capacity >= 1 && var.autoscale_max_capacity <= 100
    error_message = "Autoscale max capacity must be between 1 and 100."
  }
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

variable "alert_email" {
  type        = string
  description = "Email address to receive CloudWatch alarm notifications."
  default     = ""

  validation {
    condition     = var.alert_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.alert_email))
    error_message = "Alert email must be a valid email address or empty string."
  }
}

variable "log_retention_days" {
  type        = map(number)
  description = "CloudWatch log retention in days per environment."
  default = {
    dev     = 3
    staging = 7
    prod    = 30
  }
}

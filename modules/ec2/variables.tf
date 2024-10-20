variable "public_subnet_id" {
  type        = string
  description = "Public subnet for the EC2 instances"
}

variable "security_groups" {
  type        = list(string)
  description = "Security groups for the EC2 instances"
}

variable "project_name" {
  type        = string
  description = "Name of the project"
}

variable "access_policies" {
  type = map(map(string))
  description = "A map of access policies, where each policy includes its path."
}

variable "ssh_public_key" {
  type        = string
  description = "A string / file path to a public key for EC2 ssh authentication."
}
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

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}
variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for CloudWatch alarms"
  default     = ""
}

variable "enable_monitoring" {
  type        = bool
  description = "Enable CloudWatch monitoring and alarms"
  default     = false
}

variable "rds_snapshot_identifier" {
  type        = string
  description = "Snapshot identifier to restore RDS PostgreSQL from. If provided, the database will be created from this snapshot."
  default     = null
}

variable "docdb_snapshot_identifier" {
  type        = string
  description = "Snapshot identifier to restore DocumentDB from. If provided, the cluster will be created from this snapshot."
  default     = null
}

variable "elasticache_snapshot_name" {
  type        = string
  description = "Snapshot name to restore ElastiCache from. If provided, the replication group will be created from this snapshot."
  default     = null
}

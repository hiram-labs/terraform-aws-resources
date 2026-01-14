output "generated_password" {
  description = "Shared password for all database services (RDS, ElastiCache, DocumentDB)"
  value       = random_password.shared_password.result
  sensitive   = true
}

output "cache_uri" {
  description = "ElastiCache primary endpoint address"
  value       = var.use_elasticache ? aws_elasticache_replication_group.cache_replication_group[0].primary_endpoint_address : null
}

output "cache_ro_uri" {
  description = "ElastiCache reader endpoint address"
  value       = var.use_elasticache ? aws_elasticache_replication_group.cache_replication_group[0].reader_endpoint_address : null
}

output "rds_pg_uri" {
  description = "RDS PostgreSQL endpoint address"
  value       = var.use_rds ? aws_db_instance.rds_postgres[0].endpoint : null
}

output "docdb_uri" {
  description = "DocumentDB cluster endpoint address"
  value       = var.use_docdb ? aws_docdb_cluster.docdb_cluster[0].endpoint : null
}

output "docdb_ro_uri" {
  description = "DocumentDB reader endpoint address"
  value       = var.use_docdb ? aws_docdb_cluster.docdb_cluster[0].reader_endpoint : null
}

output "rds_connection_string" {
  description = "PostgreSQL connection string (use with generated_password)"
  value       = var.use_rds ? "postgresql://postgres@${aws_db_instance.rds_postgres[0].endpoint}/postgres?sslmode=require" : null
  sensitive   = true
}

output "cache_connection_string" {
  description = "Redis/Valkey connection string (use with generated_password)"
  value       = var.use_elasticache ? "redis://:PASSWORD@${aws_elasticache_replication_group.cache_replication_group[0].primary_endpoint_address}:6379" : null
  sensitive   = true
}

output "docdb_connection_string" {
  description = "DocumentDB connection string (use with generated_password)"
  value       = var.use_docdb ? "mongodb://docdbadmin:PASSWORD@${aws_docdb_cluster.docdb_cluster[0].endpoint}:27017/?tls=true&replicaSet=rs0&readPreference=secondaryPreferred" : null
  sensitive   = true
}

output "rds_instance_id" {
  description = "RDS PostgreSQL instance identifier"
  value       = var.use_rds ? aws_db_instance.rds_postgres[0].id : null
}

output "rds_instance_arn" {
  description = "ARN of the RDS instance"
  value       = var.use_rds ? aws_db_instance.rds_postgres[0].arn : null
}

output "cache_cluster_id" {
  description = "ElastiCache replication group ID"
  value       = var.use_elasticache ? aws_elasticache_replication_group.cache_replication_group[0].id : null
}

output "cache_cluster_arn" {
  description = "ARN of the ElastiCache replication group"
  value       = var.use_elasticache ? aws_elasticache_replication_group.cache_replication_group[0].arn : null
}

output "docdb_cluster_id" {
  description = "DocumentDB cluster identifier"
  value       = var.use_docdb ? aws_docdb_cluster.docdb_cluster[0].id : null
}

output "docdb_cluster_arn" {
  description = "ARN of the DocumentDB cluster"
  value       = var.use_docdb ? aws_docdb_cluster.docdb_cluster[0].arn : null
}

output "rds_port" {
  description = "Port the RDS instance is listening on"
  value       = var.use_rds ? aws_db_instance.rds_postgres[0].port : null
}

output "cache_port" {
  description = "Port the ElastiCache cluster is listening on"
  value       = var.use_elasticache ? aws_elasticache_replication_group.cache_replication_group[0].port : null
}

output "docdb_port" {
  description = "Port the DocumentDB cluster is listening on"
  value       = var.use_docdb ? aws_docdb_cluster.docdb_cluster[0].port : null
}

output "generated_password" {
  description = "Shared password for all database services (RDS, ElastiCache, DocumentDB)"
  value       = random_password.shared_password.result
  sensitive   = true
}

output "cache_uri" {
  description = "ElastiCache primary endpoint address"
  value       = aws_elasticache_replication_group.cache_replication_group.primary_endpoint_address
}

output "cache_ro_uri" {
  description = "ElastiCache reader endpoint address"
  value       = aws_elasticache_replication_group.cache_replication_group.reader_endpoint_address
}

output "rds_pg_uri" {
  description = "RDS PostgreSQL endpoint address"
  value       = aws_db_instance.rds_postgres.endpoint
}

output "docdb_uri" {
  description = "DocumentDB cluster endpoint address"
  value       = aws_docdb_cluster.docdb_cluster.endpoint
}

output "docdb_ro_uri" {
  description = "DocumentDB reader endpoint address"
  value       = aws_docdb_cluster.docdb_cluster.reader_endpoint
}

output "rds_connection_string" {
  description = "PostgreSQL connection string (use with generated_password)"
  value       = "postgresql://postgres@${aws_db_instance.rds_postgres.endpoint}/postgres?sslmode=require"
  sensitive   = true
}

output "cache_connection_string" {
  description = "Redis/Valkey connection string (use with generated_password)"
  value       = "redis://:PASSWORD@${aws_elasticache_replication_group.cache_replication_group.primary_endpoint_address}:6379"
  sensitive   = true
}

output "docdb_connection_string" {
  description = "DocumentDB connection string (use with generated_password)"
  value       = "mongodb://docdbadmin:PASSWORD@${aws_docdb_cluster.docdb_cluster.endpoint}:27017/?tls=true&replicaSet=rs0&readPreference=secondaryPreferred"
  sensitive   = true
}

output "rds_instance_id" {
  description = "RDS PostgreSQL instance identifier"
  value       = aws_db_instance.rds_postgres.id
}

output "rds_instance_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.rds_postgres.arn
}

output "cache_cluster_id" {
  description = "ElastiCache replication group ID"
  value       = aws_elasticache_replication_group.cache_replication_group.id
}

output "cache_cluster_arn" {
  description = "ARN of the ElastiCache replication group"
  value       = aws_elasticache_replication_group.cache_replication_group.arn
}

output "docdb_cluster_id" {
  description = "DocumentDB cluster identifier"
  value       = aws_docdb_cluster.docdb_cluster.id
}

output "docdb_cluster_arn" {
  description = "ARN of the DocumentDB cluster"
  value       = aws_docdb_cluster.docdb_cluster.arn
}

output "rds_port" {
  description = "Port the RDS instance is listening on"
  value       = aws_db_instance.rds_postgres.port
}

output "cache_port" {
  description = "Port the ElastiCache cluster is listening on"
  value       = aws_elasticache_replication_group.cache_replication_group.port
}

output "docdb_port" {
  description = "Port the DocumentDB cluster is listening on"
  value       = aws_docdb_cluster.docdb_cluster.port
}

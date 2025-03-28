output "generated_password" {
  value = random_password.shared_password.result
  sensitive = true
}

output "cache_uri" {
  value = aws_elasticache_replication_group.cache_replication_group.primary_endpoint_address
}

output "cache_ro_uri" {
  value = aws_elasticache_replication_group.cache_replication_group.reader_endpoint_address
}

output "rds_pg_uri" {
  value = aws_db_instance.rds_postgres.endpoint
}

output "docdb_uri" {
  value = aws_docdb_cluster.docdb_cluster.endpoint
}

output "docdb_ro_uri" {
  value = aws_docdb_cluster.docdb_cluster.reader_endpoint
}

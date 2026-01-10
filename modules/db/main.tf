resource "random_password" "shared_password" {
  length           = 16
  special          = true
  override_special = "-_~"
}


# ----- CACHE VALKEY -----
##################################################################################################
# ElastiCache Cluster-Based Deployment                                                           #
#                                                                                                #
# Deploys a traditional ElastiCache Replication Group for Valkey.                                #
# This setup provides persistent caching with high availability, backups, and failover support.  #
#                                                                                                #
# Components:                                                                                    #
# - Subnet Group: Ensures deployment in private subnets.                                         #
# - Parameter Group: Defines Valkey-specific cache optimizations.                                #
# - User & User Group: Implements authentication with password protection.                       #
# - Replication Group: Creates the cache cluster with optional failover support.                 #
#                                                                                                #
# Key Features:                                                                                  #
# - Custom maintenance and snapshot schedules.                                                   #
# - Manual control over scaling and node configurations.                                         #
# - Ideal for workloads requiring predictable performance and full control over cache nodes.     #
##################################################################################################
resource "aws_elasticache_subnet_group" "cache_subnet_group" {
  name       = "${var.project_name}-cache-subnet-group"
  subnet_ids = var.private_subnets

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-cache-subnet-group"
    }
  )
}
resource "aws_elasticache_parameter_group" "cache_params" {
  name   = "${var.project_name}-cache-params"
  family = "valkey7"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-cache-params"
    }
  )
}
resource "aws_elasticache_user" "cache_default_user" {
  engine        = "valkey"
  user_id       = "${var.project_name}-default-user-id"
  user_name     = "svc"
  access_string = "on ~* +@all"

  authentication_mode {
    type = "password"
    passwords = [random_password.shared_password.result]
  }
}
resource "aws_elasticache_user_group" "cache_default_user_group" {
  engine        = "valkey"
  user_group_id = "${var.project_name}-default-user-group-id"
  user_ids      = [aws_elasticache_user.cache_default_user.user_id]
}
resource "aws_elasticache_replication_group" "cache_replication_group" {
  replication_group_id       = "${var.project_name}-cache-replication-group"
  description                = "Replication group for ${var.project_name}"
  engine                     = "valkey"
  engine_version             = "7.2"
  node_type                  = "cache.t3.micro"
  port                       = 6379

  # for high availability add extra nodes and turn on failover
  num_cache_clusters         = 1
  automatic_failover_enabled = false

  transit_encryption_enabled = true
  apply_immediately          = true
  final_snapshot_identifier  = "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-HH-mm-ss", timestamp())}"
  
  user_group_ids             = [aws_elasticache_user_group.cache_default_user_group.id]
  parameter_group_name       = aws_elasticache_parameter_group.cache_params.name
  subnet_group_name          = aws_elasticache_subnet_group.cache_subnet_group.name
  security_group_ids         = var.security_groups

  snapshot_retention_limit   = 1
  snapshot_window            = "00:00-02:00"
  maintenance_window         = "sun:02:00-sun:05:00"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-cache-replication-group"
    }
  )
}


# ----- RDS DATABASE PG -----
##################################################################################################
# Amazon RDS PostgreSQL Deployment                                                               #
#                                                                                                #
# Deploys a managed PostgreSQL instance with high availability, security, and backups.           #
#                                                                                                #
# Components:                                                                                    #
# - Subnet Group: Ensures deployment in private subnets for security.                            #
# - Parameter Group: Configures database settings (e.g., SSL enforcement, logging).              #
# - Option Group: Placeholder for future PostgreSQL extensions.                                  #
# - Database Instance: Creates the primary PostgreSQL instance with scaling and monitoring.      #
#                                                                                                #
# Key Features:                                                                                  #
# - Multi-AZ for high availability and automatic failover.                                       #
# - Encrypted storage for data security.                                                         #
# - Performance Insights enabled for query performance monitoring.                               #
# - Backup retention with scheduled maintenance and snapshotting.                                #
# - Private networking with security group restrictions.                                         #
##################################################################################################
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = var.private_subnets

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-subnet-group"
    }
  )
}
resource "aws_db_parameter_group" "rds_pg_params" {
  name        = "${var.project_name}-rds-pg-params"
  family      = "postgres16"

  parameter {
    name  = "log_min_duration_statement"
    value = "500"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-pg-params"
    }
  )
}
resource "aws_db_option_group" "rds_pg_options" {
  name                 = "${var.project_name}-rds-pg-options"
  engine_name          = "postgres"
  major_engine_version = "16"

  # pg has limited option functionality compared to oracle and mysql
  # so this resource is mostly for documentation and consistency

  # option {}

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-pg-options"
    }
  )
}
resource "aws_db_instance" "rds_postgres" {
  identifier                            = "${var.project_name}-rds-postgres"
  engine                                = "postgres"
  engine_version                        = "16"
  instance_class                        = "db.t4g.micro"
  port                                  = 5432
  allocated_storage                     = 20
  max_allocated_storage                 = 1000

  username                              = "svc"
  password                              = random_password.shared_password.result

  option_group_name                     = aws_db_option_group.rds_pg_options.name
  parameter_group_name                  = aws_db_parameter_group.rds_pg_params.name
  db_subnet_group_name                  = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids                = var.security_groups

  multi_az                              = true
  storage_encrypted                     = true
  backup_retention_period               = 7
  backup_window                         = "00:00-02:00"
  maintenance_window                    = "sun:02:00-sun:05:00"

  deletion_protection                   = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  publicly_accessible                   = false
  apply_immediately                     = true
  skip_final_snapshot                   = false
  final_snapshot_identifier             = "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-HH-mm-ss", timestamp())}"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-postgres"
    }
  )
}


# ----- DOCUMENT_DB CLUSTER -----
#####################################################################################################
# Amazon DocumentDB (with MongoDB compatibility) Deployment                                         #
#                                                                                                   #
# Deploys a fully managed Amazon DocumentDB cluster with high availability, security, and backups.  #
# This setup ensures reliable and scalable document-based storage, with automatic failover and      #
# performance monitoring features.                                                                  #
#                                                                                                   #
# Components:                                                                                       #
# - Subnet Group: Ensures deployment in private subnets for enhanced security.                      #
# - Cluster Parameter Group: Configures DocumentDB-specific settings (e.g., audit logs, TLS).       #
# - Cluster: Creates the main DocumentDB cluster, handling storage, backups, and scaling.           #
# - Cluster Instance: Deploys individual cluster instances for load balancing and high availability.#
#                                                                                                   #
# Key Features:                                                                                     #
# - Multi-AZ deployment for high availability with automatic failover.                              #
# - Encrypted storage for secure data at rest.                                                      #
# - Backup retention with customizable backup and maintenance windows.                              #
# - Integrated auditing and TLS for secure operations.                                              #
# - Performance insights and monitoring integration for proactive management.                       #
#####################################################################################################
resource "aws_docdb_subnet_group" "docdb_subnet_group" {
  name       = "${var.project_name}-docdb-subnet-group"
  subnet_ids = var.private_subnets

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-docdb-subnet-group"
    }
  )
}
resource "aws_docdb_cluster_parameter_group" "docdb_pg_params" {
  name        = "${var.project_name}-docdb-pg-params"
  family      = "docdb4.0"

  parameter {
    name  = "audit_logs"
    value = "enabled"
  }
  parameter {
    name  = "tls"
    value = "enabled"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-docdb-pg-params"
    }
  )
}
resource "aws_docdb_cluster" "docdb_cluster" {
  cluster_identifier              = "${var.project_name}-docdb-cluster"
  engine                          = "docdb"
  engine_version                  = "4.0.0"
  port                            = 27017

  master_username                 = "svc"
  master_password                 = random_password.shared_password.result

  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.docdb_pg_params.name
  db_subnet_group_name            = aws_docdb_subnet_group.docdb_subnet_group.name
  vpc_security_group_ids          = var.security_groups

  storage_encrypted               = true
  backup_retention_period         = 7
  preferred_backup_window         = "00:00-02:00"
  preferred_maintenance_window    = "sun:02:00-sun:05:00"

  deletion_protection             = false

  apply_immediately               = true
  skip_final_snapshot             = false
  final_snapshot_identifier       = "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-HH-mm-ss", timestamp())}"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-docdb-cluster"
    }
  )
}
resource "aws_docdb_cluster_instance" "docdb_cluster_instance" {
  count              = 1
  identifier         = "${var.project_name}-docdb-cluster-instance-${count.index}"
  cluster_identifier = aws_docdb_cluster.docdb_cluster.id
  instance_class     = "db.t3.medium"

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-docdb-cluster-instance-${count.index}"
    }
  )
}

#######################################################################
# CloudWatch Alarms for RDS PostgreSQL                                #
#######################################################################
resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count               = var.sns_topic_arn != "" ? 1 : 0
  alarm_name          = "${var.project_name}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU utilization is above 80%"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds_postgres.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-cpu-high"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  count               = var.sns_topic_arn != "" ? 1 : 0
  alarm_name          = "${var.project_name}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 2147483648  # 2GB in bytes
  alarm_description   = "RDS free storage space is below 2GB"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds_postgres.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-storage-low"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  count               = var.sns_topic_arn != "" ? 1 : 0
  alarm_name          = "${var.project_name}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS database connections are high"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds_postgres.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-connections-high"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "rds_read_latency_high" {
  count               = var.sns_topic_arn != "" ? 1 : 0
  alarm_name          = "${var.project_name}-rds-read-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.1  # 100ms
  alarm_description   = "RDS read latency is above 100ms"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds_postgres.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-read-latency-high"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "rds_write_latency_high" {
  count               = var.sns_topic_arn != "" ? 1 : 0
  alarm_name          = "${var.project_name}-rds-write-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.1  # 100ms
  alarm_description   = "RDS write latency is above 100ms"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.rds_postgres.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-rds-write-latency-high"
    }
  )
}

#######################################################################
# CloudWatch Alarms for ElastiCache                                   #
#######################################################################
resource "aws_cloudwatch_metric_alarm" "elasticache_cpu_high" {
  count               = var.sns_topic_arn != "" ? 1 : 0
  alarm_name          = "${var.project_name}-elasticache-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 75
  alarm_description   = "ElastiCache CPU utilization is above 75%"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.cache_replication_group.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-elasticache-cpu-high"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "elasticache_memory_high" {
  count               = var.sns_topic_arn != "" ? 1 : 0
  alarm_name          = "${var.project_name}-elasticache-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "ElastiCache memory usage is above 90%"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.cache_replication_group.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-elasticache-memory-high"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "elasticache_evictions_high" {
  count               = var.sns_topic_arn != "" ? 1 : 0
  alarm_name          = "${var.project_name}-elasticache-evictions-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = 300
  statistic           = "Sum"
  threshold           = 1000
  alarm_description   = "ElastiCache evictions are high"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.cache_replication_group.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-elasticache-evictions-high"
    }
  )
}

#######################################################################
# CloudWatch Alarms for DocumentDB                                    #
#######################################################################
resource "aws_cloudwatch_metric_alarm" "docdb_cpu_high" {
  count               = var.sns_topic_arn != "" ? 1 : 0
  alarm_name          = "${var.project_name}-docdb-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/DocDB"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "DocumentDB CPU utilization is above 80%"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBClusterIdentifier = aws_docdb_cluster.docdb_cluster.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-docdb-cpu-high"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "docdb_connections_high" {
  count               = var.sns_topic_arn != "" ? 1 : 0
  alarm_name          = "${var.project_name}-docdb-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/DocDB"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "DocumentDB connections are high"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBClusterIdentifier = aws_docdb_cluster.docdb_cluster.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-docdb-connections-high"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "docdb_replication_lag" {
  count               = var.sns_topic_arn != "" ? 1 : 0
  alarm_name          = "${var.project_name}-docdb-replication-lag"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DBClusterReplicaLag"
  namespace           = "AWS/DocDB"
  period              = 300
  statistic           = "Average"
  threshold           = 1000  # 1 second in ms
  alarm_description   = "DocumentDB replication lag is above 1 second"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    DBClusterIdentifier = aws_docdb_cluster.docdb_cluster.id
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-docdb-replication-lag"
    }
  )
}

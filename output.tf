output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = module.ec2.instance_public_ips
}

output "s3_website_endpoint" {
  description = "S3 website endpoint URL"
  value       = module.s3.website_endpoint
}

output "ses_smtp_username" {
  description = "SES SMTP username for sending emails"
  value       = module.ses.smtp_username
}

output "ses_smtp_password" {
  description = "SES SMTP password for sending emails"
  value       = module.ses.smtp_password
  sensitive   = true
}

#######################################################################
# VPC Outputs                                                          #
#######################################################################
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway (if created)"
  value       = module.vpc.nat_gateway_public_ip
}

#######################################################################
# Database Outputs                                                     #
#######################################################################
output "database_password" {
  description = "Shared database password for all databases"
  value       = module.db.generated_password
  sensitive   = true
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = module.db.rds_pg_uri
}

output "rds_connection_string" {
  description = "PostgreSQL connection string"
  value       = module.db.rds_connection_string
  sensitive   = true
}

output "elasticache_endpoint" {
  description = "ElastiCache primary endpoint"
  value       = module.db.cache_uri
}

output "elasticache_reader_endpoint" {
  description = "ElastiCache reader endpoint"
  value       = module.db.cache_ro_uri
}

output "documentdb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = module.db.docdb_uri
}

output "documentdb_reader_endpoint" {
  description = "DocumentDB reader endpoint"
  value       = module.db.docdb_ro_uri
}

#######################################################################
# ALB and Networking Outputs                                           #
#######################################################################
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "alb_zone_id" {
  description = "Zone ID of the ALB for Route53 alias records"
  value       = module.alb.alb_zone_id
}

#######################################################################
# ECS Outputs                                                          #
#######################################################################
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.ecs_cluster_arn
}

output "service_discovery_namespace" {
  description = "Private DNS namespace for ECS service discovery"
  value       = module.ecs.service_discovery_namespace_name
}

#######################################################################
# Route53 and Domain Outputs                                           #
#######################################################################
output "route53_zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.r53.route53_zone_id
}

output "route53_zone_name" {
  description = "Route53 hosted zone name"
  value       = module.r53.route53_zone_name
}

output "route53_name_servers" {
  description = "Route53 name servers for domain delegation"
  value       = module.r53.route53_name_servers
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = module.r53.certificate_arn
}

#######################################################################
# SNS Outputs                                                          #
#######################################################################
output "sns_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarms"
  value       = module.sns.sns_topic_arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = module.sns.sns_topic_name
}

#######################################################################
# S3 Outputs                                                           #
#######################################################################
output "s3_bucket_name" {
  description = "Name of the S3 website bucket"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 website bucket"
  value       = module.s3.bucket_arn
}

#######################################################################
# ECR Outputs                                                         #
#######################################################################
output "ecr_repository_urls" {
  description = "Map of ECR repository names to their URLs"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map of ECR repository names to their ARNs"
  value       = module.ecr.repository_arns
}

output "ecr_registry_id" {
  description = "Registry ID where ECR repositories are created"
  value       = module.ecr.registry_id
}

#######################################################################
# Quick Start Connection Information                                  #
#######################################################################
output "quick_start_info" {
  description = "Quick start connection information"
  value = {
    application_url     = "https://${var.domain_name}"
    alb_endpoint        = module.alb.alb_dns_name
    database_endpoints = {
      postgres   = module.db.rds_pg_uri
      redis      = module.db.cache_uri
      documentdb = module.db.docdb_uri
    }
    ecs_cluster         = module.ecs.ecs_cluster_name
    service_discovery   = module.ecs.service_discovery_namespace_name
  }
}

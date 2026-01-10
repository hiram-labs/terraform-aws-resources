output "ecs_log_group" {
  description = "Name of the CloudWatch log group for ECS services"
  value       = aws_cloudwatch_log_group.ecs_services.name
}

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "service_discovery_namespace_id" {
  description = "ID of the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "service_discovery_namespace_name" {
  description = "Name of the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "public_service_names" {
  description = "List of public ECS service names"
  value       = keys(var.public_task_definitions)
}

output "private_service_names" {
  description = "List of private ECS service names"
  value       = keys(var.private_task_definitions)
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.main_ecs_role.arn
}

output "ecs_task_execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = aws_iam_role.main_ecs_role.name
}

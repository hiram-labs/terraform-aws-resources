##################
# cloud watch logs
##################
resource "aws_cloudwatch_log_group" "ecs_services" {
  name              = "/aws/ecs/${var.project_name}/services"
  retention_in_days = 3
}

###############
# access policy
###############
resource "aws_iam_role" "main_ecs_role" {
  name               = "${var.project_name}-ECS-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy_attachment" {
  role       = aws_iam_role.main_ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#####
# ECS
#####
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-main"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project_name}.local"
  description = "Private DNS for ECS services to enable coms across multi td"
  vpc         = var.vpc_id
}
#
resource "aws_service_discovery_service" "public_sd" {
  for_each = var.public_task_definitions
  name     = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}
resource "aws_ecs_task_definition" "public_td" {
  for_each                 = var.public_task_definitions
  family                   = each.key
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.main_ecs_role.arn
  
  container_definitions    = templatefile(
    each.value["path"], {
      aws_region = var.aws_region
      log_group  = aws_cloudwatch_log_group.ecs_services.name
    }
  )

  depends_on               = [aws_cloudwatch_log_group.ecs_services]

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
}
resource "aws_ecs_service" "public_svc" {
  for_each        = var.public_task_definitions
  name            = each.key
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.public_td[each.key].arn
  desired_count   = 1
  
  force_new_deployment = true

  triggers = {
    redeployment = plantimestamp()
  }

  network_configuration {
    subnets          = var.public_subnets
    security_groups  = var.public_td_security_groups
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.web_ip_tg_arn
    container_name   = each.value["entry_container_name"]
    container_port   = each.value["entry_container_port"]
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}
resource "aws_appautoscaling_target" "public_scaling_target" {
  for_each           = var.public_task_definitions
  max_capacity       = var.autoscale_max_capacity
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.public_svc[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
resource "aws_appautoscaling_policy" "public_scaling_up_policy" {
  for_each           = var.public_task_definitions
  name               = "scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.public_scaling_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.public_scaling_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.public_scaling_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 150
    scale_out_cooldown = 150
  }
}
resource "aws_appautoscaling_policy" "public_scaling_down_policy" {
  for_each           = var.public_task_definitions
  name               = "scale-down"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.public_scaling_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.public_scaling_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.public_scaling_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 30.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 150
    scale_out_cooldown = 150
  }
}
#
resource "aws_service_discovery_service" "private_sd" {
  for_each = var.private_task_definitions
  name     = each.key

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}
resource "aws_ecs_task_definition" "private_td" {
  for_each                 = var.private_task_definitions
  family                   = each.key
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.main_ecs_role.arn
  
  container_definitions    = templatefile(
    each.value["path"], {
      aws_region = var.aws_region
      log_group  = aws_cloudwatch_log_group.ecs_services.name
    }
  )

  depends_on               = [aws_cloudwatch_log_group.ecs_services]

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
}
resource "aws_ecs_service" "private_svc" {
  for_each        = var.private_task_definitions
  name            = each.key
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.private_td[each.key].arn
  desired_count   = 1
  
  force_new_deployment = true

  triggers = {
    redeployment = plantimestamp()
  }

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = var.private_td_security_groups
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}
resource "aws_appautoscaling_target" "private_scaling_target" {
  for_each           = var.private_task_definitions
  max_capacity       = var.autoscale_max_capacity
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.private_svc[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
resource "aws_appautoscaling_policy" "private_scaling_up_policy" {
  for_each           = var.private_task_definitions
  name               = "scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.private_scaling_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.private_scaling_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.private_scaling_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 150
    scale_out_cooldown = 60
  }
}
resource "aws_appautoscaling_policy" "private_scaling_down_policy" {
  for_each           = var.private_task_definitions
  name               = "scale-down"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.private_scaling_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.private_scaling_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.private_scaling_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 30.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 150
    scale_out_cooldown = 60
  }
}

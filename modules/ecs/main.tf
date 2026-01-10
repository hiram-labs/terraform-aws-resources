##################################################################################################
# CloudWatch Logs Configuration                                                                  #
#                                                                                                #
# This section defines the CloudWatch Log Group for ECS services, which will capture logs        #
# for monitoring and troubleshooting ECS tasks. The retention period for logs is set to 3 days.  #
##################################################################################################
resource "aws_cloudwatch_log_group" "ecs_services" {
  name              = "/aws/ecs/${var.project_name}/services"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecs-services-logs"
    }
  )
}

##################################################################################################
# IAM Role and Policy for ECS Task Execution                                                     #
#                                                                                                #
# The IAM Role grants ECS tasks permissions to interact with AWS services, such as pulling       #
# container images from Amazon ECR or logging to CloudWatch. The policy attachment ensures the   #
# required execution role policies are applied to this role.                                     #
##################################################################################################
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

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ECS-access-role"
    }
  )
}
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy_attachment" {
  role       = aws_iam_role.main_ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

##################################################################################################
# ECS Cluster and Capacity Providers Configuration                                               #
#                                                                                                #
# This section creates the ECS Cluster where tasks will run, enabling container insights for     #
# monitoring. It also configures the cluster with Fargate as the capacity provider, ensuring     #
# that tasks will run on serverless compute resources.                                           #
##################################################################################################
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-main"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-main"
    }
  )
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

##################################################################################################
# Service Discovery Configuration for ECS Services                                               #
#                                                                                                #
# This section sets up the private DNS namespace for ECS services, enabling service discovery    #
# for communication between services in the same VPC. It also configures DNS records for each    #
# ECS service, both for public and private task definitions.                                     #
#                                                                                                #
# http://backend.${var.project_name}.local:<port>                                                #
##################################################################################################
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project_name}.local"
  description = "Private DNS for ECS services to enable coms across multi td"
  vpc         = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}.local"
    }
  )
}

# ----- PUBLIC -----

##################################################################################################
# Service Discovery for Public ECS Tasks                                                         #
#                                                                                                #
# Enables internal DNS resolution for public ECS tasks, allowing them to be accessed via a       #
# consistent hostname within the VPC. This is crucial for inter-service communication, reducing  #
# dependency on external DNS resolution and ensuring reliability.                                #
##################################################################################################
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

###################################################################################################
# ECS Task Definition for Public Services                                                         #
#                                                                                                 #
# Defines how each public-facing service runs on AWS Fargate. This includes CPU/memory settings,  #
# execution roles, container definitions (loaded from a template), and networking configurations. #
###################################################################################################
resource "aws_ecs_task_definition" "public_td" {
  for_each                 = var.public_task_definitions
  family                   = each.key
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value["cpu"]
  memory                   = each.value["memory"]
  execution_role_arn       = aws_iam_role.main_ecs_role.arn
  
  container_definitions    = templatefile(
    each.value["path"], {
      aws_region  = var.aws_region
      log_group   = aws_cloudwatch_log_group.ecs_services.name
      volume_name = "${var.project_name}-${each.key}-volume"
    }
  )

  depends_on               = [aws_cloudwatch_log_group.ecs_services]

  volume {
    name                   = "${var.project_name}-${each.key}-volume"
  }

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = merge(
    var.common_tags,
    {
      Name = each.key
    }
  )
}

##################################################################################################
# ECS Service for Public Applications                                                            #
#                                                                                                #
# Deploys ECS tasks as services, ensuring high availability and load balancing. Public tasks     #
# are assigned public IPs, placed in public subnets, and exposed via the ALB. This allows the    #
# application to receive internet traffic. It also triggers redeployment on configuration        #
# changes.                                                                                       #
##################################################################################################
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

  service_registries {
    registry_arn = aws_service_discovery_service.public_sd[each.key].arn
  }

  network_configuration {
    subnets          = var.public_subnets
    security_groups  = var.public_td_security_groups
    assign_public_ip = true
  }

  dynamic "load_balancer" {
    for_each = try(each.value["is_entry_container"], false) ? [1] : []
    content {
      target_group_arn = var.web_ip_tg_arn
      container_name   = each.value["entry_container_name"]
      container_port   = each.value["entry_container_port"]
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge(
    var.common_tags,
    {
      Name = each.key
    }
  )
}

##################################################################################################
# Auto Scaling for Public ECS Services                                                           #
#                                                                                                #
# Defines auto-scaling for public ECS services based on CPU utilization. The service scales up   #
# when CPU usage exceeds 70% and scales down when below 30%. This ensures cost efficiency while  #
# maintaining performance. Scaling adjustments are subject to cooldown periods to prevent rapid  #
# fluctuations.                                                                                  #
##################################################################################################
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
  name               = "${var.project_name}-cpu-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.public_scaling_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.public_scaling_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.public_scaling_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 75.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 120
    scale_out_cooldown = 300
  }

  depends_on = [aws_appautoscaling_target.public_scaling_target]
}
resource "aws_appautoscaling_policy" "public_scaling_down_policy" {
  for_each           = var.public_task_definitions
  name               = "${var.project_name}-cpu-scale-down"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.public_scaling_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.public_scaling_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.public_scaling_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 45.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 120
    scale_out_cooldown = 300
  }

  depends_on = [aws_appautoscaling_target.public_scaling_target]
}

# ----- PRIVATE -----

###################################################################################################
# Service Discovery for Private ECS Tasks                                                         #
#                                                                                                 #
# Enables internal DNS resolution for private ECS services, allowing them to communicate securely #
# within the VPC. Unlike public tasks, private tasks do not require internet access and rely o n  #
# internal networking for inter-service communication.                                            #
###################################################################################################
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

##################################################################################################
# ECS Task Definition for Private Services                                                       #
#                                                                                                #
# Similar to public task definitions but designed for services that do not require internet      #
# exposure. These tasks run in private subnets and rely on internal service discovery.           #
##################################################################################################
resource "aws_ecs_task_definition" "private_td" {
  for_each                 = var.private_task_definitions
  family                   = each.key
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value["cpu"]
  memory                   = each.value["memory"]
  execution_role_arn       = aws_iam_role.main_ecs_role.arn
  
  container_definitions    = templatefile(
    each.value["path"], {
      aws_region  = var.aws_region
      log_group   = aws_cloudwatch_log_group.ecs_services.name
      volume_name = "${var.project_name}-${each.key}-volume"
    }
  )

  depends_on               = [aws_cloudwatch_log_group.ecs_services]

  volume {
    name                   = "${var.project_name}-${each.key}-volume"
  }

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  tags = merge(
    var.common_tags,
    {
      Name = each.key
    }
  )
}

##################################################################################################
# ECS Service for Private Applications                                                           #
#                                                                                                #
# Deploys private ECS services that run exclusively within the VPC. These tasks are assigned     #
# private IPs, placed in private subnets, and do not receive direct internet traffic. They rely  #
# on service discovery for internal communication.                                               #
##################################################################################################
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

  service_registries {
    registry_arn = aws_service_discovery_service.private_sd[each.key].arn
  }

  network_configuration {
    subnets          = var.private_subnets
    security_groups  = var.private_td_security_groups
    assign_public_ip = false
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge(
    var.common_tags,
    {
      Name = each.key
    }
  )
}

##################################################################################################
# Auto Scaling for Private ECS Services                                                          #
#                                                                                                #
# Similar to public service auto-scaling, but applied to private workloads. Ensures that         #
# non-public services can dynamically adjust based on CPU load while maintaining internal        #
# security constraints.                                                                          #
##################################################################################################
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
  name               = "${var.project_name}-cpu-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.private_scaling_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.private_scaling_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.private_scaling_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 75.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 120
    scale_out_cooldown = 300
  }

  depends_on = [aws_appautoscaling_target.private_scaling_target]
}
resource "aws_appautoscaling_policy" "private_scaling_down_policy" {
  for_each           = var.private_task_definitions
  name               = "${var.project_name}-cpu-scale-down"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.private_scaling_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.private_scaling_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.private_scaling_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 45.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 120
    scale_out_cooldown = 300
  }

  depends_on = [aws_appautoscaling_target.private_scaling_target]
}


#######################################################################
# CloudWatch Alarms for ECS Public Services                           #
#######################################################################
resource "aws_cloudwatch_metric_alarm" "ecs_public_unhealthy_tasks" {
  for_each            = var.enable_monitoring ? var.public_task_definitions : {}
  alarm_name          = "${var.project_name}-ecs-${each.key}-unhealthy-tasks"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "ECS service ${each.key} has unhealthy tasks"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ServiceName = each.key
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecs-${each.key}-unhealthy-tasks"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "ecs_public_cpu_high" {
  for_each            = var.enable_monitoring ? var.public_task_definitions : {}
  alarm_name          = "${var.project_name}-ecs-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS service ${each.key} CPU utilization is above 80%"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ServiceName = each.key
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecs-${each.key}-cpu-high"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "ecs_public_memory_high" {
  for_each            = var.enable_monitoring ? var.public_task_definitions : {}
  alarm_name          = "${var.project_name}-ecs-${each.key}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS service ${each.key} memory utilization is above 80%"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ServiceName = each.key
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecs-${each.key}-memory-high"
    }
  )
}

#######################################################################
# CloudWatch Alarms for ECS Private Services                          #
#######################################################################
resource "aws_cloudwatch_metric_alarm" "ecs_private_cpu_high" {
  for_each            = var.enable_monitoring ? var.private_task_definitions : {}
  alarm_name          = "${var.project_name}-ecs-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS service ${each.key} CPU utilization is above 80%"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ServiceName = each.key
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecs-${each.key}-cpu-high"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "ecs_private_memory_high" {
  for_each            = var.enable_monitoring ? var.private_task_definitions : {}
  alarm_name          = "${var.project_name}-ecs-${each.key}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS service ${each.key} memory utilization is above 80%"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ServiceName = each.key
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ecs-${each.key}-memory-high"
    }
  )
}

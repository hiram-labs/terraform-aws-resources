#######################################################################
# Application Load Balancer (ALB) Configuration                       #
#                                                                     #
# This section defines an Application Load Balancer (ALB) for the     #
# project, which is used to distribute traffic across multiple        #
# targets (e.g., EC2 instances, IP addresses). It's exposed to the    #
# internet and serves as the front-facing component for HTTP/HTTPS    #
# traffic. ALB handles routing, load balancing, and security for      #
# the application's backend services.                                 #
#######################################################################
resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.security_groups
  subnets            = var.public_subnets

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-alb"
    }
  )
}

#######################################################################
# AWS WAF Web ACL for ALB                                              #
#                                                                     #
# Provides protection against common web exploits including:          #
# - SQL injection attacks                                             #
# - Cross-site scripting (XSS)                                        #
# - Known bad inputs (OWASP Top 10)                                   #
# - Rate limiting and DDoS protection                                 #
#                                                                     #
# Cost: ~$5-10/month base + $0.60 per million requests                #
# Controlled by var.use_alb_waf (default: false)                       #
#######################################################################
resource "aws_wafv2_web_acl" "alb_waf" {
  count = var.use_alb_waf ? 1 : 0
  name  = "${var.project_name}-alb-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-metrics"
    sampled_requests_enabled   = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-alb-waf"
    }
  )
}

resource "aws_wafv2_web_acl_association" "alb_waf_association" {
  count        = var.use_alb_waf ? 1 : 0
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf[0].arn
}

#######################################################################
# Load Balancer Target Group Configuration                            #
#                                                                     #
# This resource defines the target group for the ALB, which contains  #
# the targets (e.g., EC2 instances or IPs) that the ALB will route    #
# traffic to. It's configured for HTTP traffic on port 80, using the  #
# IP target type. The target group is registered with the VPC to      #
# ensure proper routing.                                              #
#######################################################################
resource "aws_lb_target_group" "web_ip_tg" {
  name        = "${var.project_name}-web-ip-tg"
  vpc_id      = var.vpc_id
  target_type = "ip"
  protocol    = "HTTP"
  port        = 80

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-web-ip-tg"
    }
  )
}

#######################################################################
# HTTP Listener for Application Load Balancer                         #
#                                                                     #
# This listener listens for HTTP traffic (on port 80) on the ALB. It  #
# routes incoming requests to the target group defined above.         #
# The listener is responsible for forwarding traffic from the         #
# internet to the appropriate backend targets based on the configured #
# routing rules.                                                      #
#######################################################################
resource "aws_lb_listener" "http_alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_ip_tg.arn
  }
}

#######################################################################
# HTTPS Listener for Application Load Balancer                        #
#                                                                     #
# Similar to the HTTP listener, this listener handles encrypted HTTPS #
# traffic on port 443. SSL certificates are required for HTTPS. This  #
# listener uses the specified SSL policy and a provided certificate   #
# to ensure secure connections. The traffic is forwarded to the same  #
# target group as the HTTP listener.                                  #
#######################################################################
resource "aws_lb_listener" "https_alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_ip_tg.arn
  }
}

#######################################################################
# Route 53 Alias Record for ALB                                       #
#                                                                     #
# This resource creates an alias record in Route 53 to point the      #
# domain (e.g., www) to the ALB's DNS name. Alias records in Route    #
# 53 allow direct integration with AWS resources like ALBs, without   #
# needing an IP address. The evaluate_target_health option ensures    #
# that traffic is only routed to healthy targets.                     #
#######################################################################
resource "aws_route53_record" "www" {
  zone_id = var.route53_zone_id
  name    = var.route53_zone_name
  type    = "A"
  
  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

########################################################################
# VPC Endpoint Configuration                                           #
#                                                                      #
# This section defines VPC Endpoints for ECR (both API and Docker) and #
# S3, enabling private connections to these services from within the   #
# VPC without traversing the public internet. The configuration uses   #
# Interface endpoints for ECR and a Gateway endpoint for S3. These     #
# endpoints enhance security and performance by keeping traffic within #
# the AWS network.                                                     #
########################################################################
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = flatten([for subnet in var.private_subnets : subnet])
  security_group_ids = var.security_groups

  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = flatten([for subnet in var.private_subnets : subnet])
  security_group_ids = var.security_groups

  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "logs" {
  vpc_id             = var.vpc_id
  service_name       = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = flatten([for subnet in var.private_subnets : subnet])
  security_group_ids = var.security_groups

  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [var.private_route_table_id]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-s3gw"
    }
  )
}


#######################################################################
# CloudWatch Alarms for Application Load Balancer                     #
#######################################################################
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors_high" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-alb-5xx-errors-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB 5xx errors are above 10 in 5 minutes"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    LoadBalancer = aws_lb.alb.arn_suffix
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-alb-5xx-errors-high"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-alb-target-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 1.0  # 1 second
  alarm_description   = "ALB target response time is above 1 second"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    LoadBalancer = aws_lb.alb.arn_suffix
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-alb-target-response-time-high"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "ALB has unhealthy targets"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    LoadBalancer = aws_lb.alb.arn_suffix
    TargetGroup  = aws_lb_target_group.web_ip_tg.arn_suffix
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-alb-unhealthy-targets"
    }
  )
}

resource "aws_cloudwatch_metric_alarm" "alb_request_count_anomaly" {
  count               = var.enable_monitoring ? 1 : 0
  alarm_name          = "${var.project_name}-alb-request-count-anomaly"
  comparison_operator = "GreaterThanUpperThreshold"
  evaluation_periods  = 2
  threshold_metric_id = "e1"
  alarm_description   = "ALB request count anomaly detected"
  alarm_actions       = [var.sns_topic_arn]

  metric_query {
    id          = "e1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)"
    label       = "RequestCount (expected)"
    return_data = "true"
  }

  metric_query {
    id          = "m1"
    return_data = "true"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"

      dimensions = {
        LoadBalancer = aws_lb.alb.arn_suffix
      }
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-alb-request-count-anomaly"
    }
  )
}

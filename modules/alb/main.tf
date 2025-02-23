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

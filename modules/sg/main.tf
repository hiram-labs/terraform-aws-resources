################
# security group
################
resource "aws_security_group" "whitelist_sg" {
  name        = "${var.project_name}-whitelist-sg"
  description = "Services adopting this sg are threated as whitelist"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-whitelist-sg"
  }
}
#
resource "aws_security_group" "whitelist_all_access_sg" {
  name        = "${var.project_name}-whitelist-all-access-sg"
  description = "Allows all ingress and egress traffic amongst services assigned the whitelist sg"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-whitelist-all-access-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "whitelist_all_access_sg_ingress" {
  security_group_id                    = aws_security_group.whitelist_all_access_sg.id
  referenced_security_group_id         = aws_security_group.whitelist_sg.id
  ip_protocol                          = "-1"
}
resource "aws_vpc_security_group_egress_rule" "whitelist_all_access_sg_egress" {
  security_group_id = aws_security_group.whitelist_all_access_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
#
resource "aws_security_group" "whitelist_db_sg" {
  name        = "${var.project_name}-whitelist-db-sg"
  description = "Allows db and mq ingress traffic only from other services part of whitelist sg"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-whitelist-db-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "whitelist_db_sg_ingress" {
  for_each                     = var.db_sg_attr
  security_group_id            = aws_security_group.whitelist_db_sg.id
  referenced_security_group_id = aws_security_group.whitelist_sg.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value

  tags = {
    Name = each.key
  }
}
resource "aws_vpc_security_group_egress_rule" "whitelist_db_sg_egress" {
  security_group_id = aws_security_group.whitelist_db_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
#
resource "aws_security_group" "whitelist_web_sg" {
  name        = "${var.project_name}-whitelist-web-sg"
  description = "Allows http(80) and https(443) ingress traffic only from other services part of whitelist sg"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-whitelist-web-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "whitelist_web_sg_ingress" {
  for_each                     = var.web_sg_attr
  security_group_id            = aws_security_group.whitelist_web_sg.id
  referenced_security_group_id = aws_security_group.whitelist_sg.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value

  tags = {
    Name = each.key
  }
}
resource "aws_vpc_security_group_egress_rule" "whitelist_web_sg_egress" {
  security_group_id = aws_security_group.whitelist_web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
#
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Allows http(80) and https(443) ingress traffic"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "web_sg_ingress" {
  for_each          = var.web_sg_attr
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value

  tags = {
    Name = each.key
  }
}
resource "aws_vpc_security_group_egress_rule" "web_sg_egress" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
#
resource "aws_security_group" "ssh_sg" {
  name        = "${var.project_name}-ssh-sg"
  description = "Allows ssh(22) ingress traffic"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-ssh-sg"
  }
}
resource "aws_vpc_security_group_ingress_rule" "ssh_sg_ingress" {
  security_group_id = aws_security_group.ssh_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22

  tags = {
    Name = "ssh"
  }
}
resource "aws_vpc_security_group_egress_rule" "ssh_sg_egress" {
  security_group_id = aws_security_group.ssh_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
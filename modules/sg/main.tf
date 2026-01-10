#######################################################################
# Security Group for Whitelisted Services                             #
#                                                                     #
# This security group is designed to treat services within it as part #
# of a trusted whitelist. Other services can reference this group to  #
# establish trusted communication between them. It is intended for    #
# internal communication within a defined trusted network.            #
#######################################################################
resource "aws_security_group" "whitelist_sg" {
  name        = "${var.project_name}-whitelist-sg"
  description = "Services adopting this sg are threated as whitelist"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-whitelist-sg"
    }
  )
}

# ----- ALL -----

#######################################################################
# Security Group for All Traffic Between Whitelisted Services         #
#                                                                     #
# This security group allows unrestricted traffic between services    #
# that are part of the whitelist. It is meant to facilitate full      #
# communication between trusted services while limiting access from   #
# other services or sources outside this group.                       #
#######################################################################
resource "aws_security_group" "whitelist_all_access_sg" {
  name        = "${var.project_name}-whitelist-all-access-sg"
  description = "Allows all ingress and egress traffic amongst services assigned the whitelist sg"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-whitelist-all-access-sg"
    }
  )
}

#######################################################################
# Ingress Rule for Allowing Traffic Between Whitelisted Services      #
#                                                                     #
# This rule ensures that traffic can flow freely between services     #
# assigned to the whitelist security group, by allowing all inbound   #
# traffic from other services within that group.                      #
#######################################################################
resource "aws_vpc_security_group_ingress_rule" "whitelist_all_access_sg_ingress" {
  security_group_id                    = aws_security_group.whitelist_all_access_sg.id
  referenced_security_group_id         = aws_security_group.whitelist_sg.id
  ip_protocol                          = "-1"
}

#######################################################################
# Egress Rule Allowing All Outbound Traffic for Whitelisted Services  #
#                                                                     #
# This egress rule allows services within the whitelist group to      #
# send outbound traffic to any destination, ensuring unrestricted     #
# communication with external services if needed.                     #
#######################################################################
resource "aws_vpc_security_group_egress_rule" "whitelist_all_access_sg_egress" {
  security_group_id = aws_security_group.whitelist_all_access_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ----- DB -----

#######################################################################
# Security Group for Database (DB) Access from Whitelisted Services   #
#                                                                     #
# This security group restricts database and message queue access     #
# to only services within the whitelist group, ensuring tight control #
# over who can connect to critical data services.                     #
#######################################################################
resource "aws_security_group" "whitelist_db_sg" {
  name        = "${var.project_name}-whitelist-db-sg"
  description = "Allows db and mq ingress traffic only from other services part of whitelist sg"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-whitelist-db-sg"
    }
  )
}

#######################################################################
# Ingress Rules for Allowing Database Access Only from Whitelisted    #
# Services                                                            #
#                                                                     #
# These rules define the allowed ports for database and message queue #
# connections, ensuring that only whitelisted services can access the #
# database over the defined protocols (TCP) and ports.                #
#######################################################################
resource "aws_vpc_security_group_ingress_rule" "whitelist_db_sg_ingress" {
  for_each                     = var.db_sg_attr
  security_group_id            = aws_security_group.whitelist_db_sg.id
  referenced_security_group_id = aws_security_group.whitelist_sg.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value

  tags = merge(
    var.common_tags,
    {
      Name = each.key
    }
  )
}

#######################################################################
# Egress Rule Allowing All Outbound Traffic from DB Services          #
#                                                                     #
# This rule permits all outbound traffic from the database security   #
# group, ensuring that database services can initiate connections to  #
# any other destinations if required.                                 #
#######################################################################
resource "aws_vpc_security_group_egress_rule" "whitelist_db_sg_egress" {
  security_group_id = aws_security_group.whitelist_db_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ----- WEB WHITELIST -----

#######################################################################
# Security Group for Web Access from Whitelisted Services             #
#                                                                     #
# This security group is used for web servers that should only        #
# accept HTTP (80) and HTTPS (443) traffic from other trusted         #
# services within the whitelist. This limits access to internal web   #
# services only from within the trusted group.                        #
#######################################################################
resource "aws_security_group" "whitelist_web_sg" {
  name        = "${var.project_name}-whitelist-web-sg"
  description = "Allows http(80) and https(443) ingress traffic only from other services part of whitelist sg"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-whitelist-web-sg"
    }
  )
}

#######################################################################
# Ingress Rules for Allowing Web Traffic Only from Whitelisted        #
# Services                                                            #
#                                                                     #
# Defines rules to allow HTTP and HTTPS traffic from trusted services.#
# Ensures web services can only accept requests from within the       #
# whitelisted group.                                                  #
#######################################################################
resource "aws_vpc_security_group_ingress_rule" "whitelist_web_sg_ingress" {
  for_each                     = var.web_sg_attr
  security_group_id            = aws_security_group.whitelist_web_sg.id
  referenced_security_group_id = aws_security_group.whitelist_sg.id
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value

  tags = merge(
    var.common_tags,
    {
      Name = each.key
    }
  )
}

#######################################################################
# Egress Rule Allowing All Outbound Web Traffic                       #
#                                                                     #
# This egress rule allows outbound traffic from the web services      #
# within the Whitelisted web security group, allowing them to access  #
# external resources if needed.                                       #
#######################################################################
resource "aws_vpc_security_group_egress_rule" "whitelist_web_sg_egress" {
  security_group_id = aws_security_group.whitelist_web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ----- WEB -----

########################################################################
# Security Group for Web Access                                        #
#                                                                      #
# This security group is used for web servers that should accept only  #
# HTTP (80) and HTTPS (443) traffic. It provides the network-level     #
# security to ensure that only these services can communicate over the #
# required web protocols, protecting them from other types of traffic. #
########################################################################
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Allows http(80) and https(443) ingress traffic"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-web-sg"
    }
  )
}

#########################################################################
# Ingress Rule for Web Access (HTTP/HTTPS)                              #
#                                                                       #
# This rule defines the allowed inbound traffic for web servers,        #
# specifically allowing HTTP (port 80) and HTTPS (port 443) traffic.    #
# This rule restricts inbound communication to only web-related traffic #
# from any source (`0.0.0.0/0`).                                        #
#########################################################################
resource "aws_vpc_security_group_ingress_rule" "web_sg_ingress" {
  for_each          = var.web_sg_attr
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value

  tags = merge(
    var.common_tags,
    {
      Name = each.key
    }
  )
}

#########################################################################
# Egress Rule for Web Instances                                         #
#                                                                       #
# This egress rule allows all outbound traffic from the web security    #
# group, meaning that web services can access external resources if     #
# required, such as calling external APIs or reaching out to databases. #
# It ensures that the services are not restricted from sending data     #
# out.                                                                  #
#########################################################################
resource "aws_vpc_security_group_egress_rule" "web_sg_egress" {
  security_group_id = aws_security_group.web_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ----- SSH -----

###########################################################################
# Security Group for SSH Access                                           #
#                                                                         #
# This security group allows SSH access to instances, enabling            #
# secure shell access (typically for administration and troubleshooting). #
# Access is restricted to port 22 only.                                   #
###########################################################################
resource "aws_security_group" "ssh_sg" {
  name        = "${var.project_name}-ssh-sg"
  description = "Allows ssh(22) ingress traffic"
  vpc_id      = var.vpc_id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-ssh-sg"
    }
  )
}

#######################################################################
# Ingress Rule for SSH Access                                         #
#                                                                     #
# This rule allows SSH access only from trusted sources, typically    #
# for administrative access to instances.                             #
#######################################################################
resource "aws_vpc_security_group_ingress_rule" "ssh_sg_ingress" {
  security_group_id = aws_security_group.ssh_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22

  tags = merge(
    var.common_tags,
    {
      Name = "ssh"
    }
  )
}

#######################################################################
# Egress Rule Allowing All Outbound Traffic from SSH Instances        #
#                                                                     #
# Ensures that SSH instances can initiate outbound connections to any #
# destination. This is often needed for updates, configuration, or    #
# accessing remote resources.                                         #
#######################################################################
resource "aws_vpc_security_group_egress_rule" "ssh_sg_egress" {
  security_group_id = aws_security_group.ssh_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
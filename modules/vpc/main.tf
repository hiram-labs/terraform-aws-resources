#######################################################################
# Virtual Private Cloud (VPC) Configuration                           #
#                                                                     #
# This section configures the primary networking infrastructure,      #
# creating a VPC with DNS support, multiple subnets (both public and  #
# private), and the necessary routing components (NAT gateway,        #
# Internet gateway, and route tables) for efficient network access.   #
# The configuration enables scalable and isolated environments for    #
# various AWS resources.                                              #
#######################################################################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-main-vpc"
  }
}

#######################################################################
# Availability Zones Data Source                                      #
#                                                                     #
# This data block fetches available Availability Zones in the AWS     #
# region to be used in subnet creation.                               #
#######################################################################
data "aws_availability_zones" "available" {
  state = "available"
}

########################################################################
# Public Subnet Configuration                                          #
#                                                                      #
# Creates multiple public subnets spread across different Availability #
# Zones within the VPC. These subnets are meant to host publicly       #
# accessible resources, such as web servers, and will be associated    #
# with a route table connected to an Internet Gateway for external     #
# access.                                                              #
########################################################################
resource "aws_subnet" "public" {
  count = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index + 1)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index}"
  }
}

#########################################################################
# Private Subnet Configuration                                          #
#                                                                       #
# Creates multiple private subnets spread across different Availability #
# Zones for hosting internal resources (e.g., databases). These subnets #
# are associated with a route table that routes outbound traffic via    #
# a NAT Gateway, allowing private resources to access the internet.     #
#########################################################################
resource "aws_subnet" "private" {
  count = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index + 4)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index}"
  }
}

########################################################################
# Shuffle Public Subnets to Ensure Random Assignment for NAT Gateway   #
#                                                                      #
# This resource ensures that a random public subnet is selected for    #
# deploying the NAT Gateway, helping to distribute the load.           #
########################################################################
resource "random_shuffle" "public_subnet_shuffle" {
  input        = flatten([for subnet in aws_subnet.public : subnet.id])
  result_count = 1
}

########################################################################
# Shuffle Private Subnets to Ensure Random Assignment for Route Table  #
#                                                                      #
# Similar to public subnets, this ensures a random private subnet is   #
# selected to associate with the route table, supporting dynamic       #
# infrastructure setups.                                               #
########################################################################
resource "random_shuffle" "private_subnet_shuffle" {
  input        = flatten([for subnet in aws_subnet.private : subnet.id])
  result_count = 1
}

#######################################################################
# Elastic IP for NAT Gateway                                          #
#                                                                     #
# This resource provisions an Elastic IP (EIP) for the NAT Gateway,   #
# which is required for routing internet-bound traffic from private   #
# subnets. The allocation of this IP depends on the creation of a NAT #
# Gateway.                                                            #
#######################################################################
resource "aws_eip" "nat_eip" {
  count    = var.use_nat_gateway ? 1 : 0
  domain   = "vpc"
}

########################################################################
# Internet Gateway Configuration                                       #
#                                                                      #
# The Internet Gateway allows resources in the VPC (especially those   #
# in public subnets) to communicate with the internet. It is connected #
# to the VPC and facilitates inbound and outbound traffic.             #
########################################################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

##########################################################################
# NAT Gateway Configuration                                              #
#                                                                        #
# The NAT Gateway enables instances in private subnets to access the     #
# internet. It uses the allocated Elastic IP for internet-facing traffic #
# while ensuring private subnets remain isolated from direct internet    #
# access. This resource is only created if specified in the variables.   #
##########################################################################
resource "aws_nat_gateway" "ngw" {
  count = var.use_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = random_shuffle.public_subnet_shuffle.result[0]

  tags = {
    Name = "${var.project_name}-ngw"
  }
  depends_on = [aws_internet_gateway.igw]
}

########################################################################
# Public Route Table Configuration                                     #
#                                                                      #
# The route table for public subnets is configured to route all        #
# outbound traffic (0.0.0.0/0) to the Internet Gateway, allowing       #
# internet access for resources like web servers in the public subnet. #
########################################################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

#######################################################################
# Private Route Table Configuration                                   #
#                                                                     #
# The route table for private subnets is configured to route traffic  #
# to the NAT Gateway (if created), allowing private resources to      #
# access the internet while keeping them isolated from direct access. #
#######################################################################
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.use_nat_gateway ? [1] : []
    content {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_nat_gateway.ngw[0].id
    }
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

#######################################################################
# Route Table Association for Public Subnets                          #
#                                                                     #
# Associates the public subnets with the public route table to allow  #
# traffic routing to the Internet Gateway.                            #
#######################################################################
resource "aws_route_table_association" "public_association" {
  count = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

#######################################################################
# Route Table Association for Private Subnets                         #
#                                                                     #
# Associates the private subnets with the private route table to      #
# route internet-bound traffic through the NAT Gateway.               #
#######################################################################
resource "aws_route_table_association" "private_association" {
  count = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

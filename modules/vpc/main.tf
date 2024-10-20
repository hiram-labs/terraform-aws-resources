######
# vpc
######
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-main-vpc"
  }
}

#########
# subnets
#########
data "aws_availability_zones" "available" {
  state = "available"
}
resource "aws_subnet" "public" {
  count = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index + 1)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index}"
  }
}
resource "aws_subnet" "private" {
  count = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index + 4)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index}"
  }
}
resource "random_shuffle" "public_subnet_shuffle" {
  input        = flatten([for subnet in aws_subnet.public : subnet.id])
  result_count = 1
}
resource "random_shuffle" "private_subnet_shuffle" {
  input        = flatten([for subnet in aws_subnet.private : subnet.id])
  result_count = 1
}

##########
# gateways
##########
resource "aws_eip" "nat_eip" {
  domain   = "vpc"
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = random_shuffle.public_subnet_shuffle.result[0]

  tags = {
    Name = "${var.project_name}-ngw"
  }
  depends_on = [aws_internet_gateway.igw]
}

#############
# route-table
#############
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
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw.id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}
resource "aws_route_table_association" "public_association" {
  count = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "private_association" {
  count = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
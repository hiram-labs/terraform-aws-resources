output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "random_public_subnet" {
  description = "Randomly selected public subnet ID"
  value       = random_shuffle.public_subnet_shuffle.result[0]
}

output "random_private_subnet" {
  description = "Randomly selected private subnet ID"
  value       = random_shuffle.private_subnet_shuffle.result[0]
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (if created)"
  value       = var.use_nat_gateway ? aws_nat_gateway.ngw[0].id : null
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway (if created)"
  value       = var.use_nat_gateway ? aws_eip.nat_eip[0].public_ip : null
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = data.aws_availability_zones.available.names
}

output "flow_logs_log_group" {
  description = "CloudWatch log group for VPC Flow Logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.name
}

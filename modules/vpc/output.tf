output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = aws_subnet.public[*].id
}

output "private_subnets" {
  value = aws_subnet.private[*].id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "random_public_subnet" {
  value = random_shuffle.public_subnet_shuffle.result[0]
}

output "random_private_subnet" {
  value = random_shuffle.private_subnet_shuffle.result[0]
}

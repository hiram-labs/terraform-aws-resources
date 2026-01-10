output "instance_public_ips" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.main.public_ip
}

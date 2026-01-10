output "whitelist_sg_id" {
  description = "ID of the whitelist security group"
  value       = aws_security_group.whitelist_sg.id
}

output "whitelist_all_access_sg_id" {
  description = "ID of the whitelist all-access security group"
  value       = aws_security_group.whitelist_all_access_sg.id
}

output "whitelist_db_sg_id" {
  description = "ID of the whitelist database security group"
  value       = aws_security_group.whitelist_db_sg.id
}

output "whitelist_web_sg_id" {
  description = "ID of the whitelist web security group"
  value       = aws_security_group.whitelist_web_sg.id
}

output "web_sg_id" {
  description = "ID of the web security group (public HTTP/HTTPS)"
  value       = aws_security_group.web_sg.id
}

output "ssh_sg_id" {
  description = "ID of the SSH security group"
  value       = aws_security_group.ssh_sg.id
}

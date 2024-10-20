output "whitelist_sg_id" {
  value = aws_security_group.whitelist_sg.id
}

output "whitelist_all_access_sg_id" {
  value = aws_security_group.whitelist_all_access_sg.id
}

output "whitelist_db_sg_id" {
  value = aws_security_group.whitelist_db_sg.id
}

output "whitelist_web_sg_id" {
  value = aws_security_group.whitelist_web_sg.id
}

output "web_sg_id" {
  value = aws_security_group.web_sg.id
}

output "ssh_sg_id" {
  value = aws_security_group.ssh_sg.id
}

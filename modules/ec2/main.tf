###############
# access policy
###############
resource "aws_iam_role" "main_ec2_role" {
  name               = "${var.project_name}-EC2-access-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}
resource "aws_iam_policy" "extend_access_policy" {
  for_each    = var.access_policies
  name        = each.key
  description = "Policy to allow EC2 instances access to required resources"
  policy      = file(each.value["path"])
}
resource "aws_iam_role_policy_attachment" "extend_access_policy_attachment" {
  for_each    = var.access_policies
  role        = aws_iam_role.main_ec2_role.name
  policy_arn  = aws_iam_policy.extend_access_policy[each.key].arn
}
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${var.project_name}-ec2-instance-profile"
  role = aws_iam_role.main_ec2_role.name
}

#####
# EC2
#####
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
resource "aws_key_pair" "main_key" {
  key_name   = "main-key"
  public_key = fileexists(var.ssh_public_key) ? file(var.ssh_public_key) : var.ssh_public_key
}
resource "aws_instance" "main" {
  instance_type               = "t2.micro"
  ami                         = data.aws_ami.ubuntu.id
  key_name                    = aws_key_pair.main_key.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = var.security_groups
  associate_public_ip_address = true

  instance_market_options {
    market_type = "spot"
  }

  tags = {
    Name = "${var.project_name}-main"
  }
}
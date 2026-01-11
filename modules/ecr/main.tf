###############################################################
# Amazon Elastic Container Registry (ECR)                     #
#                                                             #
# Private container image registry for storing Docker images. #
# Enables private ECS tasks to pull images without requiring  #
# NAT Gateway when VPC endpoints are configured.              #
#                                                             #
# Features:                                                   #
# - Image scanning on push for vulnerability detection        #
# - Lifecycle policies for automated image cleanup            #
# - Encryption at rest with AES256                            #
# - Tag mutability for flexible image management              #
###############################################################
resource "aws_ecr_repository" "repositories" {
  for_each = var.repositories

  name                 = "${var.project_name}-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-${each.key}"
    }
  )
}

###############################################################
# ECR Lifecycle Policy                                        #
#                                                             #
# Automatically manages image retention:                      #
# - Keeps the most recent N tagged images                     #
# - Expires untagged images after N days                      #
# - Reduces storage costs while maintaining availability      #
###############################################################
resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  for_each = var.repositories

  repository = aws_ecr_repository.repositories[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${each.value.keep_image_count} images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = each.value.keep_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after ${each.value.untagged_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = each.value.untagged_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

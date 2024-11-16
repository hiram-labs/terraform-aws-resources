terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
}

module "r53" {
  source       = "./modules/r53"
  project_name = var.project_name
  domain_name  = var.domain_name
}

module "ses" {
  source            = "./modules/ses"
  project_name      = var.project_name
  domain_name       = var.domain_name
  aws_region        = var.aws_region
  route53_zone_id   = module.r53.route53_zone_id
}

module "vpc" {
  source       = "./modules/vpc"
  project_name = var.project_name
}

module "sg" {
  source       = "./modules/sg"
  project_name = var.project_name
  db_sg_attr   = var.db_sg_attr
  web_sg_attr  = var.web_sg_attr
  vpc_id       = module.vpc.vpc_id
}

module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnets    = module.vpc.public_subnets
  route53_zone_id   = module.r53.route53_zone_id
  route53_zone_name = module.r53.route53_zone_name
  certificate_arn   = module.r53.certificate_arn
  security_groups   = [module.sg.whitelist_sg_id, module.sg.web_sg_id]
}

module "ecs" {
  source                     = "./modules/ecs"
  project_name               = var.project_name
  aws_region                 = var.aws_region
  autoscale_max_capacity     = var.autoscale_max_capacity
  ecs_task_cpu               = var.ecs_task_cpu
  ecs_task_memory            = var.ecs_task_memory
  public_task_definitions    = var.public_task_definitions
  private_task_definitions   = var.private_task_definitions
  vpc_id                     = module.vpc.vpc_id
  web_ip_tg_arn              = module.alb.web_ip_tg_arn
  public_subnets             = module.vpc.public_subnets
  private_subnets            = module.vpc.private_subnets
  public_td_security_groups  = [module.sg.whitelist_sg_id, module.sg.whitelist_web_sg_id]
  private_td_security_groups = [module.sg.whitelist_sg_id, module.sg.whitelist_all_access_sg_id]
}

module "ec2" {
  source           = "./modules/ec2"
  project_name     = var.project_name
  ssh_public_key   = var.ssh_public_key
  public_subnet_id = module.vpc.random_public_subnet
  security_groups  = [module.sg.whitelist_sg_id, module.sg.ssh_sg_id]
}

module "s3" {
  source       = "./modules/s3"
  project_name = var.project_name
}

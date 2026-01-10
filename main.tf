provider "aws" {
  region = var.aws_region
}

module "r53" {
  source       = "./modules/r53"
  project_name = var.project_name
  domain_name  = var.domain_name
  common_tags  = local.common_tags
}

module "ses" {
  source            = "./modules/ses"
  project_name      = var.project_name
  domain_name       = var.domain_name
  aws_region        = var.aws_region
  route53_zone_id   = module.r53.route53_zone_id
  common_tags       = local.common_tags
}

module "vpc" {
  source             = "./modules/vpc"
  project_name       = var.project_name
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  use_nat_gateway    = var.use_nat_gateway
  log_retention_days = var.log_retention_days[var.environment]
  sns_topic_arn      = module.sns.sns_topic_arn
  common_tags        = local.common_tags
}

module "sg" {
  source       = "./modules/sg"
  project_name = var.project_name
  db_sg_attr   = var.db_sg_attr
  web_sg_attr  = var.web_sg_attr
  vpc_id       = module.vpc.vpc_id
  common_tags  = local.common_tags
}

module "alb" {
  source                 = "./modules/alb"
  project_name           = var.project_name
  aws_region             = var.aws_region
  use_alb_waf            = var.use_alb_waf
  vpc_id                 = module.vpc.vpc_id
  public_subnets         = module.vpc.public_subnets
  private_subnets        = module.vpc.private_subnets
  public_route_table_id  = module.vpc.public_route_table_id
  private_route_table_id = module.vpc.private_route_table_id
  route53_zone_id        = module.r53.route53_zone_id
  route53_zone_name      = module.r53.route53_zone_name
  certificate_arn        = module.r53.certificate_arn
  sns_topic_arn          = module.sns.sns_topic_arn
  security_groups        = [module.sg.whitelist_sg_id, module.sg.web_sg_id]
  common_tags            = local.common_tags
}

module "ecs" {
  source                     = "./modules/ecs"
  project_name               = var.project_name
  aws_region                 = var.aws_region
  autoscale_max_capacity     = var.autoscale_max_capacity
  public_task_definitions    = var.public_task_definitions
  private_task_definitions   = var.private_task_definitions
  log_retention_days         = var.log_retention_days[var.environment]
  vpc_id                     = module.vpc.vpc_id
  web_ip_tg_arn              = module.alb.web_ip_tg_arn
  public_subnets             = module.vpc.public_subnets
  private_subnets            = module.vpc.private_subnets
  sns_topic_arn              = module.sns.sns_topic_arn
  public_td_security_groups  = [module.sg.whitelist_sg_id, module.sg.whitelist_web_sg_id]
  private_td_security_groups = [module.sg.whitelist_sg_id, module.sg.whitelist_all_access_sg_id]
  common_tags                = local.common_tags
}

module "ec2" {
  source           = "./modules/ec2"
  project_name     = var.project_name
  ssh_public_key   = var.ssh_public_key
  public_subnet_id = module.vpc.random_public_subnet
  security_groups  = [module.sg.whitelist_sg_id, module.sg.ssh_sg_id]
  common_tags      = local.common_tags
}

module "s3" {
  source       = "./modules/s3"
  project_name = var.project_name
  common_tags  = local.common_tags
}


module "db" {
  source          = "./modules/db"
  project_name    = var.project_name
  private_subnets = module.vpc.private_subnets
  sns_topic_arn   = module.sns.sns_topic_arn
  security_groups = [module.sg.whitelist_sg_id, module.sg.whitelist_db_sg_id]
  common_tags     = local.common_tags
}

module "sns" {
  source       = "./modules/sns"
  project_name = var.project_name
  alert_email  = var.alert_email
  common_tags  = local.common_tags
}

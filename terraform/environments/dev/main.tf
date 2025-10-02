terraform {
  required_version = ">= 1.5.0"
}

locals {
  project_name = "imageunderstander"
  environment  = "dev"
  aws_region   = var.aws_region

  # Network configuration
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["${local.aws_region}a", "${local.aws_region}b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  # Common tags
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  project_name         = local.project_name
  environment          = local.environment
  aws_region           = local.aws_region
  vpc_cidr             = local.vpc_cidr
  availability_zones   = local.availability_zones
  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs
}

# Storage Module (S3, Secrets Manager, CloudWatch Logs)
module "storage" {
  source = "../../modules/storage"

  project_name         = local.project_name
  environment          = local.environment
  allowed_cors_origins = var.allowed_cors_origins
  rds_master_username  = var.rds_master_username
  llm_api_key          = var.llm_api_key
  log_retention_days   = var.log_retention_days
}

# Security Module (Security Groups, IAM Roles)
module "security" {
  source = "../../modules/security"

  project_name          = local.project_name
  environment           = local.environment
  vpc_id                = module.networking.vpc_id
  s3_bucket_arn         = module.storage.s3_bucket_arn
  secrets_manager_arns  = module.storage.secrets_manager_arns
}

# Database Module (RDS MySQL)
module "database" {
  source = "../../modules/database"

  project_name            = local.project_name
  environment             = local.environment
  private_subnet_ids      = module.networking.private_subnet_ids
  rds_security_group_id   = module.security.rds_security_group_id
  db_master_username      = module.storage.rds_master_username
  db_master_password      = module.storage.rds_master_password
  database_name           = var.database_name
  mysql_engine_version    = var.mysql_engine_version
  db_instance_class       = var.db_instance_class
  db_allocated_storage    = var.db_allocated_storage
  multi_az                = var.db_multi_az
  backup_retention_period = var.db_backup_retention_period
  skip_final_snapshot     = var.db_skip_final_snapshot
  deletion_protection     = var.db_deletion_protection
}

# Compute Module (EC2 Instances)
module "compute" {
  source = "../../modules/compute"

  project_name                    = local.project_name
  environment                     = local.environment
  private_subnet_ids              = module.networking.private_subnet_ids
  frontend_security_group_id      = module.security.frontend_security_group_id
  backend_security_group_id       = module.security.backend_security_group_id
  llm_security_group_id           = module.security.llm_security_group_id
  chromadb_security_group_id      = module.security.chromadb_security_group_id
  frontend_instance_profile_name  = module.security.frontend_instance_profile_name
  backend_instance_profile_name   = module.security.backend_instance_profile_name
  llm_instance_profile_name       = module.security.llm_instance_profile_name
  chromadb_instance_profile_name  = module.security.chromadb_instance_profile_name
  cloudwatch_log_groups           = module.storage.cloudwatch_log_group_names
  s3_bucket_name                  = module.storage.s3_bucket_name
  db_endpoint                     = module.database.db_instance_endpoint
  db_name                         = module.database.db_name
  rds_secret_name                 = module.storage.rds_master_password_secret_name
  app_secrets_name                = module.storage.app_secrets_name
  frontend_instance_type          = var.frontend_instance_type
  backend_instance_type           = var.backend_instance_type
  llm_instance_type               = var.llm_instance_type
  chromadb_instance_type          = var.chromadb_instance_type
  frontend_spot_max_price         = var.frontend_spot_max_price
  backend_spot_max_price          = var.backend_spot_max_price
  llm_ebs_volume_size             = var.llm_ebs_volume_size
  chromadb_ebs_volume_size        = var.chromadb_ebs_volume_size

  depends_on = [
    module.database,
    module.storage
  ]
}

# ACM Certificate for HTTPS
resource "aws_acm_certificate" "main" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.project_name}-${local.environment}-cert"
    }
  )
}

# Route53 Module (DNS Management)
module "route53" {
  count  = var.create_hosted_zone ? 1 : 0
  source = "../../modules/route53"

  project_name                        = local.project_name
  environment                         = local.environment
  domain_name                         = var.domain_name
  alb_dns_name                        = module.loadbalancer.alb_dns_name
  alb_zone_id                         = module.loadbalancer.alb_zone_id
  certificate_domain_validation_options = aws_acm_certificate.main.domain_validation_options
  create_www_record                   = var.create_www_record
  create_api_record                   = var.create_api_record
  create_health_check                 = var.create_route53_health_check
  health_check_path                   = var.health_check_path

  depends_on = [
    module.loadbalancer,
    aws_acm_certificate.main
  ]
}

# ACM certificate validation (automatic if using Route53)
resource "aws_acm_certificate_validation" "main" {
  count                   = var.create_hosted_zone ? 1 : 0
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = module.route53[0].cert_validation_record_fqdns

  timeouts {
    create = "10m"
  }

  depends_on = [module.route53]
}

# Load Balancer Module
module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project_name               = local.project_name
  environment                = local.environment
  vpc_id                     = module.networking.vpc_id
  public_subnet_ids          = module.networking.public_subnet_ids
  alb_security_group_id      = module.security.alb_security_group_id
  frontend_instance_id       = module.compute.frontend_instance_id
  acm_certificate_arn        = aws_acm_certificate.main.arn
  enable_deletion_protection = var.alb_deletion_protection

  depends_on = [
    aws_acm_certificate.main,
    module.compute
  ]
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "domain_name" {
  description = "Domain name for ACM certificate, ALB, and Route53"
  type        = string
}

variable "create_hosted_zone" {
  description = "Create Route53 hosted zone for the domain (set false if using external DNS)"
  type        = bool
  default     = false
}

variable "create_www_record" {
  description = "Create www subdomain record pointing to ALB (only if create_hosted_zone is true)"
  type        = bool
  default     = true
}

variable "create_api_record" {
  description = "Create api subdomain record pointing to ALB (only if create_hosted_zone is true)"
  type        = bool
  default     = false
}

variable "create_route53_health_check" {
  description = "Create Route53 health check for ALB endpoint (recommended for production)"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Path for Route53 health check"
  type        = string
  default     = "/health"
}

variable "allowed_cors_origins" {
  description = "List of allowed CORS origins for S3 bucket"
  type        = list(string)
  default     = ["*"]
}

variable "rds_master_username" {
  description = "Master username for RDS database"
  type        = string
  default     = "admin"
}

variable "llm_api_key" {
  description = "API key for LLM service (optional, can be updated later)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "database_name" {
  description = "Name of the default database"
  type        = string
  default     = "imageunderstander"
}

variable "mysql_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0.39"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB for RDS"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = true
}

variable "db_backup_retention_period" {
  description = "Number of days to retain RDS backups"
  type        = number
  default     = 7
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot on RDS deletion (use true for dev)"
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = "Enable deletion protection for RDS (use false for dev)"
  type        = bool
  default     = false
}

variable "frontend_instance_type" {
  description = "Instance type for frontend"
  type        = string
  default     = "t4g.micro"
}

variable "backend_instance_type" {
  description = "Instance type for backend"
  type        = string
  default     = "t4g.micro"
}

variable "llm_instance_type" {
  description = "Instance type for LLM service"
  type        = string
  default     = "g5.xlarge"
}

variable "chromadb_instance_type" {
  description = "Instance type for ChromaDB"
  type        = string
  default     = "t3.medium"
}

variable "frontend_spot_max_price" {
  description = "Maximum spot price for frontend instances"
  type        = string
  default     = "0.01"
}

variable "backend_spot_max_price" {
  description = "Maximum spot price for backend instances"
  type        = string
  default     = "0.01"
}

variable "llm_ebs_volume_size" {
  description = "EBS volume size in GB for LLM model storage"
  type        = number
  default     = 50
}

variable "chromadb_ebs_volume_size" {
  description = "EBS volume size in GB for ChromaDB data storage"
  type        = number
  default     = 100
}

variable "alb_deletion_protection" {
  description = "Enable deletion protection for ALB (use false for dev)"
  type        = bool
  default     = false
}

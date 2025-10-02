variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for instances"
  type        = list(string)
}

variable "frontend_security_group_id" {
  description = "Security group ID for frontend instances"
  type        = string
}

variable "backend_security_group_id" {
  description = "Security group ID for backend instances"
  type        = string
}

variable "llm_security_group_id" {
  description = "Security group ID for LLM service instances"
  type        = string
}

variable "chromadb_security_group_id" {
  description = "Security group ID for ChromaDB instances"
  type        = string
}

variable "frontend_instance_profile_name" {
  description = "IAM instance profile name for frontend instances"
  type        = string
}

variable "backend_instance_profile_name" {
  description = "IAM instance profile name for backend instances"
  type        = string
}

variable "llm_instance_profile_name" {
  description = "IAM instance profile name for LLM service instances"
  type        = string
}

variable "chromadb_instance_profile_name" {
  description = "IAM instance profile name for ChromaDB instances"
  type        = string
}

variable "cloudwatch_log_groups" {
  description = "Map of CloudWatch log group names"
  type = object({
    frontend = string
    backend  = string
    llm      = string
    chromadb = string
  })
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for uploads"
  type        = string
}

variable "db_endpoint" {
  description = "RDS database endpoint"
  type        = string
}

variable "db_name" {
  description = "RDS database name"
  type        = string
}

variable "rds_secret_name" {
  description = "Name of the Secrets Manager secret for RDS credentials"
  type        = string
}

variable "app_secrets_name" {
  description = "Name of the Secrets Manager secret for application secrets"
  type        = string
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

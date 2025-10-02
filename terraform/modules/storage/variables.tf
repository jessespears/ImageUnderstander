variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
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

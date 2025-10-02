# S3 Bucket for Image and Document Storage
resource "aws_s3_bucket" "uploads" {
  bucket_prefix = "${var.project_name}-${var.environment}-uploads-"

  tags = {
    Name = "${var.project_name}-${var.environment}-uploads"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# S3 Bucket CORS Configuration (for frontend uploads)
resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = var.allowed_cors_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Random password for RDS
resource "random_password" "rds_master_password" {
  length  = 32
  special = true
}

# Secrets Manager - RDS Master Password
resource "aws_secretsmanager_secret" "rds_master_password" {
  name_prefix             = "${var.project_name}-${var.environment}-rds-master-"
  description             = "Master password for RDS MySQL database"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-master-password"
  }
}

resource "aws_secretsmanager_secret_version" "rds_master_password" {
  secret_id = aws_secretsmanager_secret.rds_master_password.id
  secret_string = jsonencode({
    username = var.rds_master_username
    password = random_password.rds_master_password.result
  })
}

# Secrets Manager - Application Secrets
resource "aws_secretsmanager_secret" "app_secrets" {
  name_prefix             = "${var.project_name}-${var.environment}-app-secrets-"
  description             = "Application secrets (API keys, etc.)"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-app-secrets"
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    llm_api_key    = var.llm_api_key != "" ? var.llm_api_key : "PLACEHOLDER_UPDATE_AFTER_DEPLOYMENT"
    jwt_secret_key = random_password.jwt_secret.result
    encryption_key = random_password.encryption_key.result
  })
}

# Random JWT secret
resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

# Random encryption key
resource "random_password" "encryption_key" {
  length  = 32
  special = false
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}/frontend"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend-logs"
  }
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}/backend"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-backend-logs"
  }
}

resource "aws_cloudwatch_log_group" "llm" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}/llm"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-llm-logs"
  }
}

resource "aws_cloudwatch_log_group" "chromadb" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}/chromadb"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-chromadb-logs"
  }
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # ====================================================================
  # REMOTE STATE BACKEND (S3 + DynamoDB)
  # ====================================================================
  # By default, Terraform stores state locally in terraform.tfstate file.
  # For production and team environments, you should use REMOTE STATE.
  #
  # WHY USE REMOTE STATE?
  # 1. COLLABORATION: Multiple team members can work on the same infrastructure
  # 2. LOCKING: Prevents concurrent modifications that could corrupt state
  # 3. BACKUP: State is stored in S3 with versioning and encryption
  # 4. SECURITY: State files contain sensitive data (passwords, IPs, etc.)
  # 5. AUTOMATION: CI/CD pipelines can access shared state
  #
  # HOW IT WORKS:
  # - S3 bucket: Stores the terraform.tfstate file
  # - DynamoDB table: Provides state locking (prevents race conditions)
  # - Encryption: State is encrypted at rest in S3
  # - Versioning: S3 versioning allows you to recover from mistakes
  #
  # SETUP INSTRUCTIONS:
  # 1. Create an S3 bucket:
  #      aws s3 mb s3://your-terraform-state-bucket --region us-east-1
  #      aws s3api put-bucket-versioning --bucket your-terraform-state-bucket \
  #        --versioning-configuration Status=Enabled
  #      aws s3api put-bucket-encryption --bucket your-terraform-state-bucket \
  #        --server-side-encryption-configuration \
  #        '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  #
  # 2. Create a DynamoDB table for locking:
  #      aws dynamodb create-table \
  #        --table-name terraform-state-lock \
  #        --attribute-definitions AttributeName=LockID,AttributeType=S \
  #        --key-schema AttributeName=LockID,KeyType=HASH \
  #        --billing-mode PAY_PER_REQUEST \
  #        --region us-east-1
  #
  # 3. Uncomment the backend block below and update values
  # 4. Run: terraform init -migrate-state
  #
  # IMPORTANT: The backend block CANNOT use variables. Values must be hardcoded
  # or provided via -backend-config flags during terraform init.
  #
  # ====================================================================
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"        # REPLACE with your bucket name
  #   key            = "imageunderstander/terraform.tfstate" # Path within bucket
  #   region         = "us-east-1"                          # AWS region for S3 bucket
  #   encrypt        = true                                  # Encrypt state at rest
  #   dynamodb_table = "terraform-state-lock"               # REPLACE with your table name
  #
  #   # Optional: Enable state locking with a specific lock timeout
  #   # lock_timeout = "5m"
  #
  #   # Optional: Use KMS encryption instead of AES256
  #   # kms_key_id = "arn:aws:kms:us-east-1:ACCOUNT_ID:key/KEY_ID"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ImageUnderstander"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

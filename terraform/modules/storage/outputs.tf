output "s3_bucket_id" {
  description = "ID of the S3 bucket for uploads"
  value       = aws_s3_bucket.uploads.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for uploads"
  value       = aws_s3_bucket.uploads.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for uploads"
  value       = aws_s3_bucket.uploads.bucket
}

output "rds_master_password_secret_arn" {
  description = "ARN of the Secrets Manager secret for RDS master password"
  value       = aws_secretsmanager_secret.rds_master_password.arn
}

output "rds_master_password_secret_name" {
  description = "Name of the Secrets Manager secret for RDS master password"
  value       = aws_secretsmanager_secret.rds_master_password.name
}

output "rds_master_username" {
  description = "Master username for RDS database"
  value       = var.rds_master_username
}

output "rds_master_password" {
  description = "Master password for RDS database (sensitive)"
  value       = random_password.rds_master_password.result
  sensitive   = true
}

output "app_secrets_arn" {
  description = "ARN of the Secrets Manager secret for application secrets"
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "app_secrets_name" {
  description = "Name of the Secrets Manager secret for application secrets"
  value       = aws_secretsmanager_secret.app_secrets.name
}

output "secrets_manager_arns" {
  description = "List of all Secrets Manager ARNs"
  value = [
    aws_secretsmanager_secret.rds_master_password.arn,
    aws_secretsmanager_secret.app_secrets.arn
  ]
}

output "cloudwatch_log_group_names" {
  description = "Map of CloudWatch log group names"
  value = {
    frontend = aws_cloudwatch_log_group.frontend.name
    backend  = aws_cloudwatch_log_group.backend.name
    llm      = aws_cloudwatch_log_group.llm.name
    chromadb = aws_cloudwatch_log_group.chromadb.name
  }
}

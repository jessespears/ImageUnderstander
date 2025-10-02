variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for IAM policies"
  type        = string
}

variable "secrets_manager_arns" {
  description = "List of Secrets Manager ARNs for IAM policies"
  type        = list(string)
}

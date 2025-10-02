output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "frontend_security_group_id" {
  description = "Security group ID for frontend instances"
  value       = aws_security_group.frontend.id
}

output "backend_security_group_id" {
  description = "Security group ID for backend instances"
  value       = aws_security_group.backend.id
}

output "llm_security_group_id" {
  description = "Security group ID for LLM service instances"
  value       = aws_security_group.llm.id
}

output "chromadb_security_group_id" {
  description = "Security group ID for ChromaDB instances"
  value       = aws_security_group.chromadb.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS database"
  value       = aws_security_group.rds.id
}

output "frontend_instance_profile_name" {
  description = "Instance profile name for frontend instances"
  value       = aws_iam_instance_profile.frontend.name
}

output "backend_instance_profile_name" {
  description = "Instance profile name for backend instances"
  value       = aws_iam_instance_profile.backend.name
}

output "llm_instance_profile_name" {
  description = "Instance profile name for LLM service instances"
  value       = aws_iam_instance_profile.llm.name
}

output "chromadb_instance_profile_name" {
  description = "Instance profile name for ChromaDB instances"
  value       = aws_iam_instance_profile.chromadb.name
}

output "frontend_role_arn" {
  description = "ARN of the frontend IAM role"
  value       = aws_iam_role.frontend.arn
}

output "backend_role_arn" {
  description = "ARN of the backend IAM role"
  value       = aws_iam_role.backend.arn
}

output "llm_role_arn" {
  description = "ARN of the LLM service IAM role"
  value       = aws_iam_role.llm.arn
}

output "chromadb_role_arn" {
  description = "ARN of the ChromaDB IAM role"
  value       = aws_iam_role.chromadb.arn
}

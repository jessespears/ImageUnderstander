output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for uploads"
  value       = module.storage.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.storage.s3_bucket_arn
}

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = module.database.db_instance_endpoint
}

output "rds_secret_name" {
  description = "Name of the Secrets Manager secret for RDS credentials"
  value       = module.storage.rds_master_password_secret_name
}

output "app_secrets_name" {
  description = "Name of the Secrets Manager secret for application secrets"
  value       = module.storage.app_secrets_name
}

output "frontend_instance_id" {
  description = "ID of the frontend instance"
  value       = module.compute.frontend_instance_id
}

output "backend_instance_id" {
  description = "ID of the backend instance"
  value       = module.compute.backend_instance_id
}

output "llm_instance_id" {
  description = "ID of the LLM service instance"
  value       = module.compute.llm_instance_id
}

output "chromadb_instance_id" {
  description = "ID of the ChromaDB instance"
  value       = module.compute.chromadb_instance_id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.loadbalancer.alb_dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer (for Route53)"
  value       = module.loadbalancer.alb_zone_id
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = aws_acm_certificate.main.arn
}

output "acm_certificate_domain_validation_options" {
  description = "Domain validation options for ACM certificate"
  value       = aws_acm_certificate.main.domain_validation_options
}

output "instance_private_ips" {
  description = "Map of instance private IP addresses"
  value       = module.compute.private_ips
}

output "cloudwatch_log_groups" {
  description = "Map of CloudWatch log group names"
  value       = module.storage.cloudwatch_log_group_names
}

output "connection_instructions" {
  description = "Instructions for connecting to instances"
  value = <<-EOT
    To connect to instances via AWS Systems Manager:

    Frontend:
      aws ssm start-session --target ${module.compute.frontend_instance_id}

    Backend:
      aws ssm start-session --target ${module.compute.backend_instance_id}

    LLM Service:
      aws ssm start-session --target ${module.compute.llm_instance_id}

    ChromaDB:
      aws ssm start-session --target ${module.compute.chromadb_instance_id}

    ALB DNS: ${module.loadbalancer.alb_dns_name}

    ${var.create_hosted_zone ? "Route53 Name Servers (update at your domain registrar):" : "Add DNS validation record to your domain:"}
    ${var.create_hosted_zone ? join("\n    ", module.route53[0].name_servers) : "(Check acm_certificate_domain_validation_options output for details)"}
  EOT
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID (if created)"
  value       = var.create_hosted_zone ? module.route53[0].zone_id : null
}

output "route53_name_servers" {
  description = "Route53 name servers (if created) - update these at your domain registrar"
  value       = var.create_hosted_zone ? module.route53[0].name_servers : null
}

output "route53_zone_arn" {
  description = "Route53 hosted zone ARN (if created)"
  value       = var.create_hosted_zone ? module.route53[0].zone_arn : null
}

output "domain_url" {
  description = "Full URL to access the application"
  value       = "https://${var.domain_name}"
}

output "www_url" {
  description = "WWW subdomain URL (if created)"
  value       = var.create_hosted_zone && var.create_www_record ? "https://www.${var.domain_name}" : null
}

output "api_url" {
  description = "API subdomain URL (if created)"
  value       = var.create_hosted_zone && var.create_api_record ? "https://api.${var.domain_name}" : null
}

output "route53_health_check_id" {
  description = "Route53 health check ID (if created)"
  value       = var.create_hosted_zone && var.create_route53_health_check ? module.route53[0].health_check_id : null
}

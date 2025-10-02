output "zone_id" {
  description = "ID of the Route53 hosted zone"
  value       = aws_route53_zone.main.zone_id
}

output "zone_arn" {
  description = "ARN of the Route53 hosted zone"
  value       = aws_route53_zone.main.arn
}

output "name_servers" {
  description = "Name servers for the Route53 hosted zone (update these at your domain registrar)"
  value       = aws_route53_zone.main.name_servers
}

output "zone_name" {
  description = "Name of the Route53 hosted zone"
  value       = aws_route53_zone.main.name
}

output "app_record_fqdn" {
  description = "FQDN of the app A record"
  value       = aws_route53_record.app.fqdn
}

output "www_record_fqdn" {
  description = "FQDN of the www A record (if created)"
  value       = var.create_www_record ? aws_route53_record.www[0].fqdn : null
}

output "api_record_fqdn" {
  description = "FQDN of the api A record (if created)"
  value       = var.create_api_record ? aws_route53_record.api[0].fqdn : null
}

output "cert_validation_record_fqdns" {
  description = "FQDNs of the certificate validation records"
  value       = [for record in aws_route53_record.cert_validation : record.fqdn]
}

output "health_check_id" {
  description = "ID of the Route53 health check (if created)"
  value       = var.create_health_check ? aws_route53_health_check.alb[0].id : null
}

output "health_check_arn" {
  description = "ARN of the Route53 health check (if created)"
  value       = var.create_health_check ? aws_route53_health_check.alb[0].arn : null
}

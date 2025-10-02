variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the Route53 hosted zone"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  type        = string
}

variable "certificate_domain_validation_options" {
  description = "ACM certificate domain validation options for creating validation records"
  type        = set(object({
    domain_name           = string
    resource_record_name  = string
    resource_record_type  = string
    resource_record_value = string
  }))
}

variable "create_www_record" {
  description = "Create www subdomain record pointing to ALB"
  type        = bool
  default     = true
}

variable "create_api_record" {
  description = "Create api subdomain record pointing to ALB"
  type        = bool
  default     = false
}

variable "create_health_check" {
  description = "Create Route53 health check for the ALB endpoint"
  type        = bool
  default     = false
}

variable "health_check_path" {
  description = "Path for Route53 health check"
  type        = string
  default     = "/health"
}

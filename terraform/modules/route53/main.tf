# Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name        = "${var.project_name}-${var.environment}-zone"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ACM Certificate Validation Records
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in var.certificate_domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

# A Record for apex domain pointing to ALB
resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Optional: WWW subdomain
resource "aws_route53_record" "www" {
  count   = var.create_www_record ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Optional: API subdomain pointing to ALB
resource "aws_route53_record" "api" {
  count   = var.create_api_record ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# Health Check for ALB (optional but recommended for production)
resource "aws_route53_health_check" "alb" {
  count             = var.create_health_check ? 1 : 0
  fqdn              = var.alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-health-check"
    Project     = var.project_name
    Environment = var.environment
  }
}

# CloudWatch Alarm for Health Check failures
resource "aws_cloudwatch_metric_alarm" "route53_health_check" {
  count               = var.create_health_check ? 1 : 0
  alarm_name          = "${var.project_name}-${var.environment}-route53-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "Route53 health check failing for ${var.domain_name}"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.alb[0].id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-route53-alarm"
    Project     = var.project_name
    Environment = var.environment
  }
}

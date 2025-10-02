# Route53 DNS Management Module

This module manages DNS configuration for the ImageUnderstander application using AWS Route53.

## Features

- **Hosted Zone Management**: Creates and manages a Route53 hosted zone for your domain
- **Automatic Certificate Validation**: Automatically creates DNS records for ACM certificate validation
- **A Record Management**: Creates A records (aliases) pointing to the Application Load Balancer
- **Subdomain Support**: Optional www and api subdomains
- **Health Checks**: Optional Route53 health checks for monitoring ALB availability
- **CloudWatch Integration**: Alarms for health check failures

## Usage

### Basic Setup (Managed DNS in Route53)

```hcl
module "route53" {
  source = "../../modules/route53"

  project_name  = "imageunderstander"
  environment   = "dev"
  domain_name   = "app.example.com"
  
  # ALB details
  alb_dns_name  = module.loadbalancer.alb_dns_name
  alb_zone_id   = module.loadbalancer.alb_zone_id
  
  # Certificate validation
  certificate_domain_validation_options = aws_acm_certificate.main.domain_validation_options
  
  # Optional subdomains
  create_www_record = true
  create_api_record = false
  
  # Optional health check
  create_health_check = false
  health_check_path   = "/health"
}
```

### With Health Checks (Production)

```hcl
module "route53" {
  source = "../../modules/route53"

  project_name  = "imageunderstander"
  environment   = "prod"
  domain_name   = "app.example.com"
  
  alb_dns_name  = module.loadbalancer.alb_dns_name
  alb_zone_id   = module.loadbalancer.alb_zone_id
  
  certificate_domain_validation_options = aws_acm_certificate.main.domain_validation_options
  
  create_www_record   = true
  create_api_record   = true
  create_health_check = true
  health_check_path   = "/health"
}
```

## How It Works

### 1. Hosted Zone Creation

When you apply this module, it creates a Route53 hosted zone for your domain. AWS will assign 4 name servers to this zone.

**Important**: You MUST update your domain registrar's name servers to point to these Route53 name servers.

### 2. Certificate Validation

The module automatically creates the DNS records needed for ACM certificate validation. This is a CNAME record that proves you own the domain.

### 3. A Records (Aliases)

The module creates A records that point to your Application Load Balancer:
- `app.example.com` → ALB (always created)
- `www.app.example.com` → ALB (optional, if `create_www_record = true`)
- `api.app.example.com` → ALB (optional, if `create_api_record = true`)

These use Route53 aliases, which are free and automatically updated if the ALB changes.

### 4. Health Checks (Optional)

If enabled, creates a Route53 health check that monitors your ALB endpoint over HTTPS. If the health check fails, CloudWatch alarms are triggered.

## Setup Instructions

### Step 1: Apply Terraform

```bash
cd terraform/environments/dev
terraform apply
```

### Step 2: Get Name Servers

After apply completes:

```bash
terraform output route53_name_servers
```

You'll see output like:
```
[
  "ns-123.awsdns-12.com",
  "ns-456.awsdns-45.net",
  "ns-789.awsdns-78.org",
  "ns-012.awsdns-01.co.uk"
]
```

### Step 3: Update Domain Registrar

Go to your domain registrar (GoDaddy, Namecheap, Google Domains, etc.) and update the name servers for your domain to the 4 name servers from Step 2.

**Example for GoDaddy:**
1. Log in to GoDaddy
2. Go to "My Products" → "Domains"
3. Click on your domain
4. Scroll to "Nameservers" → Click "Change"
5. Select "Custom" and enter the 4 name servers
6. Save changes

**DNS propagation takes 1-48 hours**, but typically completes in 1-4 hours.

### Step 4: Verify

Check DNS propagation:

```bash
# Check name servers
dig NS app.example.com

# Check A record
dig A app.example.com

# Should point to your ALB
nslookup app.example.com
```

Or use online tools:
- https://www.whatsmydns.net/
- https://dnschecker.org/

### Step 5: Certificate Validation

Once DNS propagates, ACM will automatically validate your certificate (5-30 minutes). Check status:

```bash
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --query 'Certificate.Status' \
  --output text
```

Should show: `ISSUED`

## DNS Records Created

| Record Type | Name | Value | Purpose |
|-------------|------|-------|---------|
| NS | app.example.com | Route53 name servers | Delegates DNS to Route53 |
| SOA | app.example.com | Route53 SOA record | Zone authority |
| CNAME | _xxxxx.app.example.com | _yyyyy.acm-validations.aws | ACM certificate validation |
| A (Alias) | app.example.com | ALB DNS name | Points domain to load balancer |
| A (Alias) | www.app.example.com | ALB DNS name | WWW subdomain (optional) |
| A (Alias) | api.app.example.com | ALB DNS name | API subdomain (optional) |

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name for resource naming | string | - | yes |
| environment | Environment name (dev, staging, prod) | string | - | yes |
| domain_name | Domain name for Route53 hosted zone | string | - | yes |
| alb_dns_name | DNS name of the Application Load Balancer | string | - | yes |
| alb_zone_id | Zone ID of the Application Load Balancer | string | - | yes |
| certificate_domain_validation_options | ACM certificate validation options | set(object) | - | yes |
| create_www_record | Create www subdomain record | bool | true | no |
| create_api_record | Create api subdomain record | bool | false | no |
| create_health_check | Create Route53 health check | bool | false | no |
| health_check_path | Path for health check | string | "/health" | no |

## Outputs

| Name | Description |
|------|-------------|
| zone_id | ID of the Route53 hosted zone |
| zone_arn | ARN of the Route53 hosted zone |
| name_servers | Name servers for the hosted zone (update at registrar) |
| zone_name | Name of the hosted zone |
| app_record_fqdn | FQDN of the apex domain A record |
| www_record_fqdn | FQDN of the www subdomain (if created) |
| api_record_fqdn | FQDN of the api subdomain (if created) |
| cert_validation_record_fqdns | FQDNs of certificate validation records |
| health_check_id | ID of the Route53 health check (if created) |
| health_check_arn | ARN of the Route53 health check (if created) |

## Cost

**Route53 Pricing (us-east-1):**
- Hosted zone: $0.50/month per zone
- Standard queries: $0.40 per million queries
- Alias queries: FREE (to AWS resources like ALB)
- Health checks: $0.50/month per health check

**Typical Monthly Cost:**
- Without health check: ~$0.50-1.00/month
- With health check: ~$1.00-1.50/month

**Note**: Alias records to ALB are free, so most traffic cost is minimal.

## When to Use Route53 vs External DNS

### Use Route53 When:
- ✅ You want fully automated DNS management
- ✅ ACM certificate validation should be automatic
- ✅ You need AWS-native health checks
- ✅ You want to manage DNS via Infrastructure-as-Code
- ✅ You're starting a new domain or can transfer DNS

### Use External DNS When:
- ✅ Your domain is already managed elsewhere (Cloudflare, Google Domains)
- ✅ You have complex DNS configurations outside AWS
- ✅ You prefer your existing DNS provider's UI
- ✅ Your organization has a policy about DNS providers
- ✅ You need features Route53 doesn't support

**If using external DNS:**
Set `create_hosted_zone = false` in terraform.tfvars and manually:
1. Create CNAME record for ACM certificate validation
2. Create A record pointing to ALB DNS name

## Advanced Configuration

### Multiple Subdomains

Add custom subdomains by extending the module:

```hcl
resource "aws_route53_record" "custom" {
  zone_id = module.route53.zone_id
  name    = "custom.app.example.com"
  type    = "A"

  alias {
    name                   = module.loadbalancer.alb_dns_name
    zone_id                = module.loadbalancer.alb_zone_id
    evaluate_target_health = true
  }
}
```

### Geolocation Routing

For multi-region deployments:

```hcl
resource "aws_route53_record" "us" {
  zone_id = module.route53.zone_id
  name    = "app.example.com"
  type    = "A"

  geolocation_routing_policy {
    continent = "NA"
  }

  alias {
    name                   = module.loadbalancer_us.alb_dns_name
    zone_id                = module.loadbalancer_us.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "eu" {
  zone_id = module.route53.zone_id
  name    = "app.example.com"
  type    = "A"

  geolocation_routing_policy {
    continent = "EU"
  }

  alias {
    name                   = module.loadbalancer_eu.alb_dns_name
    zone_id                = module.loadbalancer_eu.alb_zone_id
    evaluate_target_health = true
  }
}
```

### Weighted Routing (Blue-Green Deployments)

```hcl
resource "aws_route53_record" "blue" {
  zone_id = module.route53.zone_id
  name    = "app.example.com"
  type    = "A"

  set_identifier = "blue"
  weight         = 90

  alias {
    name                   = module.loadbalancer_blue.alb_dns_name
    zone_id                = module.loadbalancer_blue.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "green" {
  zone_id = module.route53.zone_id
  name    = "app.example.com"
  type    = "A"

  set_identifier = "green"
  weight         = 10

  alias {
    name                   = module.loadbalancer_green.alb_dns_name
    zone_id                = module.loadbalancer_green.alb_zone_id
    evaluate_target_health = true
  }
}
```

## Troubleshooting

### Certificate Validation Stuck

**Problem**: ACM certificate stuck in "Pending validation"

**Solution**:
1. Check DNS records were created:
   ```bash
   terraform output route53_name_servers
   dig _xxxxx.app.example.com CNAME
   ```
2. Verify name servers updated at registrar
3. Wait for DNS propagation (up to 48 hours)
4. Check ACM console for validation status

### Domain Not Resolving

**Problem**: `dig app.example.com` returns NXDOMAIN or no answer

**Solution**:
1. Verify name servers:
   ```bash
   dig NS app.example.com
   ```
2. Should return Route53 name servers from `terraform output`
3. If not, update at domain registrar
4. Wait for DNS propagation

### Health Check Always Failing

**Problem**: Route53 health check shows as unhealthy

**Solution**:
1. Verify ALB is responding on HTTPS port 443
2. Check health check path returns 200 OK:
   ```bash
   curl -I https://app.example.com/health
   ```
3. Verify ALB security group allows traffic from Route53 health checkers (see Route53 IP ranges)
4. Check CloudWatch logs for ALB

### WWW Redirect Not Working

**Problem**: www.app.example.com doesn't redirect to app.example.com

**Solution**:
This module creates www.app.example.com as an alias to the same ALB. The redirect must be handled by your application:

**In your frontend/backend:**
```javascript
// Express.js example
app.use((req, res, next) => {
  if (req.hostname === 'www.app.example.com') {
    return res.redirect(301, `https://app.example.com${req.url}`);
  }
  next();
});
```

Or use ALB listener rules (not implemented in this module).

## Security Considerations

- **DNSSEC**: Not enabled by default (configure if needed)
- **Query Logging**: Not enabled by default (add `aws_route53_query_log` resource)
- **Health Check Alarms**: Connect to SNS for notifications
- **Access Control**: Use IAM policies to restrict Route53 changes

## Migration from External DNS

If you're migrating from another DNS provider:

1. **Before applying Terraform**:
   - Note all existing DNS records
   - Reduce TTLs to 300 seconds (5 minutes)
   - Wait for old TTLs to expire

2. **Apply Terraform**:
   - Creates Route53 zone with name servers
   - Creates A records for ALB

3. **Parallel DNS**:
   - Add Route53 name servers to registrar (don't remove old ones yet)
   - Wait 24 hours, monitor traffic

4. **Cutover**:
   - Remove old name servers from registrar
   - Only Route53 name servers remain

5. **Verify**:
   - Check all DNS records resolve correctly
   - Monitor application for issues

## Examples

See `terraform/environments/dev/main.tf` for complete implementation examples.

## Resources Created

- `aws_route53_zone.main` - Hosted zone
- `aws_route53_record.cert_validation` - ACM validation records
- `aws_route53_record.app` - Apex domain A record
- `aws_route53_record.www` - WWW subdomain (optional)
- `aws_route53_record.api` - API subdomain (optional)
- `aws_route53_health_check.alb` - Health check (optional)
- `aws_cloudwatch_metric_alarm.route53_health_check` - Health check alarm (optional)

## References

- [AWS Route53 Documentation](https://docs.aws.amazon.com/route53/)
- [Route53 Pricing](https://aws.amazon.com/route53/pricing/)
- [ACM Certificate Validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)
- [Terraform Route53 Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone)
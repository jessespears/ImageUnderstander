# Terraform Infrastructure - AI Agent Guidelines

This document provides instructions for AI agents working on the Terraform infrastructure for ImageUnderstander.

## Infrastructure Overview

This Terraform configuration deploys a complete RAG (Retrieval-Augmented Generation) application on AWS with:

- **4 EC2 Instances**: Frontend (t4g.micro spot), Backend (t4g.micro spot), LLM Service (g5.xlarge on-demand with GPU), ChromaDB (t3.medium on-demand)
- **RDS MySQL**: Multi-AZ managed database with automated backups
- **Application Load Balancer**: HTTPS termination with ACM certificate
- **VPC Networking**: Public/private subnets across 2 AZs with NAT Gateway
- **Storage**: S3 bucket for uploads, EBS volumes for LLM models and ChromaDB data
- **Security**: Security groups, IAM roles, Secrets Manager for credentials
- **DNS**: Route53 hosted zone with automatic certificate validation (optional)
- **Monitoring**: CloudWatch logs and metrics for all services
- **Access**: AWS Systems Manager Session Manager (no bastion host)

**Estimated Monthly Cost**: ~$521/month (mostly LLM GPU instance)

## Module Architecture

```
terraform/
├── environments/dev/          # Environment-specific configuration
│   ├── main.tf               # Orchestrates all modules
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Output values
│   ├── provider.tf           # AWS provider config
│   └── terraform.tfvars.example
│
└── modules/                   # Reusable infrastructure modules
    ├── networking/            # VPC, subnets, NAT, IGW, VPC endpoints
    ├── security/              # Security groups, IAM roles, instance profiles
    ├── storage/               # S3, Secrets Manager, CloudWatch log groups
    ├── database/              # RDS MySQL with monitoring
    ├── compute/               # EC2 instances with user_data scripts
    ├── loadbalancer/          # ALB, target groups, listeners
    └── route53/               # DNS management with Route53 (optional)
```

## General Principles

### Terraform Best Practices

1. **Module Organization**: Keep modules focused on a single concern (networking, security, etc.)
2. **Variable Naming**: Use descriptive names with consistent prefixes (e.g., `db_`, `llm_`)
3. **Output Everything Useful**: Other modules or external tools may need these values
4. **Use Data Sources**: Fetch AMIs, availability zones dynamically
5. **Tag Everything**: Use consistent tagging for cost allocation and management
6. **Sensitive Values**: Mark passwords and API keys as `sensitive = true`

### Code Style

- Use `terraform fmt` to format all files
- Use 2-space indentation
- Group related resources together with comments
- Add descriptions to all variables and outputs
- Use `locals` for computed values used multiple times
- Keep line length reasonable (~120 characters)

### Security First

- Never hardcode secrets in .tf files
- Use Secrets Manager or Parameter Store for sensitive data
- All instances in private subnets unless absolutely necessary
- Use security groups with least-privilege access
- Enable encryption at rest for all storage (EBS, RDS, S3)
- Enforce IMDSv2 on EC2 instances

## Module-Specific Guidelines

### Networking Module

**Purpose**: Creates VPC, subnets, route tables, NAT Gateway, VPC endpoints

**Key Resources**:
- VPC with DNS enabled
- 2 public subnets (for ALB, NAT Gateway)
- 2 private subnets (for EC2, RDS)
- NAT Gateway with Elastic IP
- VPC endpoints for S3, SSM, SSM Messages, EC2 Messages (cost optimization and security)

**Best Practices**:
- Use at least 2 AZs for high availability
- Size subnet CIDRs appropriately (allow for growth)
- VPC endpoints reduce NAT Gateway costs and improve security
- Tag subnets with Type=Public or Type=Private

**Common Changes**:
- Adding more subnets: Update `availability_zones`, `public_subnet_cidrs`, `private_subnet_cidrs`
- Adding VPC peering: Create `aws_vpc_peering_connection` and update route tables
- Changing CIDR blocks: May require destroying and recreating VPC

### Security Module

**Purpose**: Security groups for all services, IAM roles and instance profiles

**Key Resources**:
- 6 security groups (ALB, Frontend, Backend, LLM, ChromaDB, RDS)
- 4 IAM roles with instance profiles (Frontend, Backend, LLM, ChromaDB)
- IAM policies for S3, Secrets Manager, CloudWatch

**Security Group Rules**:
- ALB: 443 and 80 from internet (0.0.0.0/0)
- Frontend: 8080 from ALB only
- Backend: 8000 from Frontend only
- LLM: 8001 from Backend only
- ChromaDB: 8000 from Backend and LLM
- RDS: 3306 from Backend and LLM

**IAM Permissions**:
- All roles: SSM Session Manager, CloudWatch logs/metrics
- Backend/LLM: S3 read/write, Secrets Manager read
- Frontend: Minimal permissions (CloudWatch only)

**Best Practices**:
- Reference security groups by ID, not CIDR blocks when possible
- Use `name_prefix` instead of `name` for auto-generated unique names
- Always include lifecycle `create_before_destroy = true` for security groups
- Keep IAM policies as restrictive as possible

### Storage Module

**Purpose**: S3 bucket, Secrets Manager secrets, CloudWatch log groups

**Key Resources**:
- S3 bucket with versioning, encryption, lifecycle policies
- Secrets Manager secrets for RDS and application
- CloudWatch log groups for each service (30-day retention)
- Random password generation for secrets

**S3 Configuration**:
- Versioning enabled (recover from accidents)
- Server-side encryption (AES256)
- Public access blocked
- CORS enabled for frontend uploads
- Lifecycle: Transition to IA after 30 days, delete old versions after 90 days

**Secrets Manager**:
- RDS master password (auto-generated)
- Application secrets (JWT, encryption keys, LLM API keys)
- 7-day recovery window for accidental deletions

**Best Practices**:
- Use `bucket_prefix` instead of hardcoded bucket names (ensures uniqueness)
- Generate secrets with Terraform's `random_password` resource
- Set appropriate log retention (30 days dev, 90+ days prod)
- Never output sensitive values without `sensitive = true`

### Database Module

**Purpose**: RDS MySQL instance with Multi-AZ, backups, monitoring

**Key Resources**:
- RDS MySQL 8.0 instance
- DB subnet group (spans private subnets)
- Parameter group (custom MySQL settings)
- Enhanced monitoring IAM role
- CloudWatch alarms (CPU, storage, connections)

**Configuration**:
- Engine: MySQL 8.0.35
- Instance class: db.t4g.micro (upgradeable)
- Storage: gp3 with 3000 IOPS
- Multi-AZ: Enabled (high availability)
- Backups: 7-day retention, automated
- Encryption: Enabled at rest
- Monitoring: 60-second enhanced monitoring

**Best Practices**:
- Use parameter groups for custom MySQL settings
- Enable Multi-AZ for production
- Set `skip_final_snapshot = false` for production
- Set `deletion_protection = true` for production
- Use Secrets Manager for passwords (never hardcode)
- Monitor storage space with CloudWatch alarms

**Common Changes**:
- Scaling vertically: Change `db_instance_class`
- Scaling storage: Change `db_allocated_storage` (can only increase)
- Adding read replicas: Create `aws_db_instance` with `replicate_source_db`

### Compute Module

**Purpose**: EC2 instances for all application services

**Key Resources**:
- Frontend instance (t4g.micro ARM, spot)
- Backend instance (t4g.micro ARM, spot)
- LLM instance (g5.xlarge with GPU, on-demand)
- ChromaDB instance (t3.medium x86, on-demand)
- User data scripts for initialization
- EBS volumes for LLM (50GB) and ChromaDB (100GB)

**AMI Selection**:
- Frontend/Backend/ChromaDB: Amazon Linux 2023 (latest)
- LLM: AWS Deep Learning Base AMI (Ubuntu 22.04 with NVIDIA drivers)
- Use data sources to get latest AMIs automatically

**Spot Instances**:
- Frontend/Backend use spot for cost savings (~70% cheaper)
- Max price set to prevent runaway costs
- LLM uses on-demand (avoid interruption during inference)

**User Data Scripts**:
- Install system packages and dependencies
- Configure CloudWatch agent
- Mount EBS volumes
- Create systemd service files
- **DO NOT deploy application code** (see README.md)

**Best Practices**:
- Use spot instances for stateless, interruptible workloads
- Set appropriate spot max prices
- Enforce IMDSv2 with `http_tokens = "required"`
- Use `ignore_changes = [ami]` to prevent unnecessary replacements
- Mount EBS volumes in user_data for persistent storage
- Use ARM instances (t4g) when possible (better price/performance)

**EBS Volumes**:
- LLM: 50GB for model weights (adjust based on model size)
- ChromaDB: 100GB for vector data (adjust based on dataset size)
- Volumes are encrypted and `delete_on_termination = false` (persist data)

### Load Balancer Module

**Purpose**: Application Load Balancer with HTTPS termination

**Key Resources**:
- Application Load Balancer (public subnets)
- Target group for frontend
- HTTPS listener (port 443) with ACM certificate
- HTTP listener (port 80) redirects to HTTPS
- CloudWatch alarms for health and performance

**Configuration**:
- Listener: HTTPS with TLS 1.3 policy
- Target: Frontend instance on port 8080
- Health check: HTTP GET /health every 30s
- Stickiness: Enabled with 24-hour cookie
- Cross-zone load balancing: Enabled

**Best Practices**:
- Always redirect HTTP to HTTPS (never serve plain HTTP)
- Use latest TLS policy (ELBSecurityPolicy-TLS13-1-2-2021-06)
- Set appropriate health check intervals and thresholds
- Enable access logs for debugging (not implemented, but recommended)
- Use `name_prefix` to avoid name conflicts

**ACM Certificate**:
- Managed in environments/dev/main.tf
- DNS validation required (add CNAME to your domain)
- Auto-renews before expiration
- Must be in same region as ALB

### Route53 Module

**Purpose**: DNS management with Route53 hosted zone (optional)

**Key Resources**:
- Route53 hosted zone for your domain
- ACM certificate validation records (automatic)
- A records (aliases) for apex domain, www, api subdomains
- Optional health checks for ALB monitoring
- CloudWatch alarms for health check failures

**Configuration**:
- Hosted zone: Created for your domain
- Name servers: Must be updated at domain registrar
- Validation records: Automatically created for ACM
- A records: Alias to ALB (free, no query charges)
- Health checks: Optional HTTPS monitoring

**Best Practices**:
- Set `create_hosted_zone = false` if using external DNS (Cloudflare, etc.)
- Update name servers at registrar after zone creation (1-48 hour propagation)
- Enable health checks for production (`create_route53_health_check = true`)
- Use subdomains for different purposes (www, api, admin)

**When to Use Route53**:
- ✅ You want fully automated DNS and certificate validation
- ✅ You're starting a new domain or can transfer DNS management
- ✅ You want infrastructure-as-code for DNS
- ✅ You need health checks and failover capabilities

**When to Use External DNS**:
- ✅ Domain already managed elsewhere (existing setup)
- ✅ Company policy requires specific DNS provider
- ✅ Complex DNS configurations outside AWS
- ✅ Cost-sensitive (though Route53 is only ~$1/month)

**Setup Process**:
1. Set `create_hosted_zone = true` in terraform.tfvars
2. Apply Terraform
3. Get name servers: `terraform output route53_name_servers`
4. Update name servers at domain registrar
5. Wait for DNS propagation (1-48 hours)
6. Certificate validates automatically

## Working with Environments

### Directory Structure

Each environment (dev, staging, prod) should have its own directory:

```
environments/
├── dev/
│   ├── main.tf              # Module composition
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Outputs
│   ├── provider.tf          # Provider config
│   └── terraform.tfvars     # Variable values (gitignored)
├── staging/
│   └── ...
└── prod/
    └── ...
```

### Environment Differences

**Dev Environment**:
- `db_skip_final_snapshot = true` (faster teardown)
- `db_deletion_protection = false` (allow deletion)
- `alb_deletion_protection = false` (allow deletion)
- `create_hosted_zone = false` (optional, use if testing DNS)
- `create_route53_health_check = false` (save costs)
- Shorter log retention (30 days)
- Single-AZ RDS (optional, for cost savings)

**Production Environment**:
- `db_skip_final_snapshot = false` (keep backups)
- `db_deletion_protection = true` (prevent accidents)
- `alb_deletion_protection = true` (prevent accidents)
- `create_hosted_zone = true` (manage DNS in AWS)
- `create_route53_health_check = true` (monitor availability)
- Longer log retention (90+ days)
- Multi-AZ RDS (high availability)
- Reserved Instances or Savings Plans

### Creating New Environments

1. Copy `environments/dev/` to `environments/prod/`
2. Update `locals` in main.tf (set `environment = "prod"`)
3. Update `provider.tf` default tags
4. Create new `terraform.tfvars` with prod values
5. Run `terraform init` in the new directory
6. Consider separate AWS accounts for isolation

## Remote State Backend (S3 + DynamoDB)

### Why Use Remote State?

**Local State (default)**:
- State stored in `terraform.tfstate` file locally
- ❌ No collaboration (file conflicts)
- ❌ No locking (concurrent runs corrupt state)
- ❌ No backup (lose file, lose state)
- ❌ Sensitive data in plain text

**Remote State (S3 + DynamoDB)**:
- State stored in S3 bucket
- ✅ Team collaboration (shared state)
- ✅ State locking via DynamoDB (prevents race conditions)
- ✅ Versioning and backup (recover from mistakes)
- ✅ Encryption at rest
- ✅ CI/CD pipeline access

### How It Works

1. **S3 Bucket**: Stores `terraform.tfstate` file
   - Versioning enabled (rollback capability)
   - Encryption enabled (protect secrets)
   - Access logged (audit trail)

2. **DynamoDB Table**: Provides state locking
   - Key: LockID (string)
   - Prevents concurrent `terraform apply` operations
   - Released automatically after operation completes
   - Pay-per-request billing (very cheap)

3. **Workflow**:
   ```
   terraform plan
   ├─> Acquire lock in DynamoDB
   ├─> Download state from S3
   ├─> Generate plan
   └─> Release lock

   terraform apply
   ├─> Acquire lock in DynamoDB
   ├─> Download state from S3
   ├─> Apply changes
   ├─> Upload new state to S3
   └─> Release lock
   ```

### Setup Instructions

See detailed instructions in `terraform/versions.tf` and `terraform/README.md`.

**Quick setup**:
```bash
# Create bucket
aws s3 mb s3://mycompany-terraform-state

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket mycompany-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

### Backend Configuration

The backend block **cannot use variables**. Two options:

**Option 1: Hardcode in versions.tf**
```hcl
backend "s3" {
  bucket         = "mycompany-terraform-state"
  key            = "imageunderstander/dev/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

**Option 2: Use backend config file**
```bash
# backend.hcl
bucket         = "mycompany-terraform-state"
key            = "imageunderstander/dev/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "terraform-state-lock"

# Use with:
terraform init -backend-config=backend.hcl
```

## User Data Scripts - Important Notes

### What's Real vs Placeholder

**REAL (Actually Works)**:
- ✅ System package installation
- ✅ CloudWatch agent configuration and startup
- ✅ EBS volume mounting and formatting
- ✅ Secrets Manager credential retrieval
- ✅ Environment file creation with real secrets
- ✅ ChromaDB installation and auto-start

**PLACEHOLDER (Needs Actual Code)**:
- ❌ Frontend application code (not deployed)
- ❌ Backend application code (not deployed)
- ❌ LLM service code (template only, model not downloaded)
- ❌ Example requirements.txt files (replace with real dependencies)

### Service Startup Status

- **ChromaDB**: ✅ Starts automatically, ready immediately
- **Frontend**: ❌ Service defined but not started (no code)
- **Backend**: ❌ Service defined but not started (no code)
- **LLM**: ❌ Service defined but not started (no code, no model)

### Application Deployment Required

After Terraform creates infrastructure, you MUST deploy application code via:

1. **CI/CD Pipeline** (Recommended):
   - GitHub Actions, GitLab CI, Jenkins
   - Build code, create artifacts, deploy to instances
   - Use AWS Systems Manager Run Command or CodeDeploy

2. **Manual Deployment**:
   - Connect via AWS Systems Manager Session Manager
   - Clone git repos to /opt/frontend, /opt/backend, /opt/llm
   - Install dependencies, build applications
   - Start systemd services

3. **Container-Based** (Advanced):
   - Build Docker images, push to ECR
   - Update user_data to pull and run containers
   - Consider ECS/Fargate for orchestration

4. **Configuration Management**:
   - Ansible, Chef, Puppet playbooks
   - Automated application deployment and updates

## Common Tasks

### Adding a New EC2 Instance Type

1. Add variable in `modules/compute/variables.tf`:
   ```hcl
   variable "new_service_instance_type" {
     description = "Instance type for new service"
     type        = string
     default     = "t3.small"
   }
   ```

2. Create instance resource in `modules/compute/main.tf`
3. Add security group in `modules/security/main.tf`
4. Create user_data script in `modules/compute/user_data/`
5. Add outputs in `modules/compute/outputs.tf`
6. Wire up in `environments/dev/main.tf`

### Changing Instance Types

Update in `terraform.tfvars`:
```hcl
backend_instance_type = "t4g.small"  # Upgrade from micro
```

Then:
```bash
terraform plan   # Review changes
terraform apply  # Apply (will recreate instance)
```

**Warning**: Changing instance type requires instance replacement (downtime).

### Adding More Subnets

1. Add CIDR blocks in `environments/dev/main.tf`:
   ```hcl
   private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
   ```

2. Add availability zone:
   ```hcl
   availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
   ```

3. Apply changes

### Scaling RDS Storage

Update in `terraform.tfvars`:
```hcl
db_allocated_storage = 50  # Increase from 20 GB
```

**Note**: RDS storage can only be increased, not decreased. Downtime may occur.

### Updating Secrets

Use AWS CLI, not Terraform:
```bash
# Update LLM API key
aws secretsmanager put-secret-value \
  --secret-id $(terraform output -raw app_secrets_name) \
  --secret-string '{"llm_api_key":"new-key","jwt_secret_key":"...","encryption_key":"..."}'
```

### Viewing Logs

```bash
# CloudWatch Logs
aws logs tail /aws/ec2/imageunderstander-dev/backend --follow

# Instance user-data logs
aws ssm start-session --target INSTANCE_ID
sudo tail -f /var/log/cloud-init-output.log
```

### DNS Management

**Using Route53:**
```bash
# Get name servers (update at registrar)
terraform output route53_name_servers

# Check DNS propagation
dig NS yourdomain.com
dig A yourdomain.com

# Verify records
aws route53 list-resource-record-sets --hosted-zone-id $(terraform output -raw route53_zone_id)
```

**Using External DNS:**
- Manually create CNAME for ACM validation
- Manually create A record pointing to ALB
- Get validation info: `terraform output acm_certificate_domain_validation_options`
- Get ALB DNS: `terraform output alb_dns_name`

## Troubleshooting

### State Lock Issues

If Terraform crashes, state may remain locked:
```bash
# List locks
terraform force-unlock LOCK_ID

# Or directly in DynamoDB
aws dynamodb scan --table-name terraform-state-lock
aws dynamodb delete-item --table-name terraform-state-lock \
  --key '{"LockID": {"S": "LOCK_ID"}}'
```

### Dependency Cycles

If Terraform reports circular dependencies:
1. Check for resources referencing each other
2. Use `depends_on` explicitly to break cycles
3. Split into multiple apply operations

### Resource Already Exists

If resource exists but not in state:
```bash
# Import existing resource
terraform import module.compute.aws_instance.frontend i-1234567890abcdef0

# Or remove from AWS and let Terraform recreate
aws ec2 terminate-instances --instance-ids i-1234567890abcdef0
terraform apply
```

### Invalid AMI ID

AMIs are region-specific and can become deprecated:
- Data sources fetch latest AMI automatically
- If AMI not found, check region in provider.tf
- Use `ignore_changes = [ami]` to prevent unnecessary updates

### Certificate Validation Stuck

**With Route53 (create_hosted_zone = true):**
1. Check name servers updated at registrar:
   ```bash
   dig NS yourdomain.com
   terraform output route53_name_servers
   ```
2. Wait for DNS propagation (1-48 hours typically)
3. Validation records created automatically
4. Check status: `aws acm describe-certificate --certificate-arn ARN`

**Without Route53 (external DNS):**
1. Get validation record: `terraform output acm_certificate_domain_validation_options`
2. Add CNAME record to your DNS provider
3. Wait for DNS propagation
4. ACM validates automatically after DNS propagates

### Domain Not Resolving

**With Route53:**
1. Verify name servers match:
   ```bash
   terraform output route53_name_servers
   dig NS yourdomain.com +short
   ```
2. If different, update at domain registrar
3. Wait for propagation (use https://dnschecker.org/)
4. A records created automatically

**Without Route53:**
1. Verify A record points to ALB:
   ```bash
   terraform output alb_dns_name
   dig A yourdomain.com
   ```
2. Update A record if incorrect

### Route53 Health Check Failing

1. Verify ALB is responding:
   ```bash
   curl -I https://yourdomain.com/health
   ```
2. Check health check configuration matches endpoint
3. Verify frontend has `/health` endpoint
4. Check ALB target group health in AWS Console

### Out of Capacity (Spot Instances)

Spot instances may fail to launch:
- Try different availability zones
- Increase max spot price
- Use on-demand instances
- Implement spot fleet with multiple instance types

## Testing Changes

### Plan Only (Dry Run)

Always run plan before apply:
```bash
terraform plan -out=tfplan
```

Review the output carefully. Look for:
- Resources being destroyed (red, minus sign)
- Resources being created (green, plus sign)
- Resources being modified (yellow, tilde)

### Targeted Apply

Test changes to specific resources:
```bash
terraform plan -target=module.compute.aws_instance.backend
terraform apply -target=module.compute.aws_instance.backend
```

**Warning**: Use sparingly, can lead to inconsistent state.

### Validate Configuration

```bash
terraform validate  # Check syntax
terraform fmt -check  # Check formatting
```

## Security Checklist

Before deploying to production:

- [ ] Remote state backend configured (S3 + DynamoDB)
- [ ] State bucket has versioning and encryption enabled
- [ ] No secrets hardcoded in .tf files
- [ ] All sensitive outputs marked as `sensitive = true`
- [ ] terraform.tfvars added to .gitignore
- [ ] All instances in private subnets
- [ ] Security groups use least-privilege principle
- [ ] IMDSv2 enforced on all instances
- [ ] Encryption enabled on all storage (EBS, RDS, S3)
- [ ] Deletion protection enabled for critical resources (prod)
- [ ] CloudWatch alarms configured
- [ ] IAM roles follow least-privilege principle
- [ ] VPC Flow Logs enabled (optional, not implemented)
- [ ] AWS Config enabled for compliance (optional, not implemented)

## Cost Optimization

### Immediate Savings

1. **Stop LLM instance when not in use** (saves ~$380/month)
   ```bash
   aws ec2 stop-instances --instance-ids $(terraform output -raw llm_instance_id)
   ```

2. **Use single-AZ RDS in dev** (saves ~$14/month)
   ```hcl
   db_multi_az = false
   ```

3. **Reduce log retention** (saves ~$5/month)
   ```hcl
   log_retention_days = 7
   ```

4. **Use spot for LLM** (saves ~$260/month, but interruptible)

### Long-term Savings

1. **Reserved Instances** (save up to 72%)
   - Commit to 1 or 3 years
   - For predictable workloads (RDS, NAT Gateway)

2. **Savings Plans** (save up to 72%)
   - More flexible than Reserved Instances
   - Apply to EC2, Lambda, Fargate

3. **Auto Scaling** (scale to zero when idle)
   - Not implemented in this basic setup
   - Add Auto Scaling Groups for frontend/backend

4. **S3 Intelligent Tiering**
   - Automatically moves objects to cheaper tiers
   - Already using lifecycle policies

5. **External DNS Instead of Route53**
   - Saves $0.50/month (hosted zone cost)
   - Trade automation for minimal savings
   - Set `create_hosted_zone = false`

## Production Readiness

This configuration is a **starting point**. For production, add:

### High Availability
- [ ] Auto Scaling Groups for frontend/backend
- [ ] Multi-region deployment with Route53 failover and health checks
- [ ] RDS read replicas for scaling reads
- [ ] ElastiCache for session storage and caching
- [ ] Route53 geolocation or latency-based routing

### Security
- [ ] AWS WAF on ALB (DDoS protection, SQL injection)
- [ ] GuardDuty for threat detection
- [ ] Security Hub for compliance monitoring
- [ ] VPC Flow Logs for network analysis
- [ ] AWS Config for configuration auditing

### Monitoring
- [ ] X-Ray for distributed tracing
- [ ] Enhanced CloudWatch dashboards
- [ ] SNS topics for alarm notifications
- [ ] PagerDuty/Opsgenie integration

### Backup and Recovery
- [ ] AWS Backup for automated backups
- [ ] Cross-region backup replication
- [ ] Disaster recovery runbooks
- [ ] Regular restore testing

### CI/CD
- [ ] GitHub Actions / GitLab CI pipeline
- [ ] Automated terraform plan on PR
- [ ] Automated deploy on merge to main
- [ ] Blue-green or canary deployments

### Compliance
- [ ] Enable CloudTrail for audit logging
- [ ] Tag resources for cost allocation
- [ ] Implement least-privilege IAM policies
- [ ] Regular security audits

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Cost Optimization](https://aws.amazon.com/pricing/cost-optimization/)
- [Route53 Documentation](https://docs.aws.amazon.com/route53/)
- [ACM Certificate Validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)
- [Route53 Module README](../modules/route53/README.md)

## Quick Reference

### Essential Commands
```bash
# Initialize
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# Format code
terraform fmt -recursive

# Validate syntax
terraform validate

# Show outputs
terraform output

# Show state
terraform state list
terraform state show <resource>

# Import existing resource
terraform import <resource> <id>

# Refresh state
terraform refresh
```

### File Structure Rules
- `main.tf` - Primary resources
- `variables.tf` - Input variables (no values)
- `outputs.tf` - Output values
- `versions.tf` - Provider versions and backend
- `terraform.tfvars` - Variable values (gitignored)
- `README.md` - Human documentation
- `AGENTS.md` - AI agent documentation

---

**Remember**: Infrastructure-as-code is code. Apply the same rigor: version control, code review, testing, documentation.
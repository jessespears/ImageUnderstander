# Terraform Infrastructure for ImageUnderstander

This directory contains Terraform infrastructure-as-code for deploying the ImageUnderstander RAG application on AWS.

## Architecture Overview

The infrastructure consists of:

- **Networking**: VPC with public/private subnets across 2 AZs, NAT Gateway, Internet Gateway
- **Compute**: 4 EC2 instances
  - Frontend (t4g.micro, spot)
  - Backend API (t4g.micro, spot)
  - LLM Service (g5.xlarge, on-demand with GPU)
  - ChromaDB (t3.medium, on-demand)
- **Database**: RDS MySQL (Multi-AZ, automated backups)
- **Storage**: S3 bucket for images/documents, EBS volumes for LLM and ChromaDB
- **Security**: Security groups, IAM roles, Secrets Manager for credentials
- **Load Balancing**: Application Load Balancer with HTTPS (ACM certificate)
- **DNS**: Route53 hosted zone with automatic certificate validation (optional)
- **Monitoring**: CloudWatch logs and metrics for all services
- **Access**: AWS Systems Manager Session Manager (no bastion host)

## Directory Structure

```
terraform/
├── environments/
│   └── dev/                    # Development environment
│       ├── main.tf             # Main configuration
│       ├── variables.tf        # Input variables
│       ├── outputs.tf          # Output values
│       ├── provider.tf         # AWS provider config
│       └── terraform.tfvars.example  # Example variables
├── modules/
│   ├── networking/             # VPC, subnets, gateways
│   ├── security/               # Security groups, IAM roles
│   ├── storage/                # S3, Secrets Manager, CloudWatch
│   ├── database/               # RDS MySQL
│   ├── compute/                # EC2 instances
│   ├── loadbalancer/           # Application Load Balancer
│   └── route53/                # DNS management (optional)
├── versions.tf                 # Provider version constraints
├── AGENTS.md                   # AI agent documentation
└── README.md                   # This file
```

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** >= 1.5.0 installed
4. **Domain name** for HTTPS certificate
5. **S3 bucket** for remote state (optional but recommended for teams)
6. **Domain registrar access** (if using Route53 to manage DNS)

## Quick Start

### 1. Configure Remote State (Recommended)

For team environments, set up remote state storage:

```bash
# Create S3 bucket for state
aws s3 mb s3://your-company-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket your-company-terraform-state \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption \
  --bucket your-company-terraform-state \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

Then uncomment and configure the backend block in `versions.tf`.

### 2. Configure Variables

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your values:
- `domain_name` - Your domain for HTTPS certificate (REQUIRED)
- `create_hosted_zone` - Set to `true` to use Route53 for DNS, `false` for external DNS
- `aws_region` - AWS region (default: us-east-1)
- Other optional settings (instance types, storage sizes, etc.)

### 3. Initialize Terraform

```bash
terraform init
```

If using remote state:
```bash
terraform init -migrate-state
```

### 4. Review Plan

```bash
terraform plan
```

Review the resources that will be created (~40-50 resources).

### 5. Apply Configuration

```bash
terraform apply
```

This will take 10-15 minutes to complete.

### 6. Configure DNS

#### Option A: Using Route53 (create_hosted_zone = true)

If you set `create_hosted_zone = true`, DNS is automated! You just need to:

1. Get the Route53 name servers:
   ```bash
   terraform output route53_name_servers
   ```

2. Update your domain registrar to use these name servers

3. Wait for DNS propagation (1-48 hours, typically 1-4 hours)

4. Certificate validation and A records are created automatically!

#### Option B: Using External DNS (create_hosted_zone = false)

If managing DNS outside AWS:

1. Get the ACM certificate validation record:
   ```bash
   terraform output acm_certificate_domain_validation_options
   ```

2. Add the CNAME record to your DNS provider

3. Wait for certificate validation (5-30 minutes)

4. Get the ALB DNS name:
   ```bash
   terraform output alb_dns_name
   ```

5. Create an A record in your DNS pointing to the ALB

## Important Notes

### User Data Scripts (Instance Initialization)

The EC2 instances are initialized with user_data scripts that:
- ✅ Install system packages and dependencies
- ✅ Configure CloudWatch monitoring
- ✅ Mount EBS volumes (LLM and ChromaDB)
- ✅ Set up systemd services
- ❌ **DO NOT** deploy application code

**What's Placeholder/Not Real:**
- Frontend: No actual frontend code deployed
- Backend: Example requirements.txt, no actual app code
- LLM: Template FastAPI service, model not downloaded
- Only ChromaDB starts automatically

**You Must Deploy Application Code Separately** via:
- CI/CD pipeline (GitHub Actions, CodeDeploy, etc.)
- Manual deployment using AWS Systems Manager
- Container images (Docker)
- Configuration management tools (Ansible)

### Services That Start Automatically

- ✅ **ChromaDB**: Starts automatically and is ready immediately
- ❌ **Frontend**: Service defined but not started (no code deployed)
- ❌ **Backend**: Service defined but not started (no code deployed)
- ❌ **LLM**: Service defined but not started (no code deployed)

### First-Time LLM Setup

When you deploy the LLM service:
1. Model download will take 10-30 minutes (10-30 GB)
2. First inference request may take 1-2 minutes
3. Monitor with: `journalctl -u llm.service -f`

## Access Instances

All instances are in private subnets. Access via AWS Systems Manager:

```bash
# Frontend
aws ssm start-session --target $(terraform output -raw frontend_instance_id)

# Backend
aws ssm start-session --target $(terraform output -raw backend_instance_id)

# LLM Service
aws ssm start-session --target $(terraform output -raw llm_instance_id)

# ChromaDB
aws ssm start-session --target $(terraform output -raw chromadb_instance_id)
```

## Secrets Management

Secrets are stored in AWS Secrets Manager:

```bash
# RDS credentials
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw rds_secret_name) \
  --query SecretString --output text | jq

# Application secrets (JWT, API keys)
aws secretsmanager get-secret-value \
  --secret-id $(terraform output -raw app_secrets_name) \
  --query SecretString --output text | jq
```

### Update LLM API Key

```bash
SECRET_NAME=$(terraform output -raw app_secrets_name)

# Get current secret
CURRENT=$(aws secretsmanager get-secret-value \
  --secret-id $SECRET_NAME \
  --query SecretString --output text)

# Update with new API key
echo $CURRENT | jq '.llm_api_key = "your-new-api-key"' | \
aws secretsmanager put-secret-value \
  --secret-id $SECRET_NAME \
  --secret-string file:///dev/stdin
```

## Useful Commands

```bash
# Show all outputs
terraform output

# Show specific output
terraform output alb_dns_name

# View state
terraform state list
terraform state show module.compute.aws_instance.frontend

# Destroy specific resource
terraform destroy -target=module.compute.aws_instance.frontend

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Refresh state
terraform refresh
```

## Cost Estimation

Monthly costs (24/7 operation, us-east-1):

| Resource | Type | Monthly Cost |
|----------|------|--------------|
| Frontend | t4g.micro spot | ~$2 |
| Backend | t4g.micro spot | ~$2 |
| LLM Service | g5.xlarge on-demand | ~$380 |
| ChromaDB | t3.medium on-demand | ~$30 |
| RDS MySQL | db.t4g.micro Multi-AZ | ~$28 |
| ALB | Application Load Balancer | ~$16 |
| NAT Gateway | Data transfer + hourly | ~$35 |
| EBS Volumes | 150 GB gp3 | ~$12 |
| S3 | Storage + requests | ~$5 |
| Route53 | Hosted zone + queries | ~$1 |
| CloudWatch | Logs + metrics | ~$10 |
| **Total** | | **~$521/month** |

**Cost Optimization Tips:**
- Use spot instances for LLM (saves ~70%, but can be interrupted)
- Stop LLM instance when not in use (saves $380/month)
- Reduce RDS to single-AZ in dev (saves $14/month)
- Use smaller instance types if possible
- Set up auto-shutdown for dev environments

## Monitoring

### CloudWatch Logs

```bash
# View frontend logs
aws logs tail /aws/ec2/imageunderstander-dev/frontend --follow

# View backend logs
aws logs tail /aws/ec2/imageunderstander-dev/backend --follow

# View LLM logs
aws logs tail /aws/ec2/imageunderstander-dev/llm --follow

# View ChromaDB logs
aws logs tail /aws/ec2/imageunderstander-dev/chromadb --follow
```

### CloudWatch Alarms

Pre-configured alarms for:
- RDS CPU utilization (>80%)
- RDS free storage space (<5 GB)
- RDS database connections (>150)
- ALB healthy host count (<1)
- ALB response time (>2s)
- ALB 5xx errors (>10)
- Route53 health check failures (if enabled)

## Troubleshooting

### Certificate Validation Stuck

**If using Route53 (create_hosted_zone = true):**
1. Verify name servers updated at registrar:
   ```bash
   dig NS yourdomain.com
   ```
2. Check DNS propagation (can take 1-48 hours)
3. Validation records are created automatically

**If using external DNS (create_hosted_zone = false):**
1. Verify DNS record was added correctly
2. Check DNS propagation: `dig CNAME _xxxxx.yourdomain.com`
3. Certificate validation can take up to 72 hours

### Domain Not Resolving

**If using Route53:**
1. Verify name servers match at registrar:
   ```bash
   terraform output route53_name_servers
   dig NS yourdomain.com
   ```
2. Wait for DNS propagation
3. Use https://dnschecker.org/ to check propagation status

**If using external DNS:**
1. Verify A record points to ALB DNS name
2. Check with: `dig A yourdomain.com`

### Instance Not Starting

Check user-data logs:
```bash
aws ssm start-session --target INSTANCE_ID
sudo tail -f /var/log/cloud-init-output.log
```

### Database Connection Issues

1. Verify security groups allow traffic
2. Check RDS endpoint: `terraform output rds_endpoint`
3. Test connection from backend instance:
   ```bash
   mysql -h DB_ENDPOINT -u admin -p
   ```

### LLM Service Out of Memory

- Check GPU memory: `nvidia-smi`
- Reduce batch size in .env file
- Consider larger instance (g5.2xlarge)

### Spot Instance Terminated

Spot instances can be terminated by AWS. For production:
1. Use on-demand for critical services
2. Implement auto-scaling groups
3. Use multiple instance types in spot fleet

## Security Best Practices

✅ **Implemented:**
- All instances in private subnets
- Security groups with minimal required access
- Secrets stored in Secrets Manager
- Encryption at rest (EBS, RDS, S3)
- IMDSv2 enforced on instances
- HTTPS enforced (HTTP redirects to HTTPS)

⚠️ **Additional Recommendations:**
- Enable VPC Flow Logs for network monitoring
- Set up AWS Config for compliance monitoring
- Use AWS WAF on ALB for DDoS protection
- Enable GuardDuty for threat detection
- Implement AWS Backup for automated backups
- Use Systems Manager Parameter Store for non-sensitive configs

## Cleanup

To destroy all resources:

```bash
cd environments/dev
terraform destroy
```

**Warning:** This will delete:
- All EC2 instances
- RDS database (unless deletion protection enabled)
- S3 bucket (may fail if not empty)
- All networking components

Manual cleanup may be required for:
- EBS snapshots
- CloudWatch log data
- S3 bucket contents (must be deleted first)

## Production Deployment

For production, create `environments/prod/` with:
- `db_deletion_protection = true`
- `db_skip_final_snapshot = false`
- `alb_deletion_protection = true`
- `create_route53_health_check = true` (monitor ALB availability)
- Smaller `log_retention_days` if needed
- More restrictive `allowed_cors_origins`
- Consider Reserved Instances or Savings Plans
- Implement auto-scaling for frontend/backend
- Use multi-region deployment for DR

## Support

For issues related to:
- **Terraform configuration**: See module-specific README files
- **AWS resources**: Check AWS documentation
- **Application deployment**: See main project README
- **AI agent instructions**: See AGENTS.md

## License

See project root LICENSE file.
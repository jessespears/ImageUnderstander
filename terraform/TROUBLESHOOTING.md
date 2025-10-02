# Terraform Troubleshooting Guide

## Common Issues and Solutions

### Apple Silicon (M1/M2/M3) Compatibility Error

**Error Message:**
```
Error: Incompatible provider version

Provider registry.terraform.io/hashicorp/template v2.2.0 does not have a package available for your current
platform, darwin_arm64.
```

**Cause:** The deprecated `template` provider doesn't support Apple Silicon (ARM64 Macs).

**Solution:** This has been fixed! The code now uses Terraform's built-in `templatefile()` function instead.

**If you still see this error:**

1. Remove any cached provider data:
   ```bash
   cd terraform/environments/dev
   rm -rf .terraform .terraform.lock.hcl
   ```

2. Re-initialize Terraform:
   ```bash
   terraform init
   ```

3. If the error persists, check for any remaining `data "template_file"` blocks:
   ```bash
   grep -r "template_file" ../../modules/
   ```

---

### AWS Credentials Not Found

**Error Message:**
```
Error: error configuring Terraform AWS Provider: no valid credential sources
```

**Solution:**
```bash
# Configure AWS CLI
aws configure

# Or set environment variables
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"

# Verify credentials work
aws sts get-caller-identity
```

---

### Terraform Init Fails - Backend Configuration

**Error Message:**
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**Solution:** If using remote state (S3 backend), either:

1. Create the S3 bucket first:
   ```bash
   aws s3 mb s3://your-terraform-state-bucket
   ```

2. Or comment out the backend block in `terraform/versions.tf`:
   ```hcl
   # backend "s3" {
   #   bucket = "..."
   # }
   ```

---

### Permission Denied Errors During Apply

**Error Message:**
```
Error: creating EC2 Instance: UnauthorizedOperation
```

**Solution:** Your AWS user/role needs additional IAM permissions. Attach these policies:
- `AmazonEC2FullAccess`
- `AmazonRDSFullAccess`
- `AmazonS3FullAccess`
- `IAMFullAccess`
- `AmazonVPCFullAccess`

Or use `AdministratorAccess` for testing (not recommended for production).

---

### DNS Zone Already Exists

**Error Message:**
```
Error: error creating Route53 Hosted Zone: HostedZoneAlreadyExists
```

**Solution:** A hosted zone for this domain already exists.

1. Import existing zone:
   ```bash
   # Get zone ID
   aws route53 list-hosted-zones-by-name --dns-name imageunderstander.jessespears.com
   
   # Import to Terraform
   terraform import 'module.route53[0].aws_route53_zone.main' Z1234567890ABC
   ```

2. Or destroy the existing zone in AWS Console and re-run Terraform.

---

### Certificate Validation Timeout

**Error Message:**
```
Error: error waiting for ACM Certificate validation: timeout
```

**Solution:**

1. Check DNS records were created:
   ```bash
   terraform output acm_certificate_domain_validation_options
   dig _xxxxx.imageunderstander.jessespears.com CNAME
   ```

2. Verify nameservers were updated at parent domain registrar:
   ```bash
   dig NS imageunderstander.jessespears.com
   ```

3. Increase timeout in `terraform/environments/dev/main.tf`:
   ```hcl
   resource "aws_acm_certificate_validation" "main" {
     timeouts {
       create = "30m"  # Increase from 10m
     }
   }
   ```

---

### Spot Instance Request Failed

**Error Message:**
```
Error: error creating EC2 Instance: SpotMaxPriceTooLow
```

**Solution:** Increase spot max price in `terraform.tfvars`:
```hcl
frontend_spot_max_price = "0.02"  # Increase from 0.01
backend_spot_max_price  = "0.02"
```

Or use on-demand instances (more expensive but guaranteed):
Remove the `instance_market_options` block from the instance resource.

---

### Resource Already Exists

**Error Message:**
```
Error: creating VPC: VpcLimitExceeded
```

**Solution:**

1. Check existing VPCs:
   ```bash
   aws ec2 describe-vpcs
   ```

2. Delete unused VPCs or request limit increase from AWS Support.

3. Or import existing VPC:
   ```bash
   terraform import module.networking.aws_vpc.main vpc-12345678
   ```

---

### State Lock Timeout

**Error Message:**
```
Error: Error acquiring the state lock
```

**Solution:**

1. Wait for other Terraform operations to complete.

2. If no other operations are running, force unlock:
   ```bash
   terraform force-unlock <lock-id>
   ```

3. If using DynamoDB for locking, check the lock table:
   ```bash
   aws dynamodb scan --table-name terraform-state-lock
   ```

---

### Out of Memory During Apply

**Error Message:**
```
signal: killed
```

**Solution:** Terraform ran out of memory (common on large infrastructures).

1. Increase available memory or use a machine with more RAM.

2. Apply in stages using `-target`:
   ```bash
   terraform apply -target=module.networking
   terraform apply -target=module.security
   terraform apply -target=module.database
   # etc.
   ```

---

### Module Not Found

**Error Message:**
```
Error: Module not installed
```

**Solution:**
```bash
# Re-initialize to download modules
terraform init -upgrade
```

---

### Provider Version Conflicts

**Error Message:**
```
Error: Failed to query available provider packages
```

**Solution:**

1. Remove lock file and re-initialize:
   ```bash
   rm .terraform.lock.hcl
   terraform init -upgrade
   ```

2. Or specify exact provider version in `versions.tf`:
   ```hcl
   required_providers {
     aws = {
       source  = "hashicorp/aws"
       version = "5.31.0"  # Specify exact version
     }
   }
   ```

---

## Getting Help

If you encounter an issue not listed here:

1. **Check Terraform output:** Read the full error message carefully
2. **Validate syntax:** `terraform validate`
3. **Check AWS Console:** Verify resources are in expected state
4. **Enable debug logging:**
   ```bash
   export TF_LOG=DEBUG
   terraform apply
   ```
5. **Search Terraform Registry docs:** https://registry.terraform.io/
6. **Check AWS service limits:** Some errors are due to account limits

## Useful Debugging Commands

```bash
# Show Terraform version and providers
terraform version

# Validate configuration syntax
terraform validate

# Format code
terraform fmt -recursive

# Show detailed plan
terraform plan -out=tfplan

# Show current state
terraform state list
terraform state show <resource>

# Refresh state from AWS
terraform refresh

# Show dependency graph
terraform graph | dot -Tpng > graph.png

# Enable debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log

# Check AWS connectivity
aws sts get-caller-identity
aws ec2 describe-vpcs --region us-east-1
```

## Clean Slate (Nuclear Option)

If everything is broken and you want to start fresh:

```bash
# WARNING: This destroys everything!

# 1. Destroy all resources
terraform destroy

# 2. Remove local state
rm -rf .terraform .terraform.lock.hcl terraform.tfstate*

# 3. Re-initialize
terraform init

# 4. Re-apply
terraform apply
```

---

**For more help, see:**
- `terraform/README.md` - Infrastructure documentation
- `DEPLOYMENT.md` - Deployment walkthrough
- AWS Support - For AWS-specific issues
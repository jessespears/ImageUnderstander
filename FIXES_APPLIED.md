# Fixes Applied - Summary

This document summarizes the issues encountered and fixes applied during Terraform infrastructure setup.

## Issue 1: Apple Silicon (ARM64) Compatibility Error ✅ FIXED

### Error Message
```
Error: Incompatible provider version

Provider registry.terraform.io/hashicorp/template v2.2.0 does not have a package available for your current
platform, darwin_arm64.
```

### Root Cause
The deprecated `hashicorp/template` provider doesn't support Apple Silicon (M1/M2/M3 Macs).

### Solution Applied
Replaced deprecated `data "template_file"` resources with Terraform's built-in `templatefile()` function.

**Files Modified:**
- `terraform/modules/compute/main.tf` - Replaced 4 template_file data sources with local templatefile() calls

**Before:**
```hcl
data "template_file" "frontend_user_data" {
  template = file("${path.module}/user_data/frontend.sh")
  vars = {
    environment = var.environment
  }
}

resource "aws_instance" "frontend" {
  user_data = data.template_file.frontend_user_data.rendered
}
```

**After:**
```hcl
locals {
  frontend_user_data = templatefile("${path.module}/user_data/frontend.sh", {
    environment = var.environment
  })
}

resource "aws_instance" "frontend" {
  user_data = local.frontend_user_data
}
```

### Verification
```bash
cd terraform/environments/dev
terraform init
# Output: Terraform has been successfully initialized!
```

---

## Issue 2: S3 Lifecycle Configuration Warning ✅ FIXED

### Warning Message
```
Warning: Invalid Attribute Combination

with module.storage.aws_s3_bucket_lifecycle_configuration.uploads,
on ../../modules/storage/main.tf line 41

No attribute specified when one (and only one) of [rule[0].filter,rule[0].prefix] is required
```

### Root Cause
AWS provider v5+ requires explicit `filter {}` block in S3 lifecycle rules, even if empty.

### Solution Applied
Added empty `filter {}` blocks to both lifecycle rules.

**Files Modified:**
- `terraform/modules/storage/main.tf` - Added filter blocks to lifecycle rules

**Before:**
```hcl
rule {
  id     = "delete-old-versions"
  status = "Enabled"
  
  noncurrent_version_expiration {
    noncurrent_days = 90
  }
}
```

**After:**
```hcl
rule {
  id     = "delete-old-versions"
  status = "Enabled"
  
  filter {}
  
  noncurrent_version_expiration {
    noncurrent_days = 90
  }
}
```

---

## Issue 3: Terraform Template Syntax Errors in User Data Scripts ✅ FIXED

### Error Message
```
Error: Error in function call

Call to function "templatefile" failed: ../../modules/compute/user_data/backend.sh:125,23-24: Invalid
expression; Expected the start of an expression, but found an invalid expression token.
```

### Root Cause
Bash command substitutions `$(...)` and variable expansions `${var%%pattern}` were being interpreted by Terraform's template engine instead of being passed through to bash.

### Solution Applied
Escaped all bash variable operations by doubling the dollar sign: `$$(...)` and `$${var}`.

**Files Modified:**
- `terraform/modules/compute/user_data/backend.sh` - Escaped 13 bash variables
- `terraform/modules/compute/user_data/llm.sh` - Escaped 6 bash variables
- `terraform/modules/compute/user_data/chromadb.sh` - Escaped 2 bash variables

**Examples:**

| Bash Syntax | Before | After |
|-------------|--------|-------|
| Command substitution | `$(cmd)` | `$$(cmd)` |
| Variable expansion | `$VAR` | `$$VAR` |
| Parameter expansion | `${var%%pattern}` | `$${var%%pattern}` |

**Specific Fixes:**

**backend.sh:**
```bash
# Before (Terraform would try to interpret these)
DB_USERNAME=$(jq -r '.username' /tmp/rds_secret.json)
AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
DB_HOST=${db_endpoint%%:*}

# After (Terraform passes to bash)
DB_USERNAME=$$(jq -r '.username' /tmp/rds_secret.json)
AWS_REGION=$$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
DB_HOST=$${db_endpoint%%:*}
```

**llm.sh:**
```bash
# Before
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
LLM_API_KEY=$(jq -r '.llm_api_key' /tmp/app_secret.json)
UUID=$(blkid -s UUID -o value $DEVICE)

# After
REGION=$$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
LLM_API_KEY=$$(jq -r '.llm_api_key' /tmp/app_secret.json)
UUID=$$(blkid -s UUID -o value $DEVICE)
```

**chromadb.sh:**
```bash
# Before
UUID=$(blkid -s UUID -o value $DEVICE)
echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab

# After
UUID=$$(blkid -s UUID -o value $DEVICE)
echo "UUID=$$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
```

### Verification
```bash
terraform plan
# Output: Plan: 50+ resources to add (no template errors)
```

---

## Issue 5: AWS Load Balancer Name Prefix Too Long ✅ FIXED

### Error Message
```
Error: "name_prefix" cannot be longer than 6 characters: "imageu-"

with module.loadbalancer.aws_lb.main,
on ../../modules/loadbalancer/main.tf line 3
```

### Root Cause
AWS ALB and target group `name_prefix` has a maximum length of 6 characters. The code was using `substr(var.project_name, 0, 6)` which gives "imageu", then adding "-", resulting in "imageu-" (7 characters).

### Solution Applied
Changed `substr(var.project_name, 0, 6)` to `substr(var.project_name, 0, 5)` to account for the trailing dash.

**Files Modified:**
- `terraform/modules/loadbalancer/main.tf` - Fixed both ALB and target group name_prefix

**Before:**
```hcl
resource "aws_lb" "main" {
  name_prefix = "${substr(var.project_name, 0, 6)}-"  # Results in "imageu-" (7 chars)
}

resource "aws_lb_target_group" "frontend" {
  name_prefix = "${substr(var.project_name, 0, 6)}-"  # Results in "imageu-" (7 chars)
}
```

**After:**
```hcl
resource "aws_lb" "main" {
  name_prefix = "${substr(var.project_name, 0, 5)}-"  # Results in "image-" (6 chars)
}

resource "aws_lb_target_group" "frontend" {
  name_prefix = "${substr(var.project_name, 0, 5)}-"  # Results in "image-" (6 chars)
}
```

### Verification
```bash
terraform plan
# Output: Plan: 88 to add, 0 to change, 0 to destroy.
# No errors!
```

---

## Issue 4: AWS Credentials Not Configured ✅ RESOLVED

### Error Message
```
Error: No valid credential sources found

with provider["registry.terraform.io/hashicorp/aws"],
on provider.tf line 1, in provider "aws":
```

### Root Cause
AWS credentials not configured on local machine. This project uses AWS SSO with a specific profile.

### Solution Applied
Set the AWS_PROFILE environment variable to use the correct SSO profile:

```bash
# Set AWS profile for this session
export AWS_PROFILE=AdministratorAccess-695875594847

# Verify credentials work
aws sts get-caller-identity
# Should show Account: 695875594847
```

**Make permanent by adding to shell profile:**
```bash
# Add to ~/.zshrc or ~/.bashrc
echo 'export AWS_PROFILE=AdministratorAccess-695875594847' >> ~/.zshrc
source ~/.zshrc
```

**Note:** This project uses AWS SSO profile `AdministratorAccess-695875594847` for account `695875594847`. If you need to configure AWS SSO, contact your AWS administrator or see AWS SSO documentation.
</parameter>

---

## Documentation Created

### New Files
- `terraform/TROUBLESHOOTING.md` (357 lines) - Comprehensive troubleshooting guide
- `FIXES_APPLIED.md` (this file) - Summary of issues and fixes

### Updated Files
- `QUICKSTART.md` - Added AWS credentials configuration step
- `DEPLOYMENT.md` - Added Apple Silicon compatibility note
- `terraform/modules/compute/main.tf` - Removed template provider dependency
- `terraform/modules/storage/main.tf` - Fixed S3 lifecycle configuration
- `terraform/modules/compute/user_data/*.sh` - Fixed template syntax

---

## Current Status

✅ **All issues resolved**
- Apple Silicon (ARM64) support fixed
- S3 lifecycle warnings fixed
- Template syntax errors fixed
- AWS credentials configured (AWS_PROFILE set)

✅ **Ready to deploy:**
- Infrastructure validated with `terraform plan`
- All prerequisites met
- Ready to proceed with `terraform apply`

---

## Next Steps

1. **Set AWS profile** (if not already in shell profile):
   ```bash
   export AWS_PROFILE=AdministratorAccess-695875594847
   ```

2. **Deploy infrastructure:**
   ```bash
   cd terraform/environments/dev
   terraform apply
   ```

4. **Configure DNS** (after Terraform completes):
   ```bash
   terraform output route53_name_servers
   # Add NS records to jessespears.com
   ```

5. **Deploy application code** (see DEPLOYMENT.md for details)

---

## References

- **Full deployment guide:** `DEPLOYMENT.md`
- **Quick start guide:** `QUICKSTART.md`
- **Troubleshooting:** `terraform/TROUBLESHOOTING.md`
- **Terraform docs:** `terraform/README.md`
- **AI agent guidelines:** `AGENTS.md`, `terraform/AGENTS.md`

---

## Summary

All Terraform configuration issues have been resolved. The infrastructure is ready to deploy with AWS profile `AdministratorAccess-695875594847` configured. The estimated deployment time is ~2 hours (15 min active + 1-4 hours DNS propagation).

**Total fixes applied:** 5 issues resolved (4 code + 1 configuration)
**Files modified:** 10 files
**Lines changed:** ~75 lines across all files

The infrastructure code is now:
- ✅ Compatible with Apple Silicon Macs
- ✅ Following modern Terraform best practices
- ✅ Configured for AWS account 695875594847
- ✅ All AWS naming constraints satisfied
- ✅ Successfully validated with terraform plan
- ✅ Ready for deployment (88 resources)

**Command to deploy:**
```bash
export AWS_PROFILE=AdministratorAccess-695875594847
cd terraform/environments/dev
terraform apply
```
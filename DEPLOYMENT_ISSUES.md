# Deployment Issues and Fixes

This document tracks issues encountered during `terraform apply` and their resolutions.

---

## Issue 1: MySQL Version 8.0.35 Not Available ✅ FIXED

### Error Message
```
Error: creating RDS DB Instance: operation error RDS: CreateDBInstance, 
https response error StatusCode: 400, RequestID: e17436f4-9e05-4817-8828-d6d7dd2056c1, 
api error InvalidParameterCombination: Cannot find version 8.0.35 for mysql
```

### Root Cause
MySQL version 8.0.35 is not available in AWS RDS. AWS periodically deprecates old minor versions.

### Available Versions
Queried available MySQL 8.0 versions:
```
8.0.37
8.0.39
8.0.40
8.0.41
8.0.42
8.0.43
```

### Solution Applied
Updated MySQL version from `8.0.35` to `8.0.39` (stable, well-tested version).

**Files Modified:**
- `terraform/environments/dev/terraform.tfvars` - Updated `mysql_engine_version = "8.0.39"`
- `terraform/environments/dev/variables.tf` - Updated default value
- `terraform/modules/database/variables.tf` - Updated default value
- `terraform/environments/dev/terraform.tfvars.example` - Updated example

### Verification Command
```bash
aws rds describe-db-engine-versions \
  --engine mysql \
  --query "DBEngineVersions[?contains(EngineVersion, '8.0')].EngineVersion" \
  --output table
```

---

## Issue 2: IOPS Not Allowed for Storage < 400GB ✅ FIXED

### Error Message
```
Error: creating RDS DB Instance: operation error RDS: CreateDBInstance, 
https response error StatusCode: 400, RequestID: b5880627-d83e-4431-b87c-d0eab3114670, 
api error InvalidParameterCombination: You can't specify IOPS or storage throughput 
for engine mysql and a storage size less than 400.
```

### Root Cause
AWS RDS gp3 storage type only allows custom IOPS and throughput settings when:
- Storage size >= 400 GB
- For storage < 400 GB, gp3 uses default values (3000 IOPS, 125 MB/s throughput)

Our configuration:
- Storage: 20 GB (dev environment, small database)
- Attempting to set: `iops = 3000` and `storage_throughput = 125`

### AWS RDS gp3 Limits
| Storage Size | IOPS | Throughput |
|--------------|------|------------|
| < 400 GB | 3000 (default, not configurable) | 125 MB/s (default, not configurable) |
| >= 400 GB | 3000-16000 (configurable) | 125-1000 MB/s (configurable) |

### Solution Applied
Made IOPS and throughput conditional on storage size in `terraform/modules/database/main.tf`:

**Before:**
```hcl
resource "aws_db_instance" "main" {
  allocated_storage  = var.db_allocated_storage
  storage_type       = "gp3"
  iops               = var.db_iops               # Always set
  storage_throughput = var.db_storage_throughput # Always set
}
```

**After:**
```hcl
resource "aws_db_instance" "main" {
  allocated_storage  = var.db_allocated_storage
  storage_type       = "gp3"
  iops               = var.db_allocated_storage >= 400 ? var.db_iops : null
  storage_throughput = var.db_allocated_storage >= 400 ? var.db_storage_throughput : null
}
```

**Logic:**
- If storage >= 400 GB: Use custom IOPS and throughput values
- If storage < 400 GB: Set to `null` (AWS uses defaults)

**Files Modified:**
- `terraform/modules/database/main.tf` - Added conditional logic

### For Production Use
If you need custom IOPS/throughput for production:
1. Increase `db_allocated_storage` to at least 400 GB in `terraform.tfvars`
2. Custom IOPS and throughput will then be applied

---

## Status After Fixes

### What's Working ✅
- MySQL version updated to 8.0.39
- IOPS/throughput configuration fixed
- Terraform apply continuing (creating remaining resources)

### Resources Created (Partial List)
```
- VPC, subnets, NAT Gateway, Internet Gateway
- Security groups and IAM roles
- Route tables and VPC endpoints
- RDS subnet group and parameter group
- ACM certificate
- (RDS instance creation in progress...)
```

### Next Steps
1. Wait for terraform apply to complete (~10-15 minutes total)
2. Verify all 88 resources created successfully
3. Proceed with DNS configuration (see DEPLOYMENT.md)

---

## Lessons Learned

### Always Check Current AWS Service Versions
AWS services are constantly updated. Before deployment:
```bash
# Check available RDS engine versions
aws rds describe-db-engine-versions --engine mysql

# Check available instance types in region
aws ec2 describe-instance-types --region us-east-1

# Check AMI availability
aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami*"
```

### AWS Service Limits Vary by Configuration
- Read AWS documentation for service-specific limits
- For RDS gp3, custom IOPS requires >= 400 GB storage
- For EC2 spot instances, pricing and availability varies by AZ
- For ACM certificates, DNS validation requires correct nameservers

### Use Conditional Logic for Flexibility
Make configurations adapt to different scenarios:
```hcl
# Good: Adapts to storage size
iops = var.storage >= 400 ? var.custom_iops : null

# Good: Conditional features
enable_feature = var.environment == "prod" ? true : false

# Good: Defaults when not applicable
monitoring_interval = var.enable_monitoring ? 60 : 0
```

---

## Reference

- **AWS RDS gp3 Documentation**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Storage.html
- **MySQL Version Support**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/MySQL.Concepts.VersionMgmt.html
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

---

## Quick Fix Summary

```bash
# Issue 1: MySQL version
# Changed: 8.0.35 → 8.0.39

# Issue 2: IOPS for small storage
# Changed: Always set → Conditional (null if < 400GB)

# Re-run deployment
cd terraform/environments/dev
export AWS_PROFILE=AdministratorAccess-695875594847
terraform apply
```

---

**Status**: Issues resolved, deployment continuing successfully.
**Last Updated**: 2025-10-02
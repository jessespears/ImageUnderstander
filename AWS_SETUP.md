# AWS Configuration Guide

This document explains how to configure AWS credentials for the ImageUnderstander project.

## Overview

This project uses **AWS SSO (Single Sign-On)** with a specific profile for account `695875594847`.

**AWS Profile**: `AdministratorAccess-695875594847`  
**AWS Account**: `695875594847`  
**AWS Region**: `us-east-1` (N. Virginia)

## Quick Setup

### Option 1: Set Environment Variable (Recommended)

```bash
# Set AWS profile for current session
export AWS_PROFILE=AdministratorAccess-695875594847

# Verify it works
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "...",
    "Account": "695875594847",
    "Arn": "arn:aws:sts::695875594847:assumed-role/..."
}
```

### Option 2: Add to Shell Profile (Permanent)

```bash
# For Zsh (macOS default)
echo 'export AWS_PROFILE=AdministratorAccess-695875594847' >> ~/.zshrc
source ~/.zshrc

# For Bash
echo 'export AWS_PROFILE=AdministratorAccess-695875594847' >> ~/.bashrc
source ~/.bashrc
```

### Option 3: Use direnv (Auto-loads when entering directory)

```bash
# Install direnv
brew install direnv

# Add to shell configuration
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
source ~/.zshrc

# Allow direnv in this project
cd ImageUnderstander
direnv allow
```

The `.envrc` file in this repository will automatically set `AWS_PROFILE` when you enter the directory.

## Verifying AWS Access

### Check Current Identity

```bash
aws sts get-caller-identity
```

Should show:
- **Account**: `695875594847`
- **Arn**: Contains `AdministratorAccess`

### Check AWS Profile Configuration

```bash
# List configured profiles
aws configure list-profiles

# Show current profile
echo $AWS_PROFILE
```

### Test AWS Permissions

```bash
# List S3 buckets (tests basic permissions)
aws s3 ls

# Describe VPCs (tests EC2 permissions)
aws ec2 describe-vpcs --region us-east-1

# List IAM users (tests IAM permissions)
aws iam list-users
```

## AWS SSO Configuration

If the profile `AdministratorAccess-695875594847` is not configured on your machine:

### Check if SSO is configured

```bash
cat ~/.aws/config
```

Look for a section like:
```ini
[profile AdministratorAccess-695875594847]
sso_start_url = https://your-org.awsapps.com/start
sso_region = us-east-1
sso_account_id = 695875594847
sso_role_name = AdministratorAccess
region = us-east-1
```

### Configure AWS SSO (if needed)

```bash
aws configure sso
```

Follow the prompts:
1. **SSO start URL**: `https://your-org.awsapps.com/start` (ask your AWS admin)
2. **SSO Region**: `us-east-1`
3. **SSO registration scopes**: `sso:account:access`
4. Browser will open for authentication
5. Select account: `695875594847`
6. Select role: `AdministratorAccess`
7. **CLI default region**: `us-east-1`
8. **CLI default output format**: `json`
9. **CLI profile name**: `AdministratorAccess-695875594847`

### Login to AWS SSO

If your SSO session expires:

```bash
aws sso login --profile AdministratorAccess-695875594847
```

Or if AWS_PROFILE is set:

```bash
aws sso login
```

## Required IAM Permissions

The `AdministratorAccess` role should have all necessary permissions. If using a restricted role, ensure these services are accessible:

- **EC2**: Create/manage instances, security groups, VPCs
- **RDS**: Create/manage databases
- **S3**: Create/manage buckets
- **IAM**: Create/manage roles and policies
- **ELB**: Create/manage load balancers
- **Route53**: Create/manage hosted zones and records
- **ACM**: Request/manage certificates
- **Secrets Manager**: Create/manage secrets
- **CloudWatch**: Create/manage logs and alarms
- **Systems Manager**: Access via Session Manager

## Troubleshooting

### Error: No valid credential sources found

**Problem**: AWS credentials not configured

**Solution**:
```bash
export AWS_PROFILE=AdministratorAccess-695875594847
aws sts get-caller-identity
```

If this fails, configure AWS SSO (see above).

### Error: The security token included in the request is expired

**Problem**: SSO session expired

**Solution**:
```bash
aws sso login --profile AdministratorAccess-695875594847
```

### Error: Could not connect to the endpoint URL

**Problem**: Wrong region or network issue

**Solution**:
```bash
# Ensure region is set
export AWS_DEFAULT_REGION=us-east-1

# Or specify region in command
aws s3 ls --region us-east-1
```

### Error: An error occurred (UnauthorizedOperation)

**Problem**: Insufficient permissions

**Solution**: Contact your AWS administrator to ensure your role has necessary permissions.

### Profile not found

**Problem**: Profile `AdministratorAccess-695875594847` doesn't exist

**Solution**: Configure AWS SSO (see "AWS SSO Configuration" above)

## Using with Terraform

Terraform automatically uses the AWS_PROFILE environment variable:

```bash
# Set profile
export AWS_PROFILE=AdministratorAccess-695875594847

# Verify Terraform can access AWS
cd terraform/environments/dev
terraform init
terraform plan
```

You can also specify the profile in provider configuration (already configured in this project):

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "AdministratorAccess-695875594847"  # Optional
}
```

## Security Best Practices

1. **Never commit AWS credentials to git** - Already configured in `.gitignore`
2. **Use SSO instead of long-term access keys** - This project uses SSO ✓
3. **Rotate credentials regularly** - SSO sessions expire automatically
4. **Use least-privilege access** - AdministratorAccess is for infrastructure management
5. **Enable MFA** - Should be configured at the SSO level
6. **Monitor CloudTrail** - All API calls are logged

## Alternative: Using AWS Access Keys (Not Recommended)

If you must use access keys instead of SSO:

```bash
# Configure with access keys
aws configure --profile AdministratorAccess-695875594847
# Enter:
#   AWS Access Key ID: AKIAIOSFODNN7EXAMPLE
#   AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
#   Default region name: us-east-1
#   Default output format: json

# Set profile
export AWS_PROFILE=AdministratorAccess-695875594847

# Verify
aws sts get-caller-identity
```

**Note**: SSO is more secure and recommended for production use.

## Quick Reference

| Command | Purpose |
|---------|---------|
| `export AWS_PROFILE=AdministratorAccess-695875594847` | Set profile for session |
| `aws sts get-caller-identity` | Verify credentials |
| `aws sso login` | Login to SSO |
| `aws configure list-profiles` | List profiles |
| `aws configure sso` | Configure SSO |
| `echo $AWS_PROFILE` | Check current profile |

## Next Steps

Once AWS is configured:

1. ✅ Verify credentials: `aws sts get-caller-identity`
2. ✅ Initialize Terraform: `cd terraform/environments/dev && terraform init`
3. ✅ Review plan: `terraform plan`
4. ✅ Deploy: `terraform apply`

See `DEPLOYMENT.md` for full deployment guide.

## Support

- **AWS SSO Issues**: Contact your AWS administrator
- **Permission Issues**: Contact your AWS administrator
- **Terraform Issues**: See `terraform/TROUBLESHOOTING.md`
- **General Setup**: See `QUICKSTART.md` or `DEPLOYMENT.md`

---

**Summary**: Set `export AWS_PROFILE=AdministratorAccess-695875594847` and you're ready to deploy!
# ImageUnderstander - Quick Start Guide

## 🚀 Deploy in 5 Steps

**Domain**: `imageunderstander.jessespears.com`  
**Time**: ~2 hours (15 min active + 1-4 hours DNS wait)  
**Cost**: ~$521/month

### Prerequisites
- AWS account with credentials
- AWS CLI installed (`brew install awscli`)
- Terraform >= 1.5.0
- Access to `jessespears.com` DNS

---

## Step 0: Configure AWS Credentials (5 min)

```bash
# Set AWS profile
export AWS_PROFILE=AdministratorAccess-695875594847

# Verify credentials work
aws sts get-caller-identity
```

**Add to your shell profile to make permanent:**
```bash
# Add to ~/.zshrc or ~/.bashrc
echo 'export AWS_PROFILE=AdministratorAccess-695875594847' >> ~/.zshrc
source ~/.zshrc
```

**Note:** Your AWS SSO profile `AdministratorAccess-695875594847` must be configured. If not already set up, contact your AWS administrator.

---

## Step 1: Deploy Infrastructure (15 min)

```bash
cd terraform/environments/dev

# Review configuration (already set for your domain)
cat terraform.tfvars

# Initialize and deploy
terraform init
terraform apply
```

Type `yes` when prompted. Wait 15 minutes. ☕

---

## Step 2: Configure DNS (5 min)

```bash
# Get Route53 nameservers
terraform output route53_name_servers
```

Add NS record to `jessespears.com` DNS:
- **Type**: NS
- **Name**: `imageunderstander`
- **Value**: (the 4 nameservers from above)

---

## Step 3: Wait for DNS (1-4 hours)

```bash
# Check propagation
dig NS imageunderstander.jessespears.com

# Check certificate validation
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --query 'Certificate.Status'
```

Wait until certificate shows `ISSUED`.

---

## Step 4: Deploy Application Code (30-60 min)

```bash
# Connect to each instance
aws ssm start-session --target $(terraform output -raw frontend_instance_id)
aws ssm start-session --target $(terraform output -raw backend_instance_id)
aws ssm start-session --target $(terraform output -raw llm_instance_id)

# On each instance:
# - Clone your application code to /opt/[frontend|backend|llm]
# - Install dependencies
# - Start systemd service: sudo systemctl start [service].service
```

See `DEPLOYMENT.md` for detailed deployment steps.

---

## Step 5: Verify (5 min)

```bash
# Test the application
curl -I https://imageunderstander.jessespears.com/health

# Visit in browser
open https://imageunderstander.jessespears.com
```

---

## 🎉 Done!

Your application is now live at:
**https://imageunderstander.jessespears.com**

---

## 📊 What Was Created?

| Component | Instance Type | Purpose |
|-----------|---------------|---------|
| Frontend | t4g.micro (spot) | Web UI |
| Backend | t4g.micro (spot) | API server |
| LLM Service | g5.xlarge (GPU) | Qwen2-VL inference |
| ChromaDB | t3.medium | Vector database |
| RDS MySQL | db.t4g.micro (Multi-AZ) | Relational database |
| ALB | Application LB | HTTPS load balancer |
| Route53 | Hosted zone | DNS management |

---

## 🔧 Common Commands

### Verify AWS Connection
```bash
# Set AWS profile (if not in shell profile)
export AWS_PROFILE=AdministratorAccess-695875594847

# Check AWS credentials
aws sts get-caller-identity

# Should show your account ID: 695875594847
```

### View Infrastructure
```bash
cd terraform/environments/dev
terraform output
```

### Connect to Instances
```bash
aws ssm start-session --target $(terraform output -raw frontend_instance_id)
aws ssm start-session --target $(terraform output -raw backend_instance_id)
aws ssm start-session --target $(terraform output -raw llm_instance_id)
aws ssm start-session --target $(terraform output -raw chromadb_instance_id)
```

### View Logs
```bash
aws logs tail /aws/ec2/imageunderstander-dev/frontend --follow
aws logs tail /aws/ec2/imageunderstander-dev/backend --follow
aws logs tail /aws/ec2/imageunderstander-dev/llm --follow
```

### Check Service Status
```bash
# SSH to instance, then:
sudo systemctl status frontend.service
sudo systemctl status backend.service
sudo systemctl status llm.service
sudo systemctl status chromadb.service
```

### Restart Services
```bash
# On each instance via SSM:
sudo systemctl restart [service].service
```

---

## 💰 Cost Optimization

**Stop LLM when not in use** (saves ~$380/month):
```bash
aws ec2 stop-instances --instance-ids $(terraform output -raw llm_instance_id)
aws ec2 start-instances --instance-ids $(terraform output -raw llm_instance_id)
```

---

## 🧹 Cleanup

```bash
cd terraform/environments/dev
terraform destroy
```

Type `yes`. Then manually:
1. Remove NS record from `jessespears.com`
2. Empty S3 bucket if needed

---

## 📚 Documentation

- **Full Deployment Guide**: `DEPLOYMENT.md`
- **Terraform Docs**: `terraform/README.md`
- **Troubleshooting**: `terraform/TROUBLESHOOTING.md`
- **AI Agent Guide**: `terraform/AGENTS.md`
- **Route53 Guide**: `terraform/modules/route53/README.md`

---

## 🆘 Troubleshooting

### AWS Credentials Not Found
```bash
# Error: No valid credential sources found
export AWS_PROFILE=AdministratorAccess-695875594847
aws sts get-caller-identity

# If profile not found, configure AWS SSO or contact AWS admin
```

### Certificate Not Validating
```bash
dig NS imageunderstander.jessespears.com
# Should show Route53 nameservers
```

### Site Not Loading (503 Error)
```bash
# Check frontend health
aws ssm start-session --target $(terraform output -raw frontend_instance_id)
sudo systemctl status frontend.service
curl http://localhost:8080/health
```

### LLM Out of Memory
```bash
# Check GPU memory
nvidia-smi

# Consider upgrading instance or using smaller model
```

### High Costs
```bash
# Stop LLM instance when not needed
aws ec2 stop-instances --instance-ids $(terraform output -raw llm_instance_id)
```

---

## 🔐 Security Notes

- All instances in private subnets
- Access via AWS Systems Manager (no SSH keys)
- Secrets stored in AWS Secrets Manager
- HTTPS enforced (HTTP redirects to HTTPS)
- Encryption at rest (EBS, RDS, S3)

---

## 📞 Support

For detailed information, see:
- `DEPLOYMENT.md` - Full deployment walkthrough
- `terraform/README.md` - Infrastructure documentation
- `terraform/AGENTS.md` - AI agent guidelines

---

**Happy Deploying!** 🚀
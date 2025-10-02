# Deployment Guide for ImageUnderstander

This guide walks you through deploying the ImageUnderstander RAG application to AWS with the domain `imageunderstander.jessespears.com`.

## Prerequisites

- [x] AWS Account with appropriate permissions
- [x] AWS CLI configured with SSO profile
- [x] Terraform >= 1.5.0 installed
- [x] Domain: `jessespears.com` (already owned)
- [ ] Access to DNS management for `jessespears.com`

## Architecture Overview

**Domain**: `imageunderstander.jessespears.com`  
**Region**: `us-east-1` (N. Virginia)  
**Estimated Cost**: ~$521/month (mostly GPU instance)

**Infrastructure**:
- Frontend: t4g.micro (spot) - Node.js/React app
- Backend: t4g.micro (spot) - Python FastAPI
- LLM Service: g5.xlarge (on-demand) - Qwen2-VL with GPU
- ChromaDB: t3.medium (on-demand) - Vector database
- RDS MySQL: db.t4g.micro (Multi-AZ)
- ALB: HTTPS with ACM certificate
- Route53: DNS management for subdomain

## Deployment Steps

### Phase 1: Infrastructure Setup (15 minutes)

#### Step 1: Set AWS Profile

```bash
# Set the AWS profile for this session
export AWS_PROFILE=AdministratorAccess-695875594847

# Verify credentials work
aws sts get-caller-identity
# Should show Account: 695875594847
```

**Make permanent (optional):**
```bash
# Add to your shell profile
echo 'export AWS_PROFILE=AdministratorAccess-695875594847' >> ~/.zshrc
source ~/.zshrc
```

#### Step 2: Configure Terraform

The configuration is already set for your domain:

```bash
cd terraform/environments/dev
cat terraform.tfvars
```

Verify these settings:
- `domain_name = "imageunderstander.jessespears.com"` ✓
- `create_hosted_zone = true` ✓
- `aws_region = "us-east-1"` ✓

**Optional**: Review and adjust instance types or storage sizes if needed.

#### Step 3: Initialize Terraform

```bash
terraform init
```

This downloads AWS provider and initializes the backend.

**Note for Apple Silicon (M1/M2/M3) users**: The deprecated `template` provider has been replaced with the built-in `templatefile()` function, so there should be no compatibility issues. If you encounter any errors, see `terraform/TROUBLESHOOTING.md`.

#### Step 4: Review Infrastructure Plan

```bash
terraform plan
```

Review the ~50-60 resources that will be created:
- VPC with public/private subnets
- 4 EC2 instances
- RDS MySQL database
- Application Load Balancer
- Route53 hosted zone
- Security groups, IAM roles, etc.

#### Step 5: Apply Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

**This takes 10-15 minutes** to complete. Go get coffee ☕

### Phase 2: DNS Configuration (5 minutes + wait 1-4 hours)

#### Step 6: Get Route53 Name Servers

After terraform completes:

```bash
terraform output route53_name_servers
```

You'll see 4 name servers like:
```
[
  "ns-123.awsdns-12.com",
  "ns-456.awsdns-45.net",
  "ns-789.awsdns-78.org",
  "ns-012.awsdns-01.co.uk"
]
```

#### Step 7: Create NS Record for Subdomain

Go to your DNS provider where `jessespears.com` is managed and add:

**Record Type**: NS (Name Server)  
**Name**: `imageunderstander` (or `imageunderstander.jessespears.com`)  
**Value**: All 4 name servers from Step 5  
**TTL**: 300 (5 minutes)

**Example for different providers:**

**Cloudflare**:
1. Log in to Cloudflare
2. Select `jessespears.com`
3. Go to DNS → Add Record
4. Type: NS
5. Name: `imageunderstander`
6. Value: `ns-123.awsdns-12.com` (add all 4 as separate records)

**AWS Route53** (if jessespears.com is already in Route53):
```bash
# Get the parent zone ID for jessespears.com
PARENT_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name jessespears.com \
  --query 'HostedZones[0].Id' \
  --output text | cut -d'/' -f3)

# Get the child zone name servers
CHILD_NS=$(terraform output -json route53_name_servers | jq -r '.[]')

# Create NS record in parent zone
aws route53 change-resource-record-sets \
  --hosted-zone-id $PARENT_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "imageunderstander.jessespears.com",
        "Type": "NS",
        "TTL": 300,
        "ResourceRecords": [
          {"Value": "ns-123.awsdns-12.com"},
          {"Value": "ns-456.awsdns-45.net"},
          {"Value": "ns-789.awsdns-78.org"},
          {"Value": "ns-012.awsdns-01.co.uk"}
        ]
      }
    }]
  }'
```

#### Step 8: Wait for DNS Propagation

DNS changes take time to propagate globally:
- Minimum: 5 minutes (TTL)
- Typical: 1-4 hours
- Maximum: 48 hours

**Check propagation**:
```bash
# Check NS records
dig NS imageunderstander.jessespears.com

# Should show the Route53 nameservers
# If it shows your registrar's nameservers, wait longer

# Check globally
# https://www.whatsmydns.net/
# Search for: imageunderstander.jessespears.com (NS)
```

#### Step 9: Verify Certificate Validation

Once DNS propagates, ACM automatically validates your certificate:

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --query 'Certificate.Status' \
  --output text
```

Wait until it shows: `ISSUED` (takes 5-30 minutes after DNS propagates)

**Check A record was created**:
```bash
dig A imageunderstander.jessespears.com

# Should show ALB IP addresses
nslookup imageunderstander.jessespears.com
```

### Phase 3: Application Deployment (30-60 minutes)

Terraform created the infrastructure but **did NOT deploy application code**.

#### Step 10: Access Instances via AWS Systems Manager

```bash
# Get instance IDs
terraform output | grep instance_id

# Connect to each instance
aws ssm start-session --target $(terraform output -raw frontend_instance_id)
aws ssm start-session --target $(terraform output -raw backend_instance_id)
aws ssm start-session --target $(terraform output -raw llm_instance_id)
aws ssm start-session --target $(terraform output -raw chromadb_instance_id)
```

#### Step 11: Deploy Frontend Application

```bash
# Connect to frontend instance
aws ssm start-session --target $(terraform output -raw frontend_instance_id)

# On the instance:
cd /opt/frontend

# Clone your frontend repository
sudo -u ec2-user git clone https://github.com/yourusername/imageunderstander-frontend.git .

# Install dependencies
sudo -u ec2-user npm install

# Build for production
sudo -u ec2-user npm run build

# Create a simple health endpoint if not exists
sudo -u ec2-user tee /opt/frontend/server.js > /dev/null <<'EOF'
const express = require('express');
const path = require('path');
const app = express();

app.use(express.static('dist'));

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Frontend server running on port ${PORT}`);
});
EOF

# Install express if needed
sudo -u ec2-user npm install express

# Update systemd service
sudo tee /etc/systemd/system/frontend.service > /dev/null <<'EOF'
[Unit]
Description=Frontend Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/frontend
EnvironmentFile=/opt/frontend/.env
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=append:/var/log/frontend/app.log
StandardError=append:/var/log/frontend/error.log

[Install]
WantedBy=multi-user.target
EOF

# Start the service
sudo systemctl daemon-reload
sudo systemctl enable frontend.service
sudo systemctl start frontend.service

# Check status
sudo systemctl status frontend.service
```

#### Step 12: Deploy Backend Application

```bash
# Connect to backend instance
aws ssm start-session --target $(terraform output -raw backend_instance_id)

# On the instance:
cd /opt/backend

# Clone your backend repository
sudo -u ec2-user git clone https://github.com/yourusername/imageunderstander-backend.git .

# Activate virtual environment
sudo -u ec2-user bash -c "cd /opt/backend && source venv/bin/activate && pip install -r requirements.txt"

# Verify environment variables are set
cat /opt/backend/.env

# Start the service
sudo systemctl daemon-reload
sudo systemctl enable backend.service
sudo systemctl start backend.service

# Check status
sudo systemctl status backend.service

# Check logs
sudo journalctl -u backend.service -f
```

#### Step 13: Deploy LLM Service

**WARNING**: First model download takes 10-30 minutes and downloads 10-30 GB.

```bash
# Connect to LLM instance
aws ssm start-session --target $(terraform output -raw llm_instance_id)

# On the instance:
cd /opt/llm

# Clone your LLM service repository (or use the template)
# The template main.py is already created, but you may want to replace it
sudo -u ubuntu git clone https://github.com/yourusername/imageunderstander-llm.git .

# Install dependencies
sudo -u ubuntu pip3 install -r requirements.txt

# Verify GPU is available
nvidia-smi

# Verify environment
cat /opt/llm/.env

# Start the service (this will download the model on first run)
sudo systemctl daemon-reload
sudo systemctl enable llm.service
sudo systemctl start llm.service

# Monitor the first startup (model download)
sudo journalctl -u llm.service -f

# This will show model downloading progress
# Wait until you see "Model loaded successfully"
```

#### Step 14: Verify ChromaDB

ChromaDB should already be running:

```bash
# Connect to ChromaDB instance
aws ssm start-session --target $(terraform output -raw chromadb_instance_id)

# Check status
sudo systemctl status chromadb.service

# Test ChromaDB
curl http://localhost:8000/api/v1/heartbeat

# Should return: {"nanosecond heartbeat": ...}
```

### Phase 4: Verification (10 minutes)

#### Step 15: Test Each Service

```bash
# Test ALB health
curl -I https://imageunderstander.jessespears.com/health

# Should return 200 OK

# Test backend (from backend instance)
curl http://localhost:8000/health

# Test LLM service (from backend instance)
curl http://localhost:8001/health

# Test ChromaDB (from backend instance)
curl http://localhost:8000/api/v1/heartbeat
```

#### Step 16: Test End-to-End

```bash
# Visit in browser
open https://imageunderstander.jessespears.com

# Or with curl
curl https://imageunderstander.jessespears.com
```

#### Step 17: Check CloudWatch Logs

```bash
# View logs
aws logs tail /aws/ec2/imageunderstander-dev/frontend --follow
aws logs tail /aws/ec2/imageunderstander-dev/backend --follow
aws logs tail /aws/ec2/imageunderstander-dev/llm --follow
aws logs tail /aws/ec2/imageunderstander-dev/chromadb --follow
```

### Phase 5: Optional Configuration

#### Step 18: Update LLM API Key (if needed)

```bash
# Get secret name
SECRET_NAME=$(terraform output -raw app_secrets_name)

# Get current secret
CURRENT=$(aws secretsmanager get-secret-value \
  --secret-id $SECRET_NAME \
  --query SecretString --output text)

# Update with your API key
echo $CURRENT | jq '.llm_api_key = "your-actual-api-key"' | \
aws secretsmanager put-secret-value \
  --secret-id $SECRET_NAME \
  --secret-string file:///dev/stdin

# Restart services to pick up new secret
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Role,Values=Backend,LLM" \
  --parameters 'commands=["sudo systemctl restart backend.service llm.service"]'
```

#### Step 19: Set Up Monitoring Alerts (Optional)

```bash
# Create SNS topic for alerts
aws sns create-topic --name imageunderstander-alerts

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:$(aws sts get-caller-identity --query Account --output text):imageunderstander-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com

# Confirm subscription via email

# Update CloudWatch alarms to use this SNS topic (requires Terraform update)
```

## Access Information

After successful deployment:

- **Primary URL**: https://imageunderstander.jessespears.com
- **WWW URL**: https://www.imageunderstander.jessespears.com (if enabled)
- **API URL**: Backend at port 8000 (private, accessed via frontend)
- **Region**: us-east-1
- **Environment**: dev

## Troubleshooting

### AWS Credentials Not Found

**Problem**: `Error: No valid credential sources found`

**Solution**: Set the AWS profile environment variable:
```bash
export AWS_PROFILE=AdministratorAccess-695875594847
aws sts get-caller-identity
```

Add to shell profile for persistence:
```bash
echo 'export AWS_PROFILE=AdministratorAccess-695875594847' >> ~/.zshrc
source ~/.zshrc
```

### Terraform Init Fails on Apple Silicon

**Problem**: Error about incompatible provider for `darwin_arm64`

**Solution**: This has been fixed! The deprecated `template` provider was replaced with Terraform's built-in `templatefile()` function.

If you still see this error:
```bash
cd terraform/environments/dev
rm -rf .terraform .terraform.lock.hcl
terraform init
```

See `terraform/TROUBLESHOOTING.md` for more details.

### Certificate Not Validating

**Problem**: Certificate stuck in "Pending validation"

**Solution**:
```bash
# Check NS records propagated
dig NS imageunderstander.jessespears.com

# Should show Route53 nameservers
# If not, verify you added NS record in parent zone (jessespears.com)

# Check validation record exists
dig _xxxxx.imageunderstander.jessespears.com CNAME

# Wait up to 48 hours for DNS propagation
```

### ALB Returns 503 Service Unavailable

**Problem**: Load balancer shows unhealthy targets

**Solution**:
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Common issues:
# 1. Frontend not listening on port 8080
# 2. Frontend doesn't have /health endpoint
# 3. Security group blocking traffic

# Check frontend is running
aws ssm start-session --target $(terraform output -raw frontend_instance_id)
sudo systemctl status frontend.service
sudo netstat -tlnp | grep 8080
curl http://localhost:8080/health
```

### LLM Service Out of Memory

**Problem**: LLM service crashes or won't start

**Solution**:
```bash
# Check memory usage
nvidia-smi
free -h

# g5.xlarge has 24GB GPU memory
# Qwen2-VL-7B needs ~14-16GB

# If out of memory:
# 1. Use smaller model (Qwen2-VL-2B)
# 2. Upgrade to g5.2xlarge
# 3. Use model quantization (int8, int4)
```

### Cannot Connect to Instances

**Problem**: SSM session won't start

**Solution**:
```bash
# Verify SSM agent is running
# Check in EC2 console: Instance State > System Status

# Verify IAM role has SSManagedInstanceCore policy
aws iam list-attached-role-policies \
  --role-name imageunderstander-dev-frontend-*

# Check VPC endpoints are created
terraform output | grep vpc_endpoint

# Wait 5-10 minutes after instance launch for SSM to initialize
```

### High Costs

**Problem**: AWS bill higher than expected

**Solution**:
```bash
# Stop LLM instance when not in use (saves $380/month)
aws ec2 stop-instances --instance-ids $(terraform output -raw llm_instance_id)

# Start when needed
aws ec2 start-instances --instance-ids $(terraform output -raw llm_instance_id)

# Check Cost Explorer
# https://console.aws.amazon.com/cost-management/home

# Set up AWS Budget alert
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget file://budget.json
```

## Maintenance

### Updating Application Code

```bash
# Connect to instance via SSM
aws ssm start-session --target INSTANCE_ID

# Pull latest code
cd /opt/frontend  # or backend, llm
sudo -u ec2-user git pull origin main

# Rebuild/reinstall if needed
sudo -u ec2-user npm run build  # frontend
source venv/bin/activate && pip install -r requirements.txt  # backend

# Restart service
sudo systemctl restart frontend.service  # or backend, llm
```

### Rotating Secrets

```bash
# Rotate RDS password
aws secretsmanager rotate-secret \
  --secret-id $(terraform output -raw rds_secret_name)

# Update application secrets
aws secretsmanager update-secret \
  --secret-id $(terraform output -raw app_secrets_name) \
  --secret-string '{"llm_api_key":"new-key","jwt_secret_key":"...","encryption_key":"..."}'

# Restart affected services
```

### Scaling Resources

Update `terraform.tfvars`:

```hcl
# Upgrade backend instance
backend_instance_type = "t4g.small"

# Increase database storage
db_allocated_storage = 50

# Upgrade LLM instance
llm_instance_type = "g5.2xlarge"
```

Then apply:
```bash
terraform plan
terraform apply
```

### Backups

**RDS**: Automated daily backups (7-day retention) are already configured.

**Manual Snapshot**:
```bash
aws rds create-db-snapshot \
  --db-instance-identifier $(terraform output -raw db_instance_id) \
  --db-snapshot-identifier imageunderstander-manual-$(date +%Y%m%d)
```

**EBS Volumes**:
```bash
# Snapshot LLM model storage
aws ec2 create-snapshot \
  --volume-id $(aws ec2 describe-volumes \
    --filters "Name=tag:Name,Values=*llm*" \
    --query 'Volumes[0].VolumeId' --output text) \
  --description "LLM models backup $(date)"

# Snapshot ChromaDB data
aws ec2 create-snapshot \
  --volume-id $(aws ec2 describe-volumes \
    --filters "Name=tag:Name,Values=*chromadb*" \
    --query 'Volumes[0].VolumeId' --output text) \
  --description "ChromaDB data backup $(date)"
```

## Cleanup / Teardown

To destroy all infrastructure:

```bash
cd terraform/environments/dev

# Destroy everything
terraform destroy

# Type: yes

# This will:
# - Terminate all EC2 instances
# - Delete RDS database (final snapshot created if enabled)
# - Delete S3 bucket (must be empty first)
# - Delete Route53 hosted zone
# - Remove all networking components
```

**Manual cleanup needed**:
1. Remove NS record from parent zone (jessespears.com)
2. Delete any manual EBS snapshots
3. Empty S3 bucket if destroy fails

## Cost Breakdown

| Resource | Monthly Cost |
|----------|--------------|
| Frontend (t4g.micro spot) | ~$2 |
| Backend (t4g.micro spot) | ~$2 |
| LLM Service (g5.xlarge on-demand) | ~$380 |
| ChromaDB (t3.medium on-demand) | ~$30 |
| RDS MySQL (db.t4g.micro Multi-AZ) | ~$28 |
| ALB | ~$16 |
| NAT Gateway | ~$35 |
| EBS (150GB) | ~$12 |
| S3 | ~$5 |
| Route53 | ~$1 |
| CloudWatch | ~$10 |
| **Total** | **~$521/month** |

**Cost optimization tip**: Stop LLM instance when not in use to save ~$380/month.

## Support

- **Terraform Issues**: See `terraform/README.md` and `terraform/AGENTS.md`
- **AWS Resources**: Check AWS documentation
- **Application Issues**: See application-specific READMEs in backend/frontend directories

## Next Steps

After successful deployment:

1. [ ] Set up CI/CD pipeline (GitHub Actions, GitLab CI)
2. [ ] Configure monitoring alerts (SNS + CloudWatch)
3. [ ] Set up automated backups schedule
4. [ ] Enable AWS GuardDuty for threat detection
5. [ ] Enable AWS WAF on ALB for DDoS protection
6. [ ] Document application-specific deployment procedures
7. [ ] Create runbooks for common operational tasks
8. [ ] Set up cost alerts and budgets
9. [ ] Plan for production environment (separate from dev)
10. [ ] Test disaster recovery procedures

---

**Deployment Complete!** 🎉

Your ImageUnderstander application should now be running at:
**https://imageunderstander.jessespears.com**
# ImageUnderstander

RAG application with LLM-powered image understanding capabilities.

**Live URL**: https://imageunderstander.jessespears.com  
**Status**: Infrastructure configured, application deployment pending

## Quick Links

- **[Quick Start Guide](QUICKSTART.md)** - Deploy in 5 steps (~2 hours)
- **[Full Deployment Guide](DEPLOYMENT.md)** - Detailed walkthrough with troubleshooting
- **[Terraform Documentation](terraform/README.md)** - Infrastructure details
- **[AI Agent Guidelines](AGENTS.md)** - For LLM assistants working on this project

## Architecture

This is a full-stack RAG (Retrieval-Augmented Generation) application deployed on AWS:

- **Frontend**: React/TypeScript web interface (t4g.micro spot instance)
- **Backend API**: Python FastAPI service (t4g.micro spot instance)
- **LLM Service**: Qwen2-VL model on GPU (g5.xlarge with NVIDIA A10G)
- **Vector Database**: ChromaDB for embeddings (t3.medium)
- **SQL Database**: RDS MySQL Multi-AZ (db.t4g.micro)
- **Load Balancer**: ALB with HTTPS/ACM certificate
- **DNS**: Route53 managed subdomain

**Estimated Cost**: ~$521/month (mostly GPU instance - can be stopped when not in use)

## Repository Structure

```
ImageUnderstander/
├── QUICKSTART.md           # 5-step deployment guide
├── DEPLOYMENT.md           # Detailed deployment walkthrough
├── AGENTS.md              # AI agent development guidelines
├── README.md              # This file
├── LICENSE
│
├── terraform/             # Infrastructure as Code
│   ├── README.md         # Infrastructure documentation
│   ├── AGENTS.md         # Terraform-specific AI guidelines
│   ├── versions.tf       # Provider and backend configuration
│   │
│   ├── environments/     # Environment-specific configs
│   │   └── dev/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       ├── provider.tf
│   │       ├── terraform.tfvars          # Your configuration
│   │       └── terraform.tfvars.example  # Template
│   │
│   └── modules/          # Reusable Terraform modules
│       ├── networking/   # VPC, subnets, NAT, IGW
│       ├── security/     # Security groups, IAM roles
│       ├── storage/      # S3, Secrets Manager, CloudWatch
│       ├── database/     # RDS MySQL
│       ├── compute/      # EC2 instances
│       ├── loadbalancer/ # ALB configuration
│       └── route53/      # DNS management
│
├── backend/              # Python RAG application (to be added)
│   ├── app/
│   │   ├── main.py
│   │   ├── api/
│   │   ├── services/
│   │   ├── models/
│   │   └── utils/
│   ├── tests/
│   └── requirements.txt
│
├── frontend/             # TypeScript web interface (to be added)
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── services/
│   │   └── utils/
│   └── package.json
│
└── scripts/              # Deployment utilities (to be added)
```

## Getting Started

### Prerequisites

- AWS account with appropriate permissions
- AWS CLI configured (`aws configure`)
- Terraform >= 1.5.0
- Access to DNS for `jessespears.com` domain

### Deploy Infrastructure

1. **Quick Deploy** (if you just want it running):
   ```bash
   # Follow the 5-step guide
   cat QUICKSTART.md
   ```

2. **Detailed Deploy** (if you want to understand everything):
   ```bash
   # Follow the comprehensive guide
   cat DEPLOYMENT.md
   ```

3. **Manual Terraform** (if you know what you're doing):
   ```bash
   cd terraform/environments/dev
   terraform init
   terraform apply
   # Then configure DNS and deploy application code
   ```

### Configuration

The infrastructure is pre-configured for:
- **Domain**: `imageunderstander.jessespears.com`
- **Region**: `us-east-1` (N. Virginia)
- **Environment**: dev

To change settings, edit `terraform/environments/dev/terraform.tfvars`.

## Development Guidelines

### For Humans

- See `DEPLOYMENT.md` for infrastructure deployment
- See `terraform/README.md` for Terraform details
- Follow standard Python (PEP 8) and TypeScript conventions
- Use environment variables for configuration (never hardcode secrets)

### For AI Agents

- Read `AGENTS.md` for project-wide guidelines
- Read `terraform/AGENTS.md` for infrastructure guidelines
- User data scripts in `terraform/modules/compute/user_data/` are templates (application code must be deployed separately)
- Follow the established module structure and naming conventions

## Key Features

- **Fully Automated Infrastructure**: Terraform provisions all AWS resources
- **Automatic DNS Management**: Route53 handles certificate validation and A records
- **Secure by Default**: Private subnets, security groups, encrypted storage
- **Cost Optimized**: Spot instances for stateless services, right-sized resources
- **Production Ready**: Multi-AZ RDS, health checks, CloudWatch monitoring
- **Easy Access**: AWS Systems Manager (no SSH keys or bastion hosts)

## Infrastructure Components

### Networking
- VPC with public/private subnets across 2 availability zones
- NAT Gateway for private subnet internet access
- VPC endpoints for S3 and AWS Systems Manager (cost optimization)

### Compute
- **Frontend**: t4g.micro ARM instance (spot) - serves web UI
- **Backend**: t4g.micro ARM instance (spot) - API server
- **LLM Service**: g5.xlarge with NVIDIA A10G GPU - model inference
- **ChromaDB**: t3.medium - vector database for embeddings

### Storage
- **S3**: Versioned bucket for image/document uploads
- **EBS**: 50GB for LLM models, 100GB for ChromaDB data
- **RDS MySQL**: Multi-AZ, encrypted, automated backups

### Security
- Security groups with least-privilege access
- IAM roles for EC2 instances (S3, Secrets Manager, CloudWatch)
- Secrets Manager for passwords and API keys
- ACM certificate for HTTPS
- All storage encrypted at rest

### Monitoring
- CloudWatch logs for all services
- CloudWatch metrics and alarms
- Optional Route53 health checks

## Cost Breakdown

| Component | Monthly Cost |
|-----------|--------------|
| LLM Service (g5.xlarge GPU) | ~$380 |
| NAT Gateway | ~$35 |
| RDS MySQL (Multi-AZ) | ~$28 |
| ChromaDB (t3.medium) | ~$30 |
| ALB | ~$16 |
| EBS Storage (150GB) | ~$12 |
| CloudWatch Logs | ~$10 |
| S3 Storage | ~$5 |
| Frontend (spot) | ~$2 |
| Backend (spot) | ~$2 |
| Route53 | ~$1 |
| **Total** | **~$521/month** |

**Cost Optimization**: Stop the LLM instance when not in use to save ~$380/month.

## Deployment Status

✅ Infrastructure configuration complete  
✅ Terraform modules created  
✅ Documentation written  
⏳ Application code deployment pending  
⏳ CI/CD pipeline pending  

## Next Steps

1. Deploy the infrastructure (`terraform apply`)
2. Configure DNS nameservers for subdomain delegation
3. Deploy application code to EC2 instances
4. Set up CI/CD pipeline for automated deployments
5. Configure monitoring alerts
6. Test end-to-end functionality

## Troubleshooting

See `DEPLOYMENT.md` for comprehensive troubleshooting guide.

Common issues:
- **Certificate not validating**: Check DNS propagation with `dig NS imageunderstander.jessespears.com`
- **503 errors**: Frontend service not started or no `/health` endpoint
- **Cannot connect to instances**: Wait 5-10 minutes for SSM agent initialization
- **High costs**: Stop LLM instance when not in use

## Support

- **Infrastructure Issues**: See `terraform/README.md`
- **Deployment Issues**: See `DEPLOYMENT.md`
- **AI Agent Questions**: See `AGENTS.md`

## License

See [LICENSE](LICENSE) file for details.

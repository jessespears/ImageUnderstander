#!/bin/bash
set -e

# Update system
dnf update -y

# Install required packages
dnf install -y \
    amazon-cloudwatch-agent \
    amazon-ssm-agent \
    git \
    python3.11 \
    python3.11-pip \
    python3.11-devel \
    gcc \
    jq \
    awscli

# Start and enable services
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/backend/app.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/app",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/backend/error.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/error",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "${project_name}/${environment}/Backend",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"},
          {"name": "cpu_usage_iowait", "rename": "CPU_IOWAIT", "unit": "Percent"}
        ],
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          {"name": "used_percent", "rename": "DISK_USED", "unit": "Percent"}
        ],
        "resources": ["*"]
      },
      "mem": {
        "measurement": [
          {"name": "mem_used_percent", "rename": "MEM_USED", "unit": "Percent"}
        ]
      }
    }
  }
}
EOF

# Create log directory
mkdir -p /var/log/backend
chown ec2-user:ec2-user /var/log/backend

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Create application directory
mkdir -p /opt/backend
chown ec2-user:ec2-user /opt/backend

# ====================================================================
# REAL: Retrieve secrets from Secrets Manager
# This section actually fetches real credentials
# ====================================================================
# Retrieve secrets from Secrets Manager
aws secretsmanager get-secret-value \
    --secret-id ${rds_secret_name} \
    --region $$(curl -s http://169.254.169.254/latest/meta-data/placement/region) \
    --query SecretString \
    --output text > /tmp/rds_secret.json

aws secretsmanager get-secret-value \
    --secret-id ${app_secrets_name} \
    --region $$(curl -s http://169.254.169.254/latest/meta-data/placement/region) \
    --query SecretString \
    --output text > /tmp/app_secret.json

# Extract credentials
DB_USERNAME=$$(jq -r '.username' /tmp/rds_secret.json)
DB_PASSWORD=$$(jq -r '.password' /tmp/rds_secret.json)
JWT_SECRET=$$(jq -r '.jwt_secret_key' /tmp/app_secret.json)

# Clean up temporary files
rm /tmp/rds_secret.json /tmp/app_secret.json

# ====================================================================
# REAL: Environment configuration with actual secrets
# These environment variables will contain real database credentials
# ====================================================================
# Create environment configuration
cat > /opt/backend/.env <<EOF
# Application
ENVIRONMENT=${environment}
PORT=8000
LOG_LEVEL=info

# Database
DATABASE_URL=mysql://$$DB_USERNAME:$$DB_PASSWORD@${db_endpoint}/${db_name}
DB_HOST=$${db_endpoint%%:*}
DB_PORT=3306
DB_NAME=${db_name}
DB_USER=$$DB_USERNAME
DB_PASSWORD=$$DB_PASSWORD

# Storage
S3_BUCKET_NAME=${s3_bucket_name}
AWS_REGION=$$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

# Services
LLM_ENDPOINT=${llm_endpoint}
CHROMADB_ENDPOINT=${chromadb_endpoint}

# Security
JWT_SECRET_KEY=$$JWT_SECRET

# Secrets Manager
RDS_SECRET_NAME=${rds_secret_name}
APP_SECRETS_NAME=${app_secrets_name}
EOF

chown ec2-user:ec2-user /opt/backend/.env
chmod 600 /opt/backend/.env

# ====================================================================
# PLACEHOLDER: Python dependencies list
# These are example dependencies. You need to replace this with your
# actual requirements.txt from your backend application repository
# ====================================================================
# Install Python dependencies (example)
cat > /opt/backend/requirements.txt <<EOF
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-dotenv==1.0.0
pydantic==2.5.0
pydantic-settings==2.1.0
aiomysql==0.2.0
sqlalchemy==2.0.23
boto3==1.34.0
chromadb==0.4.18
httpx==0.25.2
python-multipart==0.0.6
pillow==10.1.0
numpy==1.26.2
EOF

chown ec2-user:ec2-user /opt/backend/requirements.txt

# ====================================================================
# PLACEHOLDER: Virtual environment and package installation
# This installs the example packages, but you need to:
# 1. Clone/deploy your actual backend code to /opt/backend
# 2. Use your real requirements.txt file
# 3. Run any additional setup (database migrations, etc.)
# ====================================================================
# Create virtual environment
su - ec2-user -c "cd /opt/backend && python3.11 -m venv venv"
su - ec2-user -c "cd /opt/backend && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"

# ====================================================================
# PLACEHOLDER: Systemd service configuration
# This assumes your backend has a standard FastAPI app structure
# at 'app.main:app'. You need to:
# 1. Deploy your actual application code
# 2. Update the ExecStart path to match your app structure
# 3. Run any database migrations or initialization
# ====================================================================
# Create systemd service for backend
cat > /etc/systemd/system/backend.service <<EOF
[Unit]
Description=Backend API Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/backend
Environment="PATH=/opt/backend/venv/bin"
EnvironmentFile=/opt/backend/.env
ExecStart=/opt/backend/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10
StandardOutput=append:/var/log/backend/app.log
StandardError=append:/var/log/backend/error.log

[Install]
WantedBy=multi-user.target
EOF

# ====================================================================
# NOT STARTED: The backend service is NOT automatically started
# You must deploy your application code first, then:
#   systemctl daemon-reload
#   systemctl enable backend.service
#   systemctl start backend.service
# ====================================================================

echo "Backend instance initialization complete" >> /var/log/user-data.log

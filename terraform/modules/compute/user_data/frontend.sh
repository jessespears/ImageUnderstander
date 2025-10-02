#!/bin/bash
set -e

# Update system
dnf update -y

# Install required packages
dnf install -y \
    amazon-cloudwatch-agent \
    amazon-ssm-agent \
    git \
    docker \
    jq

# Start and enable services
systemctl start docker
systemctl enable docker
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Install Node.js (latest LTS)
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/frontend/app.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/app",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/frontend/error.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/error",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "${project_name}/${environment}/Frontend",
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
mkdir -p /var/log/frontend
chown ec2-user:ec2-user /var/log/frontend

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Create application directory
mkdir -p /opt/frontend
chown ec2-user:ec2-user /opt/frontend

# ====================================================================
# PLACEHOLDER: Environment configuration
# In a real deployment, these values may come from Secrets Manager
# or be injected by your CI/CD pipeline
# ====================================================================
cat > /opt/frontend/.env <<EOF
NODE_ENV=production
BACKEND_URL=${backend_endpoint}
PORT=8080
EOF

chown ec2-user:ec2-user /opt/frontend/.env

# ====================================================================
# PLACEHOLDER: Systemd service configuration
# This assumes your frontend has a 'npm start' command
# In reality, you need to:
# 1. Clone/deploy your actual frontend code to /opt/frontend
# 2. Run 'npm install' to install dependencies
# 3. Build the production bundle (e.g., 'npm run build')
# 4. Configure the correct start command (might be 'npm run serve' or similar)
# ====================================================================
cat > /etc/systemd/system/frontend.service <<EOF
[Unit]
Description=Frontend Application
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/frontend
EnvironmentFile=/opt/frontend/.env
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
StandardOutput=append:/var/log/frontend/app.log
StandardError=append:/var/log/frontend/error.log

[Install]
WantedBy=multi-user.target
EOF

# ====================================================================
# NOT STARTED: The frontend service is NOT automatically started
# You must deploy your application code first, then:
#   systemctl daemon-reload
#   systemctl enable frontend.service
#   systemctl start frontend.service
# ====================================================================

echo "Frontend instance initialization complete" >> /var/log/user-data.log

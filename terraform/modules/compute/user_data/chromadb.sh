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
    gcc-c++ \
    make \
    sqlite-devel \
    jq

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
            "file_path": "/var/log/chromadb/app.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/app",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/chromadb/error.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/error",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "${project_name}/${environment}/ChromaDB",
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
mkdir -p /var/log/chromadb
chown ec2-user:ec2-user /var/log/chromadb

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Mount EBS volume for ChromaDB data storage
DEVICE="/dev/nvme1n1"
MOUNT_POINT="/mnt/chromadb"

# Wait for device to be available
for i in {1..30}; do
    if [ -e "$DEVICE" ]; then
        break
    fi
    sleep 2
done

# Check if filesystem exists, create if not
if ! file -s $DEVICE | grep -q ext4; then
    mkfs -t ext4 $DEVICE
fi

# Create mount point and mount
mkdir -p $MOUNT_POINT
mount $DEVICE $MOUNT_POINT

# Add to fstab for persistence
if ! grep -q "$MOUNT_POINT" /etc/fstab; then
    UUID=$$(blkid -s UUID -o value $DEVICE)
    echo "UUID=$$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
fi

chown -R ec2-user:ec2-user $MOUNT_POINT

# Create ChromaDB data directory
mkdir -p $MOUNT_POINT/data
chown -R ec2-user:ec2-user $MOUNT_POINT/data

# Create application directory
mkdir -p /opt/chromadb
chown ec2-user:ec2-user /opt/chromadb

# ====================================================================
# REAL: Environment configuration
# These settings configure ChromaDB to persist data to the EBS volume
# ====================================================================
# Create environment configuration
cat > /opt/chromadb/.env <<EOF
# Application
ENVIRONMENT=${environment}
PORT=8000
LOG_LEVEL=info

# ChromaDB Configuration
CHROMA_HOST=0.0.0.0
CHROMA_PORT=8000
CHROMA_DB_IMPL=duckdb+parquet
PERSIST_DIRECTORY=/mnt/chromadb/data
ANONYMIZED_TELEMETRY=False

# Authentication (optional, configure as needed)
CHROMA_SERVER_AUTH_CREDENTIALS_PROVIDER=chromadb.auth.token.TokenConfigServerAuthCredentialsProvider
CHROMA_SERVER_AUTH_PROVIDER=chromadb.auth.token.TokenAuthServerProvider

# Performance
CHROMA_WORKERS=2
EOF

chown ec2-user:ec2-user /opt/chromadb/.env
chmod 600 /opt/chromadb/.env

# ====================================================================
# REAL: ChromaDB installation with specific versions
# These packages are installed and the service will start automatically
# ====================================================================
# Install ChromaDB
cat > /opt/chromadb/requirements.txt <<EOF
chromadb==0.4.18
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-dotenv==1.0.0
pydantic==2.5.0
numpy==1.26.2
EOF

chown ec2-user:ec2-user /opt/chromadb/requirements.txt

# Create virtual environment and install dependencies
su - ec2-user -c "cd /opt/chromadb && python3.11 -m venv venv"
su - ec2-user -c "cd /opt/chromadb && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"

# ====================================================================
# PLACEHOLDER: ChromaDB server script (not actually used)
# This Python script is created but NOT used by the systemd service
# The actual service uses 'chroma run' command directly (see below)
# ====================================================================
# Create ChromaDB server script
cat > /opt/chromadb/server.py <<'PYEOF'
import chromadb
from chromadb.config import Settings
import os
from dotenv import load_dotenv

load_dotenv()

def main():
    persist_directory = os.getenv("PERSIST_DIRECTORY", "/mnt/chromadb/data")
    host = os.getenv("CHROMA_HOST", "0.0.0.0")
    port = int(os.getenv("CHROMA_PORT", "8000"))

    print(f"Starting ChromaDB server on {host}:{port}")
    print(f"Data directory: {persist_directory}")

    settings = Settings(
        chroma_db_impl="duckdb+parquet",
        persist_directory=persist_directory,
        anonymized_telemetry=False
    )

    # This will start the ChromaDB HTTP server
    chromadb.Server(settings=settings, host=host, port=port)

if __name__ == "__main__":
    main()
PYEOF

chown ec2-user:ec2-user /opt/chromadb/server.py

# ====================================================================
# REAL: Systemd service configuration for ChromaDB
# This service WILL automatically start ChromaDB on boot
# The 'chroma run' command is the standard ChromaDB server
# ====================================================================
# Create systemd service for ChromaDB
cat > /etc/systemd/system/chromadb.service <<EOF
[Unit]
Description=ChromaDB Vector Database
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/chromadb
Environment="PATH=/opt/chromadb/venv/bin"
EnvironmentFile=/opt/chromadb/.env
ExecStart=/opt/chromadb/venv/bin/chroma run --path /mnt/chromadb/data --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10
StandardOutput=append:/var/log/chromadb/app.log
StandardError=append:/var/log/chromadb/error.log

[Install]
WantedBy=multi-user.target
EOF

# ====================================================================
# REAL: ChromaDB service is ACTUALLY STARTED automatically
# Unlike the other services, ChromaDB starts on instance boot
# It will be ready immediately after instance initialization
# ====================================================================
# Enable and start ChromaDB service
systemctl daemon-reload
systemctl enable chromadb.service
systemctl start chromadb.service

echo "ChromaDB instance initialization complete" >> /var/log/user-data.log

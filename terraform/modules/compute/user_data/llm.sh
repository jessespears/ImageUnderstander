#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    awscli \
    jq \
    htop \
    nvtop \
    git \
    wget \
    curl

# Install CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Verify NVIDIA drivers
nvidia-smi || echo "WARNING: NVIDIA drivers not detected"

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<EOF
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/llm/app.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/app",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/llm/error.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/error",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/llm/inference.log",
            "log_group_name": "${cloudwatch_log_group}",
            "log_stream_name": "{instance_id}/inference",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "${project_name}/${environment}/LLM",
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
      },
      "nvidia_gpu": {
        "measurement": [
          {"name": "utilization_gpu", "rename": "GPU_UTILIZATION", "unit": "Percent"},
          {"name": "utilization_memory", "rename": "GPU_MEMORY_UTILIZATION", "unit": "Percent"},
          {"name": "temperature_gpu", "rename": "GPU_TEMPERATURE", "unit": "None"}
        ]
      }
    }
  }
}
EOF

# Create log directory
mkdir -p /var/log/llm
chown ubuntu:ubuntu /var/log/llm

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json

# Mount EBS volume for model storage
DEVICE="/dev/nvme1n1"
MOUNT_POINT="/mnt/models"

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

chown -R ubuntu:ubuntu $MOUNT_POINT

# Create application directory
mkdir -p /opt/llm
chown ubuntu:ubuntu /opt/llm

# ====================================================================
# REAL: Retrieve secrets from Secrets Manager
# This section actually fetches real API keys and credentials
# ====================================================================
# Retrieve secrets from Secrets Manager
REGION=$$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

aws secretsmanager get-secret-value \
    --secret-id ${app_secrets_name} \
    --region $REGION \
    --query SecretString \
    --output text > /tmp/app_secret.json

# Extract API key if needed
LLM_API_KEY=$$(jq -r '.llm_api_key' /tmp/app_secret.json)
rm /tmp/app_secret.json

# ====================================================================
# REAL: Environment configuration with actual secrets
# These environment variables will contain real API keys
# ====================================================================
# Create environment configuration
cat > /opt/llm/.env <<EOF
# Application
ENVIRONMENT=${environment}
PORT=8001
LOG_LEVEL=info

# GPU Configuration
CUDA_VISIBLE_DEVICES=0

# Model Configuration
MODEL_PATH=/mnt/models/qwen2-vl-7b
MODEL_NAME=Qwen/Qwen2-VL-7B-Instruct
DEVICE=cuda
MAX_TOKENS=2048
TEMPERATURE=0.7

# Storage
S3_BUCKET_NAME=${s3_bucket_name}
AWS_REGION=$$REGION
MODEL_CACHE_DIR=/mnt/models/cache

# API Configuration
LLM_API_KEY=$$LLM_API_KEY

# Performance
BATCH_SIZE=1
NUM_WORKERS=1
EOF

chown ubuntu:ubuntu /opt/llm/.env
chmod 600 /opt/llm/.env

# ====================================================================
# PLACEHOLDER: Python dependencies list
# These are example dependencies for Qwen2-VL. You may need to:
# 1. Adjust versions based on your specific model requirements
# 2. Add additional dependencies for your use case
# 3. Use your actual requirements.txt from your LLM service repository
# ====================================================================
# Install Python dependencies
cat > /opt/llm/requirements.txt <<EOF
fastapi==0.104.1
uvicorn[standard]==0.24.0
python-dotenv==1.0.0
pydantic==2.5.0
torch==2.1.2
transformers==4.36.0
accelerate==0.25.0
qwen-vl-utils==0.0.2
pillow==10.1.0
numpy==1.26.2
boto3==1.34.0
httpx==0.25.2
python-multipart==0.0.6
sentencepiece==0.1.99
protobuf==4.25.1
EOF

chown ubuntu:ubuntu /opt/llm/requirements.txt

# ====================================================================
# REAL: Package installation
# This actually installs the packages, but downloading models happens
# on first service start (which can take 10-30 minutes for large models)
# ====================================================================
# Install Python packages
su - ubuntu -c "cd /opt/llm && python3 -m pip install --upgrade pip"
su - ubuntu -c "cd /opt/llm && pip3 install -r requirements.txt"

# ====================================================================
# PLACEHOLDER: FastAPI service template
# This is a SIMPLIFIED EXAMPLE service. In reality, you need to:
# 1. Replace this with your actual LLM service implementation
# 2. Implement proper image processing for Qwen2-VL
# 3. Add error handling, batching, caching as needed
# 4. Handle model loading properly (this example is incomplete)
# 5. The model will download on first run (10-30 GB, takes time)
# ====================================================================
# Create a simple FastAPI service template
cat > /opt/llm/main.py <<'PYEOF'
from fastapi import FastAPI, HTTPException, File, UploadFile
from pydantic import BaseModel
from typing import Optional
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
import os
from pathlib import Path
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/llm/inference.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Qwen VL Inference Service")

class InferenceRequest(BaseModel):
    prompt: str
    image_path: Optional[str] = None
    max_tokens: Optional[int] = 2048
    temperature: Optional[float] = 0.7

class InferenceResponse(BaseModel):
    text: str
    model: str

# Global model and tokenizer
model = None
tokenizer = None

@app.on_event("startup")
async def load_model():
    global model, tokenizer
    model_name = os.getenv("MODEL_NAME", "Qwen/Qwen2-VL-7B-Instruct")
    device = os.getenv("DEVICE", "cuda")

    logger.info(f"Loading model: {model_name}")
    try:
        tokenizer = AutoTokenizer.from_pretrained(
            model_name,
            trust_remote_code=True,
            cache_dir=os.getenv("MODEL_CACHE_DIR", "/mnt/models/cache")
        )
        model = AutoModelForCausalLM.from_pretrained(
            model_name,
            torch_dtype=torch.float16,
            device_map=device,
            trust_remote_code=True,
            cache_dir=os.getenv("MODEL_CACHE_DIR", "/mnt/models/cache")
        )
        logger.info("Model loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "gpu_available": torch.cuda.is_available(),
        "gpu_count": torch.cuda.device_count() if torch.cuda.is_available() else 0
    }

@app.post("/inference", response_model=InferenceResponse)
async def generate(request: InferenceRequest):
    if model is None or tokenizer is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    try:
        logger.info(f"Generating response for prompt: {request.prompt[:50]}...")

        inputs = tokenizer(request.prompt, return_tensors="pt").to(model.device)

        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=request.max_tokens,
                temperature=request.temperature,
                do_sample=True
            )

        generated_text = tokenizer.decode(outputs[0], skip_special_tokens=True)

        logger.info("Generation complete")
        return InferenceResponse(
            text=generated_text,
            model=os.getenv("MODEL_NAME", "Qwen/Qwen2-VL-7B-Instruct")
        )
    except Exception as e:
        logger.error(f"Inference error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
async def root():
    return {"message": "Qwen VL Inference Service", "version": "1.0.0"}
PYEOF

chown ubuntu:ubuntu /opt/llm/main.py

# ====================================================================
# PLACEHOLDER: Systemd service configuration
# This service definition is a basic template. You should:
# 1. Deploy your actual LLM service code
# 2. Adjust memory limits based on your model size
# 3. Add health checks and monitoring
# 4. Consider using a process manager like supervisor
# ====================================================================
# Create systemd service for LLM
cat > /etc/systemd/system/llm.service <<EOF
[Unit]
Description=LLM Inference Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/llm
EnvironmentFile=/opt/llm/.env
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=10
StandardOutput=append:/var/log/llm/app.log
StandardError=append:/var/log/llm/error.log

# Resource limits
MemoryMax=24G
CPUQuota=400%

[Install]
WantedBy=multi-user.target
EOF

# ====================================================================
# NOT STARTED: The LLM service is NOT automatically started
# IMPORTANT: First model load will download 10-30 GB and take 10-30 minutes
# You must:
# 1. Deploy your actual LLM service code to /opt/llm
# 2. Ensure the model path or Hugging Face model name is correct
# 3. Start the service manually:
#      systemctl daemon-reload
#      systemctl enable llm.service
#      systemctl start llm.service
# 4. Monitor logs during first start: journalctl -u llm.service -f
# ====================================================================

echo "LLM instance initialization complete" >> /var/log/user-data.log

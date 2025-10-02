# Data source for latest Amazon Linux 2023 AMI (ARM64 for t4g instances)
data "aws_ami" "amazon_linux_2023_arm" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for latest Amazon Linux 2023 AMI (x86_64 for t3 instances)
data "aws_ami" "amazon_linux_2023_x86" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for Deep Learning AMI (for GPU instances)
data "aws_ami" "deep_learning" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04)*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Local variables for user data scripts
locals {
  frontend_user_data = templatefile("${path.module}/user_data/frontend.sh", {
    environment          = var.environment
    project_name         = var.project_name
    cloudwatch_log_group = var.cloudwatch_log_groups.frontend
    backend_endpoint     = "http://${aws_instance.backend.private_ip}:8000"
  })

  backend_user_data = templatefile("${path.module}/user_data/backend.sh", {
    environment          = var.environment
    project_name         = var.project_name
    cloudwatch_log_group = var.cloudwatch_log_groups.backend
    s3_bucket_name       = var.s3_bucket_name
    db_endpoint          = var.db_endpoint
    db_name              = var.db_name
    rds_secret_name      = var.rds_secret_name
    app_secrets_name     = var.app_secrets_name
    llm_endpoint         = "http://${aws_instance.llm.private_ip}:8001"
    chromadb_endpoint    = "http://${aws_instance.chromadb.private_ip}:8000"
  })

  llm_user_data = templatefile("${path.module}/user_data/llm.sh", {
    environment          = var.environment
    project_name         = var.project_name
    cloudwatch_log_group = var.cloudwatch_log_groups.llm
    s3_bucket_name       = var.s3_bucket_name
    app_secrets_name     = var.app_secrets_name
  })

  chromadb_user_data = templatefile("${path.module}/user_data/chromadb.sh", {
    environment          = var.environment
    project_name         = var.project_name
    cloudwatch_log_group = var.cloudwatch_log_groups.chromadb
  })
}

# Frontend Instance (t4g.micro - ARM, Spot)
resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.amazon_linux_2023_arm.id
  instance_type          = var.frontend_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.frontend_security_group_id]
  iam_instance_profile   = var.frontend_instance_profile_name

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price          = var.frontend_spot_max_price
      spot_instance_type = "one-time"
    }
  }

  user_data = local.frontend_user_data

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-frontend"
    Role = "Frontend"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Backend Instance (t4g.micro - ARM, Spot)
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux_2023_arm.id
  instance_type          = var.backend_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.backend_security_group_id]
  iam_instance_profile   = var.backend_instance_profile_name

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price          = var.backend_spot_max_price
      spot_instance_type = "one-time"
    }
  }

  user_data = local.backend_user_data

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-backend"
    Role = "Backend"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# LLM Service Instance (g5.xlarge - GPU, On-Demand)
resource "aws_instance" "llm" {
  ami                    = data.aws_ami.deep_learning.id
  instance_type          = var.llm_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.llm_security_group_id]
  iam_instance_profile   = var.llm_instance_profile_name

  user_data = local.llm_user_data

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 100
    encrypted             = true
    delete_on_termination = true
  }

  # EBS volume for LLM model storage
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = var.llm_ebs_volume_size
    iops                  = 3000
    throughput            = 125
    encrypted             = true
    delete_on_termination = false
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-llm"
    Role = "LLM"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ChromaDB Instance (t3.medium - x86, On-Demand)
resource "aws_instance" "chromadb" {
  ami                    = data.aws_ami.amazon_linux_2023_x86.id
  instance_type          = var.chromadb_instance_type
  subnet_id              = var.private_subnet_ids[1]
  vpc_security_group_ids = [var.chromadb_security_group_id]
  iam_instance_profile   = var.chromadb_instance_profile_name

  user_data = local.chromadb_user_data

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  # EBS volume for ChromaDB data storage
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = var.chromadb_ebs_volume_size
    iops                  = 3000
    throughput            = 125
    encrypted             = true
    delete_on_termination = false
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-chromadb"
    Role = "VectorDB"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

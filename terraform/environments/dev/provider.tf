provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ImageUnderstander"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}

# Additional provider aliases if needed for multi-region resources
# provider "aws" {
#   alias  = "us-west-2"
#   region = "us-west-2"
# }

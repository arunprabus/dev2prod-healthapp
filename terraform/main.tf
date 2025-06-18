terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for EKS cluster
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# S3 Bucket for file uploads
resource "aws_s3_bucket" "health_app_uploads" {
  bucket = "${var.project_name}-uploads-${var.environment}-${random_id.bucket_suffix.hex}"

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-uploads-${var.environment}"
    Environment = var.environment
  })
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "health_app_uploads" {
  bucket = aws_s3_bucket.health_app_uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "health_app_uploads" {
  bucket = aws_s3_bucket.health_app_uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "health_app_uploads" {
  bucket = aws_s3_bucket.health_app_uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Module
module "dynamodb" {
  source = "./dynamodb"

  table_name                    = "${var.project_name}-${var.environment}"
  environment                   = var.environment
  enable_point_in_time_recovery = var.environment == "prod"
  common_tags                   = var.common_tags
  aws_region                    = var.aws_region
}

# IAM Module
module "iam" {
  source = "./iam"

  cluster_name              = var.cluster_name
  namespace                 = var.kubernetes_namespace
  service_account_name      = var.service_account_name
  health_profiles_table_arn = module.dynamodb.health_profiles_table_arn
  file_uploads_table_arn    = module.dynamodb.file_uploads_table_arn
  s3_bucket_arn             = aws_s3_bucket.health_app_uploads.arn
  common_tags               = var.common_tags
}

# Kubernetes Service Account
resource "kubernetes_service_account" "health_api" {
  metadata {
    name      = var.service_account_name
    namespace = var.kubernetes_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam.health_api_role_arn
    }
  }
}

# Kubernetes Secret for DynamoDB table names
resource "kubernetes_secret" "health_api_config" {
  metadata {
    name      = "health-api-config"
    namespace = var.kubernetes_namespace
  }

  data = {
    DYNAMODB_PROFILES_TABLE = module.dynamodb.health_profiles_table_name
    DYNAMODB_UPLOADS_TABLE  = module.dynamodb.file_uploads_table_name
    S3_BUCKET               = aws_s3_bucket.health_app_uploads.bucket
    AWS_REGION              = var.aws_region
  }
}
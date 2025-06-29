terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
  
  backend "s3" {
    # Backend config will be provided via -backend-config
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

locals {
  environment = "dev"
  name_prefix = "health-app-${local.environment}"
  tags = {
    Project     = "Health App"
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix           = local.name_prefix
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["ap-south-1a", "ap-south-1b"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  environment          = local.environment
  tags                 = local.tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = "${local.name_prefix}-cluster"
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_desired_size  = 1
  node_max_size      = 1
  node_min_size      = 1
  node_instance_types = ["t2.micro"]
  environment        = local.environment
  tags               = local.tags
}

module "rds" {
  source = "../../modules/rds"

  identifier           = "${local.name_prefix}-db"
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  db_instance_class   = "db.t3.micro"
  db_allocated_storage = 20
  environment         = local.environment
  tags                = local.tags
}
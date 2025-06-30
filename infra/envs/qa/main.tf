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
  host                   = var.k3s_endpoint != "" ? var.k3s_endpoint : "https://127.0.0.1:6443"
  insecure               = true
  config_path            = null
}

locals {
  environment = "qa"
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
  vpc_cidr             = "10.1.0.0/16"
  availability_zones   = ["ap-south-1a", "ap-south-1b"]
  public_subnet_cidrs  = ["10.1.101.0/24", "10.1.102.0/24"]
  private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
  environment          = local.environment
  tags                 = local.tags
}

module "k3s" {
  source = "../../modules/k3s"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr_block
  subnet_id         = module.vpc.public_subnet_ids[0]
  k3s_instance_type = "t2.micro"
  environment       = local.environment
  ssh_public_key    = var.ssh_public_key
  tags              = local.tags
}

module "rds" {
  source = "../../modules/rds"

  identifier           = "${local.name_prefix}-db"
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  db_instance_class   = "db.t3.micro"
  db_allocated_storage = 20
  db_password         = "changeme123!"
  environment         = local.environment
  tags                = local.tags
}
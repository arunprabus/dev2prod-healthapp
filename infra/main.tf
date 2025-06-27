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
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}

locals {
  name_prefix = "health-app-${var.environment}"
  tags = {
    Project     = "Health App"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Define VPC identifiers for environments
  lower_env_vpc_name = "health-app-dev-vpc"
  higher_env_vpc_name = "health-app-prod-vpc"
}

# Data sources for looking up existing VPCs when creating monitoring environment
data "aws_vpc" "lower_env" {
  count = var.environment == "monitoring" && var.connect_to_lower_env ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [local.lower_env_vpc_name]
  }
}

data "aws_vpc" "higher_env" {
  count = var.environment == "monitoring" && var.connect_to_higher_env ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [local.higher_env_vpc_name]
  }
}

# Get route tables for the environments we need to peer with
data "aws_route_tables" "lower_env" {
  count = var.environment == "monitoring" && var.connect_to_lower_env ? 1 : 0
  vpc_id = data.aws_vpc.lower_env[0].id
}

data "aws_route_tables" "higher_env" {
  count = var.environment == "monitoring" && var.connect_to_higher_env ? 1 : 0
  vpc_id = data.aws_vpc.higher_env[0].id
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix           = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = var.environment
  tags                 = local.tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = "${local.name_prefix}-cluster"
  vpc_id            = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_desired_size  = var.node_desired_size
  node_max_size      = var.node_max_size
  node_min_size      = var.node_min_size
  node_instance_types = var.node_instance_types
  environment        = var.environment
  tags               = local.tags
}

module "rds" {
  source = "./modules/rds"

  identifier           = "${local.name_prefix}-db"
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  db_instance_class   = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  environment         = var.environment
  tags                = local.tags
}

# Deployment configuration for applications
module "deployment" {
  source = "./modules/deployment"

  environment     = var.environment
  eks_cluster_name = module.eks.cluster_name
  health_api_image = var.health_api_image

  depends_on = [module.eks]
}

# Deploy monitoring tools (only for monitoring environment)
module "monitoring" {
  source = "./modules/monitoring"
  count  = var.environment == "monitoring" ? 1 : 0

  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  eks_cluster_name = module.eks.cluster_name
  tags            = local.tags

  depends_on = [module.eks]
}

# Create VPC peering connections for monitoring environment
# Only applicable when deploying the monitoring environment
module "monitoring_to_lower_peering" {
  source = "./modules/vpc_peering"
  count  = var.environment == "monitoring" && var.connect_to_lower_env ? 1 : 0

  requestor_vpc_id        = module.vpc.vpc_id
  acceptor_vpc_id         = data.aws_vpc.lower_env[0].id
  requestor_route_table_ids = module.vpc.all_route_table_ids
  acceptor_route_table_ids  = data.aws_route_tables.lower_env[0].ids
  requestor_cidr          = module.vpc.vpc_cidr
  acceptor_cidr           = data.aws_vpc.lower_env[0].cidr_block
  tags                    = local.tags

  depends_on = [module.vpc]
}

module "monitoring_to_higher_peering" {
  source = "./modules/vpc_peering"
  count  = var.environment == "monitoring" && var.connect_to_higher_env ? 1 : 0

  requestor_vpc_id        = module.vpc.vpc_id
  acceptor_vpc_id         = data.aws_vpc.higher_env[0].id
  requestor_route_table_ids = module.vpc.all_route_table_ids
  acceptor_route_table_ids  = data.aws_route_tables.higher_env[0].ids
  requestor_cidr          = module.vpc.vpc_cidr
  acceptor_cidr           = data.aws_vpc.higher_env[0].cidr_block
  tags                    = local.tags

  depends_on = [module.vpc]
}
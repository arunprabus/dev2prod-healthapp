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
  host                   = var.k3s_endpoint != "" ? var.k3s_endpoint : "https://127.0.0.1:6443"
  insecure               = true
  config_path            = null
}

locals {
  # Use tags from variables merged with common tags
  tags = merge(local.common_tags, var.tags)

  # Define VPC identifiers for environments
  lower_env_vpc_name = "health-app-dev-vpc"
  test_env_vpc_name = "health-app-test-vpc"
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

module "k3s" {
  source = "./modules/k3s"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = module.vpc.vpc_cidr_block
  subnet_id         = module.vpc.public_subnet_ids[0]
  k3s_instance_type = var.k3s_instance_type
  environment       = var.environment
  ssh_public_key    = var.ssh_public_key
  s3_bucket         = var.tf_state_bucket
  tags              = local.tags
}

module "rds" {
  source = "./modules/rds"
  count  = var.database_config != null ? 1 : 0

  identifier                = var.database_config.identifier
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  instance_class           = var.database_config.instance_class
  allocated_storage        = var.database_config.allocated_storage
  engine                   = var.database_config.engine
  engine_version          = var.database_config.engine_version
  db_name                 = var.database_config.db_name
  username                = var.database_config.username
  backup_retention_period = var.database_config.backup_retention_period
  multi_az                = var.database_config.multi_az
  snapshot_identifier     = var.database_config.snapshot_identifier
  restore_from_snapshot   = var.restore_from_snapshot
  environment             = var.environment
  tags                    = var.tags
}

# Deployment configuration for applications (disabled until K3s is ready)
# module "deployment" {
#   source = "./modules/deployment"
#
#   environment      = var.environment
#   k3s_instance_ip  = module.k3s.instance_public_ip
#   health_api_image = var.health_api_image
#
#   depends_on = [module.k3s]
# }







# Deploy GitHub runner for CI/CD
module "github_runner" {
  source = "./modules/github-runner"

  network_tier     = var.environment
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.public_subnet_ids[0]  # Use public subnet for internet access
  ssh_public_key   = var.ssh_public_key
  repo_pat         = var.github_pat
  repo_name        = var.github_repo
  s3_bucket        = var.tf_state_bucket
  aws_region       = var.aws_region

  depends_on = [module.vpc]
}

# Deploy monitoring tools (only for monitoring environment)
module "monitoring" {
  source = "./modules/monitoring"
  count  = var.environment == "monitoring" ? 1 : 0

  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  k3s_instance_ip = module.k3s.instance_public_ip
  tags            = local.tags

  depends_on = [module.k3s]
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

# Output GitHub runner information
output "github_runner_private_ip" {
  description = "Private IP of GitHub runner"
  value       = module.github_runner.runner_ip
}

output "github_runner_public_ip" {
  description = "Public IP of GitHub runner"
  value       = module.github_runner.runner_public_ip
}
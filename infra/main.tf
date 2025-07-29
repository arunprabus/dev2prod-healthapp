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
  
  # Map network tier to environment
  environment = var.network_tier == "lower" ? "dev" : var.network_tier == "higher" ? "prod" : "monitoring"
  
  # Define VPC identifiers for networks
  lower_env_vpc_name = "health-app-lower-vpc"
  higher_env_vpc_name = "health-app-higher-vpc"
  monitoring_env_vpc_name = "health-app-monitoring-vpc"
  
  # Network-specific CIDR blocks
  network_cidrs = {
    lower = "10.0.0.0/16"
    higher = "10.1.0.0/16"
    monitoring = "10.3.0.0/16"
  }
  
  vpc_cidr = local.network_cidrs[var.network_tier]
}

# Data sources for looking up existing VPCs when creating monitoring environment
data "aws_vpc" "lower_env" {
  count = var.network_tier == "monitoring" && var.connect_to_lower_env ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [local.lower_env_vpc_name]
  }
}

data "aws_vpc" "higher_env" {
  count = var.network_tier == "monitoring" && var.connect_to_higher_env ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [local.higher_env_vpc_name]
  }
}

# Get route tables for the environments we need to peer with
data "aws_route_tables" "lower_env" {
  count = var.network_tier == "monitoring" && var.connect_to_lower_env ? 1 : 0
  vpc_id = data.aws_vpc.lower_env[0].id
}

data "aws_route_tables" "higher_env" {
  count = var.network_tier == "monitoring" && var.connect_to_higher_env ? 1 : 0
  vpc_id = data.aws_vpc.higher_env[0].id
}

module "vpc" {
  source = "./modules/vpc"

  name_prefix           = local.name_prefix
  vpc_cidr             = local.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = local.environment
  tags                 = local.tags
}

# Single cluster for higher/monitoring environments
module "k3s" {
  source = "./modules/k3s"
  count  = var.network_tier != "lower" ? 1 : 0

  name_prefix              = local.name_prefix
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = module.vpc.vpc_cidr_block
  subnet_id                = module.vpc.public_subnet_ids[0]
  k3s_instance_type        = var.k3s_instance_type
  environment              = local.environment
  ssh_public_key           = var.ssh_public_key
  s3_bucket                = var.tf_state_bucket
  db_security_group_id     = var.database_config != null ? module.rds[0].db_security_group_id : null
  tags                     = local.tags
  
  depends_on = [module.rds]
}

# Multiple clusters for lower environment
module "k3s_clusters" {
  source   = "./modules/k3s"
  for_each = var.network_tier == "lower" ? var.k8s_clusters : {}

  name_prefix              = "${local.name_prefix}-${each.key}"
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = module.vpc.vpc_cidr_block
  subnet_id                = module.vpc.public_subnet_ids[each.value.subnet_index]
  k3s_instance_type        = each.value.instance_type
  environment              = each.key
  ssh_public_key           = var.ssh_public_key
  s3_bucket                = var.tf_state_bucket
  runner_security_group_id = module.github_runner.runner_security_group_id
  db_security_group_id     = var.database_config != null ? module.rds[0].db_security_group_id : null
  tags                     = merge(local.tags, { Environment = each.key })
  
  depends_on = [module.rds]
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
  environment             = local.environment
  # Pass app security group IDs for cross-SG references
  app_security_group_ids  = var.network_tier == "lower" ? [for k, v in module.k3s_clusters : v.security_group_id] : (var.network_tier != "lower" && length(module.k3s) > 0 ? [module.k3s[0].security_group_id] : [])
  tags                    = var.tags
  
  depends_on = [module.k3s, module.k3s_clusters]
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

  network_tier     = var.network_tier
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.public_subnet_ids[0]  # Use public subnet for internet access
  ssh_public_key   = var.ssh_public_key
  repo_pat         = var.github_pat
  repo_name        = var.github_repo
  s3_bucket        = var.tf_state_bucket
  aws_region       = var.aws_region

  depends_on = [module.vpc]
}

# Deploy Parameter Store for configuration management
module "parameter_store" {
  source = "./modules/parameter-store"

  environment = local.environment
  aws_region  = var.aws_region
  parameters  = var.app_parameters
  tags        = local.tags
}

# Deploy monitoring tools (only for monitoring environment)
module "monitoring" {
  source = "./modules/monitoring"
  count  = var.network_tier == "monitoring" ? 1 : 0

  environment     = local.environment
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.public_subnet_ids
  k3s_instance_ip = var.environment != "lower" ? module.k3s[0].instance_public_ip : ""
  tags            = local.tags

  depends_on = [module.k3s]
}

# Create VPC peering connections for monitoring environment
# Only applicable when deploying the monitoring environment
module "monitoring_to_lower_peering" {
  source = "./modules/vpc_peering"
  count  = var.network_tier == "monitoring" && var.connect_to_lower_env ? 1 : 0

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
  count  = var.network_tier == "monitoring" && var.connect_to_higher_env ? 1 : 0

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

# Database outputs
output "db_instance_address" {
  description = "Database instance address"
  value       = var.database_config != null ? module.rds[0].db_instance_address : null
}

output "db_instance_port" {
  description = "Database instance port"
  value       = var.database_config != null ? module.rds[0].db_instance_port : null
}

output "db_security_group_id" {
  description = "Database security group ID"
  value       = var.database_config != null ? module.rds[0].db_security_group_id : null
}

# K3s security group outputs
output "dev_security_group_id" {
  description = "Dev cluster security group ID"
  value       = var.network_tier == "lower" && contains(keys(var.k8s_clusters), "dev") ? module.k3s_clusters["dev"].security_group_id : null
}

output "test_security_group_id" {
  description = "Test cluster security group ID"
  value       = var.network_tier == "lower" && contains(keys(var.k8s_clusters), "test") ? module.k3s_clusters["test"].security_group_id : null
}

output "k3s_security_group_id" {
  description = "K3s cluster security group ID (single cluster environments)"
  value       = var.network_tier != "lower" && length(module.k3s) > 0 ? module.k3s[0].security_group_id : null
}
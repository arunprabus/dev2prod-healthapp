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

# Lower Network (Dev + Test)
module "lower_network" {
  source = "../modules/vpc"

  name_prefix           = "health-app-lower"
  vpc_cidr             = var.lower_vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.lower_public_subnet_cidrs
  private_subnet_cidrs = var.lower_private_subnet_cidrs
  environment          = "lower"
  tags                 = var.tags
}

# Higher Network (Production)
module "higher_network" {
  source = "../modules/vpc"

  name_prefix           = "health-app-higher"
  vpc_cidr             = var.higher_vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.higher_public_subnet_cidrs
  private_subnet_cidrs = var.higher_private_subnet_cidrs
  environment          = "higher"
  tags                 = var.tags
}

# Monitoring Network
module "monitoring_network" {
  source = "../modules/vpc"

  name_prefix           = "health-app-monitoring"
  vpc_cidr             = var.monitoring_vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.monitoring_public_subnet_cidrs
  private_subnet_cidrs = var.monitoring_private_subnet_cidrs
  environment          = "monitoring"
  tags                 = var.tags
}

# K3s Clusters
module "dev_k3s" {
  source = "../modules/k3s"

  name_prefix       = "health-app-dev"
  vpc_id            = module.lower_network.vpc_id
  vpc_cidr          = module.lower_network.vpc_cidr_block
  subnet_id         = module.lower_network.public_subnet_ids[0]
  k3s_instance_type = var.k3s_instance_type
  environment       = "dev"
  ssh_public_key    = var.ssh_public_key
  s3_bucket         = var.tf_state_bucket
  tags              = var.tags
}

module "test_k3s" {
  source = "../modules/k3s"

  name_prefix       = "health-app-test"
  vpc_id            = module.lower_network.vpc_id
  vpc_cidr          = module.lower_network.vpc_cidr_block
  subnet_id         = module.lower_network.public_subnet_ids[1]
  k3s_instance_type = var.k3s_instance_type
  environment       = "test"
  ssh_public_key    = var.ssh_public_key
  s3_bucket         = var.tf_state_bucket
  tags              = var.tags
}

module "prod_k3s" {
  source = "../modules/k3s"

  name_prefix       = "health-app-prod"
  vpc_id            = module.higher_network.vpc_id
  vpc_cidr          = module.higher_network.vpc_cidr_block
  subnet_id         = module.higher_network.public_subnet_ids[0]
  k3s_instance_type = var.k3s_instance_type
  environment       = "prod"
  ssh_public_key    = var.ssh_public_key
  s3_bucket         = var.tf_state_bucket
  tags              = var.tags
}

module "monitoring_k3s" {
  source = "../modules/k3s"

  name_prefix       = "health-app-monitoring"
  vpc_id            = module.monitoring_network.vpc_id
  vpc_cidr          = module.monitoring_network.vpc_cidr_block
  subnet_id         = module.monitoring_network.public_subnet_ids[0]
  k3s_instance_type = var.k3s_instance_type
  environment       = "monitoring"
  ssh_public_key    = var.ssh_public_key
  s3_bucket         = var.tf_state_bucket
  tags              = var.tags
}

# Databases
module "lower_rds" {
  source = "../modules/rds"

  identifier                = "healthapidb-lower"
  vpc_id                   = module.lower_network.vpc_id
  private_subnet_ids       = module.lower_network.private_subnet_ids
  instance_class           = var.db_instance_class
  allocated_storage        = var.db_allocated_storage
  engine                   = "postgres"
  engine_version          = "15.12"
  db_name                 = "healthapi"
  username                = "postgres"
  backup_retention_period = 7
  multi_az                = false
  snapshot_identifier     = var.restore_from_snapshot ? var.snapshot_identifier : null
  restore_from_snapshot   = var.restore_from_snapshot
  environment             = "lower"
  tags                    = var.tags
}

module "higher_rds" {
  source = "../modules/rds"

  identifier                = "healthapidb-higher"
  vpc_id                   = module.higher_network.vpc_id
  private_subnet_ids       = module.higher_network.private_subnet_ids
  instance_class           = var.db_instance_class
  allocated_storage        = var.db_allocated_storage
  engine                   = "postgres"
  engine_version          = "15.12"
  db_name                 = "healthapi"
  username                = "postgres"
  backup_retention_period = 7
  multi_az                = true
  snapshot_identifier     = var.restore_from_snapshot ? var.snapshot_identifier : null
  restore_from_snapshot   = var.restore_from_snapshot
  environment             = "higher"
  tags                    = var.tags
}

# GitHub Runners
module "lower_github_runner" {
  source = "../modules/github-runner"

  network_tier     = "lower"
  vpc_id           = module.lower_network.vpc_id
  subnet_id        = module.lower_network.public_subnet_ids[0]
  ssh_public_key   = var.ssh_public_key
  repo_pat         = var.github_pat
  repo_name        = var.github_repo
  s3_bucket        = var.tf_state_bucket
  aws_region       = var.aws_region
}

module "higher_github_runner" {
  source = "../modules/github-runner"

  network_tier     = "higher"
  vpc_id           = module.higher_network.vpc_id
  subnet_id        = module.higher_network.public_subnet_ids[0]
  ssh_public_key   = var.ssh_public_key
  repo_pat         = var.github_pat
  repo_name        = var.github_repo
  s3_bucket        = var.tf_state_bucket
  aws_region       = var.aws_region
}

module "monitoring_github_runner" {
  source = "../modules/github-runner"

  network_tier     = "monitoring"
  vpc_id           = module.monitoring_network.vpc_id
  subnet_id        = module.monitoring_network.public_subnet_ids[0]
  ssh_public_key   = var.ssh_public_key
  repo_pat         = var.github_pat
  repo_name        = var.github_repo
  s3_bucket        = var.tf_state_bucket
  aws_region       = var.aws_region
}

# Monitoring Stack
module "monitoring_stack" {
  source = "../modules/monitoring"

  environment     = "monitoring"
  vpc_id          = module.monitoring_network.vpc_id
  subnet_ids      = module.monitoring_network.public_subnet_ids
  k3s_instance_ip = module.monitoring_k3s.instance_public_ip
  tags            = var.tags

  depends_on = [module.monitoring_k3s]
}

# VPC Peering for Monitoring
module "monitoring_to_lower_peering" {
  source = "../modules/vpc_peering"

  requestor_vpc_id        = module.monitoring_network.vpc_id
  acceptor_vpc_id         = module.lower_network.vpc_id
  requestor_route_table_ids = module.monitoring_network.all_route_table_ids
  acceptor_route_table_ids  = module.lower_network.all_route_table_ids
  requestor_cidr          = module.monitoring_network.vpc_cidr
  acceptor_cidr           = module.lower_network.vpc_cidr
  tags                    = var.tags
}

module "monitoring_to_higher_peering" {
  source = "../modules/vpc_peering"

  requestor_vpc_id        = module.monitoring_network.vpc_id
  acceptor_vpc_id         = module.higher_network.vpc_id
  requestor_route_table_ids = module.monitoring_network.all_route_table_ids
  acceptor_route_table_ids  = module.higher_network.all_route_table_ids
  requestor_cidr          = module.monitoring_network.vpc_cidr
  acceptor_cidr           = module.higher_network.vpc_cidr
  tags                    = var.tags
}
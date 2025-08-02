# Lower Network Environment (Dev + Test + Shared DB)
environment = "lower"
cluster_name = "health-app-lower"

# Industry Standard Network Configuration
vpc_cidr = "10.0.0.0/16"
# Public subnets: K3s clusters (need public IP for API access)
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]  # K3s Dev and Test
# Private subnets: Databases and internal services
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]  # DB subnets
# Management subnet: GitHub runners and bastion hosts
management_subnet_cidrs = ["10.0.100.0/24"]  # GitHub runners subnet

# K8s Clusters (Dev + Test)
k8s_clusters = {
  dev = {
    instance_type = "t2.micro"
    subnet_index = 0  # 10.0.1.0/24
    namespace = "health-app-dev"
  }
  test = {
    instance_type = "t2.micro" 
    subnet_index = 1  # 10.0.2.0/24
    namespace = "health-app-test"
  }
}

# Shared Database Configuration
database_config = {
  identifier = "health-app-shared-db"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  engine = "postgres"
  engine_version = "15.12"
  db_name = "healthapi"
  username = "postgres"
  multi_az = false
  backup_retention_period = 7
  subnet_group_name = "health-app-lower-db-subnet-group"
  # Restore from existing snapshot (DISABLED - prevents destroy/recreate)
  # snapshot_identifier = "healthapidb-snapshot"
}

# GitHub Runner Configuration
github_repo = "arunprabus/dev2prod-healthapp"
# ssh_public_key and github_pat will be provided via GitHub Actions secrets

# Tags
tags = {
  Project = "health-app"
  Environment = "lower"
  Network = "lower"
  ManagedBy = "terraform"
  CostCenter = "development"
}
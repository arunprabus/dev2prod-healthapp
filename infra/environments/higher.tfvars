# Higher Network Environment (Prod + Dedicated DB)
environment = "higher"
cluster_name = "health-app-higher"

# Network Configuration
vpc_cidr = "10.1.0.0/16"
public_subnet_cidrs = ["10.1.1.0/24"]  # Prod subnet
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]  # DB subnets

# K8s Clusters (Prod only) - FREE TIER
k8s_clusters = {
  prod = {
    instance_type = "t2.micro"  # FREE TIER
    subnet_index = 0  # 10.1.1.0/24
    namespace = "health-app-prod"
  }
}

# Dedicated Database Configuration - FREE TIER
database_config = {
  identifier = "health-app-prod-db"
  instance_class = "db.t3.micro"  # FREE TIER
  allocated_storage = 20  # FREE TIER (max 20GB)
  engine = "postgres"
  engine_version = "15.12"
  db_name = "healthapi"
  username = "postgres"
  multi_az = false  # FREE TIER (no multi-AZ)
  backup_retention_period = 7  # FREE TIER (max 7 days)
  subnet_group_name = "health-app-higher-db-subnet-group"
  # Restore from existing snapshot (DISABLED - prevents destroy/recreate)
  # snapshot_identifier = "healthapidb-snapshot"
}

# Tags
tags = {
  Project = "health-app"
  Environment = "higher"
  Network = "higher"
  ManagedBy = "terraform"
  CostCenter = "production"
}
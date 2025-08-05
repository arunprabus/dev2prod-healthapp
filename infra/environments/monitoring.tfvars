# Monitoring Network Environment
network_tier = "monitoring"
cluster_name = "health-app-monitoring"

# Network Configuration
vpc_cidr = "10.3.0.0/16"
public_subnet_cidrs = ["10.3.1.0/24"]
private_subnet_cidrs = ["10.3.10.0/24", "10.3.11.0/24"]

# K8s Clusters (Monitoring only)
k8s_clusters = {}

# No database for monitoring environment
database_config = null

# GitHub Runner Configuration
github_repo = "arunprabus/dev2prod-healthapp"

# VPC Peering Configuration
connect_to_lower_env = true
connect_to_higher_env = true

# Tags
tags = {
  Project = "health-app"
  Environment = "monitoring"
  Network = "monitoring"
  ManagedBy = "terraform"
  CostCenter = "operations"
}
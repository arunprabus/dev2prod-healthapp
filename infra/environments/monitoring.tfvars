# Monitoring Network Environment
environment = "monitoring"
cluster_name = "health-app-monitoring"

# Industry Standard Network Configuration
vpc_cidr = "10.3.0.0/16"
# Public subnets: K3s monitoring cluster
public_subnet_cidrs = ["10.3.1.0/24"]  # K3s Monitoring
# Private subnets: Internal monitoring services
private_subnet_cidrs = ["10.3.10.0/24"]  # Internal monitoring
# Management subnet: GitHub runners with cross-network access
management_subnet_cidrs = ["10.3.100.0/24"]  # GitHub runners subnet

# K8s Clusters (Monitoring only) - FREE TIER
k8s_clusters = {
  monitoring = {
    instance_type = "t2.micro"  # FREE TIER
    subnet_index = 0  # 10.3.1.0/24
    namespace = "monitoring"
  }
}

# No Database Configuration (monitoring doesn't need DB)
database_config = null

# VPC Peering Configuration
vpc_peering = {
  peer_with_lower = true
  peer_with_higher = true
}

# Tags
tags = {
  Project = "health-app"
  Environment = "monitoring"
  Network = "monitoring"
  ManagedBy = "terraform"
  CostCenter = "operations"
}
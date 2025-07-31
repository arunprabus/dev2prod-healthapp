# GitHub Runner Configuration
network_tier = "monitoring"

# Network Configuration
vpc_cidr = "10.3.0.0/16"
public_subnet_cidrs = ["10.3.101.0/24"]
private_subnet_cidrs = ["10.3.1.0/24"]
availability_zones = ["ap-south-1a"]

# Tags
tags = {
  Environment = "runner"
  Project = "health-app"
  ManagedBy = "terraform"
}
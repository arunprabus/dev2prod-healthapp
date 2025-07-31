# GitHub Runner Configuration
network_tier = "monitoring"

# Network Configuration
vpc_cidr = "10.2.0.0/16"
public_subnet_cidrs = ["10.2.1.0/24"]
private_subnet_cidrs = ["10.2.2.0/24"]
availability_zones = ["ap-south-1a"]

# Tags
tags = {
  Environment = "runner"
  Project = "health-app"
  ManagedBy = "terraform"
}
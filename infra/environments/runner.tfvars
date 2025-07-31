# GitHub Runner Configuration
environment = "runner"
project_name = "health-app"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24"]
private_subnet_cidrs = ["10.0.2.0/24"]
availability_zones = ["ap-south-1a"]

# Runner Configuration
enable_runner = true
runner_instance_type = "t2.micro"

# Tags
tags = {
  Environment = "runner"
  Project = "health-app"
  ManagedBy = "terraform"
}
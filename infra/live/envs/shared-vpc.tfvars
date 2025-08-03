# Use existing VPC to avoid IGW limit
use_existing_vpc = true
existing_vpc_id = "vpc-xxxxxxxxx"  # Replace with your existing VPC ID
existing_subnet_ids = ["subnet-xxxxxxxxx", "subnet-yyyyyyyyy"]  # Replace with existing subnet IDs

# Network configuration
vpc_cidr = "10.0.0.0/16"  # Should match existing VPC CIDR
availability_zones = ["ap-south-1a", "ap-south-1b"]

# Environment settings
project_name = "health-app"
environment = "shared"
region = "ap-south-1"
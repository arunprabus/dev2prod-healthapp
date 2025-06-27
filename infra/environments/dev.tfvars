environment = "dev"
aws_region  = "ap-south-1"

# Network Configuration for Lower Environment (Dev)
vpc_cidr = "10.0.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

# EKS Configuration (FREE TIER)
node_desired_size = 1
node_max_size = 1
node_min_size = 1
node_instance_types = ["t3.micro"]  # FREE TIER

# Database Configuration (FREE TIER)
db_instance_class = "db.t3.micro"    # FREE TIER
db_allocated_storage = 20            # FREE TIER
environment = "prod"
aws_region  = "ap-south-1"

# Network Configuration for Higher Environment (Prod)
vpc_cidr = "10.1.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
public_subnet_cidrs = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]

# EKS Configuration (Production)
node_desired_size = 3
node_max_size = 5
node_min_size = 2
node_instance_types = ["t3.large"]

# Database Configuration (Production)
db_instance_class = "db.t3.medium"
db_allocated_storage = 100
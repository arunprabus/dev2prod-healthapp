environment = "test"
aws_region  = "ap-south-1"

# Network Configuration (Shared with Dev)
vpc_cidr = "10.0.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs = ["10.0.103.0/24", "10.0.104.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

# EKS Configuration
node_desired_size = 1
node_max_size = 3
node_min_size = 1
node_instance_types = ["t3.small"]

# Database Configuration
db_instance_class = "db.t3.micro"
db_allocated_storage = 20
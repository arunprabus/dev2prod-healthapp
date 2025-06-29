environment = "prod"
aws_region  = "ap-south-1"

# Network Configuration for Higher Environment (Prod)
vpc_cidr = "10.1.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
public_subnet_cidrs = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]

# K3s Configuration (Production)
k3s_instance_type = "t3.medium"
# ssh_public_key will be passed from GitHub secret

# Database Configuration (Production)
db_instance_class = "db.t3.medium"
db_allocated_storage = 100
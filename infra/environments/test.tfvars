environment = "test"
aws_region  = "ap-south-1"

# Network Configuration for Test Environment (Separate CIDR)
vpc_cidr = "10.2.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs = ["10.2.101.0/24", "10.2.102.0/24"]
private_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24"]

# K3s Configuration (Test)
k3s_instance_type = "t3.small"
# ssh_public_key will be passed from GitHub secret

# Database Configuration (Test)
db_instance_class = "db.t3.small"
db_allocated_storage = 20

environment = "monitoring"
aws_region  = "ap-south-1"

# Network Configuration (Monitoring specific)
vpc_cidr = "10.3.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs = ["10.3.101.0/24", "10.3.102.0/24"]
private_subnet_cidrs = ["10.3.1.0/24", "10.3.2.0/24"]

# K3s Configuration (Minimal)
k3s_instance_type = "t3.small"

# Database Configuration (Minimal)
db_instance_class = "db.t3.small"
db_allocated_storage = 20

# Monitoring specific variables
connect_to_lower_env = true
connect_to_higher_env = true

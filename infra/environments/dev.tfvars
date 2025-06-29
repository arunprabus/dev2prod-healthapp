environment = "dev"
aws_region  = "ap-south-1"

# Network Configuration for Lower Environment (Dev)
vpc_cidr = "10.0.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

# K3s Configuration (FREE TIER)
k3s_instance_type = "t2.micro"  # FREE TIER
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7S6uO6kYMp3biTguvZzpD6/example-key"

# Database Configuration (FREE TIER)
db_instance_class = "db.t3.micro"    # FREE TIER
db_allocated_storage = 20            # FREE TIER
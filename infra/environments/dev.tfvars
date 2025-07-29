environment = "dev"
aws_region  = "ap-south-1"

# Network Configuration for Lower Environment (Dev)
vpc_cidr = "10.0.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

# K3s Configuration (FREE TIER)
k3s_instance_type = "t2.micro"  # FREE TIER
# ssh_public_key will be passed from GitHub secret

# Database Configuration (FREE TIER)
database_config = {
  identifier              = "health-app-dev-db"
  instance_class         = "db.t3.micro"    # FREE TIER
  allocated_storage      = 20               # FREE TIER
  engine                 = "mysql"
  engine_version         = "8.0"
  db_name               = "healthapp"
  username              = "admin"
  backup_retention_period = 0
  multi_az              = false
  snapshot_identifier   = null
}

db_port = 3306

# K8s clusters configuration for lower environment
k8s_clusters = {
  dev = {
    instance_type = "t2.micro"  # FREE TIER
    subnet_index  = 0
    namespace     = "health-app-dev"
  }
  test = {
    instance_type = "t2.micro"  # FREE TIER
    subnet_index  = 1
    namespace     = "health-app-test"
  }
}
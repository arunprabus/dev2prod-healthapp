# Lower Network Environment (Dev + Test + Shared DB)
environment = "lower"
cluster_name = "health-app-lower"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]  # Dev and Test subnets
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]  # DB subnets

# K8s Clusters (Dev + Test)
k8s_clusters = {
  dev = {
    instance_type = "t2.micro"
    subnet_index = 0  # 10.0.1.0/24
    namespace = "health-app-dev"
  }
  test = {
    instance_type = "t2.micro" 
    subnet_index = 1  # 10.0.2.0/24
    namespace = "health-app-test"
  }
}

# Shared Database Configuration
database_config = {
  identifier = "health-app-shared-db"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  engine = "postgres"
  engine_version = "15.4"
  db_name = "healthapi"
  username = "postgres"
  multi_az = false
  backup_retention_period = 7
  subnet_group_name = "health-app-lower-db-subnet-group"
  # Restore from existing snapshot (ENABLED BY DEFAULT)
  snapshot_identifier = "healthapidb-snapshot"
}

# Tags
tags = {
  Project = "health-app"
  Environment = "lower"
  Network = "lower"
  ManagedBy = "terraform"
  CostCenter = "development"
}
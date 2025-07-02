# New Network Architecture Configuration
# Lower Network: Dev + Test + Shared Database
# Higher Network: Prod + Dedicated Database  
# Monitoring Network: Cross-environment monitoring

# Lower Network (Dev + Test)
lower_network_cidr = "10.0.0.0/16"
lower_network_subnets = {
  dev_subnet  = "10.0.1.0/24"
  test_subnet = "10.0.2.0/24"
  db_subnet   = "10.0.10.0/24"  # Shared database subnet
}

# Higher Network (Production)
higher_network_cidr = "10.1.0.0/16"
higher_network_subnets = {
  prod_subnet = "10.1.1.0/24"
  db_subnet   = "10.1.10.0/24"  # Dedicated production database
}

# Monitoring Network
monitoring_network_cidr = "10.3.0.0/16"
monitoring_network_subnets = {
  monitoring_subnet = "10.3.1.0/24"
}

# Database Configuration
database_config = {
  # Shared database for dev/test (lower network)
  shared_db = {
    instance_class = "db.t3.micro"
    allocated_storage = 20
    multi_az = false
    backup_retention_period = 7
    subnet_group = "lower-network-db"
  }
  
  # Dedicated database for production (higher network)
  prod_db = {
    instance_class = "db.t3.small"
    allocated_storage = 100
    multi_az = true
    backup_retention_period = 30
    subnet_group = "higher-network-db"
  }
}

# VPC Peering for monitoring access
vpc_peering = {
  monitoring_to_lower = true
  monitoring_to_higher = true
  lower_to_higher = false  # No direct connection between dev/test and prod
}

# Environment isolation
environment_isolation = {
  dev = {
    network = "lower"
    database = "shared"
    namespace = "health-app-dev"
  }
  test = {
    network = "lower" 
    database = "shared"
    namespace = "health-app-test"
  }
  prod = {
    network = "higher"
    database = "dedicated"
    namespace = "health-app-prod"
  }
  monitoring = {
    network = "monitoring"
    database = "none"
    namespace = "monitoring"
  }
}
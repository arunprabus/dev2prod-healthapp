# Higher Network Environment (Production)
aws_region = "ap-south-1"

# Network Configuration
higher_vpc_cidr = "10.1.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
higher_public_subnet_cidrs = ["10.1.101.0/24", "10.1.102.0/24"]
higher_private_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]

# K3s Configuration
k3s_instance_type = "t2.micro"

# Database Configuration
db_instance_class = "db.t3.micro"
db_allocated_storage = 20
restore_from_snapshot = false
# Uncomment to restore from snapshot
# snapshot_identifier = "healthapidb-snapshot"

# Tags
tags = {
  Project = "health-app"
  Environment = "higher"
  ManagedBy = "terraform"
  Owner = "devops-team"
  CostCenter = "engineering"
  Application = "health-api"
  BackupRequired = "true"
  DataClassification = "internal"
  ComplianceScope = "hipaa"
  Schedule = "24x7"
  AutoShutdown = "disabled"
  MonitoringLevel = "high"
}
# Monitoring Network Environment
aws_region = "ap-south-1"

# Network Configuration
monitoring_vpc_cidr = "10.2.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
monitoring_public_subnet_cidrs = ["10.2.101.0/24", "10.2.102.0/24"]
monitoring_private_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24"]

# K3s Configuration
k3s_instance_type = "t2.micro"

# VPC Peering
connect_to_lower_env = true
connect_to_higher_env = true

# Tags
tags = {
  Project = "health-app"
  Environment = "monitoring"
  ManagedBy = "terraform"
  Owner = "devops-team"
  CostCenter = "engineering"
  Application = "health-api-monitoring"
  BackupRequired = "true"
  DataClassification = "internal"
  ComplianceScope = "hipaa"
  Schedule = "business-hours"
  AutoShutdown = "enabled"
  MonitoringLevel = "high"
}
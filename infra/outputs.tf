# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# K3s Outputs
output "k3s_instance_ip" {
  description = "Public IP of the K3s instance"
  value       = module.k3s.instance_public_ip
}

output "k3s_cluster_endpoint" {
  description = "Endpoint for the K3s cluster API server"
  value       = module.k3s.cluster_endpoint
}

output "k3s_ssh_command" {
  description = "SSH command to connect to K3s instance"
  value       = module.k3s.ssh_command
}

# RDS Outputs
output "db_instance_endpoint" {
  description = "Connection endpoint for the RDS database"
  value       = module.rds.db_instance_endpoint
}

output "db_instance_name" {
  description = "Name of the RDS instance"
  value       = module.rds.db_instance_name
}

# Deployment Outputs
# output "kubernetes_namespace" {
#   description = "The Kubernetes namespace for the Health app deployment"
#   value       = module.deployment.namespace
# }

# output "config_map_name" {
#   description = "Name of the application config map"
#   value       = module.deployment.config_map_name
# }

# Monitoring Outputs (conditional based on whether monitoring is enabled)
output "prometheus_endpoint" {
  description = "Endpoint for Prometheus service"
  value       = var.environment == "monitoring" ? module.monitoring[0].prometheus_service_endpoint : null
}

output "grafana_endpoint" {
  description = "Endpoint for Grafana service"
  value       = var.environment == "monitoring" ? module.monitoring[0].grafana_service_endpoint : null
}

# Environment Information
output "environment" {
  description = "Current deployment environment"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

# Networking Architecture
output "network_architecture" {
  description = "Description of the network architecture"
  value       = "This deployment uses a ${var.environment == "prod" ? "higher" : "lower"} network in CIDR range ${var.vpc_cidr}."
}

# Deployment Status
output "deployment_status" {
  description = "Current deployment status"
  value       = "Deployed to ${var.environment} environment"
}

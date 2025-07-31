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

# K3s Outputs - Single cluster (higher/monitoring)
output "k3s_instance_ip" {
  description = "Public IP of the K3s instance"
  value       = var.network_tier != "lower" ? module.k3s[0].instance_public_ip : null
}

output "k3s_instance_id" {
  description = "Instance ID of the K3s instance"
  value       = var.network_tier != "lower" ? module.k3s[0].instance_id : null
}

output "k3s_cluster_endpoint" {
  description = "Endpoint for the K3s cluster API server"
  value       = var.network_tier != "lower" ? module.k3s[0].cluster_endpoint : null
}

# K3s Outputs - Multiple clusters (lower environment)
output "dev_cluster_ip" {
  description = "Public IP of the dev cluster"
  value       = var.network_tier == "lower" && contains(keys(var.k8s_clusters), "dev") ? module.k3s_clusters["dev"].instance_public_ip : null
}

output "test_cluster_ip" {
  description = "Public IP of the test cluster"
  value       = var.network_tier == "lower" && contains(keys(var.k8s_clusters), "test") ? module.k3s_clusters["test"].instance_public_ip : null
}

output "cluster_ips" {
  description = "Map of cluster names to IPs for lower environment"
  value       = var.network_tier == "lower" ? { for k, v in module.k3s_clusters : k => v.instance_public_ip } : {}
}



# RDS Outputs - commented out since RDS module is disabled
# output "db_instance_endpoint" {
#   description = "Connection endpoint for the RDS database"
#   value       = var.database_config != null ? module.rds[0].db_instance_endpoint : null
# }
#
# output "db_instance_name" {
#   description = "Name of the RDS instance"
#   value       = var.database_config != null ? module.rds[0].db_instance_name : null
# }

# Deployment Outputs
# output "kubernetes_namespace" {
#   description = "The Kubernetes namespace for the Health app deployment"
#   value       = module.deployment.namespace
# }

# output "config_map_name" {
#   description = "Name of the application config map"
#   value       = module.deployment.config_map_name
# }

# Monitoring Outputs - commented out since monitoring module is disabled
# output "prometheus_endpoint" {
#   description = "Endpoint for Prometheus service"
#   value       = var.environment == "monitoring" ? module.monitoring[0].prometheus_service_endpoint : null
# }
#
# output "grafana_endpoint" {
#   description = "Endpoint for Grafana service"
#   value       = var.environment == "monitoring" ? module.monitoring[0].grafana_service_endpoint : null
# }

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





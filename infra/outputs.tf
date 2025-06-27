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

# EKS Outputs
output "eks_cluster_id" {
  description = "ID of the EKS cluster"
  value       = module.eks.cluster_id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  description = "Certificate authority data for the EKS cluster"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
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
output "kubernetes_namespace" {
  description = "The Kubernetes namespace for the Health app deployment"
  value       = module.deployment.namespace
}

output "argocd_application_name" {
  description = "Name of the ArgoCD application"
  value       = module.deployment.argocd_application_name
}

# Monitoring Outputs (conditional based on whether monitoring is enabled)
output "prometheus_endpoint" {
  description = "Endpoint for Prometheus service"
  value       = var.enable_monitoring ? module.monitoring[0].prometheus_service_endpoint : null
}

output "grafana_endpoint" {
  description = "Endpoint for Grafana service"
  value       = var.enable_monitoring ? module.monitoring[0].grafana_service_endpoint : null
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

# Blue-Green Deployment Status (if applicable)
output "active_deployment_color" {
  description = "Currently active deployment color (blue/green) for production"
  value       = var.environment == "prod" ? data.kubernetes_resource.active_service[0].object.spec.selector.color : "n/a"
}

data "kubernetes_resource" "active_service" {
  count = var.environment == "prod" ? 1 : 0
  api_version = "v1"
  kind = "Service"
  metadata {
    name = "health-api-service"
    namespace = module.deployment.namespace
  }
}

# VPC Outputs
output "lower_vpc_id" {
  description = "ID of the Lower Network VPC"
  value       = module.lower_network.vpc_id
}

output "higher_vpc_id" {
  description = "ID of the Higher Network VPC"
  value       = module.higher_network.vpc_id
}

output "monitoring_vpc_id" {
  description = "ID of the Monitoring Network VPC"
  value       = module.monitoring_network.vpc_id
}

# K3s Outputs
output "dev_k3s_public_ip" {
  description = "Public IP of the Dev K3s cluster"
  value       = module.dev_k3s.instance_public_ip
}

output "test_k3s_public_ip" {
  description = "Public IP of the Test K3s cluster"
  value       = module.test_k3s.instance_public_ip
}

output "prod_k3s_public_ip" {
  description = "Public IP of the Production K3s cluster"
  value       = module.prod_k3s.instance_public_ip
}

output "monitoring_k3s_public_ip" {
  description = "Public IP of the Monitoring K3s cluster"
  value       = module.monitoring_k3s.instance_public_ip
}

# GitHub Runner Outputs
output "lower_github_runner_ip" {
  description = "Private IP of the Lower Network GitHub runner"
  value       = module.lower_github_runner.runner_ip
}

output "higher_github_runner_ip" {
  description = "Private IP of the Higher Network GitHub runner"
  value       = module.higher_github_runner.runner_ip
}

output "monitoring_github_runner_ip" {
  description = "Private IP of the Monitoring Network GitHub runner"
  value       = module.monitoring_github_runner.runner_ip
}

# Database Outputs
output "lower_db_endpoint" {
  description = "Endpoint of the Lower Network database"
  value       = module.lower_rds.db_endpoint
}

output "higher_db_endpoint" {
  description = "Endpoint of the Higher Network database"
  value       = module.higher_rds.db_endpoint
}

# Connection Instructions
output "connection_instructions" {
  description = "Instructions for connecting to K3s clusters"
  value = <<-EOT
    # Dev Cluster Connection
    ssh -i ~/.ssh/k3s-key ubuntu@${module.dev_k3s.instance_public_ip}
    
    # Test Cluster Connection
    ssh -i ~/.ssh/k3s-key ubuntu@${module.test_k3s.instance_public_ip}
    
    # Production Cluster Connection
    ssh -i ~/.ssh/k3s-key ubuntu@${module.prod_k3s.instance_public_ip}
    
    # Monitoring Cluster Connection
    ssh -i ~/.ssh/k3s-key ubuntu@${module.monitoring_k3s.instance_public_ip}
    
    # To get kubeconfig:
    scp -i ~/.ssh/k3s-key ubuntu@${module.dev_k3s.instance_public_ip}:/etc/rancher/k3s/k3s.yaml ./kubeconfig-dev.yaml
    # Then replace "127.0.0.1" with the cluster's public IP in the kubeconfig file
  EOT
}
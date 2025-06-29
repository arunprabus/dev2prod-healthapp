output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "k3s_cluster_name" {
  description = "K3s cluster name"
  value       = module.k3s.cluster_name
}

output "k3s_master_ip" {
  description = "K3s master public IP"
  value       = module.k3s.master_public_ip
}

output "ssh_command" {
  description = "SSH command to connect to K3s master"
  value       = module.k3s.ssh_command
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = module.k3s.kubeconfig_command
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_instance_endpoint
}

output "test_app_url" {
  description = "Test nginx app URL"
  value       = "http://${module.k3s.master_public_ip}:30080"
}
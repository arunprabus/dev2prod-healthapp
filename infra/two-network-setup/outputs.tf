output "vpc_id" {
  description = "VPC ID"
  value       = data.aws_vpc.default.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = data.aws_vpc.default.cidr_block
}

output "k3s_public_ip" {
  description = "K3s cluster public IP"
  value       = aws_instance.k3s.public_ip
}

output "k3s_instance_id" {
  description = "K3s instance ID"
  value       = aws_instance.k3s.id
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "ssh_command" {
  description = "SSH command to connect to K3s cluster"
  value       = "ssh -i ~/.ssh/k3s-key ubuntu@${aws_instance.k3s.public_ip}"
}

output "kubeconfig_download_command" {
  description = "Command to download kubeconfig from K3s cluster"
  value       = "scp -i ~/.ssh/k3s-key ubuntu@${aws_instance.k3s.public_ip}:/etc/rancher/k3s/k3s.yaml kubeconfig-${var.environment}.yaml"
}

output "kubeconfig_setup_commands" {
  description = "Commands to setup kubeconfig locally"
  value = [
    "scp -i ~/.ssh/k3s-key ubuntu@${aws_instance.k3s.public_ip}:/etc/rancher/k3s/k3s.yaml kubeconfig-${var.environment}.yaml",
    "sed -i 's/127.0.0.1/${aws_instance.k3s.public_ip}/' kubeconfig-${var.environment}.yaml",
    "export KUBECONFIG=$PWD/kubeconfig-${var.environment}.yaml",
    "kubectl get nodes"
  ]
}

output "frontend_url" {
  description = "Frontend application URL (after deployment)"
  value       = "http://${aws_instance.k3s.public_ip}:30080"
}

output "backend_url" {
  description = "Backend API URL (after deployment)"
  value       = "http://${aws_instance.k3s.public_ip}:30081"
}

output "environment_info" {
  description = "Environment information"
  value = {
    environment  = var.environment
    network_tier = var.network_tier
    vpc_cidr     = local.vpc_cidr
    cost_tier    = "FREE"
  }
}
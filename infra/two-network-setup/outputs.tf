output "vpc_id" {
  description = "VPC ID"
  value       = data.aws_vpc.first.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = data.aws_vpc.first.cidr_block
}

output "k3s_public_ip" {
  description = "K3s cluster public IP"
  value       = aws_instance.k3s.public_ip
}

output "k3s_instance_id" {
  description = "K3s instance ID"
  value       = aws_instance.k3s.id
}

output "github_runner_ip" {
  description = "GitHub runner IP"
  value       = module.github_runner.runner_ip
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.main.endpoint
}

output "environment_info" {
  description = "Environment information"
  value = {
    environment  = var.environment
    network_tier = var.network_tier
    cost_tier    = "FREE"
  }
}
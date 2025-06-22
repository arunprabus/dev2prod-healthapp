output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
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
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.k3s.public_ip}"
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
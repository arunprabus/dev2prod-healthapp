output "vpc_id" {
  description = "VPC ID"
  value       = local.current_vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = local.current_vpc.vpc_cidr_block
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
  description = "GitHub runner private IP"
  value       = module.github_runner.runner_ip
}

output "github_runner_public_ip" {
  description = "GitHub runner public IP"
  value       = module.github_runner.runner_public_ip
}

output "github_runner_ssh_command" {
  description = "SSH command to connect to GitHub runner"
  value       = "ssh -i ~/.ssh/your-key ubuntu@${module.github_runner.runner_public_ip}"
}

output "github_runner_debug_commands" {
  description = "Commands to debug GitHub runner"
  value = {
    ssh_connect = "ssh -i ~/.ssh/your-key ubuntu@${module.github_runner.runner_public_ip}"
    debug_script = "sudo /home/ubuntu/debug-runner.sh"
    service_status = "systemctl status actions.runner.*"
    service_logs = "journalctl -u actions.runner.* -f"
    cloud_init_logs = "sudo tail -f /var/log/cloud-init-output.log"
    config_logs = "cat /var/log/runner-config.log"
  }
}

# output "rds_endpoint" {
#   description = "RDS endpoint"
#   value       = aws_db_instance.main.endpoint
# }

output "k3s_endpoint" {
  description = "K3s API endpoint"
  value       = var.enable_ssl_termination ? "https://${module.k3s_nlb[0].nlb_dns_name}:443" : "https://${aws_instance.k3s.public_ip}:6443"
}

output "nlb_dns_name" {
  description = "NLB DNS name for K3s API (if SSL enabled)"
  value       = var.enable_ssl_termination ? module.k3s_nlb[0].nlb_dns_name : null
}

output "certificate_arn" {
  description = "ACM certificate ARN (if SSL enabled)"
  value       = var.enable_ssl_termination ? module.acm_certificate[0].certificate_arn : null
}

output "environment_info" {
  description = "Environment information"
  value = {
    environment     = var.environment
    network_tier    = var.network_tier
    cost_tier       = var.enable_ssl_termination ? "PAID (~$18/month)" : "FREE"
    k3s_endpoint    = var.enable_ssl_termination ? "https://${module.k3s_nlb[0].nlb_dns_name}:443" : "https://${aws_instance.k3s.public_ip}:6443"
    ssl_termination = var.enable_ssl_termination
  }
}

output "vpc_monitoring_id" {
  description = "Monitoring VPC ID"
  value       = module.vpc_monitoring.vpc_id
}

output "vpc_lower_id" {
  description = "Lower VPC ID"
  value       = module.vpc_lower.vpc_id
}

output "vpc_higher_id" {
  description = "Higher VPC ID"
  value       = module.vpc_higher.vpc_id
}
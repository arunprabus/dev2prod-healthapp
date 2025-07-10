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
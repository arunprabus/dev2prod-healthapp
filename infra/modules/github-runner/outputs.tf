output "runner_ip" {
  description = "Private IP of GitHub runner"
  value       = aws_instance.github_runner.private_ip
}

output "runner_public_ip" {
  description = "Public IP of GitHub runner"
  value       = aws_instance.github_runner.public_ip
}

output "runner_instance_id" {
  description = "Instance ID of GitHub runner"
  value       = aws_instance.github_runner.id
}

output "key_pair_name" {
  description = "Name of the created key pair"
  value       = aws_key_pair.github_runner.key_name
}
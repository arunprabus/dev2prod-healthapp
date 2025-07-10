variable "network_tier" {
  description = "Network tier (lower/higher/monitoring)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string
  sensitive   = true
}

variable "repo_pat" {
  description = "GitHub PAT for runner registration"
  type        = string
  sensitive   = true
}

variable "repo_name" {
  description = "GitHub repository (owner/repo)"
  type        = string
}

output "key_pair_name" {
  description = "Name of the created key pair"
  value       = aws_key_pair.github_runner.key_name
}
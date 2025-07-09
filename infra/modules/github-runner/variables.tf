variable "environment" {
  description = "Environment name"
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

variable "ssh_key_name" {
  description = "SSH key name"
  type        = string
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
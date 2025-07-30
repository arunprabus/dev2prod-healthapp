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

variable "s3_bucket" {
  description = "S3 bucket for log storage"
  type        = string
  default     = "health-app-terraform-state"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "metadata_ip" {
  description = "AWS metadata service IP"
  type        = string
  default     = "169.254.169.254"
}


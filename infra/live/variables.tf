variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}

variable "network_tier" {
  description = "Network tier (lower, higher, monitoring, cleanup)"
  type        = string
  validation {
    condition     = contains(["lower", "higher", "monitoring", "cleanup"], var.network_tier)
    error_message = "Network tier must be one of: lower, higher, monitoring, cleanup."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
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

variable "restore_from_snapshot" {
  description = "Whether to restore RDS from snapshot"
  type        = bool
  default     = false
}

variable "snapshot_identifier" {
  description = "RDS snapshot identifier to restore from"
  type        = string
  default     = null
}

variable "k3s_domain_name" {
  description = "Domain name for K3s API (e.g., k3s-dev.example.com)"
  type        = string
  default     = "k3s.local"
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS validation (optional)"
  type        = string
  default     = ""
}

variable "enable_ssl_termination" {
  description = "Enable ACM + NLB for SSL termination (costs ~$18/month)"
  type        = bool
  default     = false
}

locals {
  # Network CIDR based on tier
  vpc_cidr = var.network_tier == "lower" ? "10.0.0.0/16" : "10.1.0.0/16"
  
  # AZ selection
  az = "${var.aws_region}a"
  
  # Tags
  tags = {
    Project     = "Learning"
    Environment = var.environment
    NetworkTier = var.network_tier
    ManagedBy   = "Terraform"
  }
  
  # Resource naming
  name_prefix = "health-app-${var.network_tier}"
}
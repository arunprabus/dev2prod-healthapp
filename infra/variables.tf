# Core Configuration
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# K3s Configuration
variable "k3s_instance_type" {
  description = "Instance type for K3s node"
  type        = string
  default     = "t2.micro"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
  sensitive   = true
}

variable "k3s_endpoint" {
  description = "K3s cluster endpoint for Kubernetes provider"
  type        = string
  default     = ""
}

# Database Configuration
variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "Allocated storage for the database (GB)"
  type        = number
  default     = 20
}

# Application Configuration
variable "health_api_image" {
  description = "Docker image for Health API"
  type        = string
  default     = "ghcr.io/arunprabus/health-api:latest"
}

# Monitoring Configuration
variable "connect_to_lower_env" {
  description = "Whether to connect monitoring to lower environment VPC"
  type        = bool
  default     = false
}

variable "connect_to_higher_env" {
  description = "Whether to connect monitoring to higher environment VPC"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Whether to enable monitoring stack"
  type        = bool
  default     = false
}

# New variables for network-level configuration
variable "cluster_name" {
  description = "Base cluster name"
  type        = string
  default     = "health-app-cluster"
}

variable "k8s_clusters" {
  description = "K8s cluster configurations"
  type = map(object({
    instance_type = string
    subnet_index  = number
    namespace     = string
  }))
  default = {}
}

variable "database_config" {
  description = "Database configuration"
  type = object({
    identifier                = string
    instance_class           = string
    allocated_storage        = number
    engine                   = string
    engine_version          = string
    db_name                 = string
    username                = string
    multi_az                = bool
    backup_retention_period = number
    subnet_group_name       = string
    snapshot_identifier     = optional(string)
  })
  default = null
}

variable "vpc_peering" {
  description = "VPC peering configuration"
  type = object({
    peer_with_lower  = optional(bool, false)
    peer_with_higher = optional(bool, false)
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "restore_from_snapshot" {
  description = "Whether to restore from snapshot"
  type        = bool
  default     = false
}

variable "tf_state_bucket" {
  description = "S3 bucket for Terraform state and kubeconfig storage"
  type        = string
  default     = "health-app-terraform-state"
}

# GitHub Runner Configuration


variable "github_pat" {
  description = "GitHub Personal Access Token for runner registration"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
  default     = "arunprabus/dev2prod-healthapp"
}

# Additional variables for locals.tf
variable "team_name" {
  description = "Team name for tagging"
  type        = string
  default     = "devops-team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "engineering"
}

variable "backup_required" {
  description = "Whether backup is required"
  type        = string
  default     = "true"
}

variable "data_classification" {
  description = "Data classification level"
  type        = string
  default     = "internal"
}

variable "compliance_scope" {
  description = "Compliance scope"
  type        = string
  default     = "hipaa"
}
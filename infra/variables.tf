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
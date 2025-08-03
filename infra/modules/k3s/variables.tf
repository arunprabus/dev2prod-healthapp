variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for K3s instance"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "k3s_instance_type" {
  description = "Instance type for K3s node"
  type        = string
  default     = "t2.micro"
}

variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "s3_bucket" {
  description = "S3 bucket for kubeconfig upload"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "K3s cluster name"
  type        = string
}

variable "db_endpoint" {
  description = "Database endpoint for application configuration"
  type        = string
  default     = ""
}

variable "network_tier" {
  description = "Network tier (lower/higher/monitoring)"
  type        = string
}

variable "management_subnet_cidrs" {
  description = "CIDR blocks of management subnets for security group rules"
  type        = list(string)
  default     = []
}

variable "nlb_security_group_ids" {
  description = "Security group IDs of NLB for K3s API access"
  type        = list(string)
  default     = []
}
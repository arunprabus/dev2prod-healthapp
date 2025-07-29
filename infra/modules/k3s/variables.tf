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

variable "runner_security_group_id" {
  description = "Security group ID of the GitHub runner"
  type        = string
  default     = ""
}

variable "s3_bucket" {
  description = "S3 bucket for kubeconfig upload"
  type        = string
  default     = ""
}


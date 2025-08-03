variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for SSL certificate"
  type        = string
  default     = "healthapp.local"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ALB"
  type        = list(string)
}

variable "k3s_instance_id" {
  description = "K3s instance ID"
  type        = string
}

# Removed to avoid circular dependency
# variable "k3s_security_group_id" {
#   description = "K3s security group ID"
#   type        = string
# }
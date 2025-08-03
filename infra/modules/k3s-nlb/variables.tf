variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where NLB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for NLB"
  type        = list(string)
}

variable "k3s_instance_id" {
  description = "K3s instance ID to attach to target group"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for TLS termination"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
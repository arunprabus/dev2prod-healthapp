variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
}

variable "k3s_endpoint" {
  description = "K3s cluster endpoint for Kubernetes provider"
  type        = string
  default     = ""
}
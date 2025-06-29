variable "environment" {
  description = "Environment name"
  type        = string
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "health_api_image" {
  description = "Health API Docker image"
  type        = string
}
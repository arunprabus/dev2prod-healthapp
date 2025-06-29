variable "environment" {
  description = "Environment name"
  type        = string
}

variable "k3s_instance_ip" {
  description = "K3s instance public IP"
  type        = string
}

variable "health_api_image" {
  description = "Health API Docker image"
  type        = string
}
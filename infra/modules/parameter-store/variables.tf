variable "environment" {
  description = "Environment name"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "health-app"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "parameters" {
  description = "Map of parameters to create"
  type = map(object({
    type        = string
    value       = string
    description = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
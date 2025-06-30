variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cost_threshold" {
  description = "Cost threshold for alerts"
  type        = string
  default     = "1.0"
}

variable "alert_email" {
  description = "Email for alerts"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
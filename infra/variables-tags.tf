# Tagging and naming variables
variable "team_name" {
  description = "Team responsible for the resources"
  type        = string
  default     = "devops-team"
  
  validation {
    condition     = length(var.team_name) > 0
    error_message = "Team name cannot be empty."
  }
}

variable "cost_center" {
  description = "Cost center for billing allocation"
  type        = string
  default     = "engineering"
  
  validation {
    condition = contains([
      "engineering", "operations", "security", 
      "finance", "marketing", "sales"
    ], var.cost_center)
    error_message = "Cost center must be a valid department."
  }
}

variable "data_classification" {
  description = "Data classification level"
  type        = string
  default     = "internal"
  
  validation {
    condition = contains([
      "public", "internal", "confidential", "restricted"
    ], var.data_classification)
    error_message = "Data classification must be public, internal, confidential, or restricted."
  }
}

variable "compliance_scope" {
  description = "Compliance requirements"
  type        = string
  default     = "hipaa"
  
  validation {
    condition = contains([
      "none", "pci", "hipaa", "gdpr", "sox"
    ], var.compliance_scope)
    error_message = "Compliance scope must be none, pci, hipaa, gdpr, or sox."
  }
}

variable "backup_required" {
  description = "Whether backup is required for resources"
  type        = string
  default     = "true"
  
  validation {
    condition = contains(["true", "false"], var.backup_required)
    error_message = "Backup required must be true or false."
  }
}

variable "monitoring_level" {
  description = "Level of monitoring required"
  type        = string
  default     = "medium"
  
  validation {
    condition = contains([
      "none", "low", "medium", "high", "critical"
    ], var.monitoring_level)
    error_message = "Monitoring level must be none, low, medium, high, or critical."
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
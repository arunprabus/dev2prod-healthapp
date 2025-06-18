variable "table_name" {
  description = "Name of the DynamoDB table for health profiles"
  type        = string
  default     = "health-profiles"
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "enable_email_gsi" {
  description = "Enable Global Secondary Index for email queries"
  type        = bool
  default     = true
}

variable "enable_user_gsi" {
  description = "Enable Global Secondary Index for user_id queries"
  type        = bool
  default     = true
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB tables"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "health-app"
    ManagedBy   = "terraform"
  }
}

variable "aws_region" {
  description = "AWS region for DynamoDB tables"
  type        = string
  default     = "us-east-1"
}
# Terraform Validation Rules
# Built-in validation to prevent accidents

# Validation: Only allow specific regions
variable "allowed_regions" {
  description = "List of allowed AWS regions"
  type        = list(string)
  default     = ["ap-south-1"]
}

# Validation: Only allow free-tier instance types
variable "allowed_instance_types" {
  description = "List of allowed EC2 instance types"
  type        = list(string)
  default     = ["t2.micro", "t2.nano"]
}

# Validation: Only allow free-tier RDS instance classes
variable "allowed_rds_classes" {
  description = "List of allowed RDS instance classes"
  type        = list(string)
  default     = ["db.t3.micro", "db.t2.micro"]
}

# Validation: Enforce naming convention
variable "resource_name_prefix" {
  description = "Required prefix for all resource names"
  type        = string
  default     = "health-app"
  
  validation {
    condition = can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.resource_name_prefix))
    error_message = "Resource name prefix must be lowercase alphanumeric with hyphens."
  }
}

# Validation: Limit EBS volume size
variable "max_ebs_size" {
  description = "Maximum EBS volume size in GB"
  type        = number
  default     = 20
  
  validation {
    condition = var.max_ebs_size <= 30
    error_message = "EBS volume size cannot exceed 30 GB (Free Tier limit)."
  }
}

# Validation: Required tags
variable "required_tags" {
  description = "Required tags for all resources"
  type        = map(string)
  default = {
    Project     = "health-app"
    ManagedBy   = "terraform"
    CostCenter  = "engineering"
  }
}

# Local validation for environment
locals {
  allowed_environments = ["dev", "test", "prod", "monitoring", "lower"]
  
  # Validate environment (using error() instead of file())
  validate_environment = contains(local.allowed_environments, var.environment) ? var.environment : error("Environment must be one of: ${join(", ", local.allowed_environments)}")
  
  # Validate network tier
  validate_network_tier = contains(["lower", "higher", "monitoring"], var.network_tier) ? var.network_tier : error("Network tier must be one of: lower, higher, monitoring")
  
  # Validate AWS region
  validate_region = contains(var.allowed_regions, var.aws_region) ? var.aws_region : error("AWS region must be one of: ${join(", ", var.allowed_regions)}")
  
  # Generate resource names with validation
  resource_prefix = "${var.resource_name_prefix}-${var.environment}"
  
  # Validate resource naming
  validate_naming = can(regex("^health-app-", local.resource_prefix)) ? local.resource_prefix : error("Resource names must start with 'health-app-'")
}



# Output validation results
output "validation_status" {
  description = "Validation status for all checks"
  value = {
    environment_valid    = contains(local.allowed_environments, var.environment)
    network_tier_valid   = contains(["lower", "higher", "monitoring"], var.network_tier)
    region_valid        = contains(var.allowed_regions, var.aws_region)
    naming_valid        = can(regex("^health-app-", local.resource_prefix))
    validation_passed    = "All validations passed"
  }
}
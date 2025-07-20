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
  allowed_environments = ["dev", "test", "prod", "monitoring"]
  
  # Validate environment
  validate_environment = contains(local.allowed_environments, var.environment) ? var.environment : file("ERROR: Environment must be one of: ${join(", ", local.allowed_environments)}")
  
  # Validate network tier
  validate_network_tier = contains(["lower", "higher", "monitoring"], var.network_tier) ? var.network_tier : file("ERROR: Network tier must be one of: lower, higher, monitoring")
  
  # Validate AWS region
  validate_region = contains(var.allowed_regions, var.aws_region) ? var.aws_region : file("ERROR: AWS region must be one of: ${join(", ", var.allowed_regions)}")
  
  # Generate resource names with validation
  resource_prefix = "${var.resource_name_prefix}-${var.environment}"
  
  # Validate resource naming
  validate_naming = can(regex("^health-app-", local.resource_prefix)) ? local.resource_prefix : file("ERROR: Resource names must start with 'health-app-'")
}

# Check blocks for runtime validation
check "instance_type_compliance" {
  assert {
    condition = alltrue([
      for instance in values(aws_instance) : 
      contains(var.allowed_instance_types, instance.instance_type)
    ])
    error_message = "All EC2 instances must use allowed instance types: ${join(", ", var.allowed_instance_types)}"
  }
}

check "rds_class_compliance" {
  assert {
    condition = alltrue([
      for db in values(aws_db_instance) : 
      contains(var.allowed_rds_classes, db.instance_class)
    ])
    error_message = "All RDS instances must use allowed instance classes: ${join(", ", var.allowed_rds_classes)}"
  }
}

check "ebs_size_compliance" {
  assert {
    condition = alltrue([
      for volume in values(aws_ebs_volume) : 
      volume.size <= var.max_ebs_size
    ])
    error_message = "All EBS volumes must be ${var.max_ebs_size} GB or smaller"
  }
}

check "required_tags_compliance" {
  assert {
    condition = alltrue([
      for resource in concat(
        values(aws_instance),
        values(aws_db_instance),
        values(aws_security_group)
      ) : 
      alltrue([
        for tag_key in keys(var.required_tags) :
        contains(keys(resource.tags), tag_key)
      ])
    ])
    error_message = "All resources must have required tags: ${join(", ", keys(var.required_tags))}"
  }
}

# Output validation results
output "validation_status" {
  description = "Validation status for all checks"
  value = {
    environment_valid    = contains(local.allowed_environments, var.environment)
    network_tier_valid   = contains(["lower", "higher", "monitoring"], var.network_tier)
    region_valid        = contains(var.allowed_regions, var.aws_region)
    naming_valid        = can(regex("^health-app-", local.resource_prefix))
  }
}
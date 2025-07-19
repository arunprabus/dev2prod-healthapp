# Core Configuration
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

# Network Configuration
variable "lower_vpc_cidr" {
  description = "CIDR block for Lower Network VPC (Dev + Test)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "higher_vpc_cidr" {
  description = "CIDR block for Higher Network VPC (Production)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "monitoring_vpc_cidr" {
  description = "CIDR block for Monitoring Network VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "lower_public_subnet_cidrs" {
  description = "CIDR blocks for Lower Network public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "lower_private_subnet_cidrs" {
  description = "CIDR blocks for Lower Network private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "higher_public_subnet_cidrs" {
  description = "CIDR blocks for Higher Network public subnets"
  type        = list(string)
  default     = ["10.1.101.0/24", "10.1.102.0/24"]
}

variable "higher_private_subnet_cidrs" {
  description = "CIDR blocks for Higher Network private subnets"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "monitoring_public_subnet_cidrs" {
  description = "CIDR blocks for Monitoring Network public subnets"
  type        = list(string)
  default     = ["10.2.101.0/24", "10.2.102.0/24"]
}

variable "monitoring_private_subnet_cidrs" {
  description = "CIDR blocks for Monitoring Network private subnets"
  type        = list(string)
  default     = ["10.2.1.0/24", "10.2.2.0/24"]
}

# K3s Configuration
variable "k3s_instance_type" {
  description = "Instance type for K3s node"
  type        = string
  default     = "t2.micro"
}

variable "ssh_public_key" {
  description = "SSH public key for EC2 access"
  type        = string
  sensitive   = true
}

# Database Configuration
variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for the database (GB)"
  type        = number
  default     = 20
}

variable "restore_from_snapshot" {
  description = "Whether to restore from snapshot"
  type        = bool
  default     = false
}

variable "snapshot_identifier" {
  description = "Snapshot identifier to restore from (optional)"
  type        = string
  default     = "healthapidb-snapshot"
}

# GitHub Runner Configuration
variable "github_pat" {
  description = "GitHub Personal Access Token for runner registration"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
  default     = "arunprabus/dev2prod-healthapp"
}

# S3 Bucket for Terraform State
variable "tf_state_bucket" {
  description = "S3 bucket for Terraform state and kubeconfig storage"
  type        = string
  default     = "health-app-terraform-state"
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {
    Project = "health-app"
    ManagedBy = "terraform"
    Owner = "devops-team"
    CostCenter = "engineering"
    Application = "health-api"
    BackupRequired = "true"
    DataClassification = "internal"
    ComplianceScope = "hipaa"
  }
}
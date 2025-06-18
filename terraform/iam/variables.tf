variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the service account"
  type        = string
  default     = "default"
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account"
  type        = string
  default     = "health-api-sa"
}

variable "health_profiles_table_arn" {
  description = "ARN of the health profiles DynamoDB table"
  type        = string
}

variable "file_uploads_table_arn" {
  description = "ARN of the file uploads DynamoDB table"
  type        = string
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket for file uploads"
  type        = string
}

variable "create_oidc_provider" {
  description = "Whether to create OIDC provider (set to false if already exists)"
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "ARN of existing OIDC provider (if create_oidc_provider is false)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "health-app"
    ManagedBy = "terraform"
  }
}
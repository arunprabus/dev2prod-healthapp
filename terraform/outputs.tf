output "dynamodb_profiles_table_name" {
  description = "Name of the health profiles DynamoDB table"
  value       = module.dynamodb.health_profiles_table_name
}

output "dynamodb_uploads_table_name" {
  description = "Name of the file uploads DynamoDB table"
  value       = module.dynamodb.file_uploads_table_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for file uploads"
  value       = aws_s3_bucket.health_app_uploads.bucket
}

output "health_api_role_arn" {
  description = "ARN of the IAM role for Health API"
  value       = module.iam.health_api_role_arn
}

output "service_account_name" {
  description = "Name of the Kubernetes service account"
  value       = kubernetes_service_account.health_api.metadata[0].name
}
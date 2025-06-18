output "health_profiles_table_name" {
  description = "Name of the health profiles DynamoDB table"
  value       = aws_dynamodb_table.health_profiles.name
}

output "health_profiles_table_arn" {
  description = "ARN of the health profiles DynamoDB table"
  value       = aws_dynamodb_table.health_profiles.arn
}

output "file_uploads_table_name" {
  description = "Name of the file uploads DynamoDB table"
  value       = aws_dynamodb_table.file_uploads.name
}

output "file_uploads_table_arn" {
  description = "ARN of the file uploads DynamoDB table"
  value       = aws_dynamodb_table.file_uploads.arn
}

output "health_profiles_table_stream_arn" {
  description = "ARN of the health profiles table stream"
  value       = aws_dynamodb_table.health_profiles.stream_arn
}

output "region" {
  description = "AWS region where tables are created"
  value       = var.aws_region
}
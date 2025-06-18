output "health_api_role_arn" {
  description = "ARN of the IAM role for Health API service account"
  value       = aws_iam_role.health_api_role.arn
}

output "health_api_role_name" {
  description = "Name of the IAM role for Health API service account"
  value       = aws_iam_role.health_api_role.name
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = var.create_oidc_provider ? aws_iam_openid_connect_provider.eks[0].arn : var.oidc_provider_arn
}
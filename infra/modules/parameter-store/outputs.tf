output "parameter_names" {
  description = "List of parameter names created"
  value       = [for k, v in aws_ssm_parameter.app_parameters : v.name]
}

output "iam_role_arn" {
  description = "ARN of the IAM role for parameter access"
  value       = aws_iam_role.parameter_access.arn
}

output "instance_profile_name" {
  description = "Name of the instance profile for parameter access"
  value       = aws_iam_instance_profile.parameter_access.name
}
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

output "kubeconfig_parameter_names" {
  description = "Parameter names for kubeconfig data"
  value = {
    server   = var.kubeconfig_server != "" ? "/${var.environment}/${var.app_name}/kubeconfig/server" : ""
    token    = var.kubeconfig_token != "" ? "/${var.environment}/${var.app_name}/kubeconfig/token" : ""
    ca_cert  = var.kubeconfig_ca_cert != "" ? "/${var.environment}/${var.app_name}/kubeconfig/ca-cert" : ""
  }
}
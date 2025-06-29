output "prometheus_namespace" {
  description = "Kubernetes namespace for Prometheus installation"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_service_endpoint" {
  description = "Endpoint for Prometheus service"
  value       = "${var.k3s_instance_ip}:30090"
}

output "grafana_service_endpoint" {
  description = "Endpoint for Grafana service"
  value       = "${var.k3s_instance_ip}:30300"
}

output "alertmanager_service_endpoint" {
  description = "Endpoint for AlertManager service"
  value       = "${var.k3s_instance_ip}:30093"
}

output "logging_namespace" {
  description = "Kubernetes namespace for centralized logging"
  value       = kubernetes_namespace.logging.metadata[0].name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for centralized logging"
  value       = aws_cloudwatch_log_group.k3s_logs.name
}

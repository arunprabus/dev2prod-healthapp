output "prometheus_namespace" {
  description = "Kubernetes namespace for Prometheus installation"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_service_endpoint" {
  description = "Endpoint for Prometheus service"
  value       = kubernetes_service.prometheus_service.status[0].load_balancer[0].ingress[0].hostname
}

output "grafana_service_endpoint" {
  description = "Endpoint for Grafana service"
  value       = kubernetes_service.grafana_service.status[0].load_balancer[0].ingress[0].hostname
}

output "alertmanager_service_endpoint" {
  description = "Endpoint for AlertManager service"
  value       = kubernetes_service.alertmanager_service.status[0].load_balancer[0].ingress[0].hostname
}

output "logging_namespace" {
  description = "Kubernetes namespace for centralized logging"
  value       = kubernetes_namespace.logging.metadata[0].name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for centralized logging"
  value       = aws_cloudwatch_log_group.eks_logs.name
}

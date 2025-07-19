output "argo_rollouts_namespace" {
  description = "Namespace where Argo Rollouts is installed"
  value       = kubernetes_namespace.argo_rollouts.metadata[0].name
}

output "app_namespaces" {
  description = "List of created application namespaces"
  value       = [for ns in kubernetes_namespace.app_namespaces : ns.metadata[0].name]
}

output "istio_enabled" {
  description = "Whether Istio is enabled"
  value       = var.enable_istio
}

output "istio_gateway" {
  description = "Name of the Istio gateway"
  value       = var.enable_istio ? "main-gateway" : null
}

output "istio_gateway_namespace" {
  description = "Namespace of the Istio gateway"
  value       = var.enable_istio ? "istio-system" : null
}
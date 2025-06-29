output "namespace" {
  description = "Kubernetes namespace name"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "config_map_name" {
  description = "Config map name"
  value       = kubernetes_config_map.app_config.metadata[0].name
}
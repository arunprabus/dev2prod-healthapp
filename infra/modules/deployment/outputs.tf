output "namespace" {
  value       = kubernetes_namespace.health_app.metadata[0].name
  description = "The Kubernetes namespace for the Health app deployment"
}

output "argocd_application_name" {
  description = "Name of the ArgoCD application"
  value       = kubernetes_manifest.argocd_health_api.manifest.metadata.name
}

output "deployment_environment" {
  description = "Deployment environment name"
  value       = var.environment
}

output "health_api_image" {
  description = "The Docker image used for the Health API"
  value       = var.health_api_image
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster where the application is deployed"
  value       = var.eks_cluster_name
}

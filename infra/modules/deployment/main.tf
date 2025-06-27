# Deployment configuration module for Health App

variable "environment" {
  description = "Deployment environment (dev, test, prod)"
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "health_api_image" {
  description = "Docker image for Health API"
  type        = string
  default     = "ghcr.io/arunprabus/health-api:latest"
}

resource "kubernetes_namespace" "health_app" {
  metadata {
    name = "health-app-${var.environment}"

    labels = {
      environment = var.environment
      app         = "health-app"
    }
  }
}

# ArgoCD application configuration that points to the Health API repository
resource "kubernetes_manifest" "argocd_health_api" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "health-api-${var.environment}"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL       = "https://github.com/arunprabus/HealthApi"
        targetRevision = var.environment == "prod" ? "main" : (var.environment == "test" ? "staging" : "develop")
        path          = "k8s"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.health_app.metadata[0].name
      }
      syncPolicy = {
        automated = {
          prune       = true
          selfHeal    = true
          allowEmpty  = false
        }
        syncOptions = ["CreateNamespace=false"]
      }
    }
  }

  depends_on = [kubernetes_namespace.health_app]
}

output "namespace" {
  value = kubernetes_namespace.health_app.metadata[0].name
  description = "The Kubernetes namespace for the Health app deployment"
}
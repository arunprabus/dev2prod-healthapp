# Deployment Module - Minimal Implementation
resource "kubernetes_namespace" "app" {
  metadata {
    name = "health-app-${var.environment}"
  }
}

resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "health-api-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    ENVIRONMENT = var.environment
    API_VERSION = "v1"
  }
}
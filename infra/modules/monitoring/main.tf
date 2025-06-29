# Monitoring Module - Minimal Implementation
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
  }
}

resource "aws_cloudwatch_log_group" "k3s_logs" {
  name              = "/aws/k3s/${var.environment}/cluster"
  retention_in_days = 7

  tags = var.tags
}

# Placeholder services - would be replaced with actual Helm charts in production
resource "kubernetes_service" "prometheus_service" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    selector = {
      app = "prometheus"
    }
    
    port {
      port        = 9090
      target_port = 9090
      node_port   = 30090
    }
    
    type = "NodePort"
  }
}

resource "kubernetes_service" "grafana_service" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    selector = {
      app = "grafana"
    }
    
    port {
      port        = 3000
      target_port = 3000
      node_port   = 30300
    }
    
    type = "NodePort"
  }
}

resource "kubernetes_service" "alertmanager_service" {
  metadata {
    name      = "alertmanager"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    selector = {
      app = "alertmanager"
    }
    
    port {
      port        = 9093
      target_port = 9093
      node_port   = 30093
    }
    
    type = "NodePort"
  }
}
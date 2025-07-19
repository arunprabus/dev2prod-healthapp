resource "kubernetes_namespace" "argo_rollouts" {
  metadata {
    name = var.argo_namespace
    labels = {
      "istio-injection" = var.enable_istio ? "enabled" : "disabled"
    }
  }
}

resource "kubernetes_namespace" "app_namespaces" {
  for_each = toset(var.app_namespaces)
  
  metadata {
    name = each.value
    labels = {
      "istio-injection" = var.enable_istio ? "enabled" : "disabled"
    }
  }
}

resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  version    = var.argo_rollouts_version
  namespace  = kubernetes_namespace.argo_rollouts.metadata[0].name

  set {
    name  = "dashboard.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = var.enable_prometheus
  }
}

resource "helm_release" "istio" {
  count      = var.enable_istio ? 1 : 0
  name       = "istio"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  version    = var.istio_version
  namespace  = "istio-system"

  depends_on = [kubernetes_namespace.istio_system[0]]
}

resource "kubernetes_namespace" "istio_system" {
  count = var.enable_istio ? 1 : 0
  
  metadata {
    name = "istio-system"
  }
}

resource "helm_release" "istiod" {
  count      = var.enable_istio ? 1 : 0
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_version
  namespace  = "istio-system"

  depends_on = [helm_release.istio]
}

resource "helm_release" "istio_gateway" {
  count      = var.enable_istio ? 1 : 0
  name       = "istio-ingress"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_version
  namespace  = "istio-system"

  depends_on = [helm_release.istiod]
}

# Create VirtualService and Gateway for each app namespace if Istio is enabled
resource "kubernetes_manifest" "virtual_services" {
  for_each = var.enable_istio ? toset(var.app_namespaces) : []
  
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "VirtualService"
    metadata = {
      name      = "${each.value}-vs"
      namespace = each.value
    }
    spec = {
      hosts    = ["${each.value}.${var.domain_name}"]
      gateways = ["istio-system/main-gateway"]
      http = [
        {
          route = [
            {
              destination = {
                host = "health-api-service"
                port = {
                  number = 80
                }
              }
            }
          ]
        }
      ]
    }
  }

  depends_on = [kubernetes_namespace.app_namespaces]
}

resource "kubernetes_manifest" "gateway" {
  count = var.enable_istio ? 1 : 0
  
  manifest = {
    apiVersion = "networking.istio.io/v1alpha3"
    kind       = "Gateway"
    metadata = {
      name      = "main-gateway"
      namespace = "istio-system"
    }
    spec = {
      selector = {
        istio = "ingressgateway"
      }
      servers = [
        {
          port = {
            number   = 80
            name     = "http"
            protocol = "HTTP"
          }
          hosts = ["*.${var.domain_name}"]
        }
      ]
    }
  }

  depends_on = [helm_release.istio_gateway]
}
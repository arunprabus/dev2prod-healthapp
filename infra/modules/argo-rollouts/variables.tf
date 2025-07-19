variable "argo_namespace" {
  description = "Namespace for Argo Rollouts"
  type        = string
  default     = "argo-rollouts"
}

variable "app_namespaces" {
  description = "List of application namespaces to create"
  type        = list(string)
  default     = ["health-app-dev", "health-app-test", "health-app-prod"]
}

variable "enable_istio" {
  description = "Whether to enable Istio service mesh"
  type        = bool
  default     = false
}

variable "enable_prometheus" {
  description = "Whether to enable Prometheus monitoring"
  type        = bool
  default     = false
}

variable "argo_rollouts_version" {
  description = "Version of Argo Rollouts to install"
  type        = string
  default     = "2.30.1"
}

variable "istio_version" {
  description = "Version of Istio to install"
  type        = string
  default     = "1.19.0"
}

variable "domain_name" {
  description = "Domain name for Istio virtual services"
  type        = string
  default     = "example.com"
}
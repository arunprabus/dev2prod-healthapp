environment         = "dev"
network_tier        = "lower"
aws_region          = "ap-south-1"

# Argo Rollouts configuration
enable_istio        = true
enable_prometheus   = true
argo_rollouts_version = "2.30.1"
istio_version       = "1.19.0"
domain_name         = "dev.health-app.local"
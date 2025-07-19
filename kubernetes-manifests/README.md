# Kubernetes Manifests for Health App

This directory contains the Kubernetes manifests for deploying the Health App platform across multiple environments.

## Directory Structure

```
kubernetes-manifests/
├── base/                           # Base resources shared across environments
│   └── namespaces.yaml             # Namespace definitions
├── components/                     # Reusable components
│   ├── health-api/                 # Health API application components
│   │   ├── configmap.yaml          # ConfigMap template
│   │   ├── deployment.yaml         # Deployment template
│   │   ├── hpa.yaml                # HorizontalPodAutoscaler template
│   │   ├── secrets.yaml            # Secrets template
│   │   └── service.yaml            # Service template
│   ├── monitoring/                 # Monitoring components
│   │   ├── grafana.yaml            # Grafana deployment and service
│   │   └── prometheus.yaml         # Prometheus deployment, config, and service
│   ├── networking/                 # Network components
│   │   └── network-policies.yaml   # Network policies for all environments
│   └── progressive-delivery/       # Progressive delivery components
│       ├── blue-green-rollout.yaml # Blue-Green deployment strategy
│       └── canary-rollout.yaml     # Canary deployment strategy
└── environments/                   # Environment-specific configurations
    ├── dev/                        # Development environment
    │   ├── configmap-patch.yaml    # Environment-specific ConfigMap values
    │   ├── deployment-patch.yaml   # Environment-specific deployment values
    │   ├── hpa-patch.yaml          # Environment-specific HPA values
    │   └── kustomization.yaml      # Kustomize configuration
    ├── test/                       # Test environment
    │   └── ...                     # Similar structure to dev
    ├── prod/                       # Production environment
    │   ├── configmap-patch.yaml    # Environment-specific ConfigMap values
    │   ├── hpa-patch.yaml          # Environment-specific HPA values
    │   ├── kustomization.yaml      # Kustomize configuration
    │   └── rollout-patch.yaml      # Environment-specific rollout values
    └── monitoring/                 # Monitoring environment
        └── kustomization.yaml      # Kustomize configuration
```

## Deployment Instructions

### Prerequisites

- kubectl installed and configured
- kustomize installed (or use kubectl built-in kustomize)
- Access to a Kubernetes cluster

### Deploying to an Environment

```bash
# Deploy to Development Environment
kubectl apply -k environments/dev

# Deploy to Test Environment
kubectl apply -k environments/test

# Deploy to Production Environment
kubectl apply -k environments/prod

# Deploy Monitoring Stack
kubectl apply -k environments/monitoring
```

### Progressive Delivery

For production deployments, we use Argo Rollouts for progressive delivery:

#### Blue-Green Deployment

```bash
# Deploy using Blue-Green strategy
kubectl apply -k environments/prod

# Check rollout status
kubectl argo rollouts get rollout health-api-rollout -n health-app-prod

# Promote the rollout when ready
kubectl argo rollouts promote health-api-rollout -n health-app-prod
```

#### Canary Deployment

```bash
# Deploy using Canary strategy
# First, switch to canary strategy in kustomization.yaml
kubectl apply -k environments/prod

# Check rollout status
kubectl argo rollouts get rollout health-api-rollout -n health-app-prod
```

## Network Architecture

The network policies enforce the following isolation:

1. **Lower Network (Dev + Test)**: Isolated from Production
2. **Higher Network (Production)**: Isolated from Dev/Test
3. **Monitoring Network**: Can access metrics endpoints in all environments

Each environment has its own namespace with appropriate labels for network policy selection.
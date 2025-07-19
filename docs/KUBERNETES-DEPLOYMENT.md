# Kubernetes Deployment Strategies

This document explains the different deployment strategies used in the Health App infrastructure.

## Overview

We use two main approaches for deploying applications to Kubernetes:

1. **Standard Kubernetes Deployments**: Simple, direct deployments using kubectl
2. **Progressive Delivery with Argo Rollouts**: Advanced deployment strategies with traffic control

## Standard Kubernetes Deployments

### Workflow: `core-deployment.yml`

This workflow provides a straightforward deployment method using native Kubernetes resources.

### How It Works

1. **Setup**: Configures kubectl with the appropriate kubeconfig based on the target environment
2. **Namespace**: Creates the namespace if it doesn't exist
3. **Deployment**:
   - If deployment exists: Updates the image using `kubectl set image`
   - If deployment doesn't exist: Creates a new deployment and service
4. **Verification**: Checks that all pods are running successfully

### Usage

```bash
# Manual trigger
gh workflow run core-deployment.yml \
  -f app=health-api \
  -f image=arunprabusiva/health-api:latest \
  -f environment=dev

# Automatic trigger from application repository
# (via repository_dispatch event)
```

### Example Deployment

```yaml
kubectl create deployment health-api --image=arunprabusiva/health-api:latest -n health-app-dev
kubectl expose deployment health-api --port=80 --target-port=8080 -n health-app-dev --type=ClusterIP
```

## Progressive Delivery with Argo Rollouts

### Workflow: `argo-rollout-deploy.yml`

This workflow uses Argo Rollouts for advanced deployment strategies like canary and blue/green deployments.

### How It Works

1. **Setup**: Configures kubectl and installs the Argo Rollouts plugin
2. **Manifest Generation**: Generates a rollout manifest using the `generate-rollout.sh` script
3. **Deployment**: Applies the rollout manifest and watches the rollout progress
4. **Verification**: Checks the rollout status and related resources

### Usage

```bash
# Manual trigger
gh workflow run argo-rollout-deploy.yml \
  -f environment=dev \
  -f image_tag=v1.0.0 \
  -f strategy=canary \
  -f traffic_router=istio
```

### Deployment Strategies

#### Canary Deployment

Gradually shifts traffic from the old version to the new version:

1. Deploy new version (canary)
2. Route 20% of traffic to canary
3. Gradually increase traffic percentage
4. Promote canary to stable when successful

```yaml
strategy:
  canary:
    steps:
    - setWeight: 20
    - pause: {duration: 30s}
    - setWeight: 40
    - pause: {duration: 30s}
    - setWeight: 60
    - pause: {duration: 30s}
    - setWeight: 80
    - pause: {duration: 30s}
```

#### Blue/Green Deployment

Runs both versions simultaneously and switches traffic all at once:

1. Deploy new version (green)
2. Validate green deployment
3. Switch all traffic from blue to green
4. Remove old version (blue) when successful

```yaml
strategy:
  blueGreen:
    activeService: health-api-active
    previewService: health-api-preview
    autoPromotionEnabled: false
```

## Kubernetes Secrets Integration

Both deployment methods can use Kubernetes Secrets for configuration:

### Standard Deployments with Secrets

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-api
spec:
  template:
    spec:
      containers:
      - name: health-api
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: db-password
```

### Argo Rollouts with Secrets

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: health-api
spec:
  template:
    spec:
      containers:
      - name: health-api
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: db-password
```

## Node.js Applications with .env Files

For Node.js applications that require .env files:

1. **Init Container Approach**: Use an init container to generate a .env file from secrets
2. **Direct Environment Variables**: Use environment variables directly with the dotenv package

See [Node.js Environment Setup](NODEJS-ENV-SETUP.md) for details.

## Monitoring Deployments

### Standard Deployments

```bash
# Check deployment status
kubectl get deployment health-api -n health-app-dev

# Check pods
kubectl get pods -l app=health-api -n health-app-dev

# Check logs
kubectl logs -l app=health-api -n health-app-dev
```

### Argo Rollouts

```bash
# Check rollout status
kubectl argo rollouts get rollout health-api -n health-app-dev

# Access the dashboard
kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100
# Then open http://localhost:3100/rollouts
```

## Choosing a Deployment Strategy

| Feature | Standard Deployment | Argo Rollouts |
|---------|---------------------|---------------|
| Complexity | Low | Medium |
| Traffic Control | Limited | Advanced |
| Rollback | Manual | Automated |
| Monitoring | Basic | Advanced |
| Use Case | Simple applications | Critical services |

Choose based on your application's requirements for reliability, availability, and risk tolerance.
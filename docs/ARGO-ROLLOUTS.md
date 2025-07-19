# Argo Rollouts Integration

This document explains how Argo Rollouts is integrated with our Health App infrastructure to provide advanced deployment strategies.

## Overview

Argo Rollouts extends Kubernetes with advanced deployment capabilities:

- **Canary Deployments**: Gradually shift traffic to the new version
- **Blue/Green Deployments**: Switch traffic all at once after validation
- **Progressive Delivery**: Automated analysis and promotion/rollback
- **Traffic Management**: Integration with service meshes like Istio

## Architecture

Our implementation uses:

1. **Separate Namespaces**: Each environment (dev/test/prod) has its own namespace
2. **Istio Service Mesh**: For advanced traffic routing and shifting
3. **Terraform Modules**: Infrastructure as code for consistent deployment
4. **GitHub Actions**: Automated deployment workflows

## Infrastructure Components

The Argo Rollouts infrastructure consists of:

- **Argo Rollouts Controller**: Manages rollout resources
- **Istio Service Mesh**: Handles traffic routing
- **Kubernetes Services**: Stable and canary services
- **Virtual Services**: Define traffic routing rules

## Deployment Strategies

### Canary Deployment

Gradually shifts traffic from the old version to the new version:

1. Deploy new version (canary)
2. Route 20% of traffic to canary
3. Analyze metrics and gradually increase traffic
4. Promote canary to stable when successful

### Blue/Green Deployment

Runs both versions simultaneously and switches traffic all at once:

1. Deploy new version (green)
2. Validate green deployment
3. Switch all traffic from blue to green
4. Remove old version (blue) when successful

## Usage

### Deploying with Argo Rollouts

#### Using GitHub Actions Workflow

1. Go to Actions → Argo Rollout Deployment
2. Click "Run workflow"
3. Fill in the parameters:
   - **Environment**: Select `dev`, `test`, or `prod`
   - **Image tag**: Enter the version to deploy (e.g., `v1.0.0`)
   - **Strategy**: Choose `canary` for gradual rollout or `blueGreen` for instant switch
   - **Traffic router**: Select `istio` for service mesh routing
4. Click "Run workflow"
5. Monitor the workflow execution in the Actions tab

The workflow will:
- Set up the appropriate kubeconfig for the selected environment
- Generate the Argo Rollout manifest with your parameters
- Apply the manifest to the cluster
- Watch the rollout progress
- Verify the deployment status

#### Workflow Parameters Explained

| Parameter | Description | Options |
|-----------|-------------|----------|
| Environment | Target deployment environment | `dev`, `test`, `prod` |
| Image tag | Container image version | Any valid tag (e.g., `v1.0.0`, `latest`) |
| Strategy | Deployment strategy | `canary`: Gradual traffic shift<br>`blueGreen`: Instant cutover |
| Traffic router | Traffic management method | `istio`: Istio service mesh<br>`smi`: SMI<br>`nginx`: NGINX Ingress |

### Manual Deployment

```bash
# Generate rollout manifest
./scripts/generate-rollout.sh \
  --namespace health-app-dev \
  --image docker.io/your-username/health-api \
  --tag v1.0.0 \
  --strategy canary \
  --router istio \
  --domain dev.health-app.local \
  --enable-istio true

# Apply rollout
kubectl apply -f k8s/generated/health-api-rollout-health-app-dev.yaml

# Watch rollout progress
kubectl argo rollouts get rollout health-api -n health-app-dev --watch
```

## Terraform Configuration

The Argo Rollouts infrastructure is managed by Terraform:

```hcl
module "argo_rollouts" {
  source = "../../modules/argo-rollouts"

  argo_namespace       = "argo-rollouts"
  app_namespaces       = ["health-app-dev"]
  enable_istio         = true
  enable_prometheus    = true
  argo_rollouts_version = "2.30.1"
  istio_version        = "1.19.0"
  domain_name          = "dev.health-app.local"
}
```

## Monitoring and Analysis

### Monitoring through the Argo Rollouts Dashboard

Argo Rollouts provides a built-in dashboard for monitoring deployments:

1. **Access the Dashboard**:
   ```bash
   # Port-forward the dashboard service
   kubectl port-forward svc/argo-rollouts-dashboard -n argo-rollouts 3100:3100
   ```

2. **Open in Browser**:
   - Navigate to http://localhost:3100/rollouts
   - The dashboard shows all rollouts across namespaces

3. **Dashboard Features**:
   - **Rollout Status**: Visual representation of rollout progress
   - **Revision History**: View previous rollouts and their status
   - **Canary Progress**: See traffic weight and step progress
   - **Pod Status**: Monitor pod health during rollout
   - **Manual Controls**: Promote, abort, or retry rollouts

4. **Command Line Monitoring**:
   ```bash
   # Watch rollout progress
   kubectl argo rollouts get rollout health-api -n health-app-dev --watch
   ```

### Integration with Metrics Providers

Argo Rollouts can be integrated with various metrics providers:

- **Prometheus**: For metrics-based analysis
- **Datadog**: For external metrics
- **CloudWatch**: For AWS metrics

## Rollback Process

If a deployment fails:

1. Automatic rollback based on metrics
2. Manual rollback:
   ```bash
   kubectl argo rollouts undo rollout health-api -n health-app-dev
   ```

## Best Practices

1. **Start Small**: Begin with canary deployments at low traffic percentages
2. **Define Good Metrics**: Use relevant metrics for automated analysis
3. **Set Appropriate Thresholds**: Balance between sensitivity and false positives
4. **Test Rollback Process**: Ensure rollbacks work correctly
5. **Monitor Deployments**: Watch the progress of rollouts
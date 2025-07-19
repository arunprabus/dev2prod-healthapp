# Scaling Configuration

This document explains how scaling is managed in the Health App infrastructure.

## Overview

We use Kubernetes Horizontal Pod Autoscaler (HPA) to automatically scale applications based on resource utilization. There are two levels of scaling:

1. **Pod-level scaling**: Using Horizontal Pod Autoscaler (HPA)
2. **Node-level scaling**: Using Cluster Autoscaler

## Horizontal Pod Autoscaler (HPA)

HPA automatically scales the number of pods in a deployment based on observed CPU/memory utilization or other metrics.

### Standard HPA

The standard HPA configuration is applied to dev and test environments:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: health-api-hpa
  namespace: health-app-dev
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: health-api
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### Advanced HPA

The advanced HPA configuration is applied to production environments:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: health-api-hpa
  namespace: health-app-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: health-api
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

## Cluster Autoscaler

The Cluster Autoscaler automatically adjusts the number of nodes in the cluster when:
- There are pods that failed to run due to insufficient resources
- There are nodes that have been underutilized for an extended period of time

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  template:
    spec:
      containers:
      - name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/health-app-cluster-dev
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
```

## How Scaling is Applied

Scaling is applied in two ways:

### 1. Automatic Application During Deployment

When you deploy an application using the `core-deployment.yml` workflow, scaling is automatically applied:

- **Dev/Test environments**: Standard HPA with 2-5 replicas
- **Production environment**: Advanced HPA with 3-10 replicas and scaling behavior

### 2. Manual Application Using the Scaling Workflow

You can manually apply or update scaling configurations using the `apply-scaling.yml` workflow:

```bash
# Run the workflow
gh workflow run apply-scaling.yml \
  -f environment=dev \
  -f app=health-api \
  -f scaling_type=standard \
  -f min_replicas=2 \
  -f max_replicas=5 \
  -f cpu_threshold=70 \
  -f memory_threshold=80
```

## Monitoring Scaling

### Checking HPA Status

```bash
# Get all HPAs in a namespace
kubectl get hpa -n health-app-dev

# Describe a specific HPA
kubectl describe hpa health-api-hpa -n health-app-dev
```

### Checking Cluster Autoscaler Status

```bash
# Check Cluster Autoscaler logs
kubectl logs -n kube-system -l app=cluster-autoscaler

# Check node status
kubectl get nodes
```

## Best Practices

1. **Set appropriate resource requests and limits** for your containers
2. **Choose appropriate metrics** for scaling (CPU, memory, custom metrics)
3. **Set reasonable min/max replicas** based on expected load
4. **Configure scaling behavior** to avoid thrashing
5. **Monitor scaling events** to fine-tune your configuration

## Troubleshooting

### Common Issues

1. **HPA not scaling up**:
   - Check if metrics are available: `kubectl describe hpa health-api-hpa -n health-app-dev`
   - Verify resource requests are set: `kubectl describe deployment health-api -n health-app-dev`

2. **Cluster Autoscaler not adding nodes**:
   - Check if ASG is configured correctly
   - Verify Cluster Autoscaler logs: `kubectl logs -n kube-system -l app=cluster-autoscaler`

3. **Scaling too aggressively**:
   - Adjust stabilization windows and scaling policies
   - Increase the CPU/memory thresholds
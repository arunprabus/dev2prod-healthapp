#!/bin/bash
# Script to deploy Node.js application with .env file from Kubernetes secrets

# Default values
NAMESPACE="health-app-dev"
IMAGE="nodejs-app"
TAG="latest"
KUBECONFIG_PATH=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    --image)
      IMAGE="$2"
      shift
      shift
      ;;
    --tag)
      TAG="$2"
      shift
      shift
      ;;
    --kubeconfig)
      KUBECONFIG_PATH="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set KUBECONFIG if provided
if [[ -n "$KUBECONFIG_PATH" ]]; then
  export KUBECONFIG="$KUBECONFIG_PATH"
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "Creating namespace '$NAMESPACE'..."
  kubectl create namespace "$NAMESPACE"
fi

# Check if secrets and configmaps exist, create if not
if ! kubectl get secret app-credentials -n "$NAMESPACE" &>/dev/null; then
  echo "Creating 'app-credentials' secret..."
  kubectl create secret generic app-credentials \
    --from-literal=db-password=changeme123 \
    --from-literal=api-key=default-api-key \
    --from-literal=jwt-secret=default-jwt-secret \
    -n "$NAMESPACE"
fi

if ! kubectl get secret aws-credentials -n "$NAMESPACE" &>/dev/null; then
  echo "Creating 'aws-credentials' secret..."
  kubectl create secret generic aws-credentials \
    --from-literal=aws-access-key-id=default-access-key \
    --from-literal=aws-secret-access-key=default-secret-key \
    --from-literal=aws-region=ap-south-1 \
    -n "$NAMESPACE"
fi

if ! kubectl get configmap nodejs-config -n "$NAMESPACE" &>/dev/null; then
  echo "Creating 'nodejs-config' configmap..."
  kubectl create configmap nodejs-config \
    --from-literal=NODE_ENV=production \
    --from-literal=LOG_LEVEL=info \
    --from-literal=DB_HOST=health-app-db.$NAMESPACE.svc.cluster.local \
    --from-literal=DB_PORT=5432 \
    --from-literal=DB_NAME=healthapp \
    --from-literal=DB_USER=admin \
    --from-literal=PORT=3000 \
    --from-literal=ENABLE_CACHE=true \
    --from-literal=RATE_LIMIT=100 \
    -n "$NAMESPACE"
fi

# Generate deployment YAML from template
echo "Generating deployment YAML..."
cat k8s/nodejs-deployment-with-env.yaml | \
  sed "s/\${NAMESPACE}/$NAMESPACE/g" | \
  sed "s/\${IMAGE}/$IMAGE/g" | \
  sed "s/\${TAG}/$TAG/g" > /tmp/nodejs-deployment.yaml

# Apply deployment
echo "Deploying Node.js application..."
kubectl apply -f /tmp/nodejs-deployment.yaml

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
kubectl rollout status deployment/nodejs-app -n "$NAMESPACE" --timeout=120s

# Get service URL
echo "Getting service URL..."
SERVICE_IP=$(kubectl get service nodejs-app-service -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
SERVICE_PORT=$(kubectl get service nodejs-app-service -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')

echo "✅ Node.js application deployed successfully!"
echo "Service URL: http://$SERVICE_IP:$SERVICE_PORT"
echo "Namespace: $NAMESPACE"

# Cleanup
rm -f /tmp/nodejs-deployment.yaml
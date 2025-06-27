#!/bin/bash

# Usage: ./rollback.sh <environment>
# Example: ./rollback.sh prod

ENV=${1:-dev}
CLUSTER_NAME="health-app-cluster-${ENV}"

echo "🔄 Rolling back $ENV environment..."

# Update kubeconfig
aws eks update-kubeconfig --region ap-south-1 --name $CLUSTER_NAME

# Get current color
CURRENT_COLOR=$(kubectl get service health-api-service -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "blue")
ROLLBACK_COLOR=$([ "$CURRENT_COLOR" = "blue" ] && echo "green" || echo "blue")
#!/bin/bash

# Script for emergency rollback to previous version
# Usage: ./rollback.sh [environment] [color]

set -e

# Default values
ENV=${1:-"prod"}
COLOR=${2:-"blue"}
AWS_REGION=${AWS_REGION:-"ap-south-1"}

# Validate environment
if [[ "$ENV" != "dev" && "$ENV" != "test" && "$ENV" != "prod" ]]; then
  echo "Invalid environment. Use 'dev', 'test', or 'prod'."
  exit 1
fi

# Validate color
if [[ "$COLOR" != "blue" && "$COLOR" != "green" ]]; then
  echo "Invalid color. Use 'blue' or 'green'."
  exit 1
fi

echo "Rolling back $ENV environment to $COLOR deployment..."

# Configure kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --region $AWS_REGION --name health-app-$ENV-cluster

# Get current color
CURRENT_COLOR=$(kubectl get service health-api-service -n health-app-$ENV -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "unknown")
echo "Current deployment color: $CURRENT_COLOR"

if [[ "$CURRENT_COLOR" == "$COLOR" ]]; then
  echo "Already using $COLOR deployment. No rollback needed."
  exit 0
fi

# Perform rollback
echo "Switching to $COLOR deployment..."

# Update health-api service
kubectl patch service health-api-service -n health-app-$ENV \
  -p '{"spec":{"selector":{"color":"'$COLOR'"}}}'  

# Update frontend service if it exists
if kubectl get service frontend-service -n health-app-$ENV &>/dev/null; then
  kubectl patch service frontend-service -n health-app-$ENV \
    -p '{"spec":{"selector":{"color":"'$COLOR'"}}}'  
fi

# Verify health
echo "Verifying health after rollback..."

# Wait for pods to be ready
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pods -l app=health-api,color=$COLOR \
  -n health-app-$ENV --timeout=60s || true

# Check endpoints
echo "Checking service endpoints..."
kubectl get endpoints health-api-service -n health-app-$ENV

# Get pod status
echo "Pod status:"
kubectl get pods -l app=health-api -n health-app-$ENV

echo "\nRollback to $COLOR deployment complete!"
echo "Current: $CURRENT_COLOR → Rolling back to: $ROLLBACK_COLOR"

# Check if rollback target exists
if kubectl get deployment health-api-${ROLLBACK_COLOR} >/dev/null 2>&1; then
    # Execute rollback
    kubectl patch service health-api-service -p '{"spec":{"selector":{"color":"'${ROLLBACK_COLOR}'"}}}'
    kubectl patch service frontend-service -p '{"spec":{"selector":{"color":"'${ROLLBACK_COLOR}'"}}}'
    
    echo "✅ Rollback completed for $ENV environment"
    echo "🔍 Verifying services..."
    kubectl get services
else
    echo "❌ No previous version found for rollback"
    exit 1
fi
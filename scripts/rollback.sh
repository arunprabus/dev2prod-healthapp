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
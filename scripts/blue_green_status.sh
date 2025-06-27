#!/bin/bash

# Script to check blue-green deployment status
# Usage: ./blue_green_status.sh [environment]

set -e

# Default values
ENV=${1:-"prod"}
AWS_REGION=${AWS_REGION:-"ap-south-1"}

# Validate environment
if [[ "$ENV" != "dev" && "$ENV" != "test" && "$ENV" != "prod" ]]; then
  echo "Invalid environment. Use 'dev', 'test', or 'prod'."
  exit 1
fi

echo "Checking blue-green deployment status for $ENV environment..."

# Configure kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --region $AWS_REGION --name health-app-$ENV-cluster

# Get current active color
CURRENT_COLOR=$(kubectl get service health-api-service -n health-app-$ENV -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "unknown")
echo "Current active deployment color: $CURRENT_COLOR"

# Get pod status for each color
echo "\nBlue deployment status:"
kubectl get pods -l app=health-api,color=blue -n health-app-$ENV

echo "\nGreen deployment status:"
kubectl get pods -l app=health-api,color=green -n health-app-$ENV

# Check service details
echo "\nService configuration:"
kubectl get service health-api-service -n health-app-$ENV -o yaml | grep -A5 selector

# Check endpoints
echo "\nEndpoints:"
kubectl get endpoints health-api-service -n health-app-$ENV

# Get deployment details
echo "\nDeployment details:"
kubectl get deployments -l app=health-api -n health-app-$ENV

echo "\nBlue-green deployment status check complete!"

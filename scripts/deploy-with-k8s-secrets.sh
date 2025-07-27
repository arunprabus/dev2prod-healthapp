#!/bin/bash

echo "🚀 Deploying applications using Kubernetes secrets..."

NAMESPACE=${1:-health-app-dev}
APP=${2:-health-api}

# Get kubeconfig from Kubernetes secret
echo "🔐 Retrieving kubeconfig from secret..."
kubectl get secret kubeconfig-${NAMESPACE#health-app-} -n $NAMESPACE -o jsonpath='{.data.config}' | base64 -d > /tmp/deploy-kubeconfig

export KUBECONFIG=/tmp/deploy-kubeconfig

# Deploy application
echo "📦 Deploying $APP to $NAMESPACE..."
kubectl apply -f kubernetes-manifests/environments/${NAMESPACE#health-app-}/

# Check deployment status
echo "📊 Checking deployment status..."
kubectl get pods -n $NAMESPACE
kubectl get services -n $NAMESPACE

# Cleanup
rm -f /tmp/deploy-kubeconfig

echo "✅ Deployment completed!"
#!/bin/bash

echo "🔐 Setting up kubeconfig secrets in Kubernetes..."

# Create namespaces if they don't exist
kubectl create namespace health-app-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace health-app-test --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace health-app-prod --dry-run=client -o yaml | kubectl apply -f -

# Create kubeconfig secrets
echo "📝 Creating kubeconfig secrets..."

# Dev environment
kubectl create secret generic kubeconfig-dev \
  --from-file=config=scripts/kubeconfig/kubeconfig-clean.yaml \
  --namespace=health-app-dev \
  --dry-run=client -o yaml | kubectl apply -f -

# Test environment  
kubectl create secret generic kubeconfig-test \
  --from-file=config=scripts/kubeconfig/kubeconfig-clean.yaml \
  --namespace=health-app-test \
  --dry-run=client -o yaml | kubectl apply -f -

# Prod environment
kubectl create secret generic kubeconfig-prod \
  --from-file=config=scripts/kubeconfig/kubeconfig-clean.yaml \
  --namespace=health-app-prod \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Kubeconfig secrets created successfully!"
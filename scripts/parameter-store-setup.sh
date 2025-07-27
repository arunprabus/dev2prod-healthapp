#!/bin/bash

# Parameter Store Setup Script
# Usage: ./parameter-store-setup.sh [environment]

ENVIRONMENT=${1:-dev}
REGION="ap-south-1"

echo "Setting up Parameter Store for environment: $ENVIRONMENT"

# Deploy infrastructure with Parameter Store
echo "Deploying Parameter Store infrastructure..."
cd ../infra

terraform apply \
  -var-file="environments/${ENVIRONMENT}.tfvars" \
  -var-file="environments/parameter-store.tfvars" \
  -auto-approve

# Install External Secrets Operator in Kubernetes
echo "Installing External Secrets Operator..."
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/crds/bundle.yaml
kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/charts/external-secrets/templates/rbac.yaml

# Apply Parameter Store secret configuration
echo "Applying Parameter Store secret configuration..."
kubectl apply -f ../kubernetes-manifests/components/external-secrets/parameter-store-secret.yaml

echo "Parameter Store setup complete!"
echo "Parameters are available at: /${ENVIRONMENT}/health-app/*"
#!/bin/bash
# Quick deployment - skip long waits

echo "🚀 Quick deployment mode..."

# Skip RDS for faster deployment
export TF_VAR_database_config=null

# Deploy infrastructure only
cd infra
terraform apply \
  -var-file="environments/lower.tfvars" \
  -var="ssh_public_key=$SSH_PUBLIC_KEY" \
  -var="github_pat=$REPO_PAT" \
  -var="database_config=null" \
  -target=module.vpc \
  -target=module.k3s_clusters \
  -target=module.github_runner \
  -auto-approve

echo "✅ Quick deployment complete (no RDS)"
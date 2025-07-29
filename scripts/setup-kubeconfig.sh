#!/bin/bash

# Kubeconfig setup script for GitHub Actions
# Usage: ./setup-kubeconfig.sh <env_name> <cluster_ip>

set -e

ENV_NAME=$1
CLUSTER_IP=$2
PARAM_PREFIX="/$ENV_NAME/health-app/kubeconfig"

echo "⏳ Waiting for K3s API at $CLUSTER_IP:6443..."

# Wait for K3s API to be accessible
for i in {1..30}; do
  echo "Attempt $i/30: Testing K3s API..."
  if timeout 10 curl -k -s "https://$CLUSTER_IP:6443/version" >/dev/null 2>&1; then
    echo "✅ K3s API is accessible"
    break
  fi
  if [ $i -eq 30 ]; then
    echo "❌ K3s API not accessible after 10 minutes"
    exit 1
  fi
  sleep 20
done

# Get kubeconfig data from Parameter Store
echo "📥 Retrieving kubeconfig from Parameter Store..."

for attempt in {1..10}; do
  echo "Parameter Store attempt $attempt/10..."
  
  SERVER=$(aws ssm get-parameter --name "$PARAM_PREFIX/server" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
  TOKEN=$(aws ssm get-parameter --name "$PARAM_PREFIX/token" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
  
  if [ -n "$SERVER" ] && [ -n "$TOKEN" ]; then
    echo "✅ Retrieved kubeconfig data from Parameter Store"
    
    # Create kubeconfig
    cat > /tmp/kubeconfig-$ENV_NAME << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: $SERVER
  name: k3s-cluster
contexts:
- context:
    cluster: k3s-cluster
    namespace: gha-access
    user: gha-deployer
  name: gha-context
current-context: gha-context
users:
- name: gha-deployer
  user:
    token: $TOKEN
EOF
    
    # Test the kubeconfig
    export KUBECONFIG=/tmp/kubeconfig-$ENV_NAME
    if timeout 30 kubectl get nodes --insecure-skip-tls-verify >/dev/null 2>&1; then
      echo "✅ Kubeconfig test successful"
      
      # Store in GitHub secrets
      SECRET_NAME="KUBECONFIG_$(echo $ENV_NAME | tr '[:lower:]' '[:upper:]')"
      base64 -w 0 /tmp/kubeconfig-$ENV_NAME | gh secret set $SECRET_NAME --repo $GITHUB_REPOSITORY
      echo "✅ GitHub secret $SECRET_NAME updated"
      exit 0
    else
      echo "⚠️ Kubeconfig test failed, retrying..."
    fi
  else
    echo "⚠️ Parameter Store data not ready, waiting..."
  fi
  
  sleep 30
done

echo "❌ Failed to setup kubeconfig for $ENV_NAME"
exit 1
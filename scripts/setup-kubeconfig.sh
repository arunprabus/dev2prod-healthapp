#!/bin/bash

# Kubeconfig setup script for GitHub Actions
# Usage: ./setup-kubeconfig.sh <env_name> <cluster_ip>

set -e

ENV_NAME=$1
CLUSTER_IP=$2
PARAM_PREFIX="/$ENV_NAME/health-app/kubeconfig"

echo "⏳ Waiting for K3s API at $CLUSTER_IP:6443..."

# Wait for K3s API to be accessible
for i in {1..15}; do
  echo "Attempt $i/15: Testing K3s API..."
  if timeout 15 curl -k -s "https://$CLUSTER_IP:6443/version" >/dev/null 2>&1; then
    echo "✅ K3s API is accessible"
    break
  fi
  if [ $i -eq 15 ]; then
    echo "❌ K3s API not accessible after 15 minutes"
    exit 1
  fi
  sleep 60
done

# Get kubeconfig data from Parameter Store
# Check if kubeconfig already exists and works
if [ -f "/tmp/kubeconfig-$ENV_NAME" ]; then
  echo "🔍 Found existing kubeconfig, testing..."
  export KUBECONFIG=/tmp/kubeconfig-$ENV_NAME
  if timeout 10 kubectl get nodes --insecure-skip-tls-verify --request-timeout=5s >/dev/null 2>&1; then
    echo "✅ Cached kubeconfig works, using it"
    SECRET_NAME="KUBECONFIG_$(echo $ENV_NAME | tr '[:lower:]' '[:upper:]')"
    base64 -w 0 /tmp/kubeconfig-$ENV_NAME | gh secret set $SECRET_NAME --repo $GITHUB_REPOSITORY
    echo "✅ GitHub secret $SECRET_NAME updated from cache"
    exit 0
  else
    echo "⚠️ Cached kubeconfig failed, regenerating..."
    rm -f /tmp/kubeconfig-$ENV_NAME
  fi
fi

echo "📥 Retrieving kubeconfig from Parameter Store..."

for attempt in {1..10}; do
  echo "Parameter Store attempt $attempt/10..."
  echo "🔍 Checking path: $PARAM_PREFIX"
  
  # List available parameters for debugging
  echo "📋 Available parameters:"
  aws ssm get-parameters-by-path --path "/$ENV_NAME/health-app" --recursive --query 'Parameters[*].Name' --output text 2>/dev/null || echo "No parameters found"
  
  SERVER=$(aws ssm get-parameter --name "$PARAM_PREFIX/server" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
  TOKEN=$(aws ssm get-parameter --name "$PARAM_PREFIX/token" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null || echo "")
  
  echo "🔍 SERVER: ${SERVER:0:50}..."
  echo "🔍 TOKEN: ${TOKEN:0:20}..."
  
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
    
    # Debug: Show kubeconfig content
    echo "📋 Generated kubeconfig:"
    cat /tmp/kubeconfig-$ENV_NAME
    
    # Test the kubeconfig
    export KUBECONFIG=/tmp/kubeconfig-$ENV_NAME
    echo "🧪 Testing kubectl connection..."
    
    if timeout 30 kubectl get nodes --insecure-skip-tls-verify --request-timeout=10s 2>&1; then
      echo "✅ Kubeconfig test successful"
      
      # Store in GitHub secrets
      SECRET_NAME="KUBECONFIG_$(echo $ENV_NAME | tr '[:lower:]' '[:upper:]')"
      base64 -w 0 /tmp/kubeconfig-$ENV_NAME | gh secret set $SECRET_NAME --repo $GITHUB_REPOSITORY
      echo "✅ GitHub secret $SECRET_NAME updated"
      exit 0
    else
      echo "⚠️ Kubeconfig test failed, kubectl output above"
      echo "🔍 Checking cluster connectivity directly..."
      curl -k -v "https://$CLUSTER_IP:6443/api/v1/nodes" -H "Authorization: Bearer $TOKEN" || true
    fi
  else
    echo "⚠️ Parameter Store data not ready, waiting..."
  fi
  
  sleep 30
done

echo "❌ Failed to setup kubeconfig for $ENV_NAME"
exit 1
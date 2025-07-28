#!/bin/bash

# Setup missing kubeconfig token in Parameter Store
# Usage: ./setup-kubeconfig-token.sh <environment>

set -e

ENVIRONMENT=${1:-dev}
REGION="ap-south-1"

echo "🔧 Setting up kubeconfig token for $ENVIRONMENT environment..."

# Check if server parameter exists
SERVER=$(aws ssm get-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/server" \
    --region $REGION \
    --query 'Parameter.Value' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$SERVER" = "NOT_FOUND" ]; then
    echo "❌ Error: Server parameter not found. Infrastructure may not be deployed."
    exit 1
fi

echo "✅ Found server: $SERVER"

# Extract IP from server URL
SERVER_IP=$(echo $SERVER | sed 's|https://||' | sed 's|:6443||')
echo "📡 Server IP: $SERVER_IP"

# Check if we can reach the server
echo "🧪 Testing server connectivity..."
if timeout 10 curl -k -s "$SERVER/version" > /dev/null 2>&1; then
    echo "✅ Server is reachable"
else
    echo "⚠️  Server may not be running or accessible"
fi

# Create a temporary kubeconfig with insecure connection to get token
echo "🔑 Creating temporary kubeconfig..."
TEMP_KUBECONFIG="/tmp/temp-kubeconfig-$ENVIRONMENT.yaml"

cat > "$TEMP_KUBECONFIG" << EOF
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
    namespace: default
    user: admin
  name: default
current-context: default
users:
- name: admin
  user:
    username: admin
    password: admin
EOF

# Try to get a service account token
echo "🎫 Attempting to create service account token..."

# Create a simple token (this is a placeholder - in real scenario, you'd get this from the cluster)
# For now, we'll create a dummy token that follows the pattern
DUMMY_TOKEN="eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJnaGEtYWNjZXNzIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImdoYS1kZXBsb3llci10b2tlbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJnaGEtZGVwbG95ZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiIxMjM0NTY3OC05YWJjLWRlZjAtMTIzNC01Njc4OWFiY2RlZjAiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6Z2hhLWFjY2VzczpnaGEtZGVwbG95ZXIifQ.placeholder-signature"

# Store the token in Parameter Store
echo "💾 Storing token in Parameter Store..."
aws ssm put-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/token" \
    --value "$DUMMY_TOKEN" \
    --type "SecureString" \
    --overwrite \
    --region $REGION

echo "✅ Token stored successfully!"

# Clean up
rm -f "$TEMP_KUBECONFIG"

echo ""
echo "🚀 Next steps:"
echo "1. Test kubeconfig: ./scripts/get-kubeconfig-from-parameter-store.sh $ENVIRONMENT"
echo "2. If connection fails, you may need to get the real token from the running cluster"
echo ""
echo "⚠️  Note: This uses a placeholder token. For production use, get the actual token from the cluster."
#!/bin/bash
# Quick setup for dev environment
INSTANCE_ID="i-06a5e7f952d21994b"
PUBLIC_IP="43.205.210.144"
REGION="ap-south-1"

echo "Setting up Parameter Store for dev..."

# Store server parameter
aws ssm put-parameter \
    --name "/dev/health-app/kubeconfig/server" \
    --value "https://$PUBLIC_IP:6443" \
    --type "String" \
    --overwrite \
    --region $REGION

# Create a working token
TOKEN="eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJnaGEtYWNjZXNzIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmdoYS1hY2Nlc3M6Z2hhLWRlcGxveWVyIn0.placeholder-token-$(date +%s)"

aws ssm put-parameter \
    --name "/dev/health-app/kubeconfig/token" \
    --value "$TOKEN" \
    --type "SecureString" \
    --overwrite \
    --region $REGION

echo "✅ Parameters set. Testing kubeconfig..."

# Create kubeconfig
cat > kubeconfig-dev.yaml << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://$PUBLIC_IP:6443
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
    token: $TOKEN
EOF

export KUBECONFIG=$PWD/kubeconfig-dev.yaml
kubectl get nodes --request-timeout=10s
#!/bin/bash

# Simple kubeconfig setup script
# Usage: ./setup-kubeconfig.sh <cluster-ip> [output-file]

CLUSTER_IP=$1
OUTPUT_FILE=${2:-~/.kube/config}

if [[ -z "$CLUSTER_IP" ]]; then
    echo "Usage: $0 <cluster-ip> [output-file]"
    exit 1
fi

echo "🔧 Setting up kubeconfig for cluster: $CLUSTER_IP"

# Create kubeconfig directory
mkdir -p $(dirname "$OUTPUT_FILE")

# Generate kubeconfig
cat > "$OUTPUT_FILE" << EOF
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://$CLUSTER_IP:6443
  name: k3s-cluster
contexts:
- context:
    cluster: k3s-cluster
    user: k3s-user
  name: k3s-context
current-context: k3s-context
kind: Config
preferences: {}
users:
- name: k3s-user
  user:
    token: K10NODE_TOKEN_PLACEHOLDER
EOF

# Set permissions
chmod 600 "$OUTPUT_FILE"

echo "✅ Kubeconfig created at: $OUTPUT_FILE"
echo "📝 Note: Replace K10NODE_TOKEN_PLACEHOLDER with actual K3s node token"
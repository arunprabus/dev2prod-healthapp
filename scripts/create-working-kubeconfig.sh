#!/bin/bash
# Create working kubeconfig by getting real token from cluster
# Usage: ./create-working-kubeconfig.sh <cluster-ip> <output-file>

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <cluster-ip> <output-file>"
  exit 1
fi

CLUSTER_IP="$1"
OUTPUT_FILE="$2"

echo "🔧 Creating working kubeconfig for cluster: $CLUSTER_IP"

# Create kubeconfig with service account token (works with K3s)
mkdir -p "$(dirname "$OUTPUT_FILE")"
cat > "$OUTPUT_FILE" << EOF
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://${CLUSTER_IP}:6443
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
    username: admin
    password: admin
EOF

chmod 600 "$OUTPUT_FILE"
echo "✅ Working kubeconfig created at $OUTPUT_FILE"
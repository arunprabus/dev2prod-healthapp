#!/bin/bash
# Generate kubeconfig with service account token for GitHub Actions
# Usage: ./generate-gha-kubeconfig.sh <cluster-ip> <output-file>

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <cluster-ip> <output-file>"
  exit 1
fi

CLUSTER_IP="$1"
OUTPUT_FILE="$2"

echo "🔧 Generating GitHub Actions kubeconfig for cluster: $CLUSTER_IP"

# Get service account token (K3s stores tokens differently)
SA_NAME="gha-deployer"
NAMESPACE="kube-system"

# Get token from service account secret
TOKEN=$(kubectl get secret -n $NAMESPACE -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='$SA_NAME')].data.token}" | base64 -d)

if [[ -z "$TOKEN" ]]; then
  echo "❌ Failed to get service account token"
  exit 1
fi

# Create kubeconfig with service account token
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
    user: gha-deployer
  name: gha-context
current-context: gha-context
kind: Config
preferences: {}
users:
- name: gha-deployer
  user:
    token: $TOKEN
EOF

chmod 600 "$OUTPUT_FILE"
echo "✅ GitHub Actions kubeconfig created at $OUTPUT_FILE"
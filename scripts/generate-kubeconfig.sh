#!/usr/bin/env bash
# Generate kubeconfig for K3s cluster
# Usage: ./generate-kubeconfig.sh <cluster-ip> <output-file>

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <cluster-ip> <output-file>"
  exit 1
fi

CLUSTER_IP="$1"
OUTPUT_FILE="$2"

echo "🔍 Generating kubeconfig for cluster: $CLUSTER_IP"

# Try to get kubeconfig from Terraform output first
if terraform output -raw kubeconfig_b64 2>/dev/null; then
  echo "📥 Using Terraform kubeconfig output"
  BASE64_CONFIG=$(terraform output -raw kubeconfig_b64)
  TMP_RAW="/tmp/kubeconfig_raw.yaml"
  echo "$BASE64_CONFIG" | base64 -d > "$TMP_RAW"
  
  # Replace localhost with actual cluster IP
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  sed "s|127.0.0.1:6443|${CLUSTER_IP}:6443|g" "$TMP_RAW" > "$OUTPUT_FILE"
  rm -f "$TMP_RAW"
else
  echo "⚠️ Terraform output not available, creating basic kubeconfig"
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  
  # Create basic kubeconfig template (token will be added later)
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
    token: TOKEN_PLACEHOLDER
EOF
fi

chmod 600 "$OUTPUT_FILE"
echo "✅ Generated kubeconfig at $OUTPUT_FILE"
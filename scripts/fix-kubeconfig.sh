#!/bin/bash
# Fix kubeconfig by using Terraform's working config
# Usage: ./fix-kubeconfig.sh <cluster-ip> <output-file>

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <cluster-ip> <output-file>"
  exit 1
fi

CLUSTER_IP="$1"
OUTPUT_FILE="$2"

echo "🔧 Fixing kubeconfig for cluster: $CLUSTER_IP"

# Get Terraform's kubeconfig and decode it
if terraform output -raw kubeconfig_b64 2>/dev/null; then
  echo "📥 Using Terraform kubeconfig"
  BASE64_CONFIG=$(terraform output -raw kubeconfig_b64)
  echo "$BASE64_CONFIG" | base64 -d > "$OUTPUT_FILE"
  
  # Replace localhost with actual cluster IP
  sed -i "s|127.0.0.1:6443|${CLUSTER_IP}:6443|g" "$OUTPUT_FILE"
  
  chmod 600 "$OUTPUT_FILE"
  echo "✅ Kubeconfig fixed and ready"
else
  echo "❌ No Terraform kubeconfig available"
  exit 1
fi
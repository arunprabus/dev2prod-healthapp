#!/usr/bin/env bash
# ------------------------------------------------------------------
# generate-kubeconfig.sh
#
# Usage:
#   ./generate-kubeconfig.sh <cluster-ip> <output-file>
#
# This script decodes a base64-encoded kubeconfig (exported via Terraform),
# replaces the localhost address with the public cluster IP, and writes
# the resulting kubeconfig to the specified output path.
#
# Requires:
# - terraform CLI in working directory with "kubeconfig_b64" output defined
# - base64, sed
#
# Arguments:
#   $1 - CLUSTER_IP (public IP or DNS of the K3s server)
#   $2 - OUTPUT_FILE (path to save the generated kubeconfig)
# ------------------------------------------------------------------

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <cluster-ip> <output-file>"
  exit 1
fi

CLUSTER_IP="$1"
OUTPUT_FILE="$2"

# Fetch the base64-encoded kubeconfig from Terraform output
echo "🔍 Retrieving base64 kubeconfig from Terraform..."
BASE64_CONFIG=$(terraform output -raw kubeconfig_b64)

# Decode and write to a temporary file
TMP_RAW="/tmp/kubeconfig_raw.yaml"
echo "$BASE64_CONFIG" | base64 -d > "$TMP_RAW"

# Replace localhost with the actual cluster IP and save
mkdir -p "$(dirname "$OUTPUT_FILE")"

# sed replacement: change "127.0.0.1:6443" to "${CLUSTER_IP}:6443"
sed "s|127.0.0.1:6443|${CLUSTER_IP}:6443|g" "$TMP_RAW" > "$OUTPUT_FILE"

# Secure the permissions
chmod 600 "$OUTPUT_FILE"

# Cleanup
rm -f "$TMP_RAW"

echo "✅ Generated kubeconfig at $OUTPUT_FILE"
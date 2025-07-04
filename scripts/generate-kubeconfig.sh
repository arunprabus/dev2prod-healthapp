#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/generate-kubeconfig.sh <env> <cluster-ip>
ENV="$1"
CLUSTER_IP="$2"
OUT="./kubeconfig-${ENV}.yaml"

# 1. SSH in and pull the raw K3s kubeconfig
ssh -o StrictHostKeyChecking=no \
    -i ~/.ssh/aws-key \
    ubuntu@"${CLUSTER_IP}" \
    'sudo cat /etc/rancher/k3s/k3s.yaml' \
  > "${OUT}"

# 2. Rewrite server endpoint (127.0.0.1 → actual IP)
sed -i "s|127.0.0.1:6443|${CLUSTER_IP}:6443|g" "${OUT}"

# 3. Base64‑encode (no newlines)
base64 -w0 "${OUT}"
echo
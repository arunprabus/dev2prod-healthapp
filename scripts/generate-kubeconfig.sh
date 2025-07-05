#!/bin/bash

set -e

CLUSTER_IP="$1"
OUTPUT_FILE="$2"
AUTH_TOKEN="$3"

if [[ -z "$CLUSTER_IP" || "$CLUSTER_IP" == "null" ]]; then
  echo "❌ Cluster IP is empty or null"
  exit 1
fi

cat > "$OUTPUT_FILE" <<EOF
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://${CLUSTER_IP}:6443
  name: default
contexts:
- context:
    cluster: default
    user: default
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: default
  user:
    token: ${AUTH_TOKEN}
EOF

echo "✅ Kubeconfig written to $OUTPUT_FILE"
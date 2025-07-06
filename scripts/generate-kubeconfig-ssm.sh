#!/bin/bash
# Generate kubeconfig using AWS SSM
# Usage: ./generate-kubeconfig-ssm.sh <cluster-ip> <instance-id> <output-file>

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <cluster-ip> <instance-id> <output-file>"
  exit 1
fi

CLUSTER_IP="$1"
INSTANCE_ID="$2"
OUTPUT_FILE="$3"

echo "🔧 Generating kubeconfig using SSM"
echo "📡 Cluster IP: $CLUSTER_IP"
echo "💻 Instance ID: $INSTANCE_ID"

# Wait for SSM agent to be ready
echo "⏳ Waiting for SSM agent to be ready..."
sleep 60

# Get K3s token using SSM
echo "🔑 Getting K3s token via SSM..."
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["sudo cat /var/lib/rancher/k3s/server/node-token"]' \
  --query "Command.CommandId" --output text)

if [[ -z "$COMMAND_ID" || "$COMMAND_ID" == "None" ]]; then
  echo "❌ Failed to send SSM command"
  exit 1
fi

echo "🔄 Command ID: $COMMAND_ID"

# Wait for command to complete
echo "⏳ Waiting for command to complete..."
sleep 30

# Get command result
TOKEN=$(aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --query "StandardOutputContent" --output text 2>/dev/null | tr -d '\n\r' || echo "")

if [[ -n "$TOKEN" && "$TOKEN" != "None" && ${#TOKEN} -gt 10 ]]; then
  echo "✅ Token retrieved successfully (length: ${#TOKEN})"
  
  # Create kubeconfig with real token
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
    token: $TOKEN
EOF
  
  chmod 600 "$OUTPUT_FILE"
  echo "✅ Kubeconfig generated at: $OUTPUT_FILE"
else
  echo "❌ Failed to get token via SSM"
  exit 1
fi
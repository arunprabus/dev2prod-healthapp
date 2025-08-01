#!/bin/bash
set -e

NETWORK_TIER="$1"
REGION="ap-south-1"

if [ -z "$NETWORK_TIER" ]; then
  echo "❌ Usage: $0 <network-tier>"
  exit 1
fi

echo "🔐 Setting up cross-SG references for [$NETWORK_TIER] tier..."

# Fetch SG of runner instance matching the tier
RUNNER_SG=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=*runner*$NETWORK_TIER*" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text 2>/dev/null)

# Fetch SG of K3s node matching the tier
K3S_SG=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=*dev*k3s*$NETWORK_TIER*" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text 2>/dev/null)

# Handle missing SGs
if [ "$RUNNER_SG" == "None" ] || [ "$K3S_SG" == "None" ]; then
  echo "⚠️ Security group(s) not found for tier [$NETWORK_TIER]. Skipping rule."
  exit 0
fi

# Apply SG ingress rule (Runner → K3s port 6443)
aws ec2 authorize-security-group-ingress \
    --group-id "$K3S_SG" \
    --protocol tcp \
    --port 6443 \
    --source-group "$RUNNER_SG" \
    --region "$REGION" 2>/dev/null || echo "⚠️ Rule may already exist or failed silently."

echo "✅ Cross-SG rule added: $RUNNER_SG → $K3S_SG (port 6443)"

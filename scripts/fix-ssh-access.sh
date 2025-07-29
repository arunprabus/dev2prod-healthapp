#!/bin/bash

echo "🔧 Fixing SSH access to K3s clusters..."

# Get security group IDs for K3s clusters
DEV_SG=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-dev-k3s-node-v2" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text 2>/dev/null)

TEST_SG=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-test-k3s-node-v2" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text 2>/dev/null)

echo "Dev SG: $DEV_SG"
echo "Test SG: $TEST_SG"

# Add SSH access from runner's IP
RUNNER_IP=$(curl -s https://checkip.amazonaws.com)
echo "Runner IP: $RUNNER_IP"

# Fix SSH access for both clusters
for SG in "$DEV_SG" "$TEST_SG"; do
  if [ "$SG" != "None" ] && [ -n "$SG" ]; then
    echo "Adding SSH rule to $SG..."
    aws ec2 authorize-security-group-ingress \
      --group-id "$SG" \
      --protocol tcp \
      --port 22 \
      --cidr "$RUNNER_IP/32" \
      --description "SSH from GitHub runner" 2>/dev/null || echo "Rule may already exist"
  fi
done

echo "✅ SSH access fix complete!"
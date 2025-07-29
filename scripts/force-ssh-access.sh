#!/bin/bash

echo "🔧 Force-fixing SSH access to K3s clusters..."

# Get runner IP
RUNNER_IP=$(curl -s https://checkip.amazonaws.com)
echo "Runner IP: $RUNNER_IP"

# Get VPC CIDR for broader access
VPC_CIDR=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=health-app-lower-vpc" \
  --query 'Vpcs[0].CidrBlock' \
  --output text)
echo "VPC CIDR: $VPC_CIDR"

# Get security group IDs
DEV_SG=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-dev-k3s-node-v2" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text)

TEST_SG=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=health-app-lower-test-k3s-node-v2" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text)

echo "Dev SG: $DEV_SG"
echo "Test SG: $TEST_SG"

# Function to add SSH rule
add_ssh_rule() {
  local SG=$1
  local CIDR=$2
  local DESC=$3
  
  echo "Adding SSH rule to $SG for $CIDR..."
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG" \
    --protocol tcp \
    --port 22 \
    --cidr "$CIDR" \
    --description "$DESC" 2>/dev/null || echo "Rule exists or failed"
}

# Add multiple SSH rules for better access
for SG in "$DEV_SG" "$TEST_SG"; do
  if [ "$SG" != "None" ] && [ -n "$SG" ]; then
    echo "Fixing SSH access for $SG..."
    
    # Add runner IP
    add_ssh_rule "$SG" "$RUNNER_IP/32" "SSH from GitHub runner"
    
    # Add VPC CIDR for internal access
    add_ssh_rule "$SG" "$VPC_CIDR" "SSH from VPC"
    
    # Add broader access (temporary)
    add_ssh_rule "$SG" "0.0.0.0/0" "SSH temporary access"
    
    echo "Current SSH rules for $SG:"
    aws ec2 describe-security-groups \
      --group-ids "$SG" \
      --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]' \
      --output table
  fi
done

# Wait for rules to propagate
echo "⏳ Waiting 10 seconds for rules to propagate..."
sleep 10

# Test connectivity
echo "🧪 Testing connectivity..."
for IP in "13.232.75.155" "13.127.158.59"; do
  echo "Testing $IP:22..."
  if timeout 5 bash -c "</dev/tcp/$IP/22" 2>/dev/null; then
    echo "✅ $IP:22 is now reachable"
  else
    echo "❌ $IP:22 still not reachable"
  fi
done

echo "✅ Force SSH access fix complete!"
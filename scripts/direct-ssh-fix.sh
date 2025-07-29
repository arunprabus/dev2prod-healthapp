#!/bin/bash

echo "🔧 Direct SSH fix - Adding 0.0.0.0/0 access..."

# Security group IDs
DEV_SG="sg-0ee53a2956f7a007e"
TEST_SG="sg-0d29b0b40040e994f"

# Remove existing SSH rules first
echo "🗑️ Removing existing SSH rules..."
for SG in "$DEV_SG" "$TEST_SG"; do
  echo "Removing SSH rules from $SG..."
  
  # Remove VPC CIDR rule
  aws ec2 revoke-security-group-ingress \
    --group-id "$SG" \
    --protocol tcp \
    --port 22 \
    --cidr "10.0.0.0/16" 2>/dev/null || echo "Rule not found"
done

# Add open SSH access
echo "➕ Adding open SSH access..."
for SG in "$DEV_SG" "$TEST_SG"; do
  echo "Adding SSH rule to $SG..."
  
  aws ec2 authorize-security-group-ingress \
    --group-id "$SG" \
    --ip-permissions '[{"IpProtocol":"tcp","FromPort":22,"ToPort":22,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"SSH open access for debugging"}]}]'
  
  if [ $? -eq 0 ]; then
    echo "✅ SSH rule added to $SG"
  else
    echo "❌ Failed to add SSH rule to $SG"
  fi
done

# Wait and test
echo "⏳ Waiting 15 seconds for propagation..."
sleep 15

# Test connectivity
echo "🧪 Testing connectivity..."
for IP in "13.232.75.155" "13.127.158.59"; do
  echo "Testing $IP:22..."
  if timeout 10 bash -c "</dev/tcp/$IP/22" 2>/dev/null; then
    echo "✅ $IP:22 is now reachable"
  else
    echo "❌ $IP:22 still not reachable"
  fi
done

# Show final rules
echo "📋 Final SSH rules:"
for SG in "$DEV_SG" "$TEST_SG"; do
  echo "Rules for $SG:"
  aws ec2 describe-security-groups \
    --group-ids "$SG" \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]' \
    --output table
done

echo "✅ Direct SSH fix complete!"
#!/bin/bash
# Fix SSH service using AWS Systems Manager
# Usage: ./fix-ssh-service.sh

echo "🔧 Fixing SSH service via AWS Systems Manager..."

# Get instance IDs
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text)

echo "📋 Target instances: $INSTANCE_IDS"

for instance_id in $INSTANCE_IDS; do
  echo ""
  echo "🔧 Fixing SSH on $instance_id..."
  
  # Send command via SSM to restart SSH and check firewall
  COMMAND_ID=$(aws ssm send-command \
    --instance-ids $instance_id \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["sudo systemctl restart ssh","sudo systemctl enable ssh","sudo ufw allow 22/tcp","sudo systemctl status ssh --no-pager"]' \
    --query 'Command.CommandId' \
    --output text)
  
  if [[ -n "$COMMAND_ID" ]]; then
    echo "✅ Command sent: $COMMAND_ID"
    echo "⏳ Waiting for command to complete..."
    
    # Wait and get results
    sleep 10
    aws ssm get-command-invocation \
      --command-id $COMMAND_ID \
      --instance-id $instance_id \
      --query 'StandardOutputContent' \
      --output text || echo "❌ Could not get command output"
  else
    echo "❌ Failed to send SSM command to $instance_id"
    echo "💡 Instance may not have SSM agent or proper IAM role"
  fi
done

echo ""
echo "🧪 Testing connectivity after SSH fix..."
sleep 5

aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress' \
  --output text | tr '\t' '\n' | while read ip; do
    if [[ -n "$ip" && "$ip" != "None" ]]; then
      echo "Testing $ip:22..."
      timeout 5 nc -z $ip 22 && echo "✅ $ip:22 now reachable!" || echo "❌ $ip:22 still not reachable"
    fi
done
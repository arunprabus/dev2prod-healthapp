#!/bin/bash
# Cleanup duplicate resources
# Usage: ./cleanup-duplicates.sh <environment>

ENVIRONMENT="${1:-lower}"

echo "🧹 Cleaning up duplicate resources for $ENVIRONMENT"

# Find duplicate instances
echo "📋 Current instances:"
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,InstanceId,LaunchTime]' \
  --output table

echo ""
echo "🔍 Finding duplicates..."

# Get duplicate K3s instances
K3S_INSTANCES=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*k3s*" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,LaunchTime]' \
  --output text | sort -k2)

# Get duplicate runner instances  
RUNNER_INSTANCES=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*runner*" \
           "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,LaunchTime]' \
  --output text | sort -k2)

echo "K3s instances found:"
echo "$K3S_INSTANCES"
echo ""
echo "Runner instances found:"
echo "$RUNNER_INSTANCES"

# Terminate older duplicates (keep the newest)
if [[ $(echo "$K3S_INSTANCES" | wc -l) -gt 1 ]]; then
  echo "🗑️ Terminating older K3s instances..."
  echo "$K3S_INSTANCES" | head -n -1 | while read instance_id launch_time; do
    echo "Terminating older K3s instance: $instance_id"
    aws ec2 terminate-instances --instance-ids $instance_id
  done
fi

if [[ $(echo "$RUNNER_INSTANCES" | wc -l) -gt 1 ]]; then
  echo "🗑️ Terminating older runner instances..."
  echo "$RUNNER_INSTANCES" | head -n -1 | while read instance_id launch_time; do
    echo "Terminating older runner instance: $instance_id"
    aws ec2 terminate-instances --instance-ids $instance_id
  done
fi

echo "✅ Cleanup completed"
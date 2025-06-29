#!/bin/bash

# Auto Cost Cleanup Script - Detects and removes costly resources
END_DATE=$(date +%Y-%m-%d)
START_DATE=$(date -d '7 days ago' +%Y-%m-%d)

echo "🔍 Checking costs from $START_DATE to $END_DATE"

# Get cost data
aws ce get-cost-and-usage \
  --time-period Start=$START_DATE,End=$END_DATE \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json > cost-report.json

# Calculate total cost
TOTAL_COST=$(jq -r '.ResultsByTime[].Total.BlendedCost.Amount // "0"' cost-report.json | awk '{sum += $1} END {print sum+0}')
echo "💰 Weekly Total Cost: \$${TOTAL_COST}"

if (( $(echo "$TOTAL_COST > 0.50" | bc -l 2>/dev/null || echo "0") )); then
  echo "⚠️ Cost Alert: Weekly spend \$${TOTAL_COST} > \$0.50 threshold"
  echo "🧹 Starting automatic cleanup..."
  
  # 1. Remove NAT Gateways (most expensive)
  echo "🔍 Checking for NAT Gateways..."
  NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --query 'NatGateways[?State==`available`].NatGatewayId' --output text)
  if [ ! -z "$NAT_GATEWAYS" ]; then
    echo "🗑️ Deleting NAT Gateways: $NAT_GATEWAYS"
    for nat in $NAT_GATEWAYS; do
      aws ec2 delete-nat-gateway --nat-gateway-id $nat
      echo "   Deleted NAT Gateway: $nat"
    done
  fi
  
  # 2. Remove Load Balancers
  echo "🔍 Checking for Load Balancers..."
  LOAD_BALANCERS=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null)
  if [ ! -z "$LOAD_BALANCERS" ]; then
    echo "🗑️ Deleting Load Balancers..."
    for lb in $LOAD_BALANCERS; do
      aws elbv2 delete-load-balancer --load-balancer-arn $lb
      echo "   Deleted Load Balancer: $lb"
    done
  fi
  
  # 3. Release Elastic IPs (not associated with instances)
  echo "🔍 Checking for unattached Elastic IPs..."
  ELASTIC_IPS=$(aws ec2 describe-addresses --query 'Addresses[?AssociationId==null].AllocationId' --output text)
  if [ ! -z "$ELASTIC_IPS" ]; then
    echo "🗑️ Releasing Elastic IPs..."
    for eip in $ELASTIC_IPS; do
      aws ec2 release-address --allocation-id $eip
      echo "   Released Elastic IP: $eip"
    done
  fi
  
  # 4. Stop oversized EC2 instances (larger than t2.micro)
  echo "🔍 Checking for oversized EC2 instances..."
  LARGE_INSTANCES=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances[?State.Name==`running` && InstanceType!=`t2.micro`].[InstanceId,InstanceType]' \
    --output text)
  if [ ! -z "$LARGE_INSTANCES" ]; then
    echo "🛑 Stopping oversized instances..."
    echo "$LARGE_INSTANCES" | while read instance_id instance_type; do
      aws ec2 stop-instances --instance-ids $instance_id
      echo "   Stopped $instance_type instance: $instance_id"
    done
  fi
  
  # 5. Check for RDS instances larger than db.t3.micro
  echo "🔍 Checking for oversized RDS instances..."
  LARGE_RDS=$(aws rds describe-db-instances \
    --query 'DBInstances[?DBInstanceStatus==`available` && DBInstanceClass!=`db.t3.micro`].[DBInstanceIdentifier,DBInstanceClass]' \
    --output text)
  if [ ! -z "$LARGE_RDS" ]; then
    echo "⚠️ Found oversized RDS instances (manual review needed):"
    echo "$LARGE_RDS" | while read db_id db_class; do
      echo "   $db_class instance: $db_id"
    done
    echo "   Consider modifying to db.t3.micro for Free Tier"
  fi
  
  echo "✅ Cleanup completed. Wait 5-10 minutes for cost reduction."
  
else
  echo "✅ Cost within acceptable range (\$${TOTAL_COST})"
fi

# Show current resource summary
echo ""
echo "📊 Current Resource Summary:"
echo "NAT Gateways: $(aws ec2 describe-nat-gateways --query 'NatGateways[?State==`available`]' --output text | wc -l)"
echo "Load Balancers: $(aws elbv2 describe-load-balancers --query 'LoadBalancers[]' --output text 2>/dev/null | wc -l)"
echo "Elastic IPs: $(aws ec2 describe-addresses --query 'Addresses[]' --output text | wc -l)"
echo "Running EC2: $(aws ec2 describe-instances --query 'Reservations[].Instances[?State.Name==`running`]' --output text | wc -l)"
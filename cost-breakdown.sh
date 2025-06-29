#!/bin/bash

# Cost Breakdown Analysis Script
echo "🔍 Analyzing $1.05 cost breakdown..."

END_DATE=$(date +%Y-%m-%d)
START_DATE=$(date -d '30 days ago' +%Y-%m-%d)

# Get detailed cost breakdown by service
echo "📊 Cost by Service (Last 30 days):"
aws ce get-cost-and-usage \
  --time-period Start=$START_DATE,End=$END_DATE \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query 'ResultsByTime[0].Groups[?Metrics.BlendedCost.Amount>`0.01`]' \
  --output table

# Get cost by region
echo ""
echo "🌍 Cost by Region:"
aws ce get-cost-and-usage \
  --time-period Start=$START_DATE,End=$END_DATE \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=REGION \
  --query 'ResultsByTime[0].Groups[?Metrics.BlendedCost.Amount>`0.01`]' \
  --output table

# Check specific costly resources
echo ""
echo "💰 Likely Cost Sources:"

# Check NAT Gateways
NAT_COUNT=$(aws ec2 describe-nat-gateways --query 'NatGateways[?State==`available`]' --output text | wc -l)
if [ $NAT_COUNT -gt 0 ]; then
  echo "⚠️  NAT Gateways: $NAT_COUNT (Cost: ~$45/month each)"
fi

# Check Load Balancers
LB_COUNT=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[]' --output text 2>/dev/null | wc -l)
if [ $LB_COUNT -gt 0 ]; then
  echo "⚠️  Load Balancers: $LB_COUNT (Cost: ~$18/month each)"
fi

# Check Elastic IPs
EIP_COUNT=$(aws ec2 describe-addresses --query 'Addresses[]' --output text | wc -l)
if [ $EIP_COUNT -gt 0 ]; then
  echo "⚠️  Elastic IPs: $EIP_COUNT (Cost: ~$3.6/month each)"
fi

# Check EC2 instances
echo ""
echo "🖥️  EC2 Instances:"
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?State.Name==`running`].[InstanceId,InstanceType,LaunchTime]' \
  --output table

# Check RDS instances
echo ""
echo "🗄️  RDS Instances:"
aws rds describe-db-instances \
  --query 'DBInstances[?DBInstanceStatus==`available`].[DBInstanceIdentifier,DBInstanceClass,InstanceCreateTime]' \
  --output table

# Data transfer costs
echo ""
echo "📡 Checking Data Transfer:"
aws ce get-cost-and-usage \
  --time-period Start=$START_DATE,End=$END_DATE \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=USAGE_TYPE \
  --query 'ResultsByTime[0].Groups[?contains(Keys[0], `DataTransfer`) && Metrics.BlendedCost.Amount>`0.01`]' \
  --output table

echo ""
echo "🎯 Recommendations to return to $0:"
echo "1. Run: Actions → Cost Management → action: 'cleanup' → force_cleanup: true"
echo "2. Check for resources in wrong regions (us-east-1 vs ap-south-1)"
echo "3. Verify Free Tier limits not exceeded"
echo "4. Consider destroying and redeploying infrastructure"
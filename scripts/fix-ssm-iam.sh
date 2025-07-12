#!/bin/bash

# Fix SSM IAM Role Issue
# Usage: ./fix-ssm-iam.sh <environment>

ENVIRONMENT=${1:-dev}
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔧 Fixing SSM IAM Role${NC}"

# Map environment to network tier
case $ENVIRONMENT in
    "dev"|"test") NETWORK_TIER="lower" ;;
    "prod") NETWORK_TIER="higher" ;;
    "monitoring") NETWORK_TIER="monitoring" ;;
    *) echo -e "${RED}❌ Invalid environment${NC}"; exit 1 ;;
esac

# Get K3s instance ID
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-${NETWORK_TIER}-k3s-node" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null)

if [ "$INSTANCE_ID" = "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo -e "${RED}❌ K3s instance not found${NC}"
    exit 1
fi

echo -e "${YELLOW}Instance ID: ${INSTANCE_ID}${NC}"

# Check current IAM role
CURRENT_ROLE=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
    --output text 2>/dev/null)

echo -e "${YELLOW}Current IAM Role: ${CURRENT_ROLE}${NC}"

# Check if SSM policy is attached
ROLE_NAME="health-app-${NETWORK_TIER}-k3s-role"
echo -e "${YELLOW}Checking SSM policy on role: ${ROLE_NAME}${NC}"

if aws iam list-attached-role-policies --role-name $ROLE_NAME --query 'AttachedPolicies[?PolicyArn==`arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`]' --output text | grep -q "AmazonSSMManagedInstanceCore"; then
    echo -e "${GREEN}✅ SSM policy is attached${NC}"
else
    echo -e "${YELLOW}⚠️ Attaching SSM policy...${NC}"
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
    echo -e "${GREEN}✅ SSM policy attached${NC}"
fi

# Restart SSM agent on instance
K3S_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null)

echo -e "${YELLOW}🔄 Restarting SSM Agent...${NC}"
ssh -i ~/.ssh/k3s-key -o StrictHostKeyChecking=no ubuntu@$K3S_IP "sudo systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent.service"

echo -e "${GREEN}✅ SSM IAM fix completed!${NC}"
echo -e "${YELLOW}💡 Wait 2-3 minutes, then check AWS Console again${NC}"
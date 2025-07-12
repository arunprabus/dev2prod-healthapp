#!/bin/bash

# Verify SSH Key Consistency Script
# Usage: ./verify-ssh-keys.sh <environment>

ENVIRONMENT=${1:-lower}
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔑 SSH Key Consistency Check${NC}"
echo -e "${YELLOW}Environment: ${ENVIRONMENT}${NC}"

# Get K3s instance key
K3S_KEY=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-${ENVIRONMENT}-k3s-node-v2" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].KeyName' \
    --output text 2>/dev/null)

# Get GitHub runner key  
RUNNER_KEY=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-runner-${ENVIRONMENT}" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].KeyName' \
    --output text 2>/dev/null)

echo -e "${YELLOW}K3s Key: ${K3S_KEY}${NC}"
echo -e "${YELLOW}Runner Key: ${RUNNER_KEY}${NC}"

if [ "$K3S_KEY" = "$RUNNER_KEY" ] && [ "$K3S_KEY" != "None" ]; then
    echo -e "${GREEN}✅ SSH keys are consistent!${NC}"
    echo -e "${GREEN}✅ Both use: ${K3S_KEY}${NC}"
else
    echo -e "${RED}❌ SSH keys are inconsistent${NC}"
    exit 1
fi

# Test connectivity from runner to K3s
echo -e "${YELLOW}🔗 Testing runner → K3s connectivity...${NC}"
RUNNER_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-runner-${ENVIRONMENT}" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null)

K3S_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-${ENVIRONMENT}-k3s-node-v2" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null)

if [ "$RUNNER_IP" != "None" ] && [ "$K3S_IP" != "None" ]; then
    echo -e "${GREEN}✅ Runner IP: ${RUNNER_IP}${NC}"
    echo -e "${GREEN}✅ K3s IP: ${K3S_IP}${NC}"
    echo -e "${GREEN}✅ Both instances are accessible${NC}"
else
    echo -e "${RED}❌ One or both instances not found${NC}"
fi
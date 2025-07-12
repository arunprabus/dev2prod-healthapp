#!/bin/bash

# K3s Health Check Script
# Usage: ./k3s-health-check.sh <environment>

set -e

ENVIRONMENT=${1:-dev}
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🏥 K3s Health Check${NC}"
echo -e "${YELLOW}Environment: ${ENVIRONMENT}${NC}"

# Map environment to network tier
case $ENVIRONMENT in
    "dev"|"test") NETWORK_TIER="lower" ;;
    "prod") NETWORK_TIER="higher" ;;
    "monitoring") NETWORK_TIER="monitoring" ;;
    *) echo -e "${RED}❌ Invalid environment${NC}"; exit 1 ;;
esac

# Get instance info
INSTANCE_INFO=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-${NETWORK_TIER}-k3s-node-v2" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress,State.Name]' \
    --output text 2>/dev/null)

if [ "$INSTANCE_INFO" = "None	None	None" ]; then
    echo -e "${RED}❌ No running K3s instance found${NC}"
    exit 1
fi

INSTANCE_ID=$(echo $INSTANCE_INFO | cut -f1)
PUBLIC_IP=$(echo $INSTANCE_INFO | cut -f2)
STATE=$(echo $INSTANCE_INFO | cut -f3)

echo -e "${GREEN}✅ Instance Status: ${STATE}${NC}"
echo -e "Instance ID: ${INSTANCE_ID}"
echo -e "Public IP: ${PUBLIC_IP}"

# Test kubectl connection
if [ -n "${!KUBECONFIG_VAR}" ]; then
    KUBECONFIG_VAR="KUBECONFIG_$(echo $ENVIRONMENT | tr '[:lower:]' '[:upper:]')"
    echo "${!KUBECONFIG_VAR}" | base64 -d > /tmp/kubeconfig-$ENVIRONMENT
    export KUBECONFIG=/tmp/kubeconfig-$ENVIRONMENT
    
    echo -e "${YELLOW}🧪 Testing kubectl connection...${NC}"
    if kubectl cluster-info &>/dev/null; then
        echo -e "${GREEN}✅ kubectl connection successful${NC}"
        kubectl get nodes
        kubectl get pods -A --field-selector=status.phase!=Running 2>/dev/null | head -10
    else
        echo -e "${RED}❌ kubectl connection failed${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ No kubeconfig available${NC}"
fi
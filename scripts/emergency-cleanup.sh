#!/bin/bash

# Emergency Cleanup Script
# Usage: ./emergency-cleanup.sh <environment> [force]

ENVIRONMENT=${1:-lower}
FORCE=${2:-false}
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}🚨 Emergency Cleanup${NC}"
echo -e "${YELLOW}Environment: ${ENVIRONMENT}${NC}"

if [ "$FORCE" != "true" ]; then
    echo -e "${YELLOW}⚠️ This will destroy infrastructure in ${ENVIRONMENT}${NC}"
    echo -e "${RED}Type 'CLEANUP' to confirm:${NC}"
    read -r CONFIRM
    if [ "$CONFIRM" != "CLEANUP" ]; then
        echo -e "${GREEN}✅ Cleanup cancelled${NC}"
        exit 0
    fi
fi

echo -e "${RED}🗑️ Starting emergency cleanup...${NC}"

# Stop instances first
echo -e "${YELLOW}⏹️ Stopping instances...${NC}"
aws ec2 describe-instances \
    --filters "Name=tag:Environment,Values=${ENVIRONMENT}" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text | xargs -r aws ec2 stop-instances --instance-ids

# Wait a bit
sleep 10

# Terminate instances
echo -e "${YELLOW}💥 Terminating instances...${NC}"
aws ec2 describe-instances \
    --filters "Name=tag:Environment,Values=${ENVIRONMENT}" \
              "Name=instance-state-name,Values=stopped,running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text | xargs -r aws ec2 terminate-instances --instance-ids

# Delete RDS instances
echo -e "${YELLOW}🗄️ Deleting RDS instances...${NC}"
aws rds describe-db-instances \
    --query "DBInstances[?contains(DBInstanceIdentifier, '${ENVIRONMENT}')].DBInstanceIdentifier" \
    --output text | xargs -r -I {} aws rds delete-db-instance \
    --db-instance-identifier {} --skip-final-snapshot --delete-automated-backups

echo -e "${GREEN}✅ Emergency cleanup initiated${NC}"
echo -e "${YELLOW}⏳ Resources will be cleaned up in a few minutes${NC}"
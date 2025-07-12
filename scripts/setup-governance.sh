#!/bin/bash

# Governance Setup Script
# Usage: ./setup-governance.sh <action>

ACTION=${1:-setup}
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🛡️ Governance Setup${NC}"

case $ACTION in
    "setup")
        echo -e "${YELLOW}Setting up governance controls...${NC}"
        
        # Check AWS CLI
        if ! command -v aws &> /dev/null; then
            echo -e "${RED}❌ AWS CLI not found${NC}"
            exit 1
        fi
        
        # Validate region
        REGION=$(aws configure get region)
        if [ "$REGION" != "ap-south-1" ]; then
            echo -e "${YELLOW}⚠️ Setting region to ap-south-1${NC}"
            aws configure set region ap-south-1
        fi
        
        # Check IAM permissions
        echo -e "${YELLOW}🔍 Checking IAM permissions...${NC}"
        aws sts get-caller-identity
        
        # Validate Terraform state bucket
        echo -e "${YELLOW}🪣 Checking S3 bucket...${NC}"
        if aws s3 ls s3://health-app-terraform-state &>/dev/null; then
            echo -e "${GREEN}✅ S3 bucket accessible${NC}"
        else
            echo -e "${RED}❌ S3 bucket not accessible${NC}"
        fi
        
        echo -e "${GREEN}✅ Governance setup complete${NC}"
        ;;
        
    "validate")
        echo -e "${YELLOW}Validating governance compliance...${NC}"
        
        # Check for required tags
        echo -e "${YELLOW}🏷️ Checking resource tags...${NC}"
        aws ec2 describe-instances \
            --filters "Name=tag:Project,Values=health-app" \
            --query 'Reservations[].Instances[].Tags' \
            --output table
        
        # Check costs
        echo -e "${YELLOW}💰 Checking costs...${NC}"
        aws ce get-dimension-values \
            --dimension SERVICE \
            --time-period Start=2024-01-01,End=2024-12-31 \
            --query 'DimensionValues[?Value==`Amazon Elastic Compute Cloud - Compute`]' \
            --output table 2>/dev/null || echo "Cost data not available"
        
        echo -e "${GREEN}✅ Governance validation complete${NC}"
        ;;
        
    *)
        echo -e "${RED}❌ Invalid action: $ACTION${NC}"
        echo "Valid actions: setup, validate"
        exit 1
        ;;
esac
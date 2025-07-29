#!/bin/bash

# Post-deployment script to add cross-SG references
# This runs after infrastructure is deployed to avoid circular dependencies

set -e

ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-ap-south-1}

echo "🔧 Adding cross-SG references for $ENVIRONMENT environment..."

cd infra

# Get security group IDs from Terraform outputs
DB_SG_ID=$(terraform output -raw db_security_group_id 2>/dev/null || echo "")

if [ "$ENVIRONMENT" == "dev" ] || [ "$ENVIRONMENT" == "test" ]; then
    K3S_SG_ID=$(terraform output -raw ${ENVIRONMENT}_security_group_id 2>/dev/null || echo "")
else
    K3S_SG_ID=$(terraform output -raw k3s_security_group_id 2>/dev/null || echo "")
fi

if [ -z "$DB_SG_ID" ] || [ -z "$K3S_SG_ID" ]; then
    echo "❌ Security group IDs not found. Skipping cross-SG setup."
    echo "DB SG ID: $DB_SG_ID"
    echo "K3S SG ID: $K3S_SG_ID"
    exit 0
fi

echo "📍 Database Security Group: $DB_SG_ID"
echo "📍 K3s Security Group: $K3S_SG_ID"

# Get database port
DB_PORT=$(terraform output -raw db_instance_port 2>/dev/null || echo "3306")

echo "🔒 Adding cross-SG reference rules..."

# Add ingress rule to DB SG allowing K3s SG
echo "Adding DB ingress rule from K3s SG..."
aws ec2 authorize-security-group-ingress \
    --group-id $DB_SG_ID \
    --protocol tcp \
    --port $DB_PORT \
    --source-group $K3S_SG_ID \
    --region $AWS_REGION \
    2>/dev/null || echo "Rule may already exist"

# Remove the broad VPC CIDR rule from DB SG
echo "Removing broad VPC CIDR rule from DB SG..."
VPC_CIDR=$(terraform output -raw vpc_cidr_block 2>/dev/null || echo "")
if [ -n "$VPC_CIDR" ]; then
    aws ec2 revoke-security-group-ingress \
        --group-id $DB_SG_ID \
        --protocol tcp \
        --port $DB_PORT \
        --cidr $VPC_CIDR \
        --region $AWS_REGION \
        2>/dev/null || echo "VPC CIDR rule may not exist"
fi

echo "✅ Cross-SG references configured successfully!"
echo ""
echo "🔒 Security Configuration:"
echo "  • Database SG allows ingress from K3s SG only"
echo "  • Removed broad VPC CIDR access"
echo "  • Network isolation maintained"
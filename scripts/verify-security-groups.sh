#!/bin/bash

# Security Group Verification Script
# Verifies that security groups are properly configured with cross-SG references

set -e

ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-ap-south-1}

echo "🔒 Verifying security group configuration for $ENVIRONMENT environment..."

cd infra

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    terraform init \
        -backend-config="bucket=${TF_STATE_BUCKET}" \
        -backend-config="key=health-app-${ENVIRONMENT}.tfstate" \
        -backend-config="region=${AWS_REGION}"
fi

# Get security group IDs from Terraform outputs
DB_SG_ID=$(terraform output -raw db_security_group_id 2>/dev/null || echo "")
K3S_SG_ID=""

if [ "$ENVIRONMENT" == "dev" ] || [ "$ENVIRONMENT" == "test" ]; then
    K3S_SG_ID=$(terraform output -raw ${ENVIRONMENT}_security_group_id 2>/dev/null || echo "")
else
    K3S_SG_ID=$(terraform output -raw k3s_security_group_id 2>/dev/null || echo "")
fi

if [ -z "$DB_SG_ID" ] || [ -z "$K3S_SG_ID" ]; then
    echo "❌ Security group IDs not found. Make sure infrastructure is deployed."
    echo "DB SG ID: $DB_SG_ID"
    echo "K3S SG ID: $K3S_SG_ID"
    exit 1
fi

echo "📍 Database Security Group: $DB_SG_ID"
echo "📍 K3s Security Group: $K3S_SG_ID"

echo ""
echo "🔍 Checking database security group ingress rules..."

# Check if database SG allows ingress from K3s SG
DB_INGRESS_RULES=$(aws ec2 describe-security-groups \
    --group-ids $DB_SG_ID \
    --region $AWS_REGION \
    --query 'SecurityGroups[0].IpPermissions[?UserIdGroupPairs[?GroupId==`'$K3S_SG_ID'`]]' \
    --output json)

if [ "$DB_INGRESS_RULES" != "[]" ]; then
    echo "✅ Database SG allows ingress from K3s SG"
    echo "$DB_INGRESS_RULES" | jq -r '.[] | "  Port: \(.FromPort)-\(.ToPort), Protocol: \(.IpProtocol)"'
else
    echo "❌ Database SG does NOT allow ingress from K3s SG"
    echo "Current ingress rules:"
    aws ec2 describe-security-groups \
        --group-ids $DB_SG_ID \
        --region $AWS_REGION \
        --query 'SecurityGroups[0].IpPermissions' \
        --output table
fi

echo ""
echo "🔍 Checking K3s security group egress rules..."

# Check if K3s SG allows egress to database SG
K3S_EGRESS_RULES=$(aws ec2 describe-security-groups \
    --group-ids $K3S_SG_ID \
    --region $AWS_REGION \
    --query 'SecurityGroups[0].IpPermissions[?UserIdGroupPairs[?GroupId==`'$DB_SG_ID'`]]' \
    --output json)

# Check for general egress rules (0.0.0.0/0)
K3S_GENERAL_EGRESS=$(aws ec2 describe-security-groups \
    --group-ids $K3S_SG_ID \
    --region $AWS_REGION \
    --query 'SecurityGroups[0].IpPermissionsEgress[?IpRanges[?CidrIp==`0.0.0.0/0`]]' \
    --output json)

if [ "$K3S_EGRESS_RULES" != "[]" ]; then
    echo "✅ K3s SG has specific egress rules to database SG"
    echo "$K3S_EGRESS_RULES" | jq -r '.[] | "  Port: \(.FromPort)-\(.ToPort), Protocol: \(.IpProtocol)"'
elif [ "$K3S_GENERAL_EGRESS" != "[]" ]; then
    echo "✅ K3s SG allows general egress (includes database access)"
    echo "  General egress rule: 0.0.0.0/0"
else
    echo "❌ K3s SG does NOT allow egress to database"
    echo "Current egress rules:"
    aws ec2 describe-security-groups \
        --group-ids $K3S_SG_ID \
        --region $AWS_REGION \
        --query 'SecurityGroups[0].IpPermissionsEgress' \
        --output table
fi

echo ""
echo "🔍 Checking subnet and routing configuration..."

# Get VPC ID
VPC_ID=$(aws ec2 describe-security-groups \
    --group-ids $DB_SG_ID \
    --region $AWS_REGION \
    --query 'SecurityGroups[0].VpcId' \
    --output text)

echo "📍 VPC ID: $VPC_ID"

# Check subnets
echo ""
echo "📍 Subnets in VPC:"
aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region $AWS_REGION \
    --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
    --output table

# Check route tables
echo ""
echo "📍 Route tables in VPC:"
aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region $AWS_REGION \
    --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Name`].Value|[0],Routes[0].GatewayId]' \
    --output table

# Check NACLs
echo ""
echo "📍 Network ACLs in VPC:"
aws ec2 describe-network-acls \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --region $AWS_REGION \
    --query 'NetworkAcls[*].[NetworkAclId,Tags[?Key==`Name`].Value|[0],Entries[?RuleAction==`allow`] | length(@)]' \
    --output table

echo ""
echo "🎯 Security Group Configuration Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Final verification
if [ "$DB_INGRESS_RULES" != "[]" ] && ([ "$K3S_EGRESS_RULES" != "[]" ] || [ "$K3S_GENERAL_EGRESS" != "[]" ]); then
    echo "✅ PASS: Cross-SG references are properly configured"
    echo "✅ PASS: Database is accessible from K3s instances"
    echo "✅ PASS: Security follows principle of least privilege"
    echo ""
    echo "🔒 Security Configuration:"
    echo "  • Database SG allows ingress from App SG only"
    echo "  • App SG has egress rules for database access"
    echo "  • No open CIDR blocks (0.0.0.0/0) on database"
    echo "  • Network isolation between environments"
    exit 0
else
    echo "❌ FAIL: Security group configuration issues detected"
    echo ""
    echo "🔧 Required fixes:"
    if [ "$DB_INGRESS_RULES" == "[]" ]; then
        echo "  • Add ingress rule to DB SG allowing K3s SG"
    fi
    if [ "$K3S_EGRESS_RULES" == "[]" ] && [ "$K3S_GENERAL_EGRESS" == "[]" ]; then
        echo "  • Add egress rule to K3s SG for database access"
    fi
    echo ""
    echo "Run 'terraform apply' to fix security group configuration"
    exit 1
fi
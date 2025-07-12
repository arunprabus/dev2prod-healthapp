#!/bin/bash

# Deployment Diagnostic Script
# Usage: ./diagnose-deployment.sh <network_tier>

NETWORK_TIER=${1:-lower}

echo "🔍 Deployment Diagnostic for $NETWORK_TIER network"
echo "Date: $(date)"
echo ""

# Check all EC2 instances
echo "=== EC2 Instances ==="
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running,stopped,stopping" \
    --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,State.Name,PublicIpAddress,PrivateIpAddress]' \
    --output table

echo ""
echo "=== EC2 Instances for $NETWORK_TIER network ==="
aws ec2 describe-instances --filters "Name=tag:NetworkTier,Values=$NETWORK_TIER" "Name=instance-state-name,Values=running,stopped,stopping" \
    --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,State.Name,PublicIpAddress,PrivateIpAddress]' \
    --output table

# Check RDS instances
echo ""
echo "=== RDS Instances ==="
aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address,Engine]' --output table

# Check Security Groups
echo ""
echo "=== Security Groups for $NETWORK_TIER ==="
aws ec2 describe-security-groups --filters "Name=tag:NetworkTier,Values=$NETWORK_TIER" \
    --query 'SecurityGroups[].[GroupName,GroupId,Description]' --output table

# Check Key Pairs
echo ""
echo "=== Key Pairs ==="
aws ec2 describe-key-pairs --query 'KeyPairs[].[KeyName,KeyFingerprint]' --output table

# Check Terraform state
echo ""
echo "=== Terraform State Check ==="
if [ -f "../infra/two-network-setup/.terraform/terraform.tfstate" ]; then
    echo "Local state file exists"
else
    echo "No local state file found"
fi

# Check S3 state
echo ""
echo "=== S3 State Files ==="
aws s3 ls s3://health-app-terraform-state/ | grep tfstate || echo "No state files in S3"

# Check for specific resources that should exist
echo ""
echo "=== Expected Resources Check ==="

# K3s cluster
K3S_INSTANCE=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=health-app-$NETWORK_TIER-k3s-node" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null)

if [ "$K3S_INSTANCE" != "None" ] && [ -n "$K3S_INSTANCE" ]; then
    echo "✅ K3s cluster found: $K3S_INSTANCE"
    
    # Get K3s IP
    K3S_IP=$(aws ec2 describe-instances --instance-ids $K3S_INSTANCE \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
    echo "   Public IP: $K3S_IP"
    
    # Test SSH connectivity
    if timeout 5 nc -z $K3S_IP 22 2>/dev/null; then
        echo "   SSH port: ✅ Open"
    else
        echo "   SSH port: ❌ Closed/Unreachable"
    fi
    
    # Test K3s API
    if timeout 5 nc -z $K3S_IP 6443 2>/dev/null; then
        echo "   K3s API port: ✅ Open"
    else
        echo "   K3s API port: ❌ Closed/Unreachable"
    fi
else
    echo "❌ K3s cluster not found"
fi

# GitHub Runner
RUNNER_INSTANCE=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=health-app-runner-$NETWORK_TIER" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null)

if [ "$RUNNER_INSTANCE" != "None" ] && [ -n "$RUNNER_INSTANCE" ]; then
    echo "✅ GitHub Runner found: $RUNNER_INSTANCE"
else
    echo "❌ GitHub Runner not found"
fi

# RDS Database
RDS_INSTANCE=$(aws rds describe-db-instances --db-instance-identifier "health-app-$NETWORK_TIER-db" \
    --query 'DBInstances[0].DBInstanceIdentifier' --output text 2>/dev/null)

if [ "$RDS_INSTANCE" != "None" ] && [ -n "$RDS_INSTANCE" ]; then
    echo "✅ RDS Database found: $RDS_INSTANCE"
    
    RDS_STATUS=$(aws rds describe-db-instances --db-instance-identifier "health-app-$NETWORK_TIER-db" \
        --query 'DBInstances[0].DBInstanceStatus' --output text 2>/dev/null)
    echo "   Status: $RDS_STATUS"
    
    RDS_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier "health-app-$NETWORK_TIER-db" \
        --query 'DBInstances[0].Endpoint.Address' --output text 2>/dev/null)
    echo "   Endpoint: $RDS_ENDPOINT"
else
    echo "❌ RDS Database not found"
fi

echo ""
echo "=== Troubleshooting Suggestions ==="

if [ "$K3S_INSTANCE" = "None" ] || [ -z "$K3S_INSTANCE" ]; then
    echo "🔧 K3s cluster missing:"
    echo "   1. Check if infrastructure deployment completed successfully"
    echo "   2. Check Terraform state: terraform state list"
    echo "   3. Re-run: Actions → Core Infrastructure → deploy → lower"
fi

if [ "$RDS_INSTANCE" = "None" ] || [ -z "$RDS_INSTANCE" ]; then
    echo "🔧 RDS database missing:"
    echo "   1. Check if RDS deployment failed due to subnet group issues"
    echo "   2. Check AWS console for RDS creation errors"
    echo "   3. Verify DB subnet group exists"
fi

if [ "$RUNNER_INSTANCE" = "None" ] || [ -z "$RUNNER_INSTANCE" ]; then
    echo "🔧 GitHub Runner missing:"
    echo "   1. Check if runner deployment failed"
    echo "   2. Verify GitHub PAT token is valid"
    echo "   3. Check runner registration in GitHub repo settings"
fi

echo ""
echo "🔍 Diagnostic completed for $NETWORK_TIER network"
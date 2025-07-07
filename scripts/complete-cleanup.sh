#!/bin/bash

# Complete AWS Resource Cleanup Script
# Removes ALL resources created by the health app infrastructure

set -e

REGION=${1:-"ap-south-1"}
FORCE=${2:-false}

echo "🧹 Complete AWS Resource Cleanup"
echo "Region: $REGION"
echo "Force mode: $FORCE"

if [ "$FORCE" != "true" ]; then
    echo "⚠️  This will DELETE ALL health app resources in $REGION"
    echo "Type 'DELETE_ALL' to confirm:"
    read -r confirmation
    if [ "$confirmation" != "DELETE_ALL" ]; then
        echo "❌ Cleanup cancelled"
        exit 1
    fi
fi

echo "🔍 Finding and cleaning up resources..."

# Function to safely delete resources
safe_delete() {
    local resource_type=$1
    local resource_id=$2
    local delete_command=$3
    
    echo "🗑️  Deleting $resource_type: $resource_id"
    if eval "$delete_command" 2>/dev/null; then
        echo "✅ Deleted $resource_type: $resource_id"
    else
        echo "⚠️  Failed to delete $resource_type: $resource_id (may not exist)"
    fi
}

# 1. Terminate EC2 instances
echo "🖥️  Terminating EC2 instances..."
INSTANCES=$(aws ec2 describe-instances \
    --region $REGION \
    --filters "Name=tag:Project,Values=Learning" "Name=instance-state-name,Values=running,stopped,stopping" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text 2>/dev/null || echo "")

if [ -n "$INSTANCES" ]; then
    for instance in $INSTANCES; do
        safe_delete "EC2 Instance" "$instance" "aws ec2 terminate-instances --region $REGION --instance-ids $instance"
    done
    
    echo "⏳ Waiting for instances to terminate..."
    for instance in $INSTANCES; do
        aws ec2 wait instance-terminated --region $REGION --instance-ids $instance 2>/dev/null || true
    done
fi

# 2. Delete RDS instances
echo "🗄️  Deleting RDS instances..."
RDS_INSTANCES=$(aws rds describe-db-instances \
    --region $REGION \
    --query "DBInstances[?contains(DBInstanceIdentifier, 'dev-') || contains(DBInstanceIdentifier, 'test-') || contains(DBInstanceIdentifier, 'prod-') || contains(DBInstanceIdentifier, 'monitoring-')].DBInstanceIdentifier" \
    --output text 2>/dev/null || echo "")

if [ -n "$RDS_INSTANCES" ]; then
    for db in $RDS_INSTANCES; do
        safe_delete "RDS Instance" "$db" "aws rds delete-db-instance --region $REGION --db-instance-identifier $db --skip-final-snapshot --delete-automated-backups"
    done
    
    echo "⏳ Waiting for RDS instances to delete..."
    for db in $RDS_INSTANCES; do
        aws rds wait db-instance-deleted --region $REGION --db-instance-identifier $db 2>/dev/null || true
    done
fi

# 3. Delete DB subnet groups
echo "🌐 Deleting DB subnet groups..."
DB_SUBNET_GROUPS=$(aws rds describe-db-subnet-groups \
    --region $REGION \
    --query "DBSubnetGroups[?contains(DBSubnetGroupName, 'dev-') || contains(DBSubnetGroupName, 'test-') || contains(DBSubnetGroupName, 'prod-') || contains(DBSubnetGroupName, 'monitoring-')].DBSubnetGroupName" \
    --output text 2>/dev/null || echo "")

if [ -n "$DB_SUBNET_GROUPS" ]; then
    for group in $DB_SUBNET_GROUPS; do
        safe_delete "DB Subnet Group" "$group" "aws rds delete-db-subnet-group --region $REGION --db-subnet-group-name $group"
    done
fi

# 4. Delete key pairs
echo "🔑 Deleting key pairs..."
KEY_PAIRS=$(aws ec2 describe-key-pairs \
    --region $REGION \
    --query "KeyPairs[?contains(KeyName, 'dev-') || contains(KeyName, 'test-') || contains(KeyName, 'prod-') || contains(KeyName, 'monitoring-')].KeyName" \
    --output text 2>/dev/null || echo "")

if [ -n "$KEY_PAIRS" ]; then
    for key in $KEY_PAIRS; do
        safe_delete "Key Pair" "$key" "aws ec2 delete-key-pair --region $REGION --key-name $key"
    done
fi

# 5. Delete security groups (after instances are terminated)
echo "🛡️  Deleting security groups..."
sleep 30  # Wait for instances to fully terminate

SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --region $REGION \
    --filters "Name=tag:Project,Values=Learning" \
    --query "SecurityGroups[?GroupName != 'default'].GroupId" \
    --output text 2>/dev/null || echo "")

if [ -n "$SECURITY_GROUPS" ]; then
    for sg in $SECURITY_GROUPS; do
        safe_delete "Security Group" "$sg" "aws ec2 delete-security-group --region $REGION --group-id $sg"
    done
fi

# 6. Delete subnets
echo "🌐 Deleting subnets..."
SUBNETS=$(aws ec2 describe-subnets \
    --region $REGION \
    --filters "Name=tag:Project,Values=Learning" \
    --query "Subnets[].SubnetId" \
    --output text 2>/dev/null || echo "")

if [ -n "$SUBNETS" ]; then
    for subnet in $SUBNETS; do
        safe_delete "Subnet" "$subnet" "aws ec2 delete-subnet --region $REGION --subnet-id $subnet"
    done
fi

# 7. Delete Lambda functions
echo "⚡ Deleting Lambda functions..."
LAMBDA_FUNCTIONS=$(aws lambda list-functions \
    --region $REGION \
    --query "Functions[?contains(FunctionName, 'health-app')].FunctionName" \
    --output text 2>/dev/null || echo "")

if [ -n "$LAMBDA_FUNCTIONS" ]; then
    for func in $LAMBDA_FUNCTIONS; do
        safe_delete "Lambda Function" "$func" "aws lambda delete-function --region $REGION --function-name $func"
    done
fi

# 8. Delete CloudWatch Log Groups
echo "📊 Deleting CloudWatch Log Groups..."
LOG_GROUPS=$(aws logs describe-log-groups \
    --region $REGION \
    --query "logGroups[?contains(logGroupName, 'health-app') || contains(logGroupName, '/aws/lambda/health-app')].logGroupName" \
    --output text 2>/dev/null || echo "")

if [ -n "$LOG_GROUPS" ]; then
    for log_group in $LOG_GROUPS; do
        safe_delete "Log Group" "$log_group" "aws logs delete-log-group --region $REGION --log-group-name $log_group"
    done
fi

# 9. Delete SSM Parameters
echo "🔧 Deleting SSM Parameters..."
SSM_PARAMS=$(aws ssm describe-parameters \
    --region $REGION \
    --query "Parameters[?contains(Name, 'health-app')].Name" \
    --output text 2>/dev/null || echo "")

if [ -n "$SSM_PARAMS" ]; then
    for param in $SSM_PARAMS; do
        safe_delete "SSM Parameter" "$param" "aws ssm delete-parameter --region $REGION --name $param"
    done
fi

# 10. Clean up Terraform state files (if accessible)
echo "🗂️  Cleaning up Terraform state..."
if aws s3 ls s3://health-app-terraform-state/ 2>/dev/null; then
    echo "📦 Found Terraform state bucket, cleaning up state files..."
    aws s3 rm s3://health-app-terraform-state/ --recursive --exclude "*" --include "*health-app*" 2>/dev/null || true
fi

echo ""
echo "✅ Complete cleanup finished!"
echo "💰 All resources should now be deleted - cost should return to $0"
echo ""
echo "🔍 Verification commands:"
echo "aws ec2 describe-instances --region $REGION --query 'Reservations[].Instances[?State.Name!=\`terminated\`].[InstanceId,State.Name]'"
echo "aws rds describe-db-instances --region $REGION --query 'DBInstances[].DBInstanceIdentifier'"
echo "aws ec2 describe-security-groups --region $REGION --filters 'Name=tag:Project,Values=Learning' --query 'SecurityGroups[].GroupId'"
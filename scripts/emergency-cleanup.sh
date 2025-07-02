#!/bin/bash

# Emergency Infrastructure Cleanup Script
set -e

ENVIRONMENT=${1:-"lower"}
FORCE=${2:-"false"}

echo "🚨 Emergency Infrastructure Cleanup"
echo "Environment: $ENVIRONMENT"
echo "Force cleanup: $FORCE"

if [[ "$FORCE" != "true" ]]; then
    echo "⚠️  This will destroy ALL resources in $ENVIRONMENT environment!"
    read -p "Type 'DESTROY' to confirm: " confirm
    if [[ "$confirm" != "DESTROY" ]]; then
        echo "❌ Cleanup cancelled"
        exit 1
    fi
fi

echo "🧹 Starting emergency cleanup..."

# Terraform cleanup
if [[ -d "infra" ]]; then
    cd infra
    
    # Initialize terraform
    terraform init \
        -backend-config="bucket=${TF_STATE_BUCKET:-health-app-terraform-state}" \
        -backend-config="key=health-app-$ENVIRONMENT.tfstate" \
        -backend-config="region=${AWS_REGION:-ap-south-1}" || true
    
    # Destroy resources
    terraform destroy \
        -var-file="environments/$ENVIRONMENT.tfvars" \
        -var="ssh_public_key=${SSH_PUBLIC_KEY:-dummy}" \
        -auto-approve || echo "Terraform destroy completed with errors"
    
    cd ..
fi

# Manual AWS resource cleanup
echo "🔍 Checking for remaining AWS resources..."

# Find and terminate EC2 instances
INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:Environment,Values=$ENVIRONMENT" "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || echo "")

if [[ -n "$INSTANCES" ]]; then
    echo "🛑 Terminating EC2 instances: $INSTANCES"
    aws ec2 terminate-instances --instance-ids $INSTANCES || true
fi

# Delete RDS instances
RDS_INSTANCES=$(aws rds describe-db-instances \
    --query "DBInstances[?contains(DBInstanceIdentifier, 'health-app-$ENVIRONMENT') || contains(DBInstanceIdentifier, '$ENVIRONMENT')].DBInstanceIdentifier" \
    --output text 2>/dev/null || echo "")

if [[ -n "$RDS_INSTANCES" ]]; then
    for db in $RDS_INSTANCES; do
        echo "🗄️ Deleting RDS instance: $db"
        aws rds delete-db-instance \
            --db-instance-identifier "$db" \
            --skip-final-snapshot \
            --delete-automated-backups || true
    done
fi

# Delete VPCs (will fail if resources still attached)
VPCS=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
    --query 'Vpcs[?IsDefault==`false`].VpcId' --output text 2>/dev/null || echo "")

if [[ -n "$VPCS" ]]; then
    for vpc in $VPCS; do
        echo "🌐 Attempting to delete VPC: $vpc"
        aws ec2 delete-vpc --vpc-id "$vpc" 2>/dev/null || echo "VPC $vpc still has dependencies"
    done
fi

# Delete security groups
SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --filters "Name=tag:Environment,Values=$ENVIRONMENT" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")

if [[ -n "$SECURITY_GROUPS" ]]; then
    for sg in $SECURITY_GROUPS; do
        echo "🔒 Deleting security group: $sg"
        aws ec2 delete-security-group --group-id "$sg" 2>/dev/null || true
    done
fi

# Delete Lambda functions
LAMBDA_FUNCTIONS=$(aws lambda list-functions \
    --query "Functions[?contains(FunctionName, 'health-app-$ENVIRONMENT')].FunctionName" \
    --output text 2>/dev/null || echo "")

if [[ -n "$LAMBDA_FUNCTIONS" ]]; then
    for func in $LAMBDA_FUNCTIONS; do
        echo "🤖 Deleting Lambda function: $func"
        aws lambda delete-function --function-name "$func" || true
    done
fi

# Delete CloudWatch log groups
LOG_GROUPS=$(aws logs describe-log-groups \
    --log-group-name-prefix "/aws/health-app/$ENVIRONMENT" \
    --query 'logGroups[].logGroupName' --output text 2>/dev/null || echo "")

if [[ -n "$LOG_GROUPS" ]]; then
    for log_group in $LOG_GROUPS; do
        echo "📊 Deleting log group: $log_group"
        aws logs delete-log-group --log-group-name "$log_group" || true
    done
fi

# Delete SSM parameters
SSM_PARAMS=$(aws ssm get-parameters-by-path \
    --path "/health-app/$ENVIRONMENT" \
    --query 'Parameters[].Name' --output text 2>/dev/null || echo "")

if [[ -n "$SSM_PARAMS" ]]; then
    for param in $SSM_PARAMS; do
        echo "🔧 Deleting SSM parameter: $param"
        aws ssm delete-parameter --name "$param" || true
    done
fi

echo ""
echo "✅ Emergency cleanup completed for $ENVIRONMENT environment"
echo "⚠️  Some resources may take time to fully terminate"
echo "💡 Run this script again in 5-10 minutes if needed"
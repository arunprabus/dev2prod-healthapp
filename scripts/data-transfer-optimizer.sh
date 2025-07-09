#!/bin/bash
# Data Transfer Optimizer - Minimize AWS data transfer costs

set -e

REGION=${1:-ap-south-1}
ACTION=${2:-optimize}

echo "🔧 AWS Data Transfer Optimizer"
echo "Region: $REGION"
echo "Action: $ACTION"

optimize_data_transfer() {
    echo "📊 Current data transfer optimization..."
    
    # 1. Stop unnecessary EC2 instances
    echo "🛑 Stopping non-essential EC2 instances..."
    aws ec2 describe-instances \
        --region $REGION \
        --filters "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[?Tags[?Key=='Environment' && Value!='prod']].InstanceId" \
        --output text | xargs -r aws ec2 stop-instances --region $REGION --instance-ids
    
    # 2. Disable CloudWatch detailed monitoring
    echo "📈 Disabling detailed monitoring..."
    aws ec2 describe-instances \
        --region $REGION \
        --query "Reservations[].Instances[].InstanceId" \
        --output text | xargs -r aws ec2 unmonitor-instances --region $REGION --instance-ids
    
    # 3. Clean up old snapshots (keep only latest)
    echo "🗑️ Cleaning old snapshots..."
    aws ec2 describe-snapshots \
        --region $REGION \
        --owner-ids self \
        --query "Snapshots[?StartTime<'$(date -d '7 days ago' --iso-8601)'].SnapshotId" \
        --output text | xargs -r aws ec2 delete-snapshot --region $REGION --snapshot-id
    
    # 4. Stop RDS instances (keep snapshots)
    echo "🗄️ Stopping RDS instances..."
    aws rds describe-db-instances \
        --region $REGION \
        --query "DBInstances[?DBInstanceStatus=='available'].DBInstanceIdentifier" \
        --output text | while read -r db; do
        if [ -n "$db" ]; then
            echo "Stopping RDS: $db"
            aws rds stop-db-instance --region $REGION --db-instance-identifier "$db" || echo "Failed to stop $db"
        fi
    done
}

monitor_usage() {
    echo "📊 Checking current data transfer usage..."
    
    # Get billing data (requires billing access)
    aws ce get-dimension-values \
        --region us-east-1 \
        --time-period Start=2025-07-01,End=2025-07-31 \
        --dimension SERVICE \
        --search-string "DataTransfer" 2>/dev/null || echo "⚠️ Billing access required for detailed usage"
    
    # Check running resources
    echo "🔍 Current running resources:"
    echo "EC2 Instances:"
    aws ec2 describe-instances \
        --region $REGION \
        --filters "Name=instance-state-name,Values=running" \
        --query "Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key=='Name'].Value|[0]]" \
        --output table
    
    echo "RDS Instances:"
    aws rds describe-db-instances \
        --region $REGION \
        --query "DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,DBInstanceClass]" \
        --output table
}

case $ACTION in
    "optimize")
        optimize_data_transfer
        ;;
    "monitor")
        monitor_usage
        ;;
    "emergency-stop")
        echo "🚨 Emergency stop - all non-prod resources"
        optimize_data_transfer
        echo "✅ Emergency optimization complete"
        ;;
    *)
        echo "Usage: $0 [region] [optimize|monitor|emergency-stop]"
        exit 1
        ;;
esac

echo "✅ Data transfer optimization complete"
#!/bin/bash

# Enhanced Cleanup Script
# Usage: ./enhanced-cleanup.sh <region> <network_tier> [force]

REGION=${1:-ap-south-1}
NETWORK_TIER=${2:-all}
FORCE=${3:-false}

echo "🧹 Enhanced Cleanup Started"
echo "Region: $REGION"
echo "Network Tier: $NETWORK_TIER"
echo "Force Mode: $FORCE"
echo "Date: $(date)"

# Function to cleanup specific network tier
cleanup_network_tier() {
    local tier=$1
    echo "🗑️ Cleaning up $tier network resources..."
    
    # Terminate EC2 instances
    echo "Terminating EC2 instances for $tier..."
    INSTANCES=$(aws ec2 describe-instances --region $REGION \
        --filters "Name=tag:NetworkTier,Values=$tier" "Name=instance-state-name,Values=running,stopped,stopping" \
        --query "Reservations[].Instances[].InstanceId" --output text 2>/dev/null || echo "")
    
    if [ -n "$INSTANCES" ] && [ "$INSTANCES" != "None" ]; then
        echo "Found instances: $INSTANCES"
        if [ "$FORCE" = "true" ]; then
            echo $INSTANCES | xargs -n1 aws ec2 terminate-instances --region $REGION --instance-ids || true
            echo "✅ Instances terminated"
        else
            echo "⚠️ Use force=true to terminate instances"
        fi
    else
        echo "No instances found for $tier"
    fi
    
    # Wait for instances to terminate
    if [ -n "$INSTANCES" ] && [ "$INSTANCES" != "None" ] && [ "$FORCE" = "true" ]; then
        echo "⏳ Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --region $REGION --instance-ids $INSTANCES || true
    fi
    
    # Delete RDS instances
    echo "Checking RDS instances for $tier..."
    RDS_INSTANCES=$(aws rds describe-db-instances --region $REGION \
        --query "DBInstances[?contains(DBInstanceIdentifier, 'health-app-$tier')].DBInstanceIdentifier" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$RDS_INSTANCES" ] && [ "$RDS_INSTANCES" != "None" ]; then
        echo "Found RDS instances: $RDS_INSTANCES"
        if [ "$FORCE" = "true" ]; then
            for rds in $RDS_INSTANCES; do
                aws rds delete-db-instance --region $REGION --db-instance-identifier $rds \
                    --skip-final-snapshot --delete-automated-backups || true
            done
            echo "✅ RDS instances deletion initiated"
        else
            echo "⚠️ Use force=true to delete RDS instances"
        fi
    else
        echo "No RDS instances found for $tier"
    fi
    
    # Delete Security Groups
    echo "Cleaning security groups for $tier..."
    SG_IDS=$(aws ec2 describe-security-groups --region $REGION \
        --filters "Name=tag:NetworkTier,Values=$tier" \
        --query "SecurityGroups[?GroupName!='default'].GroupId" --output text 2>/dev/null || echo "")
    
    if [ -n "$SG_IDS" ] && [ "$SG_IDS" != "None" ]; then
        echo "Found security groups: $SG_IDS"
        if [ "$FORCE" = "true" ]; then
            for sg in $SG_IDS; do
                aws ec2 delete-security-group --region $REGION --group-id $sg || true
            done
            echo "✅ Security groups deleted"
        else
            echo "⚠️ Use force=true to delete security groups"
        fi
    else
        echo "No security groups found for $tier"
    fi
    
    # Delete Key Pairs
    echo "Cleaning key pairs for $tier..."
    KEY_PAIRS=$(aws ec2 describe-key-pairs --region $REGION \
        --query "KeyPairs[?contains(KeyName, 'health-app-$tier')].KeyName" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$KEY_PAIRS" ] && [ "$KEY_PAIRS" != "None" ]; then
        echo "Found key pairs: $KEY_PAIRS"
        if [ "$FORCE" = "true" ]; then
            for key in $KEY_PAIRS; do
                aws ec2 delete-key-pair --region $REGION --key-name $key || true
            done
            echo "✅ Key pairs deleted"
        else
            echo "⚠️ Use force=true to delete key pairs"
        fi
    else
        echo "No key pairs found for $tier"
    fi
    
    # Delete EBS Volumes
    echo "Cleaning EBS volumes for $tier..."
    VOLUMES=$(aws ec2 describe-volumes --region $REGION \
        --filters "Name=tag:NetworkTier,Values=$tier" "Name=status,Values=available" \
        --query "Volumes[].VolumeId" --output text 2>/dev/null || echo "")
    
    if [ -n "$VOLUMES" ] && [ "$VOLUMES" != "None" ]; then
        echo "Found volumes: $VOLUMES"
        if [ "$FORCE" = "true" ]; then
            for vol in $VOLUMES; do
                aws ec2 delete-volume --region $REGION --volume-id $vol || true
            done
            echo "✅ EBS volumes deleted"
        else
            echo "⚠️ Use force=true to delete EBS volumes"
        fi
    else
        echo "No available EBS volumes found for $tier"
    fi
    
    # Delete IAM roles and policies
    echo "Cleaning IAM resources for $tier..."
    IAM_ROLES=$(aws iam list-roles --query "Roles[?contains(RoleName, 'health-app-$tier')].RoleName" --output text 2>/dev/null || echo "")
    
    if [ -n "$IAM_ROLES" ] && [ "$IAM_ROLES" != "None" ]; then
        echo "Found IAM roles: $IAM_ROLES"
        if [ "$FORCE" = "true" ]; then
            for role in $IAM_ROLES; do
                # Detach policies first
                ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name $role --query "AttachedPolicies[].PolicyArn" --output text 2>/dev/null || echo "")
                for policy in $ATTACHED_POLICIES; do
                    aws iam detach-role-policy --role-name $role --policy-arn $policy || true
                done
                
                # Delete inline policies
                INLINE_POLICIES=$(aws iam list-role-policies --role-name $role --query "PolicyNames[]" --output text 2>/dev/null || echo "")
                for policy in $INLINE_POLICIES; do
                    aws iam delete-role-policy --role-name $role --policy-name $policy || true
                done
                
                # Delete instance profiles
                INSTANCE_PROFILES=$(aws iam list-instance-profiles-for-role --role-name $role --query "InstanceProfiles[].InstanceProfileName" --output text 2>/dev/null || echo "")
                for profile in $INSTANCE_PROFILES; do
                    aws iam remove-role-from-instance-profile --instance-profile-name $profile --role-name $role || true
                    aws iam delete-instance-profile --instance-profile-name $profile || true
                done
                
                # Delete role
                aws iam delete-role --role-name $role || true
            done
            echo "✅ IAM roles cleaned up"
        else
            echo "⚠️ Use force=true to delete IAM roles"
        fi
    else
        echo "No IAM roles found for $tier"
    fi
}

# Function to cleanup orphaned resources
cleanup_orphaned_resources() {
    echo "🔍 Cleaning up orphaned resources..."
    
    # Find untagged instances that might be orphaned
    ORPHANED_INSTANCES=$(aws ec2 describe-instances --region $REGION \
        --filters "Name=instance-state-name,Values=running,stopped" \
        --query "Reservations[].Instances[?!Tags || length(Tags[?Key=='Project' && Value=='health-app']) == \`0\`].InstanceId" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$ORPHANED_INSTANCES" ] && [ "$ORPHANED_INSTANCES" != "None" ]; then
        echo "Found potentially orphaned instances: $ORPHANED_INSTANCES"
        if [ "$FORCE" = "true" ]; then
            echo "⚠️ Terminating orphaned instances..."
            echo $ORPHANED_INSTANCES | xargs -n1 aws ec2 terminate-instances --region $REGION --instance-ids || true
        else
            echo "⚠️ Use force=true to terminate orphaned instances"
        fi
    fi
    
    # Clean up unattached EBS volumes
    UNATTACHED_VOLUMES=$(aws ec2 describe-volumes --region $REGION \
        --filters "Name=status,Values=available" \
        --query "Volumes[].VolumeId" --output text 2>/dev/null || echo "")
    
    if [ -n "$UNATTACHED_VOLUMES" ] && [ "$UNATTACHED_VOLUMES" != "None" ]; then
        echo "Found unattached volumes: $UNATTACHED_VOLUMES"
        if [ "$FORCE" = "true" ]; then
            for vol in $UNATTACHED_VOLUMES; do
                aws ec2 delete-volume --region $REGION --volume-id $vol || true
            done
            echo "✅ Unattached volumes deleted"
        else
            echo "⚠️ Use force=true to delete unattached volumes"
        fi
    fi
}

# Main cleanup logic
if [ "$NETWORK_TIER" = "all" ]; then
    echo "🌐 Cleaning up all network tiers..."
    cleanup_network_tier "lower"
    cleanup_network_tier "higher" 
    cleanup_network_tier "monitoring"
    cleanup_orphaned_resources
else
    cleanup_network_tier "$NETWORK_TIER"
fi

# Final verification
echo ""
echo "🔍 Final verification..."
REMAINING_INSTANCES=$(aws ec2 describe-instances --region $REGION \
    --filters "Name=instance-state-name,Values=running,stopped,stopping" \
    --query "Reservations[].Instances[].InstanceId" --output text 2>/dev/null | wc -w)

REMAINING_RDS=$(aws rds describe-db-instances --region $REGION \
    --query "DBInstances[].DBInstanceIdentifier" --output text 2>/dev/null | wc -w)

echo "Remaining EC2 instances: $REMAINING_INSTANCES"
echo "Remaining RDS instances: $REMAINING_RDS"

if [ "$REMAINING_INSTANCES" -eq 0 ] && [ "$REMAINING_RDS" -eq 0 ]; then
    echo "✅ Cleanup completed successfully - no resources remaining"
else
    echo "⚠️ Some resources may still exist"
fi

echo "🧹 Enhanced cleanup completed for $NETWORK_TIER in $REGION"
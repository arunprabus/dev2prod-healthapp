#!/bin/bash

# Resource Prevention Script
# Ensures resources are only created in the specified region

set -e

ALLOWED_REGION=${1:-"ap-south-1"}
ACTION=${2:-"check"}

echo "🛡️ Multi-Region Resource Prevention"
echo "Allowed region: $ALLOWED_REGION"
echo "Action: $ACTION"
echo ""

check_resources_in_other_regions() {
    local found_resources=false
    
    # List of regions to check (excluding allowed region)
    local regions=("us-east-1" "us-east-2" "us-west-1" "us-west-2" "eu-west-1" "eu-central-1" "ap-northeast-1" "ap-southeast-1")
    
    for region in "${regions[@]}"; do
        if [[ "$region" == "$ALLOWED_REGION" ]]; then
            continue
        fi
        
        echo "🔍 Checking region: $region"
        
        # Check for EC2 instances
        local instances=$(aws ec2 describe-instances --region "$region" --filters "Name=instance-state-name,Values=running,stopped" --query 'length(Reservations[].Instances[])' --output text 2>/dev/null || echo "0")
        
        # Check for RDS instances
        local rds_instances=$(aws rds describe-db-instances --region "$region" --query 'length(DBInstances[])' --output text 2>/dev/null || echo "0")
        
        # Check for custom security groups
        local security_groups=$(aws ec2 describe-security-groups --region "$region" --query 'length(SecurityGroups[?GroupName!=`default`])' --output text 2>/dev/null || echo "0")
        
        if [[ "$instances" -gt 0 || "$rds_instances" -gt 0 || "$security_groups" -gt 0 ]]; then
            echo "  ⚠️  Found resources: EC2=$instances, RDS=$rds_instances, SG=$security_groups"
            found_resources=true
            
            if [[ "$ACTION" == "cleanup" ]]; then
                echo "  🧹 Cleaning up resources in $region..."
                
                # Terminate EC2 instances
                if [[ "$instances" -gt 0 ]]; then
                    local instance_ids=$(aws ec2 describe-instances --region "$region" --filters "Name=instance-state-name,Values=running,stopped" --query "Reservations[].Instances[].InstanceId" --output text)
                    for instance_id in $instance_ids; do
                        echo "    Terminating instance: $instance_id"
                        aws ec2 terminate-instances --region "$region" --instance-ids "$instance_id" || true
                    done
                fi
                
                # Delete RDS instances
                if [[ "$rds_instances" -gt 0 ]]; then
                    local rds_ids=$(aws rds describe-db-instances --region "$region" --query "DBInstances[].DBInstanceIdentifier" --output text)
                    for rds_id in $rds_ids; do
                        echo "    Deleting RDS instance: $rds_id"
                        aws rds delete-db-instance --region "$region" --db-instance-identifier "$rds_id" --skip-final-snapshot || true
                    done
                fi
                
                echo "  ✅ Cleanup initiated for $region"
            fi
        else
            echo "  ✅ No resources found"
        fi
    done
    
    if [[ "$found_resources" == true && "$ACTION" == "check" ]]; then
        echo ""
        echo "❌ Resources found in non-allowed regions!"
        echo "💡 Run with 'cleanup' action to remove them:"
        echo "   ./scripts/prevent-multi-region-resources.sh $ALLOWED_REGION cleanup"
        return 1
    elif [[ "$found_resources" == false ]]; then
        echo ""
        echo "✅ No resources found outside allowed region"
        return 0
    fi
}

setup_region_restriction() {
    echo "🔧 Setting up region restriction policies..."
    
    # Create IAM policy to restrict resource creation to specific region
    cat > /tmp/region-restriction-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Deny",
            "Action": [
                "ec2:RunInstances",
                "rds:CreateDBInstance",
                "ec2:CreateSecurityGroup"
            ],
            "Resource": "*",
            "Condition": {
                "StringNotEquals": {
                    "aws:RequestedRegion": "$ALLOWED_REGION"
                }
            }
        }
    ]
}
EOF
    
    echo "📋 Region restriction policy created at /tmp/region-restriction-policy.json"
    echo "💡 Apply this policy to your IAM user/role to prevent multi-region resource creation"
}

case "$ACTION" in
    "check")
        check_resources_in_other_regions
        ;;
    "cleanup")
        check_resources_in_other_regions
        ;;
    "setup-policy")
        setup_region_restriction
        ;;
    *)
        echo "Usage: $0 [region] [check|cleanup|setup-policy]"
        echo "Examples:"
        echo "  $0 ap-south-1 check"
        echo "  $0 ap-south-1 cleanup"
        echo "  $0 ap-south-1 setup-policy"
        exit 1
        ;;
esac
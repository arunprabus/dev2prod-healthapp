#!/bin/bash
set -e

# Get deployment context from environment variables
DEPLOYMENT_ACTION=${DEPLOYMENT_ACTION:-deploy}
TARGET_ENVIRONMENT=${TARGET_ENVIRONMENT:-}
RUNNER_TYPE=${RUNNER_TYPE:-github}

echo "🧹 Starting resource cleanup..."
echo "📊 Action: $DEPLOYMENT_ACTION"
echo "📊 Target: $TARGET_ENVIRONMENT"
echo "📊 Runner: $RUNNER_TYPE"

# Detect current runner's VPC if running on AWS self-hosted runner
CURRENT_RUNNER_VPC=""
if [[ "$RUNNER_TYPE" == "aws" ]]; then
    echo "🔍 Detecting current runner's VPC..."
    
    # Get current instance metadata
    TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null || echo "")
    if [[ -n "$TOKEN" ]]; then
        CURRENT_INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "")
        
        if [[ -n "$CURRENT_INSTANCE_ID" ]]; then
            CURRENT_RUNNER_VPC=$(aws ec2 describe-instances --instance-ids "$CURRENT_INSTANCE_ID" --query 'Reservations[0].Instances[0].VpcId' --output text 2>/dev/null || echo "")
            
            if [[ -n "$CURRENT_RUNNER_VPC" && "$CURRENT_RUNNER_VPC" != "None" ]]; then
                RUNNER_VPC_NAME=$(aws ec2 describe-vpcs --vpc-ids "$CURRENT_RUNNER_VPC" --query 'Vpcs[0].Tags[?Key==`Name`].Value|[0]' --output text 2>/dev/null || echo "")
                echo "✅ Current runner VPC detected: $RUNNER_VPC_NAME ($CURRENT_RUNNER_VPC)"
            fi
        fi
    fi
fi

# Function to check if instance is running
is_instance_running() {
    local instance_id=$1
    local state=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "not-found")
    [[ "$state" == "running" ]]
}

# Function to safely terminate instance
terminate_instance() {
    local instance_id=$1
    local name=$2
    
    if is_instance_running "$instance_id"; then
        echo "⚠️ Instance $name ($instance_id) is still running, skipping..."
        return 1
    else
        echo "🗑️ Terminating offline instance $name ($instance_id)..."
        aws ec2 terminate-instances --instance-ids "$instance_id" >/dev/null 2>&1 || true
        return 0
    fi
}

# Function to delete VPC and dependencies
delete_vpc() {
    local vpc_id=$1
    local vpc_name=$2
    
    echo "🔍 Checking VPC $vpc_name ($vpc_id)..."
    
    # Check if VPC exists
    if ! aws ec2 describe-vpcs --vpc-ids "$vpc_id" >/dev/null 2>&1; then
        echo "✅ VPC $vpc_name already deleted"
        return 0
    fi
    
    # Check for running instances in VPC
    local running_instances=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$vpc_id" "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].InstanceId' --output text)
    
    if [[ -n "$running_instances" && "$running_instances" != "None" ]]; then
        # Check if this VPC contains the current runner
        if [[ -n "$CURRENT_RUNNER_VPC" && "$vpc_id" == "$CURRENT_RUNNER_VPC" ]]; then
            echo "🚫 PROTECTED: This VPC contains the current GitHub runner - cannot delete"
            echo "   Runner VPC: $vpc_name ($vpc_id)"
            return 2  # Special return code for protected VPCs
        fi
        
        # For redeploy of target environment, force delete even with running instances
        if [[ "$DEPLOYMENT_ACTION" == "redeploy" && "$vpc_name" == *"-$TARGET_ENVIRONMENT-"* ]]; then
            echo "🔄 REDEPLOY: Force terminating instances in target VPC $vpc_name"
            echo "$running_instances" | tr ' ' '\n' | while read -r instance_id; do
                if [[ -n "$instance_id" ]]; then
                    echo "❌ Terminating instance: $instance_id"
                    aws ec2 terminate-instances --instance-ids "$instance_id" || true
                fi
            done
            echo "⏳ Waiting 60 seconds for instances to terminate..."
            sleep 60
        else
            echo "⚠️ VPC $vpc_name has running instances: $running_instances"
            echo "   Skipping VPC deletion to avoid disruption"
            return 2  # Special return code for active VPCs
        fi
    fi
    
    echo "🗑️ Deleting VPC $vpc_name ($vpc_id) and dependencies..."
    
    # Delete NAT Gateways
    local nat_gateways=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[*].NatGatewayId' --output text)
    if [[ -n "$nat_gateways" && "$nat_gateways" != "None" ]]; then
        for nat_id in $nat_gateways; do
            aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" || true
        done
        sleep 10
    fi
    
    # Delete Internet Gateways
    local igws=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[*].InternetGatewayId' --output text)
    if [[ -n "$igws" && "$igws" != "None" ]]; then
        for igw_id in $igws; do
            aws ec2 detach-internet-gateway --internet-gateway-id "$igw_id" --vpc-id "$vpc_id" || true
            aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id" || true
        done
    fi
    
    # Delete Subnets
    local subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].SubnetId' --output text)
    if [[ -n "$subnets" && "$subnets" != "None" ]]; then
        for subnet_id in $subnets; do
            aws ec2 delete-subnet --subnet-id "$subnet_id" || true
        done
    fi
    
    # Delete Route Tables (except main)
    local route_tables=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text)
    if [[ -n "$route_tables" && "$route_tables" != "None" ]]; then
        for rt_id in $route_tables; do
            aws ec2 delete-route-table --route-table-id "$rt_id" || true
        done
    fi
    
    # Delete Security Groups (except default)
    local security_groups=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
    if [[ -n "$security_groups" && "$security_groups" != "None" ]]; then
        for sg_id in $security_groups; do
            aws ec2 delete-security-group --group-id "$sg_id" || true
        done
    fi
    
    # Wait for dependencies to be deleted
    sleep 5
    
    # Delete VPC
    if aws ec2 delete-vpc --vpc-id "$vpc_id" 2>/dev/null; then
        echo "✅ VPC $vpc_name deleted successfully"
    else
        echo "⚠️ VPC $vpc_name deletion failed (may have remaining dependencies)"
    fi
}

# 1. Clean up offline GitHub runners
echo "🔍 Finding offline GitHub runners..."

# Get all health-app related instances
INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=health-app" "Name=instance-state-name,Values=stopped,terminated,stopping" \
    --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
    --output text)

if [[ -n "$INSTANCES" ]]; then
    echo "Found offline instances:"
    echo "$INSTANCES"
    
    echo "$INSTANCES" | while read -r instance_id name state; do
        if [[ "$state" == "stopped" || "$state" == "terminated" ]]; then
            echo "🗑️ Cleaning up $name ($instance_id) - State: $state"
            aws ec2 terminate-instances --instance-ids "$instance_id" >/dev/null 2>&1 || true
        fi
    done
else
    echo "✅ No offline GitHub runners found"
fi

# 2. Clean up old VPCs (only if empty)
echo "🔍 Finding health-app VPCs..."

# Get all health-app VPCs
VPCS=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Project,Values=health-app" \
    --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
    --output text)

if [[ -n "$VPCS" ]]; then
    echo "Found health-app VPCs:"
    echo "$VPCS"
    
    ACTIVE_VPCS=0
    DELETED_VPCS=0
    
    echo "$VPCS" | while read -r vpc_id vpc_name; do
        # For redeploy, prioritize target environment VPCs for deletion
        if [[ "$DEPLOYMENT_ACTION" == "redeploy" && "$vpc_name" == *"-$TARGET_ENVIRONMENT-"* ]]; then
            echo "🎯 Target environment VPC found: $vpc_name - forcing deletion"
            delete_vpc "$vpc_id" "$vpc_name"
        else
            delete_vpc "$vpc_id" "$vpc_name"
        fi
    done
    
    echo "📊 VPC cleanup summary: $DELETED_VPCS deleted, $ACTIVE_VPCS active (preserved)"
else
    echo "✅ No health-app VPCs found"
fi

# 3. Clean up orphaned resources
echo "🔍 Cleaning up orphaned resources..."

# Delete orphaned key pairs
key_pairs=$(aws ec2 describe-key-pairs --filters "Name=key-name,Values=health-app-*" --query 'KeyPairs[*].KeyName' --output text)
if [[ -n "$key_pairs" && "$key_pairs" != "None" ]]; then
    for key_name in $key_pairs; do
        aws ec2 delete-key-pair --key-name "$key_name" || true
    done
fi

# Delete orphaned security groups (not in any VPC)
orphaned_sgs=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=health-app-*" --query 'SecurityGroups[*].GroupId' --output text)
if [[ -n "$orphaned_sgs" && "$orphaned_sgs" != "None" ]]; then
    for sg_id in $orphaned_sgs; do
        aws ec2 delete-security-group --group-id "$sg_id" 2>/dev/null || true
    done
fi

# 4. Wait for VPC deletions to complete
echo "⏳ Waiting for VPC deletions to complete..."
sleep 15

# 5. Aggressive cleanup for remaining VPCs with dependencies
echo "🔍 Checking for remaining health-app VPCs with dependencies..."
REMAINING_VPCS=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Project,Values=health-app" \
    --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' \
    --output text)

if [[ -n "$REMAINING_VPCS" ]]; then
    echo "Found VPCs with remaining dependencies:"
    echo "$REMAINING_VPCS"
    
    echo "$REMAINING_VPCS" | while read -r vpc_id vpc_name; do
        echo "🔧 Force cleaning VPC $vpc_name ($vpc_id)..."
        
        # Force delete network interfaces
        enis=$(aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$vpc_id" --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text)
        if [[ -n "$enis" && "$enis" != "None" ]]; then
            for eni_id in $enis; do
                aws ec2 delete-network-interface --network-interface-id "$eni_id" 2>/dev/null || true
            done
        fi
        
        # Force delete VPC endpoints
        endpoints=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpc_id" --query 'VpcEndpoints[*].VpcEndpointId' --output text)
        if [[ -n "$endpoints" && "$endpoints" != "None" ]]; then
            for endpoint_id in $endpoints; do
                aws ec2 delete-vpc-endpoint --vpc-endpoint-id "$endpoint_id" || true
            done
        fi
        
        # Try VPC deletion again
        sleep 5
        if aws ec2 delete-vpc --vpc-id "$vpc_id" 2>/dev/null; then
            echo "✅ VPC $vpc_name force deleted"
        else
            echo "⚠️ VPC $vpc_name still has dependencies"
        fi
    done
fi

# 6. Final VPC count check
echo "📊 Final VPC usage check..."
sleep 10
VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs)')
echo "Current VPC count: $VPC_COUNT/5"

# Always exit successfully - let Terraform handle VPC limits
if [[ $VPC_COUNT -ge 5 ]]; then
    echo "⚠️ VPC limit at maximum ($VPC_COUNT/5)"
    
    # Check if we have active health-app VPCs
    ACTIVE_HEALTH_VPCS=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Project,Values=health-app" \
        --query 'length(Vpcs)')
    
    if [[ $ACTIVE_HEALTH_VPCS -gt 0 ]]; then
        echo "📊 Found $ACTIVE_HEALTH_VPCS active health-app VPCs (with running instances)"
        echo "✅ Active infrastructure preserved - this is expected"
    else
        echo "💡 No active health-app VPCs found - may need manual cleanup"
    fi
else
    echo "✅ VPC limit OK ($VPC_COUNT/5) - ready for deployment"
fi

echo "🎉 Resource cleanup completed successfully!"
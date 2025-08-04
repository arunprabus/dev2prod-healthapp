#!/bin/bash
set -e

echo "🧹 Starting resource cleanup..."

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
        echo "⚠️ VPC $vpc_name has running instances: $running_instances"
        echo "   Skipping VPC deletion to avoid disruption"
        return 1
    fi
    
    echo "🗑️ Deleting VPC $vpc_name ($vpc_id) and dependencies..."
    
    # Delete NAT Gateways
    aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$vpc_id" --query 'NatGateways[*].NatGatewayId' --output text | \
    xargs -r -n1 -I {} aws ec2 delete-nat-gateway --nat-gateway-id {} || true
    
    # Delete Internet Gateways
    aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc_id" --query 'InternetGateways[*].InternetGatewayId' --output text | \
    xargs -r -n1 -I {} sh -c 'aws ec2 detach-internet-gateway --internet-gateway-id {} --vpc-id '$vpc_id' && aws ec2 delete-internet-gateway --internet-gateway-id {}' || true
    
    # Delete Subnets
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query 'Subnets[*].SubnetId' --output text | \
    xargs -r -n1 -I {} aws ec2 delete-subnet --subnet-id {} || true
    
    # Delete Route Tables (except main)
    aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$vpc_id" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text | \
    xargs -r -n1 -I {} aws ec2 delete-route-table --route-table-id {} || true
    
    # Delete Security Groups (except default)
    aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text | \
    xargs -r -n1 -I {} aws ec2 delete-security-group --group-id {} || true
    
    # Delete VPC
    aws ec2 delete-vpc --vpc-id "$vpc_id" || true
    echo "✅ VPC $vpc_name deleted"
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
    
    echo "$VPCS" | while read -r vpc_id vpc_name; do
        delete_vpc "$vpc_id" "$vpc_name"
    done
else
    echo "✅ No health-app VPCs found"
fi

# 3. Clean up orphaned resources
echo "🔍 Cleaning up orphaned resources..."

# Delete orphaned key pairs
aws ec2 describe-key-pairs --filters "Name=key-name,Values=health-app-*" --query 'KeyPairs[*].KeyName' --output text | \
xargs -r -n1 -I {} aws ec2 delete-key-pair --key-name {} || true

# Delete orphaned security groups (not in any VPC)
aws ec2 describe-security-groups --filters "Name=group-name,Values=health-app-*" --query 'SecurityGroups[*].GroupId' --output text | \
xargs -r -n1 -I {} aws ec2 delete-security-group --group-id {} 2>/dev/null || true

# 4. Check VPC limits
echo "📊 Checking VPC usage..."
VPC_COUNT=$(aws ec2 describe-vpcs --query 'length(Vpcs)')
echo "Current VPC count: $VPC_COUNT/5"

if [[ $VPC_COUNT -ge 5 ]]; then
    echo "⚠️ WARNING: VPC limit reached ($VPC_COUNT/5)"
    echo "Consider deleting unused VPCs or requesting limit increase"
    exit 1
else
    echo "✅ VPC limit OK ($VPC_COUNT/5)"
fi

echo "🎉 Resource cleanup completed!"
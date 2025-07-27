#!/bin/bash

# Create K3s Worker Node
# Usage: ./create-worker-node.sh <environment> <master_ip>

set -e

ENV=$1
MASTER_IP=$2

if [ -z "$ENV" ] || [ -z "$MASTER_IP" ]; then
    echo "Usage: $0 <environment> <master_ip>"
    exit 1
fi

echo "🚀 Creating worker node for $ENV environment..."

# Get VPC and subnet info
VPC_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-$ENV-*" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].VpcId' --output text)

SUBNET_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-$ENV-*" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].SubnetId' --output text)

SECURITY_GROUP_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=health-app-$ENV-*" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)

# Get K3s token from master
K3S_TOKEN=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo cat /var/lib/rancher/k3s/server/node-token")

# Create worker user data
cat > /tmp/worker-userdata.sh << EOF
#!/bin/bash
curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$K3S_TOKEN sh -
EOF

# Launch worker instance
WORKER_ID=$(aws ec2 run-instances \
    --image-id ami-0f5ee92e2d63afc18 \
    --instance-type t2.micro \
    --key-name health-app-$ENV-key \
    --security-group-ids $SECURITY_GROUP_ID \
    --subnet-id $SUBNET_ID \
    --user-data file:///tmp/worker-userdata.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=health-app-$ENV-worker},{Key=Environment,Value=$ENV},{Key=Role,Value=worker}]" \
    --query 'Instances[0].InstanceId' --output text)

echo "✅ Worker node created: $WORKER_ID"

# Wait for instance to be running
echo "⏳ Waiting for worker node to be ready..."
aws ec2 wait instance-running --instance-ids $WORKER_ID

WORKER_IP=$(aws ec2 describe-instances \
    --instance-ids $WORKER_ID \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "✅ Worker node ready at: $WORKER_IP"
echo "worker_id=$WORKER_ID" >> $GITHUB_OUTPUT
echo "worker_ip=$WORKER_IP" >> $GITHUB_OUTPUT

rm -f /tmp/worker-userdata.sh
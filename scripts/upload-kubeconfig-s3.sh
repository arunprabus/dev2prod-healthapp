#!/bin/bash

# Upload kubeconfig to S3
# Usage: ./upload-kubeconfig-s3.sh <environment> <cluster-ip> [s3-bucket]

set -e

ENVIRONMENT=${1:-"lower"}
CLUSTER_IP=${2}
S3_BUCKET=${3:-${TF_STATE_BUCKET}}

if [[ -z "$CLUSTER_IP" ]]; then
    echo "Usage: $0 <environment> <cluster-ip> [s3-bucket]"
    echo "Example: $0 lower 1.2.3.4 my-terraform-bucket"
    exit 1
fi

if [[ -z "$S3_BUCKET" ]]; then
    echo "Error: S3 bucket not specified and TF_STATE_BUCKET not set"
    exit 1
fi

echo "🔧 Getting kubeconfig from cluster $CLUSTER_IP..."

# Create SSH key if needed
if [[ ! -f ~/.ssh/aws-key ]]; then
    echo "Error: SSH key not found at ~/.ssh/aws-key"
    exit 1
fi

# Get kubeconfig from cluster
if ssh -i ~/.ssh/aws-key -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@$CLUSTER_IP 'sudo cat /etc/rancher/k3s/k3s.yaml' > /tmp/k3s-config; then
    # Replace 127.0.0.1 with actual cluster IP
    sed "s|127.0.0.1:6443|$CLUSTER_IP:6443|g" /tmp/k3s-config > /tmp/kubeconfig-$ENVIRONMENT.yaml
    
    # Upload to S3
    S3_PATH="kubeconfig/$ENVIRONMENT-network.yaml"
    aws s3 cp /tmp/kubeconfig-$ENVIRONMENT.yaml s3://$S3_BUCKET/$S3_PATH
    
    echo "✅ Kubeconfig uploaded to S3: s3://$S3_BUCKET/$S3_PATH"
    
    # Cleanup
    rm -f /tmp/k3s-config /tmp/kubeconfig-$ENVIRONMENT.yaml
else
    echo "❌ Failed to get kubeconfig from cluster"
    exit 1
fi
#!/bin/bash
# K3s Setup - Modular and Parameterized
# This script calls the dedicated k3s-setup.sh with proper variables

set -e

# Variables from Terraform
METADATA_IP="${metadata_ip:-169.254.169.254}"
ENVIRONMENT="${environment}"
CLUSTER_NAME="${cluster_name}"
DB_ENDPOINT="${db_endpoint}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"

echo "☸️ Starting K3s setup with parameterized configuration..."
echo "Metadata IP: $METADATA_IP"
echo "Environment: $ENVIRONMENT"
echo "Cluster Name: $CLUSTER_NAME"
echo "S3 Bucket: $S3_BUCKET"
echo "AWS Region: $AWS_REGION"

# Export variables for the setup script
export metadata_ip="$METADATA_IP"
export environment="$ENVIRONMENT"
export cluster_name="$CLUSTER_NAME"
export db_endpoint="$DB_ENDPOINT"
export s3_bucket="$S3_BUCKET"
export aws_region="$AWS_REGION"

# Download and execute the k3s setup script
echo "Downloading k3s setup script..."
cd /tmp
wget -O k3s-setup.sh https://raw.githubusercontent.com/arunprabus/dev2prod-healthapp/main/infra/modules/k3s/k3s-setup.sh || {
    echo "Failed to download k3s-setup.sh, using embedded version..."
    # Fallback to embedded script content would go here
    echo "Please ensure k3s-setup.sh is available in the module directory"
    exit 1
}

chmod +x k3s-setup.sh
./k3s-setup.sh

echo "✅ K3s setup completed successfully!"
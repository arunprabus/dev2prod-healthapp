#!/bin/bash
# GitHub Runner Setup - Modular and Parameterized
# This script calls the dedicated runner-setup.sh with proper variables

set -e

# Variables from Terraform
METADATA_IP="${metadata_ip}"
S3_BUCKET="${s3_bucket}"
GITHUB_TOKEN="${github_token}"
GITHUB_REPO="${github_repo}"
NETWORK_TIER="${network_tier}"
AWS_REGION="${aws_region}"

echo "🚀 Starting GitHub Runner setup with parameterized configuration..."
echo "Metadata IP: $METADATA_IP"
echo "S3 Bucket: $S3_BUCKET"
echo "Network Tier: $NETWORK_TIER"
echo "AWS Region: $AWS_REGION"

# Export variables for the setup script
export metadata_ip="$METADATA_IP"
export s3_bucket="$S3_BUCKET"
export github_token="$GITHUB_TOKEN"
export github_repo="$GITHUB_REPO"
export network_tier="$NETWORK_TIER"
export aws_region="$AWS_REGION"

# Download and execute the runner setup script
echo "Downloading runner setup script..."
cd /tmp
wget -O runner-setup.sh https://raw.githubusercontent.com/arunprabus/dev2prod-healthapp/main/infra/modules/github-runner/runner-setup.sh || {
    echo "Failed to download runner-setup.sh, using embedded version..."
    # Fallback to embedded script content would go here
    echo "Please ensure runner-setup.sh is available in the module directory"
    exit 1
}

chmod +x runner-setup.sh
./runner-setup.sh

echo "✅ GitHub Runner setup completed successfully!"
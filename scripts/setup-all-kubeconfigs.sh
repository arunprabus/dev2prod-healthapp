#!/bin/bash

# Setup kubeconfig for all networks after infrastructure deployment
# This script gets cluster IPs from Terraform and generates all kubeconfigs

set -e

echo "🚀 Setting up kubeconfigs for all networks"

# Check if we're in the right directory
if [[ ! -d "infra" ]]; then
    echo "❌ Run this script from the repository root"
    exit 1
fi

cd infra

# Function to get cluster IP for environment
get_cluster_ip() {
    local env=$1
    echo "🔍 Getting cluster IP for $env environment..."
    
    # Initialize terraform for this environment
    terraform init \
        -backend-config="bucket=${TF_STATE_BUCKET:-health-app-terraform-state}" \
        -backend-config="key=health-app-$env.tfstate" \
        -backend-config="region=${AWS_REGION:-ap-south-1}" \
        > /dev/null 2>&1
    
    # Get cluster IP
    local ip=$(terraform output -raw k3s_instance_ip 2>/dev/null || echo "")
    
    if [[ -n "$ip" && "$ip" != "null" ]]; then
        echo "✅ $env cluster IP: $ip"
        echo "$ip"
    else
        echo "❌ No cluster found for $env environment"
        echo ""
    fi
}

# Generate kubeconfig for each environment
environments=("lower" "higher" "monitoring")

echo ""
echo "📋 Kubeconfig Generation Results:"
echo "=================================="

for env in "${environments[@]}"; do
    echo ""
    echo "🔧 Processing $env environment..."
    
    cluster_ip=$(get_cluster_ip "$env")
    
    if [[ -n "$cluster_ip" ]]; then
        # Generate kubeconfig
        ../scripts/generate-kubeconfig.sh "$env" "$cluster_ip"
        echo "✅ $env kubeconfig ready"
    else
        echo "⏭️  Skipping $env (no cluster deployed)"
    fi
done

echo ""
echo "🎯 Summary:"
echo "==========="
echo "✅ All available kubeconfigs generated"
echo "📋 Add the base64 values to GitHub Secrets:"
echo "   - KUBECONFIG_LOWER"
echo "   - KUBECONFIG_HIGHER" 
echo "   - KUBECONFIG_MONITORING"
echo ""
echo "🔗 GitHub Settings → Secrets and variables → Actions"
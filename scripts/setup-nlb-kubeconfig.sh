#!/bin/bash

# Setup kubeconfig to use NLB endpoint with ACM certificate
# Usage: ./setup-nlb-kubeconfig.sh <environment> <nlb_dns_name>

set -e

ENVIRONMENT=${1:-dev}
NLB_DNS_NAME=${2}

if [ -z "$NLB_DNS_NAME" ]; then
    echo "Usage: $0 <environment> <nlb_dns_name>"
    echo "Example: $0 dev health-app-lower-k3s-nlb-1234567890.elb.ap-south-1.amazonaws.com"
    exit 1
fi

echo "🔧 Setting up kubeconfig for $ENVIRONMENT using NLB: $NLB_DNS_NAME"

# Create kubeconfig directory
mkdir -p ~/.kube

# Generate kubeconfig for NLB endpoint
cat > ~/.kube/config-$ENVIRONMENT << EOF
apiVersion: v1
clusters:
- cluster:
    server: https://$NLB_DNS_NAME:443
    insecure-skip-tls-verify: true
  name: k3s-$ENVIRONMENT
contexts:
- context:
    cluster: k3s-$ENVIRONMENT
    user: k3s-$ENVIRONMENT
  name: k3s-$ENVIRONMENT
current-context: k3s-$ENVIRONMENT
kind: Config
preferences: {}
users:
- name: k3s-$ENVIRONMENT
  user:
    token: PLACEHOLDER_TOKEN
EOF

echo "✅ Kubeconfig template created at ~/.kube/config-$ENVIRONMENT"
echo "📝 Next steps:"
echo "   1. Get K3s token from cluster: sudo cat /var/lib/rancher/k3s/server/node-token"
echo "   2. Replace PLACEHOLDER_TOKEN in ~/.kube/config-$ENVIRONMENT"
echo "   3. Test connection: kubectl --kubeconfig ~/.kube/config-$ENVIRONMENT get nodes"
echo ""
echo "🔗 K3s API endpoint: https://$NLB_DNS_NAME:443"
echo "🛡️ TLS termination: ACM certificate at NLB"
echo "🔒 Backend: HTTP to K3s instance port 6443"
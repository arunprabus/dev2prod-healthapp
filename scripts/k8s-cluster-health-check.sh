#!/bin/bash
# K8s Cluster Health Check Script
# Usage: ./k8s-cluster-health-check.sh <environment> <cluster_ip> [--fix-kubeconfig]

set -e

ENVIRONMENT="${1:-dev}"
CLUSTER_IP="${2:-}"
FIX_KUBECONFIG="${3:-}"

echo "🔍 K8s Cluster Health Check for $ENVIRONMENT"
echo "================================================"

if [[ -z "$CLUSTER_IP" ]]; then
  echo "❌ Usage: $0 <environment> <cluster_ip> [--fix-kubeconfig]"
  echo "Example: $0 dev 43.205.211.129"
  echo "Example: $0 dev 43.205.211.129 --fix-kubeconfig"
  exit 1
fi

# Fix kubeconfig if requested
if [[ "$FIX_KUBECONFIG" == "--fix-kubeconfig" ]]; then
  echo "🔧 Fixing kubeconfig first..."
  ./fix-kubeconfig.sh $CLUSTER_IP
  echo ""
fi

echo "🎯 Target Cluster: https://$CLUSTER_IP:6443"
echo "📅 Date: $(date)"
echo ""

# Test 1: Port connectivity
echo "🔌 Test 1: Port Connectivity"
echo "Testing connection to $CLUSTER_IP:6443..."
if timeout 10 nc -z $CLUSTER_IP 6443; then
  echo "✅ Port 6443 is reachable"
else
  echo "❌ Port 6443 is NOT reachable"
  echo "🔍 Checking if instance is running and what ports are open..."
  
  # Test SSH port first
  if timeout 5 nc -z $CLUSTER_IP 22; then
    echo "✅ SSH port 22 is reachable - instance is up"
    echo "❌ But K3s port 6443 is blocked - K3s may not be running"
  else
    echo "❌ SSH port 22 is also not reachable - instance may be down"
  fi
  
  # Don't exit, continue with other tests
fi
echo ""

# Test 2: API Server response
echo "🌐 Test 2: API Server Response"
if curl -k -s --connect-timeout 10 https://$CLUSTER_IP:6443/version >/dev/null; then
  echo "✅ API Server is responding"
  curl -k -s https://$CLUSTER_IP:6443/version | jq . 2>/dev/null || echo "API response received"
else
  echo "❌ API Server is NOT responding"
  echo "⚠️ This suggests K3s is not running or not properly configured"
fi
echo ""

# Test 3: SSH to cluster and check K3s status
echo "🔐 Test 3: SSH Connection and K3s Status"
if [[ -n "${SSH_PRIVATE_KEY:-}" ]]; then
  echo "$SSH_PRIVATE_KEY" > /tmp/ssh_key
  chmod 600 /tmp/ssh_key
  
  if ssh -i /tmp/ssh_key -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$CLUSTER_IP "sudo systemctl is-active k3s" 2>/dev/null; then
    echo "✅ K3s service is active"
    
    # Get K3s service status
    echo "📊 K3s Service Status:"
    ssh -i /tmp/ssh_key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo systemctl status k3s --no-pager -l" 2>/dev/null || echo "Could not get detailed status"
    
    # Check nodes directly on cluster
    echo "🖥️ Cluster Nodes (from cluster):"
    ssh -i /tmp/ssh_key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo kubectl get nodes -o wide" 2>/dev/null || echo "Could not get nodes"
    
    # Check pods
    echo "🐳 System Pods (from cluster):"
    ssh -i /tmp/ssh_key -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "sudo kubectl get pods -A" 2>/dev/null || echo "Could not get pods"
    
  else
    echo "❌ K3s service is NOT active or SSH failed"
  fi
  
  rm -f /tmp/ssh_key
else
  echo "⚠️ SSH_PRIVATE_KEY not provided, skipping SSH tests"
fi
echo ""

# Test 4: External kubectl connection
echo "🔧 Test 4: External kubectl Connection"
if command -v kubectl >/dev/null; then
  # Create temporary kubeconfig
  cat > /tmp/test-kubeconfig.yaml << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://$CLUSTER_IP:6443
  name: test-cluster
contexts:
- context:
    cluster: test-cluster
    user: test-user
  name: test-context
current-context: test-context
users:
- name: test-user
  user:
    username: admin
    password: admin
EOF

  export KUBECONFIG=/tmp/test-kubeconfig.yaml
  
  if timeout 30 kubectl get nodes --insecure-skip-tls-verify 2>/dev/null; then
    echo "✅ External kubectl connection works"
  else
    echo "❌ External kubectl connection failed"
    echo "🔍 Trying with different auth methods..."
    
    # Try without auth
    if timeout 30 kubectl get --raw /api --insecure-skip-tls-verify 2>/dev/null; then
      echo "✅ API is accessible but authentication required"
    else
      echo "❌ API is not accessible externally"
    fi
  fi
  
  rm -f /tmp/test-kubeconfig.yaml
else
  echo "⚠️ kubectl not found, skipping external connection test"
fi
echo ""

echo "🏁 Health Check Complete"
echo "================================================"
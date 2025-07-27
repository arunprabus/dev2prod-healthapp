#!/bin/bash

echo "🌐 Testing network connectivity and port access..."

NAMESPACE=${1:-health-app-dev}

# Test cluster connectivity
echo "📡 Testing cluster API connectivity..."
kubectl cluster-info --insecure-skip-tls-verify

# Test node network
echo "🖥️ Node network information..."
kubectl get nodes -o wide --insecure-skip-tls-verify

# Test services and endpoints
echo "🔗 Services and endpoints..."
kubectl get services --all-namespaces --insecure-skip-tls-verify
kubectl get endpoints --all-namespaces --insecure-skip-tls-verify

# Test network policies
echo "🛡️ Network policies..."
kubectl get networkpolicies --all-namespaces --insecure-skip-tls-verify || echo "No network policies found"

# Test ingress
echo "🌍 Ingress resources..."
kubectl get ingress --all-namespaces --insecure-skip-tls-verify || echo "No ingress found"

# Test port connectivity from within cluster
echo "🔌 Testing internal connectivity..."
kubectl run network-test --image=busybox --rm -it --restart=Never --insecure-skip-tls-verify -- /bin/sh -c "
  echo 'Testing DNS resolution...'
  nslookup kubernetes.default.svc.cluster.local
  echo 'Testing API server connectivity...'
  wget -qO- --timeout=5 https://kubernetes.default.svc.cluster.local:443 || echo 'API server not reachable'
" || echo "Network test pod failed"

echo "✅ Network connectivity test completed!"
#!/bin/bash
set -e

echo "☸️ Installing K3s on $(hostname)..."
echo "Current user: $(whoami)"
echo "System info: $(uname -a)"

# Check if k3s is already running
if systemctl is-active --quiet k3s 2>/dev/null; then
  echo "✅ K3s already running"
  kubectl get nodes --insecure-skip-tls-verify 2>/dev/null || echo "kubectl not ready"
  exit 0
fi

# Update system packages
echo "📦 Updating system packages..."
apt-get update -qq

echo "📦 Installing K3s..."

# Get IP addresses
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

echo "Public IP: $PUBLIC_IP"
echo "Private IP: $PRIVATE_IP"

# Install k3s with proper configuration
echo "🚀 Installing K3s server..."
export INSTALL_K3S_EXEC="server --node-ip=$PRIVATE_IP --advertise-address=$PRIVATE_IP --tls-san $PUBLIC_IP --write-kubeconfig-mode=644 --disable=traefik"
curl -sfL https://get.k3s.io | sh -

if [ $? -ne 0 ]; then
  echo "❌ K3s installation failed"
  exit 1
fi

# Wait for k3s to be ready
echo "⏳ Waiting for K3s to be ready..."
for i in {1..30}; do
  if systemctl is-active --quiet k3s; then
    echo "✅ K3s service is active"
    # Test kubectl connectivity
    if kubectl get nodes --insecure-skip-tls-verify >/dev/null 2>&1; then
      echo "✅ K3s API is responding"
      break
    else
      echo "K3s service active but API not ready... ($i/30)"
    fi
  else
    echo "K3s service not active yet... ($i/30)"
  fi
  sleep 10
done

# Final verification
if systemctl is-active --quiet k3s && kubectl get nodes --insecure-skip-tls-verify >/dev/null 2>&1; then
  echo "✅ K3s service is running and API is responsive"
  echo "Node status:"
  kubectl get nodes --insecure-skip-tls-verify
  echo "K3s version: $(k3s --version | head -1)"
  echo "🎉 K3s installation completed successfully!"
else
  echo "❌ K3s installation verification failed"
  echo "Service status: $(systemctl is-active k3s 2>/dev/null || echo 'inactive')"
  echo "Service logs (last 10 lines):"
  journalctl -u k3s --no-pager -n 10 2>/dev/null || echo "Cannot access service logs"
  echo "Checking if kubectl is available:"
  which kubectl || echo "kubectl not found"
  echo "Checking kubeconfig:"
  ls -la /etc/rancher/k3s/ 2>/dev/null || echo "K3s config directory not found"
  exit 1
fi
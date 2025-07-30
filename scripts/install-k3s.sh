#!/bin/bash
set -e

echo "☸️ Installing K3s on $(hostname)..."

# Check if k3s is already running
if systemctl is-active --quiet k3s 2>/dev/null; then
  echo "✅ K3s already running"
  kubectl get nodes --insecure-skip-tls-verify 2>/dev/null || echo "kubectl not ready"
  exit 0
fi

echo "📦 Installing K3s..."

# Get IP addresses
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

echo "Public IP: $PUBLIC_IP"
echo "Private IP: $PRIVATE_IP"

# Install k3s with proper configuration
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip=$PRIVATE_IP --advertise-address=$PRIVATE_IP --tls-san $PUBLIC_IP --write-kubeconfig-mode=644 --disable=traefik" sh -

# Wait for k3s to be ready
echo "⏳ Waiting for K3s to be ready..."
for i in {1..30}; do
  if systemctl is-active --quiet k3s && kubectl get nodes --insecure-skip-tls-verify >/dev/null 2>&1; then
    echo "✅ K3s is ready"
    break
  fi
  echo "Waiting for K3s... ($i/30)"
  sleep 10
done

# Verify installation
if systemctl is-active --quiet k3s; then
  echo "✅ K3s service is running"
  kubectl get nodes --insecure-skip-tls-verify
else
  echo "❌ K3s service failed to start"
  echo "Service status: $(systemctl is-active k3s 2>/dev/null || echo 'inactive')"
  journalctl -u k3s --no-pager -n 5 2>/dev/null || echo "Cannot access service logs"
  exit 1
fi

echo "🎉 K3s installation completed successfully!"
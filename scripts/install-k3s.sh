#!/bin/bash
set -e

echo "🚀 Installing K3s..."

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Public IP: $PUBLIC_IP"

# Install K3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --bind-address 0.0.0.0 --advertise-address $PUBLIC_IP --tls-san $PUBLIC_IP --node-external-ip $PUBLIC_IP" sh -

# Wait for service
systemctl enable k3s
systemctl start k3s

# Wait for kubeconfig
while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
  echo "Waiting for kubeconfig..."
  sleep 5
done

# Update kubeconfig with public IP
sed -i "s|127.0.0.1|$PUBLIC_IP|g" /etc/rancher/k3s/k3s.yaml

echo "✅ K3s installation complete"
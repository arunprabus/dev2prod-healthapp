#!/bin/bash
exec > /var/log/k3s-install.log 2>&1

echo "=== K3S SIMPLE INSTALLATION STARTED ==="
date

# Variables from Terraform
ENVIRONMENT="${environment}"
CLUSTER_NAME="${cluster_name}"
NETWORK_TIER="${network_tier}"

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl wget git jq unzip

# Install AWS CLI v2 (optional - K3s works without it)
echo "Installing AWS CLI v2..."
if curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install; then
  echo "AWS CLI v2 installed successfully"
  rm -rf aws awscliv2.zip
else
  echo "AWS CLI v2 installation failed, continuing without it"
  rm -rf aws awscliv2.zip 2>/dev/null || true
fi

# Install K3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --disable traefik" sh -

# Wait for K3s to be ready
sleep 60
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Create namespaces based on environment
if [[ "$ENVIRONMENT" == "lower" ]]; then
  kubectl create namespace health-app-dev || true
  kubectl create namespace health-app-test || true
elif [[ "$ENVIRONMENT" == "higher" ]]; then
  kubectl create namespace health-app-prod || true
elif [[ "$ENVIRONMENT" == "monitoring" ]]; then
  kubectl create namespace monitoring || true
  kubectl create namespace health-app-monitoring || true
fi

# Setup local kubeconfig
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Set environment variables
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/ubuntu/.bashrc
echo 'alias k="kubectl"' >> /home/ubuntu/.bashrc

echo "SUCCESS" > /var/log/k3s-install-complete
echo "=== K3S SIMPLE INSTALLATION COMPLETED ==="
date
#!/bin/bash
set -e

# Update system
apt-get update
apt-get install -y curl

# Install K3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

# Wait for K3s to be ready
sleep 30

# Install kubectl for easier management
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Create health app namespace
kubectl create namespace health-app-${environment} || true

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Create a simple deployment for testing
cat <<EOF > /tmp/test-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: health-app-${environment}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test-service
  namespace: health-app-${environment}
spec:
  selector:
    app: nginx-test
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort
EOF

kubectl apply -f /tmp/test-deployment.yaml

# Set up kubeconfig for remote access
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Set KUBECONFIG environment variable for all users
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /etc/environment
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/ubuntu/.bashrc
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /root/.bashrc

# Create kubectl alias for convenience
echo 'alias k="kubectl"' >> /home/ubuntu/.bashrc
echo 'alias k="kubectl"' >> /root/.bashrc

echo "K3s installation completed successfully!"
echo "Cluster: ${cluster_name}"
echo "Environment: ${environment}"
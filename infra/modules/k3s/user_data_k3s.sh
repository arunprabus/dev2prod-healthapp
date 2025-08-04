#!/bin/bash
set -e
exec > >(tee /var/log/k3s-install.log) 2>&1

echo "Starting K3s installation at $(date)"

# Get public IP
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Public IP: $PUBLIC_IP"

# Install K3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --bind-address 0.0.0.0 --advertise-address $PUBLIC_IP --tls-san $PUBLIC_IP --node-external-ip $PUBLIC_IP --resolv-conf /etc/resolv.conf" sh -

systemctl enable k3s
systemctl start k3s

# Wait for kubeconfig
while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
  sleep 5
done
sleep 10

# Fix kubeconfig server endpoint
sed -i "s|https://127.0.0.1:6443|https://$PUBLIC_IP:6443|g" /etc/rancher/k3s/k3s.yaml
sed -i "s|server: https://0.0.0.0:6443|server: https://$PUBLIC_IP:6443|g" /etc/rancher/k3s/k3s.yaml

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Wait for K3s ready
for i in {1..30}; do
  if kubectl get nodes --insecure-skip-tls-verify > /dev/null 2>&1; then
    echo "K3s ready!"
    break
  fi
  sleep 10
done

# Create namespaces
if [[ "$ENVIRONMENT" == "dev" ]] || [[ "$NETWORK_TIER" == "lower" ]]; then
  kubectl create namespace health-app-dev --insecure-skip-tls-verify || true
  kubectl create namespace health-app-test --insecure-skip-tls-verify || true
elif [[ "$ENVIRONMENT" == "prod" ]] || [[ "$NETWORK_TIER" == "higher" ]]; then
  kubectl create namespace health-app-prod --insecure-skip-tls-verify || true
elif [[ "$ENVIRONMENT" == "monitoring" ]]; then
  kubectl create namespace monitoring --insecure-skip-tls-verify || true
fi

# Setup local access
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/ubuntu/.bashrc

# Install NGINX Ingress
for i in {1..3}; do
  if timeout 120 kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml --insecure-skip-tls-verify; then
    break
  fi
  sleep 30
done

# Upload kubeconfig to S3 (ONLY standard kubeconfig)
if [[ -n "$S3_BUCKET" ]]; then
  aws s3 cp /etc/rancher/k3s/k3s.yaml "s3://$S3_BUCKET/kubeconfig/$ENVIRONMENT-kubeconfig.yaml"
fi

echo "SUCCESS" > /var/log/k3s-install-complete
echo "=== K3S INSTALLATION COMPLETED ==="
date
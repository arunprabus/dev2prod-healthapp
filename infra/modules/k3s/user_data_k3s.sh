#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/k3s-install.log) 2>&1

echo "Starting K3s installation at $(date)"

# Get public IP first
echo "🌐 Fetching public IP..."
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

echo "✅ Public IP: $PUBLIC_IP"

# Install K3s with proper external access configuration
echo "Installing K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --bind-address 0.0.0.0 --advertise-address $PUBLIC_IP --tls-san $PUBLIC_IP --node-external-ip $PUBLIC_IP" sh -

# Wait for service to be ready
echo "Starting K3s service..."
systemctl enable k3s
systemctl start k3s

# Wait for kubeconfig
echo "Waiting for kubeconfig..."
while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
  echo "Kubeconfig not ready, waiting..."
  sleep 5
done

# Update kubeconfig with public IP
echo "🔧 Updating kubeconfig..." | tee -a /var/log/k3s-install.log
sed -i "s|127.0.0.1|$PUBLIC_IP|g" /etc/rancher/k3s/k3s.yaml
echo "✅ Kubeconfig updated with IP: $PUBLIC_IP" | tee -a /var/log/k3s-install.log

# Test kubectl
echo "Testing kubectl..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Wait for K3s to be ready
echo "Waiting for K3s to be ready..."
for i in {1..60}; do
  if kubectl get nodes > /dev/null 2>&1; then
    echo "✅ K3s is ready!"
    kubectl get nodes
    break
  fi
  echo "Waiting for K3s... ($i/60)"
  sleep 10
done

# Additional wait for API server to be fully ready
echo "⏳ Additional wait for API server stability..."
sleep 30

# Test external connectivity
echo "🔍 Testing external API access..."
for i in {1..10}; do
  if curl -k -s https://$PUBLIC_IP:6443/version > /dev/null 2>&1; then
    echo "✅ External API access working (attempt $i)"
    break
  fi
  echo "⏳ External API not ready (attempt $i/10), waiting..."
  sleep 15
done

# Create ALB-enabled kubeconfig and store in SSM
echo "📤 Creating ALB kubeconfig and storing in SSM..."
cp /etc/rancher/k3s/k3s.yaml /tmp/alb-kubeconfig.yaml
# Replace with ALB endpoint (will be updated by Terraform output)
sed -i "s|https://$PUBLIC_IP:6443|https://$ENVIRONMENT.k3s.healthapp.local:443|g" /tmp/alb-kubeconfig.yaml
KUBECONFIG_B64=$(base64 -w 0 /tmp/alb-kubeconfig.yaml)
aws ssm put-parameter \
  --name "/health-app/$ENVIRONMENT/kubeconfig" \
  --value "$KUBECONFIG_B64" \
  --type "SecureString" \
  --overwrite || echo "⚠️ Failed to store in SSM"

# Create completion marker
echo "K3s installation completed at $(date)"
touch /var/log/k3s-install-complete

# Create namespaces based on environment
echo "🏷️ Creating namespaces for $ENVIRONMENT..."
if [[ "$ENVIRONMENT" == "dev" ]] || [[ "$NETWORK_TIER" == "lower" ]]; then
  # Lower network: dev and test environments
  kubectl create namespace health-app-dev --insecure-skip-tls-verify || true
  kubectl create namespace health-app-test --insecure-skip-tls-verify || true

elif [[ "$ENVIRONMENT" == "prod" ]] || [[ "$NETWORK_TIER" == "higher" ]]; then
  # Higher network: production environment
  kubectl create namespace health-app-prod --insecure-skip-tls-verify || true

elif [[ "$ENVIRONMENT" == "monitoring" ]]; then
  # Monitoring network: monitoring tools
  kubectl create namespace monitoring --insecure-skip-tls-verify || true
  kubectl create namespace health-app-monitoring --insecure-skip-tls-verify || true
fi

# Create service account for GitHub Actions
echo "🔐 Creating service account for GitHub Actions..."
kubectl create namespace gha-access --insecure-skip-tls-verify || true
kubectl create serviceaccount gha-deployer -n gha-access --insecure-skip-tls-verify || true

# Create cluster role with necessary permissions
cat <<EOF | kubectl apply -f - --insecure-skip-tls-verify
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: gha-deployer-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps", "secrets", "namespaces"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

# Create cluster role binding
kubectl create clusterrolebinding gha-deployer-binding \
  --clusterrole=gha-deployer-role \
  --serviceaccount=gha-access:gha-deployer \
  --insecure-skip-tls-verify || true

# Generate service account token
echo "🎫 Generating service account token..."
TOKEN=$(kubectl create token gha-deployer -n gha-access --duration=8760h --insecure-skip-tls-verify) # 1 year

if [[ -n "$TOKEN" ]]; then
  PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
  
  # Create kubeconfig for GitHub Actions
  cat > /tmp/gha-kubeconfig.yaml << KUBE_EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://$PUBLIC_IP:6443
  name: k3s-cluster
contexts:
- context:
    cluster: k3s-cluster
    namespace: gha-access
    user: gha-deployer
  name: gha-context
current-context: gha-context
users:
- name: gha-deployer
  user:
    token: $TOKEN
KUBE_EOF
  
  # Upload kubeconfig to S3 if bucket is provided
  if [[ -n "$S3_BUCKET" ]]; then
    echo "📤 Uploading kubeconfig to S3..."
    if aws s3 ls s3://$S3_BUCKET/kubeconfig/$ENVIRONMENT-gha.yaml >/dev/null 2>&1; then
      echo "🔄 Existing kubeconfig found, updating..."
      aws s3 cp /tmp/gha-kubeconfig.yaml s3://$S3_BUCKET/kubeconfig/$ENVIRONMENT-gha.yaml
      echo "✅ GitHub Actions kubeconfig updated in S3"
    else
      echo "📤 Creating new kubeconfig..."
      aws s3 cp /tmp/gha-kubeconfig.yaml s3://$S3_BUCKET/kubeconfig/$ENVIRONMENT-gha.yaml
      echo "✅ GitHub Actions kubeconfig uploaded to S3"
    fi
  fi
else
  echo "❌ Failed to generate service account token"
fi

# Also upload standard kubeconfig to S3 for easy access
if [[ -n "$S3_BUCKET" ]]; then
  # Create standard kubeconfig with public IP
  PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
  cp /etc/rancher/k3s/k3s.yaml /tmp/kubeconfig-standard.yaml
  sed -i "s/127.0.0.1/$PUBLIC_IP/g" /tmp/kubeconfig-standard.yaml
  
  if aws s3 ls s3://$S3_BUCKET/kubeconfig/$ENVIRONMENT-standard.yaml >/dev/null 2>&1; then
    echo "🔄 Existing standard kubeconfig found, updating..."
    aws s3 cp /tmp/kubeconfig-standard.yaml s3://$S3_BUCKET/kubeconfig/$ENVIRONMENT-standard.yaml
    echo "✅ Standard kubeconfig updated in S3"
  else
    echo "📤 Creating new standard kubeconfig..."
    aws s3 cp /tmp/kubeconfig-standard.yaml s3://$S3_BUCKET/kubeconfig/$ENVIRONMENT-standard.yaml
    echo "✅ Standard kubeconfig uploaded to S3"
  fi
fi

# Setup local kubeconfig access
echo "🔧 Setting up local kubeconfig access..."
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Set environment variables
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /etc/environment
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/ubuntu/.bashrc
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /root/.bashrc

# Create kubectl aliases
echo 'alias k="kubectl"' >> /home/ubuntu/.bashrc
echo 'alias k="kubectl"' >> /root/.bashrc

# Install NGINX Ingress Controller
echo "🌐 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller to be ready
echo "⏳ Waiting for ingress controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s || true

# Final status
echo "🎉 K3s cluster setup completed!"
echo "Cluster: $CLUSTER_NAME"
echo "Environment: $ENVIRONMENT"
echo "Network Tier: $NETWORK_TIER"
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

echo "SUCCESS" > /var/log/k3s-install-complete
echo "K3S_INSTALLATION_COMPLETE=$(date)" >> /var/log/k3s-ready
echo "=== K3S INSTALLATION COMPLETED ==="
date

echo "📊 System ready for connections"
#!/bin/bash
set -e

# Variables
METADATA_IP="${metadata_ip}"
ENVIRONMENT="${environment}"
S3_BUCKET="${s3_bucket}"
AWS_REGION="${aws_region}"

echo "☸️ Setting up K3s Kubernetes cluster..."

# Update system (cached)
if [ ! -f "/var/cache/apt/pkgcache.bin" ] || [ $(find /var/cache/apt/pkgcache.bin -mtime +1) ]; then
  apt-get update
fi
apt-get install -y curl docker.io mysql-client awscli

# Install SSM Agent (single installation with proper error handling)
echo "🔧 Installing SSM Agent..."
if ! systemctl is-active --quiet amazon-ssm-agent; then
    cd /tmp
    if wget -q https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb; then
        dpkg -i amazon-ssm-agent.deb || apt-get install -f -y
        systemctl enable amazon-ssm-agent
        systemctl start amazon-ssm-agent
        systemctl status amazon-ssm-agent --no-pager
        echo "✅ SSM Agent installed via deb package"
    else
        echo "Deb installation failed, trying snap..."
        if ! command -v snap >/dev/null; then
            apt install snapd -y
        fi
        if snap install amazon-ssm-agent --classic; then
            systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
            systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
            echo "✅ SSM Agent installed via snap"
        else
            echo "⚠️ SSM Agent installation failed, but continuing..."
        fi
    fi
else
    echo "✅ SSM Agent already running"
fi

# Get both public and private IPs
echo "Getting IP addresses..."
for i in {1..10}; do
  PUBLIC_IP=$(curl -s --connect-timeout 5 http://$METADATA_IP/latest/meta-data/public-ipv4)
  PRIVATE_IP=$(curl -s --connect-timeout 5 http://$METADATA_IP/latest/meta-data/local-ipv4)
  if [[ -n "$PUBLIC_IP" ]] && [[ -n "$PRIVATE_IP" ]]; then
    echo "✅ Got public IP: $PUBLIC_IP, private IP: $PRIVATE_IP (attempt $i)"
    break
  fi
  echo "⏳ Waiting for IP addresses... (attempt $i/10)"
  sleep 5
  if [ $i -eq 10 ]; then
    echo "❌ Failed to get IP addresses after 10 attempts"
    exit 1
  fi
done

# Install K3s with error handling - proper IP configuration
echo "📦 Installing K3s..."
if curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=$PRIVATE_IP --advertise-address=$PRIVATE_IP --tls-san $PUBLIC_IP --write-kubeconfig-mode 644" sh -; then
  echo "✅ K3s installation completed"
else
  echo "❌ K3s installation failed"
  exit 1
fi

# Wait for K3s service to be active
echo "Waiting for K3s service to start..."
for i in {1..30}; do
  if systemctl is-active --quiet k3s; then
    echo "✅ K3s service is active"
    break
  fi
  echo "⏳ Waiting for K3s service... ($i/30)"
  sleep 10
  if [ $i -eq 30 ]; then
    echo "❌ K3s service failed to start"
    systemctl status k3s --no-pager
    exit 1
  fi
done

# Setup Docker
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Install kubectl (cached)
echo "☸️ Installing kubectl..."
if ! command -v kubectl >/dev/null; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  mv kubectl /usr/local/bin/
else
  echo "✅ kubectl already installed"
fi

# Set kubeconfig and wait for API server
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "Waiting for K3s API server to be ready..."
for i in {1..60}; do
  if kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
    echo "✅ K3s API server is ready"
    break
  fi
  echo "⏳ Waiting for API server... ($i/60)"
  sleep 5
  if [ $i -eq 60 ]; then
    echo "❌ K3s API server not ready"
    kubectl get nodes --request-timeout=5s || true
    exit 1
  fi
done

# Create namespace and service account with error handling
echo "Creating namespace and service account..."
if kubectl create namespace gha-access 2>/dev/null; then
  echo "✅ Namespace created"
else
  echo "⚠️ Namespace already exists or creation failed"
fi

if kubectl create serviceaccount gha-deployer -n gha-access 2>/dev/null; then
  echo "✅ Service account created"
else
  echo "❌ Service account creation failed"
  kubectl get serviceaccount -n gha-access
  exit 1
fi

# Create role with deployment permissions
echo "Creating role with deployment permissions..."
if kubectl create role gha-role --verb=get,list,watch,create,update,patch,delete --resource=pods,services,deployments,namespaces -n gha-access 2>/dev/null; then
  echo "✅ Role created"
else
  echo "⚠️ Role already exists or creation failed"
fi

if kubectl create rolebinding gha-rolebinding --role=gha-role --serviceaccount=gha-access:gha-deployer -n gha-access 2>/dev/null; then
  echo "✅ Role binding created"
else
  echo "⚠️ Role binding already exists or creation failed"
fi

# Wait a moment for service account to be ready
sleep 5

# Generate dynamic token with retry
echo "Generating dynamic token..."
for i in {1..5}; do
  TOKEN=$(kubectl create token gha-deployer -n gha-access --duration=24h 2>/dev/null)
  if [[ -n "$TOKEN" ]]; then
    echo "✅ Token generated successfully"
    break
  fi
  echo "⏳ Token generation attempt $i/5 failed, retrying..."
  sleep 10
  if [ $i -eq 5 ]; then
    echo "❌ Failed to generate token after 5 attempts"
    kubectl get serviceaccount gha-deployer -n gha-access
    exit 1
  fi
done

if [[ -n "$TOKEN" ]]; then
  # Store kubeconfig data in Parameter Store
  echo "Storing kubeconfig data in Parameter Store..."
  
  aws ssm put-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/server" \
    --value "https://$PUBLIC_IP:6443" \
    --type "String" \
    --overwrite \
    --region $AWS_REGION
  
  aws ssm put-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/token" \
    --value "$TOKEN" \
    --type "SecureString" \
    --overwrite \
    --region $AWS_REGION
  
  # Store cluster name for reference
  aws ssm put-parameter \
    --name "/$ENVIRONMENT/health-app/kubeconfig/cluster-name" \
    --value "k3s-cluster" \
    --type "String" \
    --overwrite \
    --region $AWS_REGION
  
  echo "SUCCESS: Kubeconfig data stored in Parameter Store"
  
  # Create kubeconfig with dynamic token
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
  
  # Upload to S3 (backup)
  if [[ -n "$S3_BUCKET" ]]; then
    echo "Uploading kubeconfig to S3..."
    aws s3 cp /tmp/gha-kubeconfig.yaml s3://$S3_BUCKET/kubeconfig/$ENVIRONMENT-gha.yaml
    echo "SUCCESS: Service account kubeconfig uploaded to S3"
  fi
else
  echo "ERROR: Failed to generate token"
fi

# Create health app namespace
echo "🏗️ Creating namespaces..."
kubectl create namespace health-app-$ENVIRONMENT || true

# Configure database connection based on environment
if [[ "$ENVIRONMENT" == "lower" ]]; then
  # Configure for both dev and test namespaces (shared DB)
  kubectl create namespace health-app-dev || true
  kubectl create namespace health-app-test || true
  
  # Create database secrets for shared DB
  kubectl create secret generic database-config \
    --from-literal=DB_HOST="${db_endpoint}" \
    --from-literal=DB_PORT="5432" \
    --from-literal=DB_NAME="healthapi" \
    --from-literal=DB_USER="postgres" \
    --from-literal=DB_PASSWORD="changeme123!" \
    --from-literal=DATABASE_URL="postgresql://postgres:changeme123!@${db_endpoint}:5432/healthapi" \
    -n health-app-dev || true
    
  kubectl create secret generic database-config \
    --from-literal=DB_HOST="${db_endpoint}" \
    --from-literal=DB_PORT="5432" \
    --from-literal=DB_NAME="healthapi" \
    --from-literal=DB_USER="postgres" \
    --from-literal=DB_PASSWORD="changeme123!" \
    --from-literal=DATABASE_URL="postgresql://postgres:changeme123!@${db_endpoint}:5432/healthapi" \
    -n health-app-test || true
    
elif [[ "$ENVIRONMENT" == "higher" ]]; then
  # Configure for prod namespace (dedicated DB)
  kubectl create namespace health-app-prod || true
  
  kubectl create secret generic database-config \
    --from-literal=DB_HOST="${db_endpoint}" \
    --from-literal=DB_PORT="5432" \
    --from-literal=DB_NAME="healthapi" \
    --from-literal=DB_USER="postgres" \
    --from-literal=DB_PASSWORD="changeme123!" \
    --from-literal=DATABASE_URL="postgresql://postgres:changeme123!@${db_endpoint}:5432/healthapi" \
    -n health-app-prod || true
fi

# Install Helm (cached)
echo "⚓ Installing Helm..."
if ! command -v helm >/dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "✅ Helm already installed"
fi

# Create a simple deployment for testing
echo "🧪 Creating test deployment..."
cat <<EOF > /tmp/test-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: health-app-$ENVIRONMENT
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
  namespace: health-app-$ENVIRONMENT
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
echo "🔧 Setting up kubeconfig..."
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

# Create cluster health check script
cat > /home/ubuntu/k3s-health-check.sh << 'HEALTHEOF'
#!/bin/bash
echo "🔍 K3s Cluster Health Check"
echo "=========================="

# Check K3s service status
echo "K3s Service Status:"
systemctl status k3s --no-pager -l

echo ""
echo "Node Status:"
kubectl get nodes -o wide

echo ""
echo "Pod Status:"
kubectl get pods --all-namespaces

echo ""
echo "Service Status:"
kubectl get services --all-namespaces

echo ""
echo "Namespace Status:"
kubectl get namespaces

echo ""
echo "Cluster Info:"
kubectl cluster-info

echo ""
echo "API Server Health:"
curl -k https://localhost:6443/healthz || echo "API server not responding"
HEALTHEOF

chmod +x /home/ubuntu/k3s-health-check.sh
chown ubuntu:ubuntu /home/ubuntu/k3s-health-check.sh

# Create cluster restart script
cat > /home/ubuntu/restart-k3s.sh << 'RESTARTEOF'
#!/bin/bash
echo "🔄 Restarting K3s cluster..."

# Stop K3s
systemctl stop k3s
sleep 10

# Clean up any remaining processes
pkill -f k3s || true
sleep 5

# Start K3s
systemctl start k3s
sleep 30

# Check status
if systemctl is-active --quiet k3s; then
    echo "✅ K3s restarted successfully"
    kubectl get nodes
else
    echo "❌ K3s restart failed"
    systemctl status k3s --no-pager
fi
RESTARTEOF

chmod +x /home/ubuntu/restart-k3s.sh
chown ubuntu:ubuntu /home/ubuntu/restart-k3s.sh

echo "✅ K3s installation completed successfully!"
echo "Cluster: ${cluster_name}"
echo "Environment: ${environment}"
echo "Database endpoint: ${db_endpoint}"
echo "Namespaces created and database secrets configured"
echo "Instance IP: $(curl -s http://$METADATA_IP/latest/meta-data/local-ipv4)"
echo "Public IP: $(curl -s http://$METADATA_IP/latest/meta-data/public-ipv4)"
echo ""
echo "📋 Health check script: /home/ubuntu/k3s-health-check.sh"
echo "🔄 Restart script: /home/ubuntu/restart-k3s.sh"
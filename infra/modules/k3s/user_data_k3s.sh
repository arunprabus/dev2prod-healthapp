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

# Install K3s for internal access only (ALB will handle external SSL)
echo "Installing K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

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
for i in {1..30}; do
  if kubectl get nodes --insecure-skip-tls-verify > /dev/null 2>&1; then
    echo "✅ K3s is ready!"
    kubectl get nodes --insecure-skip-tls-verify
    break
  fi
  echo "Waiting for K3s... ($i/30)"
  sleep 10
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
  
  # Database secrets commented out for now
  # echo "💾 Creating database secrets for shared DB..."
  # kubectl create secret generic database-config \
  #   --from-literal=DB_HOST="$DB_ENDPOINT" \
  #   --from-literal=DB_PORT="5432" \
  #   --from-literal=DB_NAME="healthapi" \
  #   --from-literal=DB_USER="postgres" \
  #   --from-literal=DB_PASSWORD="changeme123!" \
  #   --from-literal=DATABASE_URL="postgresql://postgres:changeme123!@$DB_ENDPOINT:5432/healthapi" \
  #   -n health-app-dev || true
  #   
  # kubectl create secret generic database-config \
  #   --from-literal=DB_HOST="$DB_ENDPOINT" \
  #   --from-literal=DB_PORT="5432" \
  #   --from-literal=DB_NAME="healthapi" \
  #   --from-literal=DB_USER="postgres" \
  #   --from-literal=DB_PASSWORD="changeme123!" \
  #   --from-literal=DATABASE_URL="postgresql://postgres:changeme123!@$DB_ENDPOINT:5432/healthapi" \
  #   -n health-app-test || true

elif [[ "$ENVIRONMENT" == "prod" ]] || [[ "$NETWORK_TIER" == "higher" ]]; then
  # Higher network: production environment
  kubectl create namespace health-app-prod --insecure-skip-tls-verify || true
  
  # Database secrets commented out for now
  # echo "💾 Creating database secrets for dedicated prod DB..."
  # kubectl create secret generic database-config \
  #   --from-literal=DB_HOST="$DB_ENDPOINT" \
  #   --from-literal=DB_PORT="5432" \
  #   --from-literal=DB_NAME="healthapi" \
  #   --from-literal=DB_USER="postgres" \
  #   --from-literal=DB_PASSWORD="changeme123!" \
  #   --from-literal=DATABASE_URL="postgresql://postgres:changeme123!@$DB_ENDPOINT:5432/healthapi" \
  #   -n health-app-prod || true

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

# Create test deployment for verification
echo "🧪 Creating test deployment..."
cat <<EOF > /tmp/test-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: health-app-$ENVIRONMENT
  labels:
    app: nginx-test
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
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
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

# Apply test deployment if namespace exists
if kubectl get namespace health-app-$ENVIRONMENT 2>/dev/null; then
  kubectl apply -f /tmp/test-deployment.yaml
  echo "✅ Test deployment created in health-app-$ENVIRONMENT"
fi

# Create health monitoring script
echo "🔍 Setting up K3s health monitoring..."
cat > /home/ubuntu/monitor-k3s.sh << 'MONEOF'
#!/bin/bash
LOG_FILE="/var/log/k3s-health.log"
echo "$(date): Checking K3s health..." >> $LOG_FILE

# Check K3s service
if systemctl is-active --quiet k3s; then
    echo "$(date): ✅ K3s service is active" >> $LOG_FILE
else
    echo "$(date): ❌ K3s service is not active, restarting..." >> $LOG_FILE
    systemctl restart k3s >> $LOG_FILE 2>&1
    sleep 30
fi

# Check API server
if kubectl get nodes > /dev/null 2>&1; then
    echo "$(date): ✅ K3s API server is responding" >> $LOG_FILE
else
    echo "$(date): ❌ K3s API server not responding" >> $LOG_FILE
fi

# Check node status
NODE_STATUS=$(kubectl get nodes --no-headers | awk '{print $2}')
if [[ "$NODE_STATUS" == "Ready" ]]; then
    echo "$(date): ✅ Node is Ready" >> $LOG_FILE
else
    echo "$(date): ⚠️ Node status: $NODE_STATUS" >> $LOG_FILE
fi

# Keep only last 100 lines of log
tail -100 $LOG_FILE > /tmp/k3s-health.tmp && mv /tmp/k3s-health.tmp $LOG_FILE
MONEOF

chmod +x /home/ubuntu/monitor-k3s.sh
chown ubuntu:ubuntu /home/ubuntu/monitor-k3s.sh

# Create cluster info script
cat > /home/ubuntu/cluster-info.sh << INFOEOF
#!/bin/bash
echo "=== K3s Cluster Information ==="
echo "Cluster: $CLUSTER_NAME"
echo "Environment: $ENVIRONMENT"
echo "Network Tier: $NETWORK_TIER"
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "=== Node Status ==="
kubectl get nodes -o wide
echo ""
echo "=== Namespaces ==="
kubectl get namespaces
echo ""
echo "=== All Pods ==="
kubectl get pods -A
echo ""
echo "=== Services ==="
kubectl get services -A
echo ""
echo "=== Ingress Controller ==="
kubectl get pods -n ingress-nginx
INFOEOF

chmod +x /home/ubuntu/cluster-info.sh
chown ubuntu:ubuntu /home/ubuntu/cluster-info.sh

# Setup cron job for health monitoring
echo "*/5 * * * * /home/ubuntu/monitor-k3s.sh" | crontab -u ubuntu -

# Create restart script
cat > /home/ubuntu/restart-k3s.sh << 'RESTEOF'
#!/bin/bash
echo "🔄 Restarting K3s cluster..."
echo "$(date): Manual restart initiated" >> /var/log/k3s-health.log

# Restart K3s service
sudo systemctl restart k3s
sleep 30

# Check status
if systemctl is-active --quiet k3s; then
    echo "✅ K3s restarted successfully"
    sudo systemctl status k3s --no-pager
    kubectl get nodes
else
    echo "❌ K3s restart failed"
    sudo journalctl -u k3s --no-pager -n 20
fi
RESTEOF

chmod +x /home/ubuntu/restart-k3s.sh
chown ubuntu:ubuntu /home/ubuntu/restart-k3s.sh

# Test connectivity and functionality
echo "🔍 Testing cluster functionality..."
if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    echo "✅ Internet connectivity: OK"
else
    echo "❌ Internet connectivity: FAILED"
fi

if kubectl get nodes > /dev/null 2>&1; then
    echo "✅ K3s API server: OK"
else
    echo "❌ K3s API server: FAILED"
fi

if kubectl get pods -A > /dev/null 2>&1; then
    echo "✅ Pod listing: OK"
else
    echo "❌ Pod listing: FAILED"
fi

# Final status
echo "🎉 K3s cluster setup completed!"
echo "Cluster: $CLUSTER_NAME"
echo "Environment: $ENVIRONMENT"
echo "Network Tier: $NETWORK_TIER"
echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
# echo "Database endpoint: $DB_ENDPOINT"  # Commented out for now

echo "📋 Available scripts:"
echo "  - /home/ubuntu/cluster-info.sh - Show cluster information"
echo "  - /home/ubuntu/monitor-k3s.sh - Health monitoring (runs every 5 minutes)"
echo "  - /home/ubuntu/restart-k3s.sh - Restart K3s cluster"

# Final verification and debug info
echo "=== FINAL VERIFICATION ==="
echo "🔍 K3s service status:"
systemctl status k3s --no-pager
echo ""
echo "🔍 K3s process:"
ps aux | grep k3s | grep -v grep
echo ""
echo "🔍 Kubeconfig file:"
ls -la /etc/rancher/k3s/k3s.yaml 2>/dev/null || echo "Kubeconfig file not found"
echo ""
echo "🔍 kubectl test:"
kubectl get nodes 2>/dev/null || echo "kubectl not working"

echo "SUCCESS" > /var/log/k3s-install-complete
echo "K3S_INSTALLATION_COMPLETE=$(date)" >> /var/log/k3s-ready
echo "=== K3S INSTALLATION COMPLETED ==="
date

echo "📊 System ready for connections"
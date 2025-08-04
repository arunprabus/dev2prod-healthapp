#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/k3s-install.log) 2>&1

echo "Starting K3s installation at $(date)"

# Get public IP once and reuse
echo "🌐 Fetching public IP..."
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

echo "✅ Public IP: $PUBLIC_IP"

# Install K3s with proper external access configuration
echo "Installing K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --bind-address 0.0.0.0 --advertise-address $PUBLIC_IP --tls-san $PUBLIC_IP --node-external-ip $PUBLIC_IP --resolv-conf /etc/resolv.conf" sh -

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

# Update kubeconfig with public IP (fix server endpoint)
echo "🔧 Updating kubeconfig..." | tee -a /var/log/k3s-install.log

# Wait for kubeconfig to be fully written
sleep 5

# Fix server endpoint in kubeconfig
sed -i "s|https://127.0.0.1:6443|https://$PUBLIC_IP:6443|g" /etc/rancher/k3s/k3s.yaml
sed -i "s|server: https://0.0.0.0:6443|server: https://$PUBLIC_IP:6443|g" /etc/rancher/k3s/k3s.yaml

# Verify the change
echo "📋 Kubeconfig server URL:"
grep "server:" /etc/rancher/k3s/k3s.yaml
echo "✅ Kubeconfig updated with IP: $PUBLIC_IP" | tee -a /var/log/k3s-install.log

# Test kubectl
echo "Testing kubectl..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Wait for K3s to be ready with insecure skip
echo "Waiting for K3s to be ready..."
for i in {1..60}; do
  if kubectl get nodes --insecure-skip-tls-verify > /dev/null 2>&1; then
    echo "✅ K3s is ready!"
    kubectl get nodes --insecure-skip-tls-verify
    break
  fi
  echo "Waiting for K3s... ($i/60)"
  sleep 10
done

# Additional wait for API server to be fully ready
echo "⏳ Additional wait for API server stability..."
sleep 60

# Wait for all system pods to be ready
echo "🔍 Waiting for system pods..."
for i in {1..30}; do
  if kubectl get pods -n kube-system --insecure-skip-tls-verify | grep -v Running | grep -v Completed | wc -l | grep -q "^1$"; then
    echo "✅ System pods ready!"
    break
  fi
  echo "Waiting for system pods... ($i/30)"
  sleep 10
done

# Test external connectivity with longer timeout
echo "🔍 Testing external API access..."
for i in {1..20}; do
  if timeout 30 kubectl get nodes --insecure-skip-tls-verify > /dev/null 2>&1; then
    echo "✅ External API access working (attempt $i)"
    break
  fi
  echo "⏳ External API not ready (attempt $i/20), waiting 30s..."
  sleep 30
done

# Final verification with detailed output
echo "🔍 Final API verification..."
kubectl get nodes --insecure-skip-tls-verify || echo "⚠️ API still not ready, but continuing..."

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

# Function to create kubeconfig
create_kubeconfig() {
  local config_file=$1
  local server_url=$2
  local token=$3
  
  cat > "$config_file" << KUBE_EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: $server_url
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
    token: $token
KUBE_EOF
}

# Function to upload to S3
upload_to_s3() {
  local file_path=$1
  local s3_key=$2
  local description=$3
  
  if aws s3 ls "s3://$S3_BUCKET/$s3_key" >/dev/null 2>&1; then
    echo "🔄 Existing $description found, updating..."
    aws s3 cp "$file_path" "s3://$S3_BUCKET/$s3_key"
    echo "✅ $description updated in S3"
  else
    echo "📤 Creating new $description..."
    aws s3 cp "$file_path" "s3://$S3_BUCKET/$s3_key"
    echo "✅ $description uploaded to S3"
  fi
}

if [[ -n "$TOKEN" ]]; then
  # Create kubeconfig for GitHub Actions
  create_kubeconfig "/tmp/gha-kubeconfig.yaml" "https://$PUBLIC_IP:6443" "$TOKEN"
  
  # Upload GitHub Actions kubeconfig to S3
  if [[ -n "$S3_BUCKET" ]]; then
    echo "📤 Uploading GitHub Actions kubeconfig to S3..."
    upload_to_s3 "/tmp/gha-kubeconfig.yaml" "kubeconfig/$ENVIRONMENT-gha.yaml" "GitHub Actions kubeconfig"
  fi
else
  echo "❌ Failed to generate service account token"
fi

# Create and upload standard kubeconfig to S3
if [[ -n "$S3_BUCKET" ]]; then
  # Create standard kubeconfig with public IP
  cp /etc/rancher/k3s/k3s.yaml /tmp/kubeconfig-standard.yaml
  sed -i "s|https://127.0.0.1:6443|https://$PUBLIC_IP:6443|g" /tmp/kubeconfig-standard.yaml
  sed -i "s|server: https://0.0.0.0:6443|server: https://$PUBLIC_IP:6443|g" /tmp/kubeconfig-standard.yaml
  
  echo "📤 Uploading standard kubeconfig to S3..."
  upload_to_s3 "/tmp/kubeconfig-standard.yaml" "kubeconfig/$ENVIRONMENT-standard.yaml" "Standard kubeconfig"
fi

# CloudWatch Agent disabled to stay in free tier
# Uncomment below to enable monitoring (costs ~$2.60/month)
# echo "📊 Installing CloudWatch Agent..."
# wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
# dpkg -i -E ./amazon-cloudwatch-agent.deb
# 
# # Create CloudWatch Agent configuration
# cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CW_EOF'
# {
#   "agent": {
#     "metrics_collection_interval": 60,
#     "run_as_user": "cwagent"
#   },
#   "metrics": {
#     "namespace": "HealthApp/K3s",
#     "metrics_collected": {
#       "cpu": {
#         "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
#         "metrics_collection_interval": 60
#       },
#       "disk": {
#         "measurement": ["used_percent"],
#         "metrics_collection_interval": 60,
#         "resources": ["*"]
#       },
#       "mem": {
#         "measurement": ["mem_used_percent"],
#         "metrics_collection_interval": 60
#       }
#     }
#   },
#   "logs": {
#     "logs_collected": {
#       "files": {
#         "collect_list": [
#           {
#             "file_path": "/var/log/k3s-install.log",
#             "log_group_name": "/aws/ec2/health-app/k3s-install",
#             "log_stream_name": "{instance_id}"
#           }
#         ]
#       }
#     }
#   }
# }
# CW_EOF
# 
# # Start CloudWatch Agent
# /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
#   -a fetch-config \
#   -m ec2 \
#   -s \
#   -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
# 
# systemctl enable amazon-cloudwatch-agent
# echo "✅ CloudWatch monitoring enabled"

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

# Install NGINX Ingress Controller with timeout handling
echo "🌐 Installing NGINX Ingress Controller..."

# Apply with timeout and retry logic
for i in {1..3}; do
  echo "Attempt $i/3: Installing NGINX Ingress..."
  if timeout 120 kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml --insecure-skip-tls-verify; then
    echo "✅ NGINX Ingress installed successfully"
    break
  else
    echo "⚠️ Attempt $i failed, retrying..."
    if [ $i -eq 3 ]; then
      echo "⚠️ NGINX Ingress installation had timeouts, but core components likely created"
      echo "Checking what was created..."
      kubectl get all -n ingress-nginx --insecure-skip-tls-verify || true
    fi
    sleep 30
  fi
done

# Create missing ServiceAccount if needed
echo "🔧 Ensuring ServiceAccount exists..."
kubectl create serviceaccount ingress-nginx-admission -n ingress-nginx --insecure-skip-tls-verify 2>/dev/null || echo "ServiceAccount already exists or created"

# Wait for ingress controller to be ready
echo "⏳ Waiting for ingress controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s --insecure-skip-tls-verify || echo "⚠️ Ingress controller may still be starting"

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
if kubectl get namespace health-app-$ENVIRONMENT --insecure-skip-tls-verify 2>/dev/null; then
  kubectl apply -f /tmp/test-deployment.yaml --insecure-skip-tls-verify
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
if kubectl get nodes --insecure-skip-tls-verify > /dev/null 2>&1; then
    echo "$(date): ✅ K3s API server is responding" >> $LOG_FILE
else
    echo "$(date): ❌ K3s API server not responding" >> $LOG_FILE
fi

# Check node status
NODE_STATUS=$(kubectl get nodes --no-headers --insecure-skip-tls-verify | awk '{print $2}')
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
echo "Public IP: $PUBLIC_IP"
echo ""
echo "=== Node Status ==="
kubectl get nodes -o wide --insecure-skip-tls-verify
echo ""
echo "=== Namespaces ==="
kubectl get namespaces --insecure-skip-tls-verify
echo ""
echo "=== All Pods ==="
kubectl get pods -A --insecure-skip-tls-verify
echo ""
echo "=== Services ==="
kubectl get services -A --insecure-skip-tls-verify
echo ""
echo "=== Ingress Controller ==="
kubectl get pods -n ingress-nginx --insecure-skip-tls-verify
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
    kubectl get nodes --insecure-skip-tls-verify
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

if kubectl get nodes --insecure-skip-tls-verify > /dev/null 2>&1; then
    echo "✅ K3s API server: OK"
else
    echo "❌ K3s API server: FAILED"
fi

if kubectl get pods -A --insecure-skip-tls-verify > /dev/null 2>&1; then
    echo "✅ Pod listing: OK"
else
    echo "❌ Pod listing: FAILED"
fi

# Final status
echo "🎉 K3s cluster setup completed!"
echo "Cluster: $CLUSTER_NAME"
echo "Environment: $ENVIRONMENT"
echo "Network Tier: $NETWORK_TIER"
echo "Public IP: $PUBLIC_IP"

echo "📋 Available scripts:"
echo "  - /home/ubuntu/cluster-info.sh - Show cluster information"
echo "  - /home/ubuntu/monitor-k3s.sh - Health monitoring (runs every 5 minutes)"
echo "  - /home/ubuntu/restart-k3s.sh - Restart K3s cluster"

# Comprehensive K3s diagnostics for troubleshooting
echo "=== COMPREHENSIVE K3S DIAGNOSTICS ==="
echo "Generated at: $(date)"
echo ""

# 1. Network and IP information
echo "=== NETWORK INFORMATION ==="
echo "🌐 Hostname and IPs:"
hostname -I || echo "hostname -I failed"
echo "🌐 Public IP: $PUBLIC_IP"
echo "🌐 Network interfaces:"
ip addr show | grep -E "inet |UP|DOWN" || echo "ip addr failed"
echo ""

# 2. K3s service status
echo "=== K3S SERVICE STATUS ==="
echo "🔧 Service status:"
systemctl status k3s --no-pager || echo "systemctl status failed"
echo ""
echo "🔧 Service is-active:"
systemctl is-active k3s || echo "Service not active"
echo "🔧 Service is-enabled:"
systemctl is-enabled k3s || echo "Service not enabled"
echo ""

# 3. K3s process information
echo "=== K3S PROCESS INFORMATION ==="
echo "🔍 K3s processes:"
ps aux | grep k3s | grep -v grep || echo "No K3s processes found"
echo ""
echo "🔍 Process tree:"
pstree -p | grep k3s || echo "No K3s in process tree"
echo ""

# 4. Network listening ports
echo "=== NETWORK PORTS ==="
echo "🔌 Ports listening on 6443:"
sudo ss -tulnp | grep 6443 || echo "Port 6443 not listening"
echo "🔌 All K3s related ports:"
sudo ss -tulnp | grep k3s || echo "No K3s ports found"
echo "🔌 All listening ports:"
sudo ss -tuln | head -20
echo ""

# 5. Kubeconfig analysis
echo "=== KUBECONFIG ANALYSIS ==="
echo "📋 Kubeconfig file info:"
ls -la /etc/rancher/k3s/k3s.yaml 2>/dev/null || echo "Kubeconfig file not found"
echo "📋 Server URL in kubeconfig:"
cat /etc/rancher/k3s/k3s.yaml | grep server || echo "No server line found"
echo "📋 Kubeconfig permissions:"
stat -c "%a %n" /etc/rancher/k3s/k3s.yaml 2>/dev/null || echo "Cannot stat kubeconfig"
echo ""

# 6. K3s logs (recent)
echo "=== K3S LOGS (LAST 50 LINES) ==="
echo "📜 Recent K3s service logs:"
sudo journalctl -u k3s -n 50 --no-pager || echo "Cannot read K3s logs"
echo ""

# 7. K3s installation log
echo "=== K3S INSTALLATION LOG (LAST 30 LINES) ==="
echo "📜 Installation log:"
tail -30 /var/log/k3s-install.log 2>/dev/null || echo "No installation log found"
echo ""

# 8. Kubernetes API connectivity test
echo "=== KUBERNETES API TESTS ==="
echo "🔍 Local API test (127.0.0.1):"
curl -k -s --connect-timeout 5 https://127.0.0.1:6443/version || echo "Local API not responding"
echo "🔍 External API test ($PUBLIC_IP):"
curl -k -s --connect-timeout 5 https://$PUBLIC_IP:6443/version || echo "External API not responding"
echo "🔍 kubectl cluster-info:"
kubectl cluster-info --insecure-skip-tls-verify 2>/dev/null || echo "kubectl cluster-info failed"
echo "🔍 kubectl get nodes:"
kubectl get nodes --insecure-skip-tls-verify 2>/dev/null || echo "kubectl get nodes failed"
echo ""

# 9. System resources
echo "=== SYSTEM RESOURCES ==="
echo "📊 Memory usage:"
free -h || echo "free command failed"
echo "📊 Disk usage:"
df -h / || echo "df command failed"
echo "📊 Load average:"
uptime || echo "uptime command failed"
echo ""

# 10. DNS and connectivity
echo "=== DNS AND CONNECTIVITY ==="
echo "🌐 DNS resolution test:"
nslookup kubernetes.default.svc.cluster.local 2>/dev/null || echo "DNS resolution failed"
echo "🌐 Internet connectivity:"
ping -c 2 8.8.8.8 2>/dev/null || echo "Internet connectivity failed"
echo ""

# 11. K3s configuration files
echo "=== K3S CONFIGURATION ==="
echo "📁 K3s data directory:"
ls -la /var/lib/rancher/k3s/ 2>/dev/null || echo "K3s data directory not found"
echo "📁 K3s config directory:"
ls -la /etc/rancher/k3s/ 2>/dev/null || echo "K3s config directory not found"
echo ""

# 12. Container runtime
echo "=== CONTAINER RUNTIME ==="
echo "📦 Containerd status:"
sudo ctr version 2>/dev/null || echo "Containerd not accessible"
echo "📦 Running containers:"
sudo ctr containers list 2>/dev/null | head -10 || echo "Cannot list containers"
echo ""

# 13. Firewall and security
echo "=== SECURITY AND FIREWALL ==="
echo "🔥 UFW status:"
sudo ufw status 2>/dev/null || echo "UFW not available"
echo "🔥 Iptables rules (K3s related):"
sudo iptables -L | grep -i k3s || echo "No K3s iptables rules found"
echo ""

# 14. Final status summary
echo "=== FINAL STATUS SUMMARY ==="
echo "📋 Environment: $ENVIRONMENT"
echo "📋 Network Tier: $NETWORK_TIER"
echo "📋 Public IP: $PUBLIC_IP"
echo "📋 Cluster Name: $CLUSTER_NAME"
echo "📋 Installation Time: $(date)"

# Test final connectivity
if kubectl get nodes --insecure-skip-tls-verify >/dev/null 2>&1; then
    echo "✅ K3S STATUS: HEALTHY - API responding"
    kubectl get nodes --insecure-skip-tls-verify
else
    echo "❌ K3S STATUS: UNHEALTHY - API not responding"
fi

if systemctl is-active --quiet k3s; then
    echo "✅ SERVICE STATUS: ACTIVE"
else
    echo "❌ SERVICE STATUS: INACTIVE"
fi

if [ -f /etc/rancher/k3s/k3s.yaml ]; then
    echo "✅ KUBECONFIG: EXISTS"
else
    echo "❌ KUBECONFIG: MISSING"
fi

echo "SUCCESS" > /var/log/k3s-install-complete
echo "K3S_INSTALLATION_COMPLETE=$(date)" >> /var/log/k3s-ready
echo "=== K3S INSTALLATION COMPLETED ==="
date

echo "📊 System ready for connections"
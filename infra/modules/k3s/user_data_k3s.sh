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
sleep 5

# Fix kubeconfig server endpoint
sed -i "s|https://127.0.0.1:6443|https://$PUBLIC_IP:6443|g" /etc/rancher/k3s/k3s.yaml
sed -i "s|server: https://0.0.0.0:6443|server: https://$PUBLIC_IP:6443|g" /etc/rancher/k3s/k3s.yaml

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Wait for K3s ready
for i in {1..60}; do
  if kubectl get nodes --insecure-skip-tls-verify > /dev/null 2>&1; then
    echo "K3s ready!"
    break
  fi
  sleep 10
done

sleep 60

# Create namespaces
if [[ "$ENVIRONMENT" == "dev" ]] || [[ "$NETWORK_TIER" == "lower" ]]; then
  kubectl create namespace health-app-dev --insecure-skip-tls-verify || true
  kubectl create namespace health-app-test --insecure-skip-tls-verify || true
elif [[ "$ENVIRONMENT" == "prod" ]] || [[ "$NETWORK_TIER" == "higher" ]]; then
  kubectl create namespace health-app-prod --insecure-skip-tls-verify || true
elif [[ "$ENVIRONMENT" == "monitoring" ]]; then
  kubectl create namespace monitoring --insecure-skip-tls-verify || true
  kubectl create namespace health-app-monitoring --insecure-skip-tls-verify || true
fi

# Service account for GitHub Actions
kubectl create namespace gha-access --insecure-skip-tls-verify || true
kubectl create serviceaccount gha-deployer -n gha-access --insecure-skip-tls-verify || true

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

kubectl create clusterrolebinding gha-deployer-binding --clusterrole=gha-deployer-role --serviceaccount=gha-access:gha-deployer --insecure-skip-tls-verify || true

TOKEN=$(kubectl create token gha-deployer -n gha-access --duration=8760h --insecure-skip-tls-verify)

# Create kubeconfig for GitHub Actions
if [[ -n "$TOKEN" && -n "$S3_BUCKET" ]]; then
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

  aws s3 cp /tmp/gha-kubeconfig.yaml "s3://$S3_BUCKET/kubeconfig/$ENVIRONMENT-gha.yaml"
  
  # Standard kubeconfig
  cp /etc/rancher/k3s/k3s.yaml /tmp/kubeconfig-standard.yaml
  sed -i "s|https://127.0.0.1:6443|https://$PUBLIC_IP:6443|g" /tmp/kubeconfig-standard.yaml
  aws s3 cp /tmp/kubeconfig-standard.yaml "s3://$S3_BUCKET/kubeconfig/$ENVIRONMENT-standard.yaml"
fi

# Setup local access
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> /home/ubuntu/.bashrc
echo 'alias k="kubectl"' >> /home/ubuntu/.bashrc

# Install NGINX Ingress
for i in {1..3}; do
  if timeout 120 kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml --insecure-skip-tls-verify; then
    break
  fi
  sleep 30
done

kubectl create serviceaccount ingress-nginx-admission -n ingress-nginx --insecure-skip-tls-verify 2>/dev/null || true

# Test deployment
if kubectl get namespace health-app-$ENVIRONMENT --insecure-skip-tls-verify 2>/dev/null; then
  cat <<EOF | kubectl apply -f - --insecure-skip-tls-verify
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
fi

# Health monitoring
cat > /home/ubuntu/monitor-k3s.sh << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/k3s-health.log"
echo "$(date): Checking K3s health..." >> $LOG_FILE

if systemctl is-active --quiet k3s; then
    echo "$(date): ✅ K3s service active" >> $LOG_FILE
else
    echo "$(date): ❌ Restarting K3s..." >> $LOG_FILE
    systemctl restart k3s >> $LOG_FILE 2>&1
    sleep 30
fi

if kubectl get nodes --insecure-skip-tls-verify > /dev/null 2>&1; then
    echo "$(date): ✅ API responding" >> $LOG_FILE
else
    echo "$(date): ❌ API not responding" >> $LOG_FILE
fi

tail -100 $LOG_FILE > /tmp/k3s-health.tmp && mv /tmp/k3s-health.tmp $LOG_FILE
EOF

chmod +x /home/ubuntu/monitor-k3s.sh
chown ubuntu:ubuntu /home/ubuntu/monitor-k3s.sh
echo "*/5 * * * * /home/ubuntu/monitor-k3s.sh" | crontab -u ubuntu -

# Cluster info script
cat > /home/ubuntu/cluster-info.sh << 'EOF'
#!/bin/bash
echo "=== K3s Cluster Information ==="
echo "Environment: $ENVIRONMENT"
echo "Public IP: $PUBLIC_IP"
kubectl get nodes -o wide --insecure-skip-tls-verify
kubectl get namespaces --insecure-skip-tls-verify
kubectl get pods -A --insecure-skip-tls-verify
EOF

chmod +x /home/ubuntu/cluster-info.sh
chown ubuntu:ubuntu /home/ubuntu/cluster-info.sh

echo "SUCCESS" > /var/log/k3s-install-complete
echo "K3S_INSTALLATION_COMPLETE=$(date)" >> /var/log/k3s-ready
echo "=== K3S INSTALLATION COMPLETED ==="
date
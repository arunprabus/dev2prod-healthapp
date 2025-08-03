#!/bin/bash

# Setup NGINX Ingress + cert-manager for K3s
# Domain: sharpzeal.com

set -e

ENVIRONMENT=${1:-dev}
DOMAIN="sharpzeal.com"
EMAIL="admin@sharpzeal.com"

echo "🚀 Setting up ingress for $ENVIRONMENT environment"
echo "📋 Domain: health-api.$DOMAIN"
echo "📧 Email: $EMAIL"

# Check if kubectl is working
if ! kubectl get nodes > /dev/null 2>&1; then
    echo "❌ kubectl not configured. Run kubeconfig setup first."
    exit 1
fi

# Get cluster IP for DNS setup
CLUSTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$CLUSTER_IP" ]; then
    CLUSTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

echo "📍 Cluster IP: $CLUSTER_IP"

# 1. Install NGINX Ingress Controller
echo "📦 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for ingress controller
echo "⏳ Waiting for NGINX Ingress Controller..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# 2. Install cert-manager
echo "📦 Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Wait for cert-manager
echo "⏳ Waiting for cert-manager..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=300s

# 3. Create namespace if not exists
kubectl create namespace health-app-$ENVIRONMENT --dry-run=client -o yaml | kubectl apply -f -

# 4. Apply ClusterIssuer
echo "🔐 Creating Let's Encrypt ClusterIssuer..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# 5. Create ingress
echo "🌐 Creating ingress for health-api.$DOMAIN..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: health-api-ingress
  namespace: health-app-$ENVIRONMENT
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - health-api.$DOMAIN
    secretName: health-api-tls
  rules:
  - host: health-api.$DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: health-api-service
            port:
              number: 80
EOF

echo ""
echo "✅ Ingress setup complete!"
echo ""
echo "📋 Next Steps:"
echo "1. 🌐 DNS Setup in Namecheap:"
echo "   - Go to Namecheap DNS settings for sharpzeal.com"
echo "   - Add A record: health-api -> $CLUSTER_IP"
echo ""
echo "2. 🚀 Deploy your application:"
echo "   kubectl apply -f k8s/health-api-complete.yaml"
echo ""
echo "3. 🔍 Check certificate status:"
echo "   kubectl get certificate -n health-app-$ENVIRONMENT"
echo ""
echo "4. 🌍 Access your app:"
echo "   https://health-api.sharpzeal.com"
echo ""
echo "⏳ SSL certificate will be issued automatically after DNS propagation (5-10 minutes)"
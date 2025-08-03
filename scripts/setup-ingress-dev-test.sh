#!/bin/bash

# Setup NGINX Ingress + cert-manager for dev/test environments
# Domains: dev.sharpzeal.com, test.sharpzeal.com

set -e

ENVIRONMENT=${1:-dev}
DOMAIN="sharpzeal.com"
EMAIL="admin@sharpzeal.com"

echo "🚀 Setting up ingress for $ENVIRONMENT environment"
echo "📋 Domain: $ENVIRONMENT.$DOMAIN"
echo "📧 Email: $EMAIL"

# Check if kubectl is working
if ! kubectl get nodes > /dev/null 2>&1; then
    echo "❌ kubectl not configured. Run kubeconfig setup first."
    exit 1
fi

# 1. Install NGINX Ingress Controller (if not exists)
if ! kubectl get namespace ingress-nginx > /dev/null 2>&1; then
    echo "📦 Installing NGINX Ingress Controller..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    
    echo "⏳ Waiting for NGINX Ingress Controller..."
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=300s
else
    echo "✅ NGINX Ingress Controller already installed"
fi

# 2. Install cert-manager (if not exists)
if ! kubectl get namespace cert-manager > /dev/null 2>&1; then
    echo "📦 Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    
    echo "⏳ Waiting for cert-manager..."
    kubectl wait --namespace cert-manager \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/instance=cert-manager \
      --timeout=300s
else
    echo "✅ cert-manager already installed"
fi

# 3. Create namespace
kubectl create namespace health-app-$ENVIRONMENT --dry-run=client -o yaml | kubectl apply -f -

# 4. Apply ClusterIssuer (if not exists)
if ! kubectl get clusterissuer letsencrypt-prod > /dev/null 2>&1; then
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
else
    echo "✅ ClusterIssuer already exists"
fi

# 5. Create ingress for the environment
echo "🌐 Creating ingress for $ENVIRONMENT.$DOMAIN..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: health-api-ingress-$ENVIRONMENT
  namespace: health-app-$ENVIRONMENT
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - $ENVIRONMENT.$DOMAIN
    secretName: health-api-tls-$ENVIRONMENT
  rules:
  - host: $ENVIRONMENT.$DOMAIN
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
echo "✅ Ingress setup complete for $ENVIRONMENT!"
echo ""
echo "📋 Status Check:"
kubectl get ingress -n health-app-$ENVIRONMENT
echo ""
echo "🔍 Certificate Status:"
kubectl get certificate -n health-app-$ENVIRONMENT 2>/dev/null || echo "Certificate will be created after first request"
echo ""
echo "🌍 Your URL: https://$ENVIRONMENT.sharpzeal.com"
echo "⏳ SSL certificate will be issued automatically (5-10 minutes)"
#!/bin/bash

# Setup NGINX Ingress + cert-manager for network tiers
# Usage: ./setup-ingress-network.sh [lower|higher|monitoring]

set -e

NETWORK_TIER=${1:-lower}
DOMAIN="sharpzeal.com"
EMAIL="admin@sharpzeal.com"

echo "🚀 Setting up ingress for $NETWORK_TIER network"
echo "📋 Domain: $NETWORK_TIER.$DOMAIN"

# Check kubectl
if ! kubectl get nodes > /dev/null 2>&1; then
    echo "❌ kubectl not configured"
    exit 1
fi

# Install NGINX Ingress (if needed)
if ! kubectl get namespace ingress-nginx > /dev/null 2>&1; then
    echo "📦 Installing NGINX Ingress..."
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s
fi

# Install cert-manager (if needed)
if ! kubectl get namespace cert-manager > /dev/null 2>&1; then
    echo "📦 Installing cert-manager..."
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml
    kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app.kubernetes.io/instance=cert-manager --timeout=300s
fi

# Create namespace
kubectl create namespace health-app-$NETWORK_TIER --dry-run=client -o yaml | kubectl apply -f -

# Create ClusterIssuer (if needed)
if ! kubectl get clusterissuer letsencrypt-prod > /dev/null 2>&1; then
    echo "🔐 Creating ClusterIssuer..."
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
fi

# Create ingress
echo "🌐 Creating ingress for $NETWORK_TIER.$DOMAIN..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: health-api-ingress-$NETWORK_TIER
  namespace: health-app-$NETWORK_TIER
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - $NETWORK_TIER.$DOMAIN
    secretName: health-api-tls-$NETWORK_TIER
  rules:
  - host: $NETWORK_TIER.$DOMAIN
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
echo "✅ Ingress ready for $NETWORK_TIER network"
echo "🌍 URL: https://$NETWORK_TIER.sharpzeal.com"
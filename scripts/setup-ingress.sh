#!/bin/bash
set -e

ENVIRONMENT=${1:-dev}
DOMAIN="sharpzeal.com"
EMAIL="admin@sharpzeal.com"

echo "🚀 Setting up ingress for $ENVIRONMENT environment"
echo "📋 Domain: $ENVIRONMENT.$DOMAIN"
echo "📧 Email: $EMAIL"

# Setup kubectl - try multiple sources
if [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
elif [ -f "./kubeconfig-$ENVIRONMENT" ]; then
    export KUBECONFIG=./kubeconfig-$ENVIRONMENT
else
    echo "❌ No kubeconfig found. Run this script on the K3s cluster."
    exit 1
fi

# Verify kubectl works
if ! kubectl get nodes > /dev/null 2>&1; then
    echo "❌ kubectl not working. Check kubeconfig."
    exit 1
fi

# Get cluster IP
CLUSTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$CLUSTER_IP" ]; then
    CLUSTER_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi
echo "📍 Cluster IP: $CLUSTER_IP"

# Install cert-manager
echo "📦 Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Wait for cert-manager
kubectl wait --namespace cert-manager --for=condition=ready pod --selector=app.kubernetes.io/instance=cert-manager --timeout=300s

# Create namespace
kubectl create namespace health-app-$ENVIRONMENT --dry-run=client -o yaml | kubectl apply -f -

# Create ClusterIssuer
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

# Create ingress
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
    - $ENVIRONMENT.$DOMAIN
    secretName: health-api-tls
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

echo "✅ Ingress setup complete!"
echo "📋 Add DNS record: $ENVIRONMENT -> $CLUSTER_IP"
echo "🌍 URL: https://$ENVIRONMENT.$DOMAIN"
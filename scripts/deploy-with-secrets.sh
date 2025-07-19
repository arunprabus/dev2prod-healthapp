#!/bin/bash
# Script to deploy an application with Kubernetes Secrets

# Default values
NAMESPACE="health-app-dev"
APP_NAME="health-api"
IMAGE="arunprabusiva/health-api:latest"
STRATEGY="standard" # standard or argo-rollouts
KUBECONFIG_PATH=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    --app)
      APP_NAME="$2"
      shift
      shift
      ;;
    --image)
      IMAGE="$2"
      shift
      shift
      ;;
    --strategy)
      STRATEGY="$2"
      shift
      shift
      ;;
    --kubeconfig)
      KUBECONFIG_PATH="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set KUBECONFIG if provided
if [[ -n "$KUBECONFIG_PATH" ]]; then
  export KUBECONFIG="$KUBECONFIG_PATH"
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "Creating namespace '$NAMESPACE'..."
  kubectl create namespace "$NAMESPACE"
fi

# Create secrets if they don't exist
if ! kubectl get secret app-credentials -n "$NAMESPACE" &>/dev/null; then
  echo "Creating app-credentials secret..."
  kubectl create secret generic app-credentials \
    --from-literal=db-password=changeme123 \
    --from-literal=api-key=default-api-key \
    --from-literal=jwt-secret=default-jwt-secret \
    -n "$NAMESPACE"
fi

if ! kubectl get secret aws-credentials -n "$NAMESPACE" &>/dev/null; then
  echo "Creating aws-credentials secret..."
  kubectl create secret generic aws-credentials \
    --from-literal=aws-access-key-id=default-access-key \
    --from-literal=aws-secret-access-key=default-secret-key \
    --from-literal=aws-region=ap-south-1 \
    -n "$NAMESPACE"
fi

# Deploy based on strategy
if [[ "$STRATEGY" == "standard" ]]; then
  echo "Deploying $APP_NAME using standard Kubernetes deployment..."
  
  # Create or update deployment
  if kubectl get deployment "$APP_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Updating existing deployment..."
    kubectl set image deployment/"$APP_NAME" "$APP_NAME=$IMAGE" -n "$NAMESPACE"
  else
    echo "Creating new deployment..."
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
  labels:
    app: $APP_NAME
spec:
  replicas: 2
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
      - name: $APP_NAME
        image: $IMAGE
        ports:
        - containerPort: 8080
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: db-password
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: api-key
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: jwt-secret
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: aws-access-key-id
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: aws-secret-access-key
        - name: AWS_REGION
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: aws-region
EOF
  fi
  
  # Create service if it doesn't exist
  if ! kubectl get service "$APP_NAME" -n "$NAMESPACE" &>/dev/null; then
    echo "Creating service..."
    kubectl expose deployment "$APP_NAME" --port=80 --target-port=8080 -n "$NAMESPACE" --type=ClusterIP
  fi
  
elif [[ "$STRATEGY" == "argo-rollouts" ]]; then
  echo "Deploying $APP_NAME using Argo Rollouts..."
  
  # Check if Argo Rollouts is installed
  if ! kubectl argo rollouts version &>/dev/null; then
    echo "Error: Argo Rollouts not installed or kubectl plugin not available"
    exit 1
  fi
  
  # Create rollout manifest
  cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
spec:
  replicas: 2
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
      - name: $APP_NAME
        image: $IMAGE
        ports:
        - containerPort: 8080
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: db-password
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: api-key
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: jwt-secret
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: aws-access-key-id
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: aws-secret-access-key
        - name: AWS_REGION
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: aws-region
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 30s}
      - setWeight: 40
      - pause: {duration: 30s}
      - setWeight: 60
      - pause: {duration: 30s}
      - setWeight: 80
      - pause: {duration: 30s}
EOF
  
  # Create services if they don't exist
  if ! kubectl get service "$APP_NAME-stable" -n "$NAMESPACE" &>/dev/null; then
    echo "Creating stable service..."
    kubectl create service clusterip "$APP_NAME-stable" --tcp=80:8080 -n "$NAMESPACE"
  fi
  
  if ! kubectl get service "$APP_NAME-canary" -n "$NAMESPACE" &>/dev/null; then
    echo "Creating canary service..."
    kubectl create service clusterip "$APP_NAME-canary" --tcp=80:8080 -n "$NAMESPACE"
  fi
else
  echo "Error: Unknown deployment strategy '$STRATEGY'"
  echo "Supported strategies: standard, argo-rollouts"
  exit 1
fi

# Wait for deployment to be ready
echo "Waiting for deployment to be ready..."
if [[ "$STRATEGY" == "standard" ]]; then
  kubectl rollout status deployment/"$APP_NAME" -n "$NAMESPACE" --timeout=120s
else
  kubectl argo rollouts get rollout "$APP_NAME" -n "$NAMESPACE" --watch
fi

echo "✅ Deployment completed successfully!"
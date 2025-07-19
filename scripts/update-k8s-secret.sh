#!/bin/bash
# Script to update Kubernetes secrets

# Default values
NAMESPACE="health-app-dev"
SECRET_NAME="app-credentials"
KEY=""
VALUE=""
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
    --secret)
      SECRET_NAME="$2"
      shift
      shift
      ;;
    --key)
      KEY="$2"
      shift
      shift
      ;;
    --value)
      VALUE="$2"
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

# Validate required parameters
if [[ -z "$KEY" || -z "$VALUE" ]]; then
  echo "Error: --key and --value are required"
  echo "Usage: $0 --namespace health-app-dev --secret app-credentials --key db-password --value newpassword [--kubeconfig /path/to/kubeconfig]"
  exit 1
fi

# Set KUBECONFIG if provided
if [[ -n "$KUBECONFIG_PATH" ]]; then
  export KUBECONFIG="$KUBECONFIG_PATH"
fi

# Check if secret exists
if ! kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &>/dev/null; then
  echo "Error: Secret '$SECRET_NAME' not found in namespace '$NAMESPACE'"
  exit 1
fi

# Get current secret data
echo "Getting current secret data..."
SECRET_DATA=$(kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" -o json)

# Extract all keys and values
KEYS=$(echo "$SECRET_DATA" | jq -r '.data | keys[]')
VALUES=()

for k in $KEYS; do
  if [[ "$k" == "$KEY" ]]; then
    # Use the new value for the key we're updating
    VALUES+=("--from-literal=$k=$VALUE")
  else
    # Get the existing value for other keys
    v=$(echo "$SECRET_DATA" | jq -r ".data.\"$k\"" | base64 --decode)
    VALUES+=("--from-literal=$k=$v")
  fi
done

# Create the updated secret
echo "Updating secret '$SECRET_NAME' in namespace '$NAMESPACE'..."
kubectl create secret generic "$SECRET_NAME" \
  ${VALUES[@]} \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret '$SECRET_NAME' updated successfully"
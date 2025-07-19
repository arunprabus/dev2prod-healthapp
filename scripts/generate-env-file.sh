#!/bin/bash
# Script to generate .env file from Kubernetes secrets

# Default values
NAMESPACE="health-app-dev"
OUTPUT_FILE=".env"
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
    --output)
      OUTPUT_FILE="$2"
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
  echo "Error: Namespace '$NAMESPACE' not found"
  exit 1
fi

# Check if secrets exist
if ! kubectl get secret app-credentials -n "$NAMESPACE" &>/dev/null; then
  echo "Error: Secret 'app-credentials' not found in namespace '$NAMESPACE'"
  exit 1
fi

if ! kubectl get secret aws-credentials -n "$NAMESPACE" &>/dev/null; then
  echo "Error: Secret 'aws-credentials' not found in namespace '$NAMESPACE'"
  exit 1
fi

if ! kubectl get configmap nodejs-config -n "$NAMESPACE" &>/dev/null; then
  echo "Error: ConfigMap 'nodejs-config' not found in namespace '$NAMESPACE'"
  exit 1
fi

echo "Generating .env file from Kubernetes secrets and configmaps..."

# Create .env file header
cat > "$OUTPUT_FILE" << EOF
# Auto-generated .env file from Kubernetes secrets
# Generated on $(date)
# Namespace: $NAMESPACE

EOF

# Add ConfigMap data
echo "# ConfigMap: nodejs-config" >> "$OUTPUT_FILE"
kubectl get configmap nodejs-config -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key)=\(.value)"' >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Add app-credentials secrets
echo "# Secret: app-credentials" >> "$OUTPUT_FILE"
kubectl get secret app-credentials -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key)=\(.value | @base64d)"' >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Add aws-credentials secrets
echo "# Secret: aws-credentials" >> "$OUTPUT_FILE"
kubectl get secret aws-credentials -n "$NAMESPACE" -o jsonpath='{.data}' | jq -r 'to_entries[] | "\(.key)=\(.value | @base64d)"' >> "$OUTPUT_FILE"

echo "✅ .env file generated successfully: $OUTPUT_FILE"
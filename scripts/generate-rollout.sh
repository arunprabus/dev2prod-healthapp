#!/bin/bash
# Script to generate Argo Rollout manifests with appropriate parameters

# Default values
NAMESPACE="health-app-dev"
IMAGE="docker.io/your-username/health-api"
TAG="latest"
STRATEGY_TYPE="canary"
TRAFFIC_ROUTER="istio"
DOMAIN_NAME="dev.health-app.local"
ENABLE_ISTIO=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --namespace)
      NAMESPACE="$2"
      shift
      shift
      ;;
    --image)
      IMAGE="$2"
      shift
      shift
      ;;
    --tag)
      TAG="$2"
      shift
      shift
      ;;
    --strategy)
      STRATEGY_TYPE="$2"
      shift
      shift
      ;;
    --router)
      TRAFFIC_ROUTER="$2"
      shift
      shift
      ;;
    --domain)
      DOMAIN_NAME="$2"
      shift
      shift
      ;;
    --enable-istio)
      ENABLE_ISTIO="$2"
      shift
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Create output directory if it doesn't exist
OUTPUT_DIR="k8s/generated"
mkdir -p $OUTPUT_DIR

# Generate the rollout manifest
echo "Generating rollout manifest for namespace: $NAMESPACE"

# Prepare the Istio VirtualService if enabled
if [ "$ENABLE_ISTIO" = "true" ]; then
  ISTIO_VS=$(cat k8s/istio-virtual-service.yaml | sed "s/\${NAMESPACE}/$NAMESPACE/g" | sed "s/\${DOMAIN_NAME}/$DOMAIN_NAME/g")
else
  ISTIO_VS=""
fi

# Generate the rollout manifest
cat k8s/health-api-rollout.yaml | \
  sed "s/\${NAMESPACE}/$NAMESPACE/g" | \
  sed "s/\${IMAGE}/$IMAGE/g" | \
  sed "s/\${TAG}/$TAG/g" | \
  sed "s/\${STRATEGY_TYPE}/$STRATEGY_TYPE/g" | \
  sed "s/\${TRAFFIC_ROUTER}/$TRAFFIC_ROUTER/g" | \
  sed "s/\${ISTIO_VIRTUAL_SERVICE}/$ISTIO_VS/g" \
  > $OUTPUT_DIR/health-api-rollout-$NAMESPACE.yaml

echo "Generated rollout manifest: $OUTPUT_DIR/health-api-rollout-$NAMESPACE.yaml"
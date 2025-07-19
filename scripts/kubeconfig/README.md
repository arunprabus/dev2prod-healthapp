# Kubeconfig Files

This directory contains kubeconfig files for connecting to Kubernetes clusters.

## Files

- `kubeconfig-fixed.yaml` - Fixed kubeconfig with proper server address
- `kubeconfig-lower.yaml` - Kubeconfig for lower network (dev/test environments)
- `kubeconfig-lower-fixed.yaml` - Fixed kubeconfig for lower network
- `kubeconfig-simple.yaml` - Simplified kubeconfig for testing

## Usage

To use these kubeconfig files:

```bash
# Set the KUBECONFIG environment variable
export KUBECONFIG=/path/to/kubeconfig-file.yaml

# Test the connection
kubectl get nodes
```

## Generating Kubeconfig

Use the scripts in the parent directory to generate kubeconfig files:

```bash
# Generate kubeconfig for an environment
../generate-kubeconfig.sh lower 1.2.3.4

# Fix kubeconfig issues
../fix-kubeconfig.sh
```

## GitHub Secrets

To update GitHub secrets with kubeconfig files:

```bash
# Use the update-github-secrets script
../update-github-secrets.sh update-kubeconfig dev kubeconfig-lower.yaml
```
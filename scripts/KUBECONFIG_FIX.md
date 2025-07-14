# 🔧 Fix kubectl "localhost:8080" Error

## Problem
```
The connection to the server localhost:8080 was refused
```

## Quick Fix

```bash
# Set your SSH private key
export SSH_PRIVATE_KEY="$(cat ~/.ssh/k3s-key)"

# Fix kubeconfig (replace with your cluster IP)
./scripts/fix-kubeconfig.sh 43.205.211.129

# Test it works
kubectl get nodes
```

## Or use health check with auto-fix
```bash
export SSH_PRIVATE_KEY="$(cat ~/.ssh/k3s-key)"
./scripts/k8s-cluster-health-check.sh dev 43.205.211.129 --fix-kubeconfig
```

## What it does
1. Downloads `/etc/rancher/k3s/k3s.yaml` from cluster
2. Replaces `127.0.0.1` with actual cluster IP
3. Saves to `~/.kube/config`
4. Tests connection

## Alternative: Manual S3 method
```bash
# Upload from cluster
sudo aws s3 cp /etc/rancher/k3s/k3s.yaml s3://your-bucket/kubeconfig

# Download and fix
aws s3 cp s3://your-bucket/kubeconfig ~/.kube/config
sed -i "s/127.0.0.1/YOUR_CLUSTER_IP/g" ~/.kube/config
```
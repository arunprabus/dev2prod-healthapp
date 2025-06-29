# 🆓 100% Free Tier Kubernetes Setup

## What This Deploys

### ✅ Completely Free Resources:
- **EC2 t2.micro** with K3s (lightweight Kubernetes)
- **RDS db.t3.micro** MySQL database
- **VPC** with public/private subnets
- **Security Groups** and networking

### 💰 Total Cost: $0/month (within free tier limits)

## Quick Start

### 1. Add Your SSH Key
Edit `variables.tf` and replace the SSH public key:
```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -f ~/.ssh/aws-key

# Copy your public key
cat ~/.ssh/aws-key.pub
```

### 2. Deploy
```bash
make init-free
make apply-free
```

### 3. Connect to Your Kubernetes Cluster
```bash
# SSH to the K3s master
ssh -i ~/.ssh/aws-key ubuntu@<MASTER_IP>

# Or copy kubeconfig locally
scp -i ~/.ssh/aws-key ubuntu@<MASTER_IP>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

### 4. Test Your Setup
```bash
# Visit the test nginx app
curl http://<MASTER_IP>:30080

# Or open in browser
open http://<MASTER_IP>:30080
```

## What You Get

### K3s Kubernetes Cluster
- Single-node cluster on t2.micro
- Pre-installed kubectl and helm
- Test nginx deployment running
- Ready for your applications

### MySQL Database
- RDS db.t3.micro instance
- 20GB storage (free tier limit)
- Accessible from K3s cluster

### Networking
- Isolated VPC
- Public subnet for K3s master
- Private subnets for database
- Security groups configured

## Deploy Your Health App

### 1. Create Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-api
  namespace: health-app-free-tier
spec:
  replicas: 1
  selector:
    matchLabels:
      app: health-api
  template:
    metadata:
      labels:
        app: health-api
    spec:
      containers:
      - name: health-api
        image: your-health-api:latest
        ports:
        - containerPort: 8080
```

### 2. Apply to Cluster
```bash
kubectl apply -f health-api-deployment.yaml
```

## Free Tier Limits

### EC2 t2.micro
- **750 hours/month** (24/7 for 31 days)
- **1 vCPU, 1GB RAM**
- Perfect for learning and small apps

### RDS db.t3.micro
- **750 hours/month**
- **20GB storage maximum**
- **1 vCPU, 1GB RAM**

## Cleanup When Done
```bash
make destroy-free
```

## Advantages Over EKS

| Feature | EKS | K3s on EC2 |
|---------|-----|------------|
| **Cost** | $73/month | $0/month |
| **Setup Time** | 15-20 min | 5-10 min |
| **Learning** | Production-like | Kubernetes fundamentals |
| **Resources** | Multiple nodes | Single node |
| **Complexity** | High | Low |

**Perfect for learning Kubernetes without the EKS cost!**
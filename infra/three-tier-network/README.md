# Three-Tier Network Architecture

This directory contains the Terraform configuration for the three-tier network architecture of the Health App platform:

1. **Lower Network** - Contains Dev and Test environments with shared database
2. **Higher Network** - Contains Production environment with dedicated database
3. **Monitoring Network** - Contains centralized monitoring and connects to both networks

## Network Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AWS Region: ap-south-1                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                   LOWER NETWORK (10.0.0.0/16)                       │ │
│ │ ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────────────┐ │ │
│ │ │   DEV ENV   │  │  TEST ENV   │  │        SHARED DATABASE          │ │ │
│ │ │ K3s Cluster │  │ K3s Cluster │  │     RDS (db.t3.micro)          │ │ │
│ │ │ + Runner    │  │ + Runner    │  │                                 │ │ │
│ │ │ t2.micro    │  │ t2.micro    │  │                                 │ │ │
│ │ └─────────────┘  └─────────────┘  └─────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                   HIGHER NETWORK (10.1.0.0/16)                      │ │
│ │ ┌─────────────┐                    ┌─────────────────────────────────┐ │ │
│ │ │  PROD ENV   │                    │     DEDICATED DATABASE          │ │ │
│ │ │ K3s Cluster │                    │     RDS (db.t3.micro)          │ │ │
│ │ │ + Runner    │                    │                                 │ │ │
│ │ │ t2.micro    │                    │                                 │ │ │
│ │ └─────────────┘                    └─────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
│ ┌─────────────────────────────────────────────────────────────────────┐ │
│ │                 MONITORING NETWORK (10.2.0.0/16)                    │ │
│ │ ┌─────────────────────────────────────────────────────────────────┐   │ │
│ │ │              MONITORING CLUSTER                                 │   │ │
│ │ │         Prometheus + Grafana + Runner                          │   │ │
│ │ │                t2.micro                                        │   │ │
│ │ │                                                                │   │ │
│ │ │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │   │ │
│ │ │  │GitHub Runner│    │GitHub Runner│    │GitHub Runner│        │   │ │
│ │ │  │awsgithubrunner│  │awsgithubrunner│  │awsgithubrunner│      │   │ │
│ │ │  └─────────────┘    └─────────────┘    └─────────────┘        │   │ │
│ │ └─────────────────────────────────────────────────────────────────┘   │ │
│ └─────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

## Deployment Instructions

### Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform CLI (v1.6.0 or later)
3. SSH key pair generated

### Deploying Infrastructure

```bash
# Deploy Lower Network (Dev + Test)
terraform init
terraform apply -var-file="environments/lower.tfvars"

# Deploy Higher Network (Production)
terraform init
terraform apply -var-file="environments/higher.tfvars"

# Deploy Monitoring Network
terraform init
terraform apply -var-file="environments/monitoring.tfvars"
```

### Connecting to Clusters

After deployment, you can connect to the clusters using the SSH key:

```bash
# Connect to Dev Cluster
ssh -i ~/.ssh/k3s-key ubuntu@<dev_k3s_public_ip>

# Connect to Test Cluster
ssh -i ~/.ssh/k3s-key ubuntu@<test_k3s_public_ip>

# Connect to Production Cluster
ssh -i ~/.ssh/k3s-key ubuntu@<prod_k3s_public_ip>

# Connect to Monitoring Cluster
ssh -i ~/.ssh/k3s-key ubuntu@<monitoring_k3s_public_ip>
```

### Getting Kubeconfig

To get the kubeconfig for a cluster:

```bash
# Download kubeconfig
scp -i ~/.ssh/k3s-key ubuntu@<cluster_public_ip>:/etc/rancher/k3s/k3s.yaml ./kubeconfig.yaml

# Replace 127.0.0.1 with the cluster's public IP
sed -i 's/127.0.0.1/<cluster_public_ip>/g' ./kubeconfig.yaml

# Use the kubeconfig
export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
```
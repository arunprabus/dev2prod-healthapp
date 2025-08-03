# 🎓 Kubernetes Learning Guide

## 🏗️ **K3s Architecture Overview**

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS EC2 Instance                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                K3s Master Node                          │ │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐ │ │
│  │ │   API       │ │  Scheduler  │ │    Controller       │ │ │
│  │ │   Server    │ │             │ │    Manager          │ │ │
│  │ └─────────────┘ └─────────────┘ └─────────────────────┘ │ │
│  │ ┌─────────────────────────────────────────────────────┐ │ │
│  │ │                   etcd                              │ │ │
│  │ └─────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                K3s Worker Node                          │ │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐ │ │
│  │ │   kubelet   │ │ kube-proxy  │ │    containerd       │ │ │
│  │ └─────────────┘ └─────────────┘ └─────────────────────┘ │ │
│  │ ┌─────────────────────────────────────────────────────┐ │ │
│  │ │                    Pods                             │ │ │
│  │ │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │ │ │
│  │ │  │health-api│  │frontend │  │database │             │ │ │
│  │ │  └─────────┘  └─────────┘  └─────────┘             │ │ │
│  │ └─────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 **Key Kubernetes Components**

### **Control Plane (Master)**
- **API Server**: Entry point for all REST commands
- **Scheduler**: Assigns pods to nodes
- **Controller Manager**: Manages cluster state
- **etcd**: Distributed key-value store

### **Worker Node**
- **kubelet**: Node agent that manages pods
- **kube-proxy**: Network proxy
- **containerd**: Container runtime

## 📦 **Kubernetes Objects Hierarchy**

```
Cluster
├── Namespaces (logical separation)
│   ├── health-app-dev
│   ├── health-app-test
│   └── health-app-prod
│
├── Deployments (manage replica sets)
│   └── health-api-backend-dev
│       └── ReplicaSet (manages pods)
│           ├── Pod 1 (health-api container)
│           ├── Pod 2 (health-api container)
│           └── Pod 3 (health-api container)
│
├── Services (networking)
│   └── health-api-service (load balancer)
│
├── ConfigMaps (configuration)
│   └── health-api-config
│
└── Secrets (sensitive data)
    └── health-api-secrets
```

## 🚀 **Deployment Flow**

### **1. Infrastructure Creation**
```bash
# Terraform creates:
- EC2 instance
- K3s installation
- Security groups
- SSH keys
```

### **2. Kubeconfig Setup**
```bash
# Workflow automatically:
- Downloads kubeconfig from K3s
- Updates server IP (127.0.0.1 → public IP)
- Stores in GitHub Secrets
```

### **3. Application Deployment**
```bash
# kubectl commands:
kubectl create namespace health-app-dev
kubectl apply -f deployment.yaml
kubectl expose deployment health-api
```

## 📋 **Learning Exercises**

### **Exercise 1: Basic Commands**
```bash
# Connect to cluster
kubectl cluster-info
kubectl get nodes

# View namespaces
kubectl get namespaces
kubectl get pods -n health-app-dev

# Describe resources
kubectl describe pod <pod-name> -n health-app-dev
```

### **Exercise 2: Scaling**
```bash
# Scale deployment
kubectl scale deployment health-api --replicas=3 -n health-app-dev

# Check status
kubectl get pods -n health-app-dev -w
```

### **Exercise 3: Troubleshooting**
```bash
# View logs
kubectl logs <pod-name> -n health-app-dev

# Execute into pod
kubectl exec -it <pod-name> -n health-app-dev -- /bin/bash

# Port forwarding
kubectl port-forward pod/<pod-name> 8080:8080 -n health-app-dev
```
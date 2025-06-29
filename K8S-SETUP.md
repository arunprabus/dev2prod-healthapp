# 🚀 K8s Infrastructure Setup Guide

## 🏗️ **Architecture Overview**

### **K8s vs EKS Comparison**
| Feature | K8s (Current) | EKS Alternative |
|---------|---------------|-----------------|
| **Control Plane** | Self-managed | AWS Managed ($73/month) |
| **Worker Nodes** | EC2 t2.micro (FREE) | EC2 t3.medium ($30/month) |
| **Networking** | VPC (FREE) | VPC + NAT Gateway ($45/month) |
| **Load Balancer** | NodePort/ClusterIP | ALB ($18/month) |
| **Monthly Cost** | **$0** | **$166** |
| **Learning Value** | Direct K8s experience | Managed service |

## 🎯 **Complete Infrastructure Components**

### **1. Application Deployment**
- **Health API**: Auto-scaling deployment (1-5 replicas)
- **Database Connectivity**: RDS integration with secrets
- **Environment Configs**: ConfigMaps and Secrets per environment
- **Health Checks**: Liveness and readiness probes
- **Service Discovery**: ClusterIP and LoadBalancer services

### **2. Monitoring & Operations**
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization dashboards
- **Health Checks**: Automated pod/service monitoring
- **Auto-scaling**: HPA + business hours scheduling
- **Resource Monitoring**: CPU/memory usage tracking

### **3. Cost Optimization**
- **Resource Scheduling**: Business hours scaling (9 AM - 6 PM)
- **RDS Monitoring**: 120-hour runtime limit enforcement
- **Auto-shutdown**: Unused resource cleanup
- **Multi-region Cleanup**: Automated resource optimization

## 🛠️ **Deployment Workflows**

### **Infrastructure Workflow** (`infrastructure.yml`)
```yaml
Actions:
  - deploy: Create/update infrastructure
  - destroy: Delete all resources
  - plan: Preview changes
Environments:
  - dev, test, prod, monitoring, all
```

### **K8s Operations Workflow** (`k8s-operations.yml`)
```yaml
Actions:
  - health-check: Monitor deployments/services/pods
  - scale-up/scale-down: Manual scaling
  - auto-scale: Business hours scheduling
  - restart-deployment: Rolling restart
Schedule: Every 2 hours (health checks)
```

### **Application Deploy Workflow** (`app-deploy.yml`)
```yaml
Process:
  1. Build container image
  2. Push to ECR registry
  3. Update K8s deployment
  4. Wait for rollout completion
  5. Verify health checks
```

### **Monitoring Workflow** (`monitoring.yml`)
```yaml
Components:
  - RDS runtime monitoring
  - K8s health checks
  - Auto-scaling management
  - Resource usage tracking
Schedule: Every 6 hours
```

## 📋 **Setup Requirements**

### **🔐 GitHub Secrets (Required)**
```yaml
# Repository Settings → Secrets and variables → Actions → Secrets
AWS_ACCESS_KEY_ID: "AKIA..."
AWS_SECRET_ACCESS_KEY: "xyz123..."
KUBECONFIG: "Base64 encoded kubeconfig file"
SSH_PUBLIC_KEY: "ssh-rsa AAAAB3..."
TF_STATE_BUCKET: "health-app-terraform-state"
SLACK_WEBHOOK_URL: "https://hooks.slack.com/..." # Optional
```

### **⚙️ GitHub Variables (K8s Configuration)**
```yaml
# Repository Settings → Secrets and variables → Actions → Variables
AWS_REGION: "ap-south-1"
K8S_CLUSTER_NAME: "health-app-cluster"
CONTAINER_REGISTRY: "your-account.dkr.ecr.ap-south-1.amazonaws.com"
REGISTRY_NAMESPACE: "health-app"
TERRAFORM_VERSION: "1.6.0"
KUBECTL_TIMEOUT: "300s"
MIN_REPLICAS: "1"
MAX_REPLICAS: "5"
CLEANUP_DELAY: "30"
LB_WAIT_TIME: "60"
HEALTH_CHECK_RETRIES: "5"
BUDGET_EMAIL: "your-email@domain.com"
BUDGET_REGIONS: "us-east-1,ap-south-1"
```

## 🚀 **Quick Start Commands**

### **1. Deploy Infrastructure**
```bash
# Via GitHub Actions
Actions → Infrastructure → action: "deploy" → environment: "dev"

# Manual deployment
cd infra
terraform init
terraform apply -var-file="environments/dev.tfvars"
```

### **2. Deploy Applications**
```bash
# Apply K8s manifests
kubectl apply -f k8s/health-api-complete.yaml
kubectl apply -f k8s/monitoring-stack.yaml

# Via GitHub Actions
Actions → App Deploy → environment: "dev"
```

### **3. Monitor & Scale**
```bash
# Health check
./scripts/k8s-health-check.sh health-app-dev

# Auto-scaling
./scripts/k8s-auto-scale.sh status health-app-dev health-api

# Manual scaling
./scripts/k8s-auto-scale.sh scale-up health-app-dev health-api
```

### **4. Cost Management**
```bash
# Monitor costs
Actions → Cost Management → action: "monitor"

# Cleanup resources
Actions → Resource Cleanup → region: "us-east-1" → action: "cleanup-dry-run"
```

## 📊 **Monitoring & Health Checks**

### **Automated Monitoring**
- **Health Checks**: Every 2 hours via GitHub Actions
- **RDS Monitoring**: 120-hour runtime limit
- **Resource Usage**: CPU/memory tracking
- **Auto-scaling**: Business hours optimization

### **Manual Monitoring**
```bash
# Check deployment status
kubectl get deployments -n health-app-dev
kubectl get pods -n health-app-dev
kubectl get services -n health-app-dev

# View logs
kubectl logs -l app=health-api -n health-app-dev

# Check HPA status
kubectl get hpa -n health-app-dev
```

### **Prometheus Metrics**
- Application metrics: `/metrics` endpoint
- Kubernetes metrics: Pod/node resources
- Custom metrics: Business KPIs
- Alerting rules: Performance thresholds

## 🔧 **Troubleshooting**

### **Common Issues**
```bash
# Pod not starting
kubectl describe pod <pod-name> -n health-app-dev
kubectl logs <pod-name> -n health-app-dev

# Service not accessible
kubectl get endpoints -n health-app-dev
kubectl describe service health-api-service -n health-app-dev

# Scaling issues
kubectl describe hpa health-api-hpa -n health-app-dev
kubectl top pods -n health-app-dev
```

### **Recovery Procedures**
```bash
# Restart deployment
kubectl rollout restart deployment/health-api -n health-app-dev

# Scale manually
kubectl scale deployment health-api --replicas=3 -n health-app-dev

# Emergency cleanup
Actions → Infrastructure → action: "destroy" → confirm: "DESTROY"
```

## 💰 **Cost Optimization Features**

### **Automated Cost Control**
- **Business Hours Scaling**: 2 replicas (9 AM - 6 PM), 1 replica (off-hours)
- **RDS Auto-stop**: Stops after 120 hours runtime
- **Resource Cleanup**: Weekly unused resource removal
- **Multi-region Cleanup**: Automated VPC/IGW cleanup

### **Manual Cost Management**
```bash
# Check current costs
Actions → Cost Management → action: "breakdown"

# Force cleanup
Actions → Resource Cleanup → action: "cleanup-execute" → confirm: "CLEANUP"

# Stop specific environment
Actions → Infrastructure → action: "destroy" → environment: "dev"
```

## 🎓 **Learning Outcomes**

### **K8s Skills**
- Direct Kubernetes cluster management
- Pod, service, deployment configuration
- Auto-scaling (HPA) setup and tuning
- Health checks and monitoring
- Secrets and ConfigMap management

### **DevOps Skills**
- Infrastructure as Code (Terraform)
- CI/CD pipeline automation
- Container registry management
- Monitoring and observability
- Cost optimization strategies

### **Production Skills**
- Multi-environment management
- Security best practices
- Disaster recovery procedures
- Performance optimization
- Incident response

## 🔗 **Useful Commands Reference**

### **K8s Operations**
```bash
# Namespace operations
kubectl get namespaces
kubectl create namespace health-app-staging

# Deployment management
kubectl get deployments -A
kubectl rollout status deployment/health-api -n health-app-dev
kubectl rollout history deployment/health-api -n health-app-dev

# Service discovery
kubectl get services -A
kubectl port-forward service/health-api-service 8080:80 -n health-app-dev

# Resource monitoring
kubectl top nodes
kubectl top pods -A
kubectl describe node <node-name>
```

### **Terraform Operations**
```bash
# State management
terraform state list
terraform state show <resource>
terraform refresh

# Planning and applying
terraform plan -var-file="environments/dev.tfvars"
terraform apply -target=<resource>
terraform destroy -target=<resource>
```

This setup provides a complete, production-ready K8s infrastructure with comprehensive monitoring, auto-scaling, and cost optimization - all at zero monthly cost!
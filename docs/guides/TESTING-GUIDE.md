# 🧪 Testing Guide: Complete Deployment Flow

## 🚀 **End-to-End Testing Steps**

### **Step 1: Deploy Infrastructure**
```bash
# Go to GitHub Actions
Actions → Infrastructure → Run workflow
- action: "deploy"
- environment: "dev"
- Click "Run workflow"

# Expected Output:
✅ VPC created
✅ EC2 instance running
✅ RDS database available
✅ K8s cluster ready
✅ Cluster IP: 1.2.3.4 (example)
```

### **Step 2: Generate & Store Kubeconfig**
```bash
# From workflow output, copy cluster IP
CLUSTER_IP="1.2.3.4"  # Replace with actual IP

# Generate kubeconfig locally
chmod +x scripts/setup-kubeconfig.sh
./scripts/setup-kubeconfig.sh dev $CLUSTER_IP

# Copy the base64 output and add to GitHub Secrets:
# Settings → Secrets → New secret
# Name: KUBECONFIG_DEV
# Value: [paste base64 output]
```

### **Step 3: Test Cluster Connection**
```bash
# SSH to cluster
ssh -i ~/.ssh/aws-key ubuntu@$CLUSTER_IP

# Check K3s status
sudo k3s kubectl get nodes
sudo k3s kubectl get namespaces
```

### **Step 4: Deploy Application**
```bash
# Go to GitHub Actions
Actions → App Deploy → Run workflow
- environment: "dev"
- Click "Run workflow"

# Expected Output:
✅ Container built and pushed
✅ Connected to K8s cluster
✅ Deployed to health-app-dev namespace
✅ Pods running
```

### **Step 5: Verify Deployment**
```bash
# Using local kubectl (with kubeconfig)
export KUBECONFIG=~/.kube/config-dev

# Check deployment
kubectl get namespaces
kubectl get pods -n health-app-dev
kubectl get services -n health-app-dev
kubectl logs -l app=health-api -n health-app-dev
```

## 🔍 **Verification Commands**

### **Infrastructure Verification**
```bash
# Check AWS resources
aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev"
aws rds describe-db-instances --db-instance-identifier health-app-db-dev
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=health-app"
```

### **K8s Cluster Verification**
```bash
# SSH to cluster
ssh -i ~/.ssh/aws-key ubuntu@$CLUSTER_IP

# Check K3s components
sudo systemctl status k3s
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
sudo k3s kubectl cluster-info
```

### **Application Verification**
```bash
# Check application pods
kubectl get pods -n health-app-dev -o wide
kubectl describe pod -l app=health-api -n health-app-dev

# Check services
kubectl get svc -n health-app-dev
kubectl describe svc health-api-service -n health-app-dev

# Check logs
kubectl logs -f -l app=health-api -n health-app-dev
```

## 🧪 **Test Scenarios**

### **Test 1: Basic Deployment**
```bash
# Expected: All pods running
kubectl get pods -n health-app-dev
# STATUS should be "Running"
```

### **Test 2: Service Connectivity**
```bash
# Port forward to test locally
kubectl port-forward svc/health-api-service 8080:80 -n health-app-dev

# Test in another terminal
curl http://localhost:8080/health
# Expected: {"status": "healthy"}
```

### **Test 3: Database Connection**
```bash
# Check if app connects to RDS
kubectl logs -l app=health-api -n health-app-dev | grep -i database
# Expected: No connection errors
```

### **Test 4: Auto-scaling**
```bash
# Check HPA status
kubectl get hpa -n health-app-dev
kubectl describe hpa health-api-hpa -n health-app-dev

# Generate load to test scaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# Inside pod: while true; do wget -q -O- http://health-api-service.health-app-dev/; done
```

## 🚨 **Troubleshooting Tests**

### **Issue: Kubeconfig Not Working**
```bash
# Test connection
kubectl cluster-info
# If fails: Check KUBECONFIG_DEV secret exists and is valid

# Debug connection
kubectl get nodes -v=6
# Shows detailed connection attempts
```

### **Issue: Pods Not Starting**
```bash
# Check pod status
kubectl describe pod -l app=health-api -n health-app-dev

# Common issues:
# - Image pull errors
# - Resource constraints
# - Configuration errors
```

### **Issue: Service Not Accessible**
```bash
# Check endpoints
kubectl get endpoints -n health-app-dev

# Check service
kubectl describe svc health-api-service -n health-app-dev

# Test internal connectivity
kubectl run test-pod --image=busybox -it --rm -- /bin/sh
# Inside: wget -qO- http://health-api-service.health-app-dev/health
```

## ✅ **Success Criteria**

### **Infrastructure Success**
- [ ] EC2 instance running with K3s
- [ ] RDS database available
- [ ] Security groups configured
- [ ] Cluster accessible via kubeconfig

### **Application Success**
- [ ] Pods running in health-app-dev namespace
- [ ] Services exposing applications
- [ ] Health endpoints responding
- [ ] Database connectivity working

### **Integration Success**
- [ ] GitHub Actions workflows completing
- [ ] Environment-specific deployment
- [ ] Proper resource tagging
- [ ] Cost monitoring active

## 🔄 **Automated Testing**

### **Run Test Scripts**
```bash
# Test AWS integrations
chmod +x scripts/test-aws-integrations.sh
./scripts/test-aws-integrations.sh dev

# Test K8s health
chmod +x scripts/k8s-health-check.sh
./scripts/k8s-health-check.sh health-app-dev
```

### **GitHub Actions Testing**
```bash
# Test all workflows
Actions → K8s Operations → action: "health-check" → namespace: "health-app-dev"
Actions → Cost Management → action: "monitor"
Actions → AWS Integrations → action: "deploy-all" → environment: "dev"
```

## 📊 **Performance Testing**

### **Load Testing**
```bash
# Install hey load tester
go install github.com/rakyll/hey@latest

# Test API performance
hey -n 1000 -c 10 http://CLUSTER_IP:PORT/health

# Monitor during load test
kubectl top pods -n health-app-dev
kubectl get hpa -n health-app-dev -w
```

### **Resource Monitoring**
```bash
# Monitor resource usage
kubectl top nodes
kubectl top pods -n health-app-dev

# Check scaling behavior
kubectl get hpa -n health-app-dev -w
kubectl get pods -n health-app-dev -w
```

This testing guide ensures your **complete deployment flow works end-to-end** from infrastructure to application! 🎉
# 🔧 Troubleshooting Guide

## 🚨 Common Issues

### 1. Deployment Stuck in Pending
**Symptoms**: Pods remain in `Pending` state
```bash
kubectl get pods -l app=health-api
```

**Solutions**:
```bash
# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pod <pod-name>

# Scale down if resource constraints
kubectl scale deployment health-api-blue --replicas=1
```

### 2. Health Check Failures
**Symptoms**: Readiness probe failures
```bash
kubectl logs -l app=health-api --tail=50
```

**Solutions**:
```bash
# Check application logs
kubectl logs deployment/health-api-green

# Verify environment variables
kubectl get secret health-api-config -o yaml

# Test health endpoint manually
kubectl port-forward svc/health-api-service 3000:3000
curl http://localhost:3000/health
```

### 3. Traffic Not Switching
**Symptoms**: Old version still receiving traffic

**Check Current State**:
```bash
# Verify service selector
kubectl get service health-api-service -o yaml | grep -A5 selector

# Check deployment labels
kubectl get deployments --show-labels
```

**Fix**:
```bash
# Manually update service selector
kubectl patch service health-api-service -p '{"spec":{"selector":{"color":"green"}}}'
```

### 4. Rollback Not Working
**Symptoms**: Rollback job fails

**Debug Steps**:
```bash
# Check if previous deployment exists
kubectl get deployments -l app=health-api

# Verify deployment history
kubectl rollout history deployment/health-api-blue
kubectl rollout history deployment/health-api-green

# Manual rollback
kubectl rollout undo deployment/health-api-green
```

## 🔍 Debugging Commands

### Pod Investigation
```bash
# Get pod details
kubectl get pods -o wide

# Check pod logs
kubectl logs <pod-name> --previous

# Execute into pod
kubectl exec -it <pod-name> -- /bin/sh

# Check pod resources
kubectl top pods
```

### Service Debugging
```bash
# Test service connectivity
kubectl run debug --image=busybox -it --rm -- sh
# Inside pod: wget -qO- http://health-api-service:3000/health

# Check endpoints
kubectl get endpoints health-api-service

# Describe service
kubectl describe service health-api-service
```

### Network Issues
```bash
# Check DNS resolution
kubectl run debug --image=busybox -it --rm -- nslookup health-api-service

# Test connectivity between pods
kubectl exec -it <frontend-pod> -- curl http://health-api-service:3000/health
```

## 🛠️ Recovery Procedures

### Complete Environment Reset
```bash
# 1. Delete all resources
kubectl delete deployments,services,secrets -l app=health-api
kubectl delete deployments,services -l app=frontend

# 2. Recreate secrets
kubectl create secret generic health-api-config \
  --from-literal=DYNAMODB_PROFILES_TABLE=<table-name> \
  --from-literal=DYNAMODB_UPLOADS_TABLE=<table-name> \
  --from-literal=S3_BUCKET=<bucket-name> \
  --from-literal=AWS_REGION=us-east-1

# 3. Redeploy applications
kubectl apply -f k8s/health-api-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
```

### Emergency Rollback
```bash
# Quick switch to known good version
kubectl patch service health-api-service -p '{"spec":{"selector":{"app":"health-api","color":"blue"}}}'
kubectl patch service frontend-service -p '{"spec":{"selector":{"app":"frontend","color":"blue"}}}'
```

## 📊 Monitoring Commands

### Real-time Monitoring
```bash
# Watch deployment status
kubectl get deployments -w

# Monitor pod status
kubectl get pods -w -l app=health-api

# Check resource usage
kubectl top nodes
kubectl top pods
```

### Log Analysis
```bash
# Stream logs from all pods
kubectl logs -f -l app=health-api

# Get logs from specific time
kubectl logs --since=1h -l app=health-api

# Export logs for analysis
kubectl logs -l app=health-api > app-logs.txt
```

## 🔧 Performance Issues

### High Memory Usage
```bash
# Check memory limits
kubectl describe pod <pod-name> | grep -A5 Limits

# Increase memory limits
kubectl patch deployment health-api-green -p '{"spec":{"template":{"spec":{"containers":[{"name":"health-api","resources":{"limits":{"memory":"512Mi"}}}]}}}}'
```

### Slow Response Times
```bash
# Check if pods are ready
kubectl get pods -l app=health-api

# Verify health check configuration
kubectl describe deployment health-api-green | grep -A10 Liveness

# Scale up replicas
kubectl scale deployment health-api-green --replicas=3
```

## 🚨 Emergency Contacts

### Escalation Path
1. **Level 1**: Check logs and basic troubleshooting
2. **Level 2**: Infrastructure team for EKS/AWS issues
3. **Level 3**: Application team for code-related problems

### Key Information to Collect
- Deployment timestamp
- Environment (dev/test/prod)
- Error messages from logs
- Current pod status
- Recent configuration changes

## 📝 Incident Response

### During an Incident
1. **Assess Impact**: Check service availability
2. **Quick Fix**: Attempt rollback if possible
3. **Communicate**: Notify stakeholders
4. **Document**: Record timeline and actions
5. **Follow-up**: Post-incident review

### Post-Incident
1. **Root Cause Analysis**: Identify what went wrong
2. **Preventive Measures**: Update processes/monitoring
3. **Documentation**: Update runbooks
4. **Testing**: Verify fixes in lower environments
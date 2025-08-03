# 🌐 DNS Setup Guide for Namecheap (sharpzeal.com)

## 📋 Overview
Configure DNS records in Namecheap to point your subdomains to your K3s clusters.

## 🔧 Required DNS Records

### **Step 1: Get Cluster IPs**
```bash
# Get cluster IPs from infrastructure outputs
# Lower network (dev/test): 
LOWER_IP="<from terraform output>"

# Higher network (prod):
HIGHER_IP="<from terraform output>"
```

### **Step 2: Namecheap DNS Configuration**

1. **Login to Namecheap**
   - Go to [Namecheap Dashboard](https://ap.www.namecheap.com/dashboard)
   - Select `sharpzeal.com` domain

2. **Advanced DNS Settings**
   - Click "Advanced DNS" tab
   - Add the following A records:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A Record | `dev` | `<LOWER_CLUSTER_IP>` | 300 |
| A Record | `test` | `<LOWER_CLUSTER_IP>` | 300 |
| A Record | `health-api` | `<HIGHER_CLUSTER_IP>` | 300 |

### **Step 3: Verify DNS Propagation**
```bash
# Check DNS resolution (may take 5-10 minutes)
nslookup dev.sharpzeal.com
nslookup test.sharpzeal.com  
nslookup health-api.sharpzeal.com

# Or use online tools:
# https://dnschecker.org/
```

## 🚀 **Environment URLs**

After DNS setup and SSL certificate issuance:

- **Development**: https://dev.sharpzeal.com
- **Test**: https://test.sharpzeal.com  
- **Production**: https://health-api.sharpzeal.com

## 🔐 **SSL Certificate Process**

1. **Automatic Issuance**: cert-manager will automatically request SSL certificates
2. **Validation**: Let's Encrypt validates domain ownership via HTTP-01 challenge
3. **Certificate Storage**: Certificates stored as Kubernetes secrets
4. **Auto-Renewal**: Certificates automatically renewed before expiry

## 🔍 **Troubleshooting**

### **DNS Not Resolving**
```bash
# Check current DNS settings
dig dev.sharpzeal.com
dig test.sharpzeal.com
dig health-api.sharpzeal.com
```

### **SSL Certificate Issues**
```bash
# Check certificate status
kubectl get certificate -A
kubectl describe certificate health-api-dev-tls -n health-app-dev

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager
```

### **Ingress Issues**
```bash
# Check ingress status
kubectl get ingress -A
kubectl describe ingress health-api-ingress -n health-app-dev

# Check NGINX ingress logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

## ⏱️ **Timeline**

1. **DNS Setup**: 2 minutes (manual)
2. **DNS Propagation**: 5-10 minutes (automatic)
3. **SSL Certificate**: 2-5 minutes after DNS (automatic)
4. **Total Time**: ~15 minutes

## 🎯 **Quick Setup Commands**

```bash
# 1. Setup ingress components
./scripts/setup-ingress.sh dev

# 2. Deploy application
kubectl apply -f k8s/health-api-complete.yaml

# 3. Apply ingress configuration
kubectl apply -f k8s/ingress-multi-env.yaml

# 4. Check status
kubectl get ingress,certificate -A
```

## 📞 **Support**

If you encounter issues:
1. Check DNS propagation: https://dnschecker.org/
2. Verify cluster IPs are correct
3. Check Namecheap DNS settings
4. Review cert-manager logs for SSL issues
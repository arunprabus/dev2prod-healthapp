# 🆓 Free vs 💰 Paid SSL Options

## Quick Comparison

| Feature | Free Option | Paid Option |
|---------|-------------|-------------|
| **Cost** | $0/month | ~$18/month |
| **SSL Certificate** | Self-signed | ACM Professional |
| **Access Method** | Direct IP:6443 | Domain name:443 |
| **Setup Complexity** | Simple | Moderate |
| **Production Ready** | Learning/Dev | Enterprise |

## 🆓 Free Option (Default)

### Deploy Command
```bash
# Default deployment - FREE
terraform apply
```

### Features
- ✅ **$0 cost** - 100% Free Tier
- ✅ **Direct access** - https://IP:6443
- ✅ **Self-signed cert** - Browser warning (skip)
- ✅ **Instant setup** - No DNS required
- ✅ **Perfect for learning** - No complexity

### Access
```bash
# Kubeconfig points to EC2 public IP
server: https://1.2.3.4:6443
# Accept self-signed certificate warning
```

## 💰 Paid Option (Professional)

### Deploy Command
```bash
# Enable SSL termination - PAID
terraform apply -var="enable_ssl_termination=true" -var="k3s_domain_name=k3s.yourdomain.com"
```

### Features
- 💰 **~$18/month** - NLB cost
- ✅ **Professional SSL** - ACM certificate
- ✅ **Domain access** - https://k3s.yourdomain.com:443
- ✅ **No browser warnings** - Trusted certificate
- ✅ **Enterprise ready** - Production grade

### Access
```bash
# Kubeconfig points to NLB domain
server: https://k3s.yourdomain.com:443
# No certificate warnings
```

## 🎯 When to Use Each

### Use Free Option When:
- 🎓 **Learning Kubernetes**
- 💻 **Development environment**
- 🧪 **Testing and experimentation**
- 💰 **Cost is primary concern**
- ⚡ **Quick setup needed**

### Use Paid Option When:
- 🏢 **Production deployment**
- 👥 **Team collaboration**
- 🔒 **Security compliance required**
- 🌐 **Public-facing API**
- 📱 **Client applications**

## 🔄 Switch Between Options

### Free → Paid
```bash
terraform apply -var="enable_ssl_termination=true" -var="k3s_domain_name=k3s.yourdomain.com"
```

### Paid → Free
```bash
terraform apply -var="enable_ssl_termination=false"
```

## 💡 Recommendation

**Start with Free** → Learn Kubernetes → **Upgrade to Paid** when ready for production!
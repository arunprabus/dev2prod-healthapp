# Security & Certificate Management

## Current Certificate Handling

### Development/Testing (Current)
- **Method**: `--insecure-skip-tls-verify` flag
- **Certificates**: K3s self-signed with SAN (Subject Alternative Names)
- **Usage**: Suitable for development and testing environments

### K3s Certificate Configuration
```bash
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --bind-address=0.0.0.0 \
  --advertise-address=$PUBLIC_IP \
  --node-external-ip=$PUBLIC_IP \
  --tls-san=$PUBLIC_IP \
  --tls-san=$PRIVATE_IP
```

## Production Recommendations

### Option 1: Proper Certificate Validation
Remove `--insecure-skip-tls-verify` and use the SAN certificates:
```yaml
clusters:
- cluster:
    certificate-authority-data: <base64-encoded-ca-cert>
    server: https://43.205.210.144:6443
```

### Option 2: Let's Encrypt with cert-manager
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Configure Let's Encrypt issuer
kubectl apply -f kubernetes-manifests/components/cert-manager/letsencrypt-issuer.yaml
```

### Option 3: Custom CA Certificates
```bash
# Generate custom CA
openssl genrsa -out ca.key 4096
openssl req -new -x509 -key ca.key -sha256 -subj "/C=US/ST=CA/O=HealthApp/CN=HealthApp-CA" -days 3650 -out ca.crt

# Configure K3s with custom CA
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --bind-address=0.0.0.0 \
  --advertise-address=$PUBLIC_IP \
  --node-external-ip=$PUBLIC_IP \
  --tls-san=$PUBLIC_IP \
  --tls-san=$PRIVATE_IP \
  --cluster-ca-cert=/path/to/ca.crt \
  --cluster-ca-key=/path/to/ca.key
```

## Security Best Practices

1. **Never use `--insecure-skip-tls-verify` in production**
2. **Always validate certificates in production environments**
3. **Use proper SAN certificates for external access**
4. **Rotate certificates regularly**
5. **Monitor certificate expiration**

## Implementation Status

- ✅ K3s with SAN certificates configured
- ✅ Development environment using insecure skip
- ⏳ Production certificate validation (planned)
- ⏳ cert-manager integration (planned)
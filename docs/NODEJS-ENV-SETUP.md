# Node.js Environment Setup with Kubernetes Secrets

This guide explains how to set up environment variables for Node.js applications using Kubernetes Secrets.

## Overview

Node.js applications typically use environment variables for configuration, often loaded from `.env` files. In Kubernetes, we can use Secrets and ConfigMaps to manage these configurations securely.

## Approaches

### 1. Init Container Approach (Recommended)

This approach uses an init container to generate a `.env` file from Kubernetes Secrets before the main application starts.

#### Benefits:
- Compatible with applications that require a physical `.env` file
- No code changes needed for applications that use `dotenv`
- Clear separation between sensitive and non-sensitive configuration

#### Implementation:

1. **Create the necessary Secrets and ConfigMaps:**

```bash
# Create ConfigMap for non-sensitive configuration
kubectl create configmap nodejs-config \
  --from-literal=NODE_ENV=production \
  --from-literal=LOG_LEVEL=info \
  --from-literal=DB_HOST=db.example.com \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=healthapp \
  --from-literal=DB_USER=admin \
  -n health-app-dev

# Create Secret for sensitive data
kubectl create secret generic app-credentials \
  --from-literal=db-password=your-password \
  --from-literal=api-key=your-api-key \
  --from-literal=jwt-secret=your-jwt-secret \
  -n health-app-dev
```

2. **Deploy using the provided template:**

```bash
# Replace variables in the template
envsubst < k8s/nodejs-deployment-with-env.yaml | kubectl apply -f -
```

### 2. Direct Environment Variables

This approach injects environment variables directly into the container.

#### Benefits:
- Simpler deployment configuration
- No need for an init container
- Works well with applications that don't require a physical `.env` file

#### Implementation:

1. **Create the necessary Secrets and ConfigMaps (same as above)**

2. **Deploy with environment variables:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-app
spec:
  template:
    spec:
      containers:
      - name: nodejs-app
        image: nodejs-app:latest
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: nodejs-config
              key: DB_HOST
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: db-password
```

## Node.js Application Setup

### Option 1: Using dotenv with .env file

```javascript
// Load environment variables from .env file
require('dotenv').config();

// Access environment variables
const dbConfig = {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD
};

console.log(`Connecting to database at ${dbConfig.host}:${dbConfig.port}`);
```

### Option 2: Using environment variables directly

```javascript
// No need to load .env file, environment variables are already set

// Access environment variables
const dbConfig = {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD
};

console.log(`Connecting to database at ${dbConfig.host}:${dbConfig.port}`);
```

## Local Development

For local development, you can generate a `.env` file from your Kubernetes environment:

```bash
# Generate .env file from Kubernetes secrets
./scripts/generate-env-file.sh --namespace health-app-dev --output .env.dev

# Use the generated .env file for local development
NODE_ENV=development dotenv -e .env.dev npm run dev
```

## Security Considerations

1. **Never commit `.env` files to version control**
2. **Use different secrets for each environment**
3. **Regularly rotate sensitive credentials**
4. **Limit access to secrets using RBAC**
5. **Consider using a secrets management solution for production**

## Troubleshooting

### Common Issues

1. **Environment variables not available in container:**
   - Check if the secret/configmap exists: `kubectl get secret app-credentials -n health-app-dev`
   - Verify the deployment has the correct references: `kubectl describe deployment nodejs-app -n health-app-dev`

2. **Init container fails:**
   - Check init container logs: `kubectl logs <pod-name> -c init-env -n health-app-dev`
   - Verify volumes are mounted correctly: `kubectl describe pod <pod-name> -n health-app-dev`

3. **Application can't read .env file:**
   - Verify file path: The .env file is mounted at `/app/.env`
   - Check file permissions: The file should be readable by the application user
   - Inspect the file content: `kubectl exec <pod-name> -n health-app-dev -- cat /app/.env`
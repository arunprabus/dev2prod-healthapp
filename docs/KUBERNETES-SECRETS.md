# Kubernetes Secrets Management

This document explains how Kubernetes Secrets are used in the Health App infrastructure.

## Overview

Kubernetes Secrets are used to store sensitive information such as:
- Database credentials
- API keys
- JWT secrets
- AWS credentials
- GitHub tokens

## Secret Types

The following secrets are created automatically during deployment:

### 1. App Credentials

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-credentials
  namespace: health-app-{environment}
type: Opaque
data:
  db-password: {base64-encoded}
  api-key: {base64-encoded}
  jwt-secret: {base64-encoded}
```

### 2. AWS Credentials

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
  namespace: health-app-{environment}
type: Opaque
data:
  aws-access-key-id: {base64-encoded}
  aws-secret-access-key: {base64-encoded}
  aws-region: {base64-encoded}
```

### 3. GitHub Credentials

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-credentials
  namespace: health-app-{environment}
type: Opaque
data:
  github-token: {base64-encoded}
```

## Using Secrets in Deployments

### Environment Variables

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-api
  namespace: health-app-dev
spec:
  template:
    spec:
      containers:
      - name: health-api
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: db-password
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: api-key
```

### Volume Mounts

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-api
  namespace: health-app-dev
spec:
  template:
    spec:
      containers:
      - name: health-api
        volumeMounts:
        - name: secrets
          mountPath: "/app/secrets"
          readOnly: true
      volumes:
      - name: secrets
        secret:
          secretName: app-credentials
```

## Managing Secrets

### Viewing Secrets

```bash
# List all secrets in a namespace
kubectl get secrets -n health-app-dev

# View a specific secret
kubectl describe secret app-credentials -n health-app-dev

# Decode a secret value
kubectl get secret app-credentials -n health-app-dev -o jsonpath="{.data.db-password}" | base64 --decode
```

### Updating Secrets

```bash
# Update a specific key in a secret
kubectl create secret generic app-credentials \
  --from-literal=db-password=newpassword \
  --from-literal=api-key=existingapikey \
  --from-literal=jwt-secret=existingjwtsecret \
  -n health-app-dev \
  --dry-run=client -o yaml | kubectl apply -f -
```

### Deleting Secrets

```bash
# Delete a specific secret
kubectl delete secret app-credentials -n health-app-dev
```

## Security Best Practices

1. **Rotation**: Regularly rotate secrets
2. **RBAC**: Limit access to secrets using RBAC
3. **Encryption**: Enable encryption at rest for etcd
4. **Minimal Access**: Only mount secrets needed by each pod
5. **Monitoring**: Audit secret access

## Using Secrets for .env Files in Node.js Applications

Node.js applications often use `.env` files for configuration. Here are two approaches to use Kubernetes Secrets with Node.js applications:

### 1. Init Container Approach

This approach uses an init container to create a `.env` file from Kubernetes Secrets before the main application starts:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-app
  namespace: health-app-dev
spec:
  template:
    spec:
      initContainers:
      - name: init-env
        image: busybox
        command: ["sh", "-c"]
        args:
          - |
            echo "DB_HOST=${DB_HOST}" > /app/.env
            echo "DB_PORT=${DB_PORT}" >> /app/.env
            echo "DB_PASSWORD=$(cat /secrets/db-password)" >> /app/.env
            echo "API_KEY=$(cat /secrets/api-key)" >> /app/.env
            echo "JWT_SECRET=$(cat /secrets/jwt-secret)" >> /app/.env
            echo "AWS_ACCESS_KEY_ID=$(cat /aws-secrets/aws-access-key-id)" >> /app/.env
            echo "AWS_SECRET_ACCESS_KEY=$(cat /aws-secrets/aws-secret-access-key)" >> /app/.env
            echo "AWS_REGION=$(cat /aws-secrets/aws-region)" >> /app/.env
        env:
        - name: DB_HOST
          value: "db.example.com"
        - name: DB_PORT
          value: "5432"
        volumeMounts:
        - name: env-file
          mountPath: /app
        - name: app-secrets
          mountPath: /secrets
        - name: aws-secrets
          mountPath: /aws-secrets
      containers:
      - name: nodejs-app
        image: nodejs-app:latest
        volumeMounts:
        - name: env-file
          mountPath: /app/.env
          subPath: .env
      volumes:
      - name: env-file
        emptyDir: {}
      - name: app-secrets
        secret:
          secretName: app-credentials
      - name: aws-secrets
        secret:
          secretName: aws-credentials
```

### 2. Environment Variables with dotenv

This approach uses environment variables directly and the `dotenv` package:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-app
  namespace: health-app-dev
spec:
  template:
    spec:
      containers:
      - name: nodejs-app
        image: nodejs-app:latest
        env:
        - name: DB_HOST
          value: "db.example.com"
        - name: DB_PORT
          value: "5432"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: db-password
        - name: API_KEY
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: api-key
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: app-credentials
              key: jwt-secret
        - name: AWS_ACCESS_KEY_ID
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: aws-access-key-id
        - name: AWS_SECRET_ACCESS_KEY
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: aws-secret-access-key
        - name: AWS_REGION
          valueFrom:
            secretKeyRef:
              name: aws-credentials
              key: aws-region
```

In your Node.js application, use the `dotenv` package to load environment variables:

```javascript
// Option 1: If using .env file from init container
require('dotenv').config();

// Option 2: Environment variables are already set by Kubernetes
// No need to load .env file, just use process.env directly

// Access environment variables
const dbConfig = {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  password: process.env.DB_PASSWORD
};

const apiKey = process.env.API_KEY;
const jwtSecret = process.env.JWT_SECRET;
```

### 3. ConfigMap for Non-Sensitive Configuration

For non-sensitive configuration, use a ConfigMap alongside Secrets:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nodejs-config
  namespace: health-app-dev
data:
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  API_URL: "https://api.example.com"
  DB_HOST: "db.example.com"
  DB_PORT: "5432"
```

Then reference both in your deployment:

```yaml
env:
- name: NODE_ENV
  valueFrom:
    configMapKeyRef:
      name: nodejs-config
      key: NODE_ENV
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: app-credentials
      key: db-password
```

## Integration with External Secret Stores

For production environments, consider using:

1. **AWS Secrets Manager** with External Secrets Operator
2. **HashiCorp Vault** for dynamic secret generation
3. **Sealed Secrets** for GitOps workflows
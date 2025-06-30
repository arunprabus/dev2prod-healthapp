# Production Architecture Guide

## Frontend Deployment (Static Hosting)

### Option 1: AWS S3 + CloudFront
```bash
# Build frontend
npm run build

# Deploy to S3
aws s3 sync build/ s3://your-frontend-bucket --delete

# Invalidate CloudFront
aws cloudfront create-invalidation --distribution-id YOUR_ID --paths "/*"
```

### Option 2: Vercel/Netlify
```bash
# Connect GitHub repo
# Auto-deploy on push to main branch
```

## Backend Deployment (Container/Serverless)

### Option 1: EKS (Kubernetes)
```yaml
# backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: health-api
  template:
    spec:
      containers:
      - name: health-api
        image: your-ecr-repo/health-api:latest
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: host
---
apiVersion: v1
kind: Service
metadata:
  name: health-api-service
spec:
  type: ClusterIP  # Internal only
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: health-api
```

### Option 2: AWS Fargate
```yaml
# fargate-task-definition.json
{
  "family": "health-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "health-api",
      "image": "your-ecr-repo/health-api:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ]
    }
  ]
}
```

## Network Security

### Backend (Private)
- Deploy in private subnets
- No direct internet access
- Access via ALB only

### Frontend (Public)
- Static files on CDN
- API calls via ALB
- CORS configured properly

## Environment Configuration

### Frontend (.env.production)
```bash
REACT_APP_API_URL=https://api.yourdomain.com
REACT_APP_ENV=production
```

### Backend (Kubernetes Secret)
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-config
type: Opaque
data:
  DB_HOST: <base64-encoded>
  DB_PASSWORD: <base64-encoded>
  JWT_SECRET: <base64-encoded>
```

## CI/CD Pipeline

### Frontend Pipeline
```yaml
# .github/workflows/frontend-deploy.yml
name: Deploy Frontend
on:
  push:
    branches: [main]
    paths: ['frontend/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Build
      run: |
        cd frontend
        npm ci
        npm run build
    - name: Deploy to S3
      run: aws s3 sync frontend/build/ s3://${{ secrets.S3_BUCKET }}
```

### Backend Pipeline
```yaml
# .github/workflows/backend-deploy.yml
name: Deploy Backend
on:
  push:
    branches: [main]
    paths: ['health-api/**']

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Build and Push to ECR
      run: |
        aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REGISTRY
        docker build -t health-api health-api/
        docker tag health-api:latest $ECR_REGISTRY/health-api:latest
        docker push $ECR_REGISTRY/health-api:latest
    - name: Deploy to EKS
      run: |
        aws eks update-kubeconfig --name your-cluster
        kubectl set image deployment/health-api health-api=$ECR_REGISTRY/health-api:latest
```
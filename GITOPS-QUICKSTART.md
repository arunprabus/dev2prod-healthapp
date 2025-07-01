# 🚀 GitOps Quick Setup Guide

## Step 1: Create Personal Access Token

### **In GitHub (your account):**
1. Go to **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token (classic)**
3. **Note**: `GitOps Token for Health App`
4. **Expiration**: `90 days` (or custom)
5. **Select scopes**:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Action workflows)
6. Click **Generate token**
7. **Copy the token** (starts with `ghp_`)

## Step 2: Add Token to Health API Repo

### **In Health API Repository:**
1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. **Name**: `INFRA_REPO_TOKEN`
4. **Secret**: `ghp_xxxxxxxxxxxxxxxxxxxx` (paste your token)
5. Click **Add secret**

## Step 3: Create Workflow in Health API Repo

### **Create file: `.github/workflows/deploy.yml`**
```yaml
name: Build and Deploy Health API

on:
  push:
    branches: [main, develop]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
    - name: Checkout repository
      uses: actions/checkout@v4

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-

    - name: Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}

    - name: Determine environment
      id: env
      run: |
        if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
          echo "environment=prod" >> $GITHUB_OUTPUT
        elif [[ "${{ github.ref }}" == "refs/heads/staging" ]]; then
          echo "environment=test" >> $GITHUB_OUTPUT
        else
          echo "environment=dev" >> $GITHUB_OUTPUT
        fi

    - name: Trigger Infrastructure Deployment
      run: |
        curl -X POST \
          -H "Authorization: token ${{ secrets.INFRA_REPO_TOKEN }}" \
          -H "Accept: application/vnd.github.v3+json" \
          -H "Content-Type: application/json" \
          https://api.github.com/repos/${{ github.repository_owner }}/dev2prod-healthapp/dispatches \
          -d '{
            "event_type": "app-deploy",
            "client_payload": {
              "app": "health-api",
              "image": "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.ref_name }}-${{ github.sha }}",
              "environment": "${{ steps.env.outputs.environment }}",
              "commit": "${{ github.sha }}",
              "actor": "${{ github.actor }}"
            }
          }'

    - name: Deployment Summary
      run: |
        echo "## 🚀 Deployment Triggered" >> $GITHUB_STEP_SUMMARY
        echo "* Image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.ref_name }}-${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
        echo "* Environment: ${{ steps.env.outputs.environment }}" >> $GITHUB_STEP_SUMMARY
        echo "* Commit: ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
        echo "* Triggered by: ${{ github.actor }}" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "Check the [Infrastructure Repository](https://github.com/${{ github.repository_owner }}/dev2prod-healthapp/actions) for deployment status." >> $GITHUB_STEP_SUMMARY
```

## Step 4: Create Dockerfile in Health API Repo

### **Create file: `Dockerfile`**
```dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["npm", "start"]
```

## Step 5: Test the Setup

### **Test Push to Health API Repo:**
```bash
# In Health API repository
git add .
git commit -m "Setup GitOps deployment"
git push origin main

# Expected Flow:
# 1. ✅ Health API workflow runs
# 2. ✅ Container built and pushed to GHCR
# 3. ✅ Webhook sent to infra repo
# 4. ✅ Infra repo deploys to K8s
# 5. ✅ Application updated in cluster
```

### **Verify Deployment:**
```bash
# Check infra repo actions
# Go to: https://github.com/your-username/dev2prod-healthapp/actions

# Check K8s deployment
kubectl get pods -n health-app-dev
kubectl describe deployment health-api-backend-dev -n health-app-dev
```

## Step 6: Monitor Deployments

### **Health API Repo Actions:**
- Shows container build and webhook trigger
- Links to infrastructure repo for deployment status

### **Infrastructure Repo Actions:**
- Shows GitOps deployment workflow
- Displays deployment success/failure
- Provides rollout status and health checks

## 🔧 Troubleshooting

### **Common Issues:**

**1. Token Permission Error**
```bash
Error: Bad credentials
Solution: Regenerate PAT with correct permissions (repo + workflow)
```

**2. Webhook Not Triggering**
```bash
Error: No deployment triggered
Solution: Check INFRA_REPO_TOKEN secret exists in Health API repo
```

**3. Container Build Failed**
```bash
Error: Docker build failed
Solution: Ensure Dockerfile exists and is valid
```

**4. Deployment Failed**
```bash
Error: K8s deployment failed
Solution: Check kubeconfig and cluster connectivity
```

## ✅ Success Indicators

### **Health API Repo:**
- ✅ Workflow completes successfully
- ✅ Container pushed to GHCR
- ✅ Webhook sent to infra repo
- ✅ Summary shows deployment details

### **Infrastructure Repo:**
- ✅ GitOps workflow triggered
- ✅ K8s deployment updated
- ✅ Pods running with new image
- ✅ Health checks passing

## 🎯 Branch Strategy

### **Automatic Environment Mapping:**
```yaml
main branch → prod environment
staging branch → test environment
develop branch → dev environment
feature/* → dev environment (default)
```

### **Manual Deployment:**
```bash
# Trigger manual deployment from Health API repo
Actions → Build and Deploy Health API → Run workflow
```

This setup provides **professional GitOps pipeline** with automatic deployments! 🚀
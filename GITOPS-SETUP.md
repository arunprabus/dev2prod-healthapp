# 🔄 GitOps Setup: App Repos → Infra Repo

## 🎯 **What's Needed for GitOps**

### **1. Repository Webhooks**
```yaml
# In Health API repo (github.com/arunprabus/health-api)
Settings → Webhooks → Add webhook:
  - URL: https://api.github.com/repos/arunprabus/dev2prod-healthapp/dispatches
  - Content type: application/json
  - Secret: WEBHOOK_SECRET
  - Events: Push to main/develop branches
```

### **2. GitHub Personal Access Token**
```yaml
# Create PAT with permissions:
- repo (full control)
- workflow (trigger workflows)

# Add to Health API repo secrets:
INFRA_REPO_TOKEN: "ghp_xxxxxxxxxxxx"
```

### **3. App Repo Workflow (Health API)**
```yaml
# .github/workflows/deploy.yml in Health API repo
name: Build and Deploy
on:
  push:
    branches: [main, develop]

jobs:
  build-and-trigger:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Build and Push Container
      run: |
        # Build container
        docker build -t health-api:${{ github.sha }} .
        
        # Push to registry
        echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
        docker tag health-api:${{ github.sha }} ghcr.io/${{ github.repository }}:${{ github.sha }}
        docker push ghcr.io/${{ github.repository }}:${{ github.sha }}
    
    - name: Trigger Infrastructure Deployment
      run: |
        curl -X POST \
          -H "Authorization: token ${{ secrets.INFRA_REPO_TOKEN }}" \
          -H "Accept: application/vnd.github.v3+json" \
          https://api.github.com/repos/arunprabus/dev2prod-healthapp/dispatches \
          -d '{
            "event_type": "app-deploy",
            "client_payload": {
              "app": "health-api",
              "image": "ghcr.io/${{ github.repository }}:${{ github.sha }}",
              "environment": "${{ github.ref == 'refs/heads/main' && 'prod' || 'dev' }}"
            }
          }'
```

### **4. Infra Repo Webhook Handler**
```yaml
# .github/workflows/gitops-deploy.yml (NEW)
name: GitOps Deployment
on:
  repository_dispatch:
    types: [app-deploy]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup kubectl
      run: |
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl && sudo mv kubectl /usr/local/bin/
        echo "${{ secrets.KUBECONFIG }}" | base64 -d > ~/.kube/config
    
    - name: Update Deployment
      run: |
        APP="${{ github.event.client_payload.app }}"
        IMAGE="${{ github.event.client_payload.image }}"
        ENV="${{ github.event.client_payload.environment }}"
        
        # Update image in deployment
        kubectl set image deployment/${APP}-backend-${ENV} \
          ${APP}=${IMAGE} -n health-app-${ENV}
        
        # Wait for rollout
        kubectl rollout status deployment/${APP}-backend-${ENV} \
          -n health-app-${ENV} --timeout=300s
```

### **5. ArgoCD Integration (Optional)**
```yaml
# Install ArgoCD in K8s cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create Application manifest
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: health-api-dev
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/arunprabus/dev2prod-healthapp
    path: k8s
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: health-app-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 🔧 **Implementation Steps**

### **Step 1: Setup App Repo (Health API)**
```bash
# In Health API repo, create workflow
mkdir -p .github/workflows
# Add deploy.yml workflow (from above)

# Add secrets
Settings → Secrets:
- INFRA_REPO_TOKEN: Personal access token
- GITHUB_TOKEN: (automatically available)
```

### **Step 2: Update Infra Repo**
```bash
# Add GitOps workflow
# .github/workflows/gitops-deploy.yml

# Update K8s manifests to use image placeholders
# Use kustomize or helm for dynamic image updates
```

### **Step 3: Configure Webhooks**
```bash
# In Health API repo
Settings → Webhooks → Add:
- URL: GitHub API endpoint
- Secret: Shared secret
- Events: Push events
```

### **Step 4: Test Flow**
```bash
# Push to Health API repo
git push origin main

# Expected flow:
1. Health API builds container
2. Pushes to registry
3. Triggers infra repo webhook
4. Infra repo updates K8s deployment
5. New version deployed
```

## 📊 **GitOps Benefits**

### **Separation of Concerns**
- **App Repos**: Focus on application code
- **Infra Repo**: Focus on deployment and infrastructure
- **Clear boundaries**: Each repo has specific responsibility

### **Automated Pipeline**
- **Code Push**: Triggers entire pipeline
- **Container Build**: Automated in app repo
- **Deployment**: Automated in infra repo
- **Rollback**: Git-based rollback capability

### **Security**
- **Limited Access**: App repos only need registry push
- **Centralized Control**: Infra repo controls deployments
- **Audit Trail**: All changes tracked in Git

## 🎯 **Minimal Requirements**

### **Must Have:**
1. **Personal Access Token** with repo/workflow permissions
2. **Webhook workflow** in infra repo
3. **Build workflow** in app repos
4. **Container registry** access

### **Nice to Have:**
1. **ArgoCD** for advanced GitOps
2. **Kustomize/Helm** for dynamic configs
3. **Slack notifications** for deployment status
4. **Rollback automation** for failed deployments

## 💰 **Cost Impact**
- **GitHub Actions**: Additional workflow runs
- **Container Registry**: Storage for images
- **ArgoCD**: Optional, runs in K8s cluster
- **Total Additional Cost**: ~$0-5/month

This GitOps setup provides **professional-grade deployment pipeline** with proper separation of concerns! 🚀
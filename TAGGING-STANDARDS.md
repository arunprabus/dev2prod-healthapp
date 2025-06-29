# 🏷️ AWS Resource Tagging & Naming Standards

## 📋 **Industry Standard Tags**

### **🔧 Required Tags (Mandatory)**
```yaml
# Cost Management
CostCenter: "engineering"
Project: "health-app"
Environment: "dev|test|prod"
Owner: "team-name"

# Operations
Application: "health-api"
Component: "backend|frontend|database"
ManagedBy: "terraform"
BackupRequired: "true|false"

# Compliance
DataClassification: "public|internal|confidential"
ComplianceScope: "pci|hipaa|gdpr|none"
```

### **📊 Optional Tags (Recommended)**
```yaml
# Business
BusinessUnit: "healthcare"
Department: "engineering"
Customer: "internal"
BillingCode: "HLTH-001"

# Technical
Version: "v1.2.3"
GitRepo: "dev2prod-healthapp"
GitCommit: "abc123"
DeployedBy: "github-actions"
CreatedDate: "2024-01-15"
LastModified: "2024-01-20"

# Scheduling
Schedule: "24x7|business-hours|weekdays"
AutoShutdown: "enabled|disabled"
MaintenanceWindow: "sunday-2am"
```

## 🏗️ **Naming Conventions**

### **AWS Resources**
```yaml
# Format: {project}-{component}-{environment}-{resource-type}
VPC: "health-app-vpc-dev"
Subnet: "health-app-subnet-public-dev-1a"
Security Group: "health-app-sg-web-dev"
EC2 Instance: "health-app-k8s-master-dev"
RDS Instance: "health-app-db-dev"
S3 Bucket: "health-app-terraform-state-dev"
Load Balancer: "health-app-alb-dev"
```

### **Kubernetes Resources**
```yaml
# Format: {app}-{component}-{environment}
Namespace: "health-app-dev"
Deployment: "health-api-backend-dev"
Service: "health-api-service-dev"
ConfigMap: "health-api-config-dev"
Secret: "health-api-secrets-dev"
Ingress: "health-api-ingress-dev"
```

## 🎯 **Implementation Examples**

### **Terraform Tags**
```hcl
# Common tags for all resources
locals {
  common_tags = {
    # Required
    Project         = "health-app"
    Environment     = var.environment
    ManagedBy      = "terraform"
    Owner          = "devops-team"
    CostCenter     = "engineering"
    Application    = "health-api"
    BackupRequired = "true"
    
    # Optional
    BusinessUnit       = "healthcare"
    DataClassification = "internal"
    ComplianceScope    = "hipaa"
    GitRepo           = "dev2prod-healthapp"
    CreatedDate       = formatdate("YYYY-MM-DD", timestamp())
    Schedule          = var.environment == "prod" ? "24x7" : "business-hours"
    AutoShutdown      = var.environment == "prod" ? "disabled" : "enabled"
  }
}

# Apply to resources
resource "aws_instance" "k8s_master" {
  ami           = var.ami_id
  instance_type = "t2.micro"
  
  tags = merge(local.common_tags, {
    Name      = "health-app-k8s-master-${var.environment}"
    Component = "k8s-control-plane"
    Role      = "master"
  })
}

resource "aws_db_instance" "main" {
  identifier = "health-app-db-${var.environment}"
  
  tags = merge(local.common_tags, {
    Name      = "health-app-db-${var.environment}"
    Component = "database"
    Engine    = "mysql"
  })
}
```

### **Kubernetes Labels**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-api-backend-dev
  namespace: health-app-dev
  labels:
    # Standard K8s labels
    app.kubernetes.io/name: health-api
    app.kubernetes.io/instance: health-api-dev
    app.kubernetes.io/version: "1.2.3"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: health-app
    app.kubernetes.io/managed-by: terraform
    
    # Custom labels
    environment: dev
    project: health-app
    team: devops
    cost-center: engineering
spec:
  selector:
    matchLabels:
      app: health-api
      component: backend
      environment: dev
  template:
    metadata:
      labels:
        app: health-api
        component: backend
        environment: dev
        version: "1.2.3"
```

## 💰 **Cost Allocation Tags**

### **Billing Tags**
```yaml
# For cost tracking and allocation
CostCenter: "engineering"          # Department billing
Project: "health-app"              # Project billing  
Environment: "dev"                 # Environment costs
Team: "backend-team"               # Team allocation
Customer: "internal"               # Customer billing
BillingCode: "PROJ-HLTH-001"      # Finance code
```

### **Usage in Cost Reports**
```bash
# AWS Cost Explorer filters
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --group-by Type=DIMENSION,Key=SERVICE \
  --group-by Type=TAG,Key=Project \
  --group-by Type=TAG,Key=Environment
```

## 🔄 **Automation Tags**

### **Lifecycle Management**
```yaml
# Auto-shutdown scheduling
Schedule: "business-hours"         # 9 AM - 6 PM
AutoShutdown: "enabled"           # Enable auto-shutdown
MaintenanceWindow: "sunday-2am"   # Maintenance time
BackupSchedule: "daily-2am"       # Backup timing
RetentionPeriod: "30-days"        # Data retention
```

### **Deployment Tags**
```yaml
# CI/CD tracking
DeployedBy: "github-actions"      # Deployment method
GitRepo: "dev2prod-healthapp"     # Source repository
GitCommit: "abc123def"            # Git commit hash
GitBranch: "main"                 # Git branch
BuildNumber: "456"                # Build number
DeploymentDate: "2024-01-20"     # Deployment date
```

## 🛡️ **Security & Compliance Tags**

### **Data Classification**
```yaml
DataClassification: "confidential"  # public|internal|confidential|restricted
ComplianceScope: "hipaa"            # pci|hipaa|gdpr|sox|none
EncryptionRequired: "true"          # Encryption requirement
AccessLevel: "restricted"           # public|internal|restricted
DataRetention: "7-years"            # Retention policy
```

### **Security Tags**
```yaml
SecurityZone: "dmz"                 # dmz|internal|restricted
NetworkTier: "public"               # public|private|isolated
MonitoringLevel: "high"             # low|medium|high|critical
IncidentResponse: "tier-1"          # Response tier
VulnerabilityScanning: "enabled"    # Security scanning
```

## 📊 **Monitoring & Alerting Tags**

### **Observability**
```yaml
MonitoringEnabled: "true"           # Enable monitoring
AlertingLevel: "critical"           # none|low|medium|high|critical
LogRetention: "30-days"             # Log retention period
MetricsCollection: "enabled"        # Metrics collection
TracingEnabled: "true"              # Distributed tracing
```

## 🎯 **Tag Validation Rules**

### **Required Tag Validation**
```bash
# Terraform validation
variable "required_tags" {
  description = "Required tags for all resources"
  type = object({
    Project     = string
    Environment = string
    Owner       = string
    CostCenter  = string
    ManagedBy   = string
  })
  
  validation {
    condition = contains(["dev", "test", "prod"], var.required_tags.Environment)
    error_message = "Environment must be dev, test, or prod."
  }
}
```

### **Tag Policy (AWS Organizations)**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RequiredTags",
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "Null": {
          "aws:RequestedRegion": "false",
          "aws:PrincipalTag/Project": "true",
          "aws:PrincipalTag/Environment": "true",
          "aws:PrincipalTag/Owner": "true"
        }
      }
    }
  ]
}
```

## 🔧 **Implementation in Workflows**

### **GitHub Actions Tagging**
```yaml
env:
  COMMON_TAGS: |
    Project=${{ vars.PROJECT_NAME || 'health-app' }}
    Environment=${{ vars.ENVIRONMENT || 'dev' }}
    Owner=${{ vars.TEAM_NAME || 'devops' }}
    ManagedBy=github-actions
    GitRepo=${{ github.repository }}
    GitCommit=${{ github.sha }}
    DeployedBy=${{ github.actor }}
    DeploymentDate=$(date +%Y-%m-%d)
```

### **Dynamic Tagging Script**
```bash
#!/bin/bash
# Auto-tagging script

PROJECT="health-app"
ENVIRONMENT=${1:-"dev"}
COMPONENT=${2:-"unknown"}

# Generate tags
TAGS="Project=${PROJECT},Environment=${ENVIRONMENT},Component=${COMPONENT}"
TAGS="${TAGS},ManagedBy=terraform,Owner=devops-team"
TAGS="${TAGS},CreatedDate=$(date +%Y-%m-%d),GitCommit=${GITHUB_SHA:-unknown}"

echo "Generated tags: $TAGS"
```

## 📋 **Tag Governance**

### **Tag Standards Checklist**
- ✅ **Consistent naming** across all resources
- ✅ **Required tags** on every resource
- ✅ **Cost allocation** tags for billing
- ✅ **Environment identification** for operations
- ✅ **Automation tags** for lifecycle management
- ✅ **Security tags** for compliance
- ✅ **Monitoring tags** for observability

### **Best Practices**
- 🎯 **Standardize** tag keys and values
- 🔄 **Automate** tagging in IaC
- 📊 **Monitor** tag compliance
- 💰 **Use** for cost optimization
- 🛡️ **Enforce** via policies
- 📝 **Document** tag meanings
- 🔍 **Audit** regularly

This tagging strategy ensures proper resource identification, cost allocation, automation, and compliance across your K8s infrastructure!
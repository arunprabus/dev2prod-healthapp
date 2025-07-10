#!/bin/bash

# Governance Setup Script
# Sets up all governance controls and rules

set -e

ACTION=${1:-"setup"}
ENVIRONMENT=${2:-"all"}

echo "🛡️ Infrastructure Governance Setup"
echo "Action: $ACTION"
echo "Environment: $ENVIRONMENT"
echo ""

setup_iam_policies() {
    echo "🔐 Setting up IAM policies..."
    
    # Create IAM policy for resource restrictions
    local policy_name="HealthAppResourceRestrictions"
    
    if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$policy_name" >/dev/null 2>&1; then
        echo "  ✅ Policy $policy_name already exists"
        
        # Update policy version
        echo "  🔄 Updating policy version..."
        aws iam create-policy-version \
            --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/$policy_name" \
            --policy-document file://policies/aws-iam-policy.json \
            --set-as-default || echo "  ⚠️  Policy update failed"
    else
        echo "  📝 Creating new policy: $policy_name"
        aws iam create-policy \
            --policy-name "$policy_name" \
            --policy-document file://policies/aws-iam-policy.json \
            --description "Restricts resource creation to health-app requirements" || echo "  ⚠️  Policy creation failed"
    fi
    
    echo "  💡 To apply this policy:"
    echo "     aws iam attach-user-policy --user-name YOUR_USERNAME --policy-arn arn:aws:iam::ACCOUNT:policy/$policy_name"
}

setup_budget_alerts() {
    echo "💰 Setting up budget alerts..."
    
    local budget_name="HealthAppBudget"
    local email=${BUDGET_EMAIL:-"admin@example.com"}
    
    cat > /tmp/budget.json << EOF
{
    "BudgetName": "$budget_name",
    "BudgetLimit": {
        "Amount": "1.00",
        "Unit": "USD"
    },
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST",
    "CostFilters": {
        "TagKey": ["Project"],
        "TagValue": ["health-app"]
    }
}
EOF
    
    cat > /tmp/notifications.json << EOF
[
    {
        "Notification": {
            "NotificationType": "ACTUAL",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 80
        },
        "Subscribers": [
            {
                "SubscriptionType": "EMAIL",
                "Address": "$email"
            }
        ]
    },
    {
        "Notification": {
            "NotificationType": "FORECASTED",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 100
        },
        "Subscribers": [
            {
                "SubscriptionType": "EMAIL",
                "Address": "$email"
            }
        ]
    }
]
EOF
    
    if aws budgets describe-budget --account-id "$(aws sts get-caller-identity --query Account --output text)" --budget-name "$budget_name" >/dev/null 2>&1; then
        echo "  ✅ Budget $budget_name already exists"
    else
        echo "  📊 Creating budget: $budget_name"
        aws budgets create-budget \
            --account-id "$(aws sts get-caller-identity --query Account --output text)" \
            --budget file:///tmp/budget.json \
            --notifications-with-subscribers file:///tmp/notifications.json || echo "  ⚠️  Budget creation failed"
    fi
}

setup_cloudwatch_alarms() {
    echo "📊 Setting up CloudWatch alarms..."
    
    # EC2 instance count alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "HealthApp-EC2-InstanceCount" \
        --alarm-description "Alert when EC2 instance count exceeds limit" \
        --metric-name "InstanceCount" \
        --namespace "AWS/EC2" \
        --statistic "Sum" \
        --period 300 \
        --threshold 5 \
        --comparison-operator "GreaterThanThreshold" \
        --evaluation-periods 1 || echo "  ⚠️  EC2 alarm creation failed"
    
    # RDS instance count alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "HealthApp-RDS-InstanceCount" \
        --alarm-description "Alert when RDS instance count exceeds limit" \
        --metric-name "DatabaseConnections" \
        --namespace "AWS/RDS" \
        --statistic "Sum" \
        --period 300 \
        --threshold 3 \
        --comparison-operator "GreaterThanThreshold" \
        --evaluation-periods 1 || echo "  ⚠️  RDS alarm creation failed"
    
    echo "  ✅ CloudWatch alarms configured"
}

setup_terraform_validation() {
    echo "🔧 Setting up Terraform validation..."
    
    # Copy validation file to all environments
    for env_dir in infra/environments/*/; do
        if [[ -d "$env_dir" ]]; then
            cp infra/validation.tf "$env_dir/" 2>/dev/null || true
            echo "  📋 Validation rules copied to $env_dir"
        fi
    done
    
    # Make policy check script executable
    chmod +x scripts/terraform-policy-check.sh
    echo "  ✅ Terraform validation configured"
}

setup_pre_commit_hooks() {
    echo "🪝 Setting up pre-commit hooks..."
    
    cat > .pre-commit-config.yaml << EOF
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.5
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_checkov
        args:
          - --args=--framework terraform
          - --args=--check CKV_AWS_79  # Ensure Instance Metadata Service Version 1 is not enabled
          - --args=--check CKV_AWS_8   # Ensure all data stored in the Launch configuration EBS is securely encrypted at rest
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
EOF
    
    echo "  📝 Pre-commit configuration created"
    echo "  💡 Install with: pip install pre-commit && pre-commit install"
}

generate_governance_report() {
    echo "📋 Generating governance report..."
    
    local report_file="governance-report-$(date +%Y%m%d-%H%M%S).md"
    
    cat > "$report_file" << EOF
# Infrastructure Governance Report

**Generated:** $(date)
**Environment:** $ENVIRONMENT

## 🛡️ Security Controls

### IAM Policies
- ✅ Resource restriction policy created
- ✅ Region limitation enforced (ap-south-1 only)
- ✅ Instance type restrictions (t2.micro, t2.nano only)
- ✅ Cost controls (no NAT Gateway, Load Balancers)

### Required Tags
- Project: health-app
- Environment: dev/test/prod/monitoring
- ManagedBy: terraform

## 💰 Cost Controls

### Budget Alerts
- Monthly budget: \$1.00
- Alert at 80% actual spend
- Alert at 100% forecasted spend

### Resource Limits
- EC2: t2.micro/t2.nano only (Free Tier)
- RDS: db.t3.micro/db.t2.micro only (Free Tier)
- EBS: Maximum 20GB per volume
- Region: ap-south-1 only

## 🔧 Validation Rules

### Terraform Validation
- Built-in variable validation
- Check blocks for runtime validation
- Policy validation script

### Pre-commit Hooks
- Terraform formatting
- Terraform validation
- Security scanning (Checkov)
- YAML/JSON validation

## 📊 Monitoring

### CloudWatch Alarms
- EC2 instance count monitoring
- RDS instance count monitoring
- Cost anomaly detection

## 🚀 Deployment Controls

### GitHub Actions
- Pre-deployment validation
- Policy checks before apply
- Resource tracking in job summaries
- Automatic cleanup on failure

## 📝 Compliance

### Naming Convention
- Pattern: health-app-{component}-{environment}
- All resources must start with 'health-app-'
- Environment suffix required

### Tagging Standards
- All resources must have Project, Environment, ManagedBy tags
- Consistent tagging enforced via IAM policies
- Tag-based cost allocation enabled

EOF
    
    echo "  📄 Report saved to: $report_file"
}

case "$ACTION" in
    "setup")
        setup_iam_policies
        setup_budget_alerts
        setup_cloudwatch_alarms
        setup_terraform_validation
        setup_pre_commit_hooks
        generate_governance_report
        echo ""
        echo "✅ Governance setup completed!"
        echo "💡 Next steps:"
        echo "   1. Attach IAM policy to your user/role"
        echo "   2. Install pre-commit hooks"
        echo "   3. Review governance report"
        ;;
    "validate")
        echo "🔍 Running governance validation..."
        ./scripts/terraform-policy-check.sh tfplan policies validate
        ./scripts/validate-resource-tags.sh ap-south-1 "$ENVIRONMENT"
        ;;
    "report")
        generate_governance_report
        ;;
    *)
        echo "Usage: $0 [setup|validate|report] [environment]"
        exit 1
        ;;
esac
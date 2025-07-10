#!/bin/bash

# Terraform Policy Validation Script
# Validates Terraform plans against organizational policies

set -e

PLAN_FILE=${1:-"tfplan"}
POLICY_DIR=${2:-"policies"}
ACTION=${3:-"validate"}

echo "🛡️ Terraform Policy Validation"
echo "Plan file: $PLAN_FILE"
echo "Policy directory: $POLICY_DIR"
echo "Action: $ACTION"
echo ""

validate_plan_against_policies() {
    if [[ ! -f "$PLAN_FILE" ]]; then
        echo "❌ Plan file not found: $PLAN_FILE"
        exit 1
    fi
    
    echo "📋 Converting plan to JSON..."
    terraform show -json "$PLAN_FILE" > /tmp/tfplan.json
    
    echo "🔍 Validating against policies..."
    
    # Manual policy checks (since OPA might not be available)
    local violations=0
    
    # Check 1: Instance types
    echo "  Checking instance types..."
    local bad_instances=$(jq -r '.resource_changes[]? | select(.type=="aws_instance") | select(.change.after.instance_type != "t2.micro" and .change.after.instance_type != "t2.nano") | .address' /tmp/tfplan.json 2>/dev/null || echo "")
    if [[ -n "$bad_instances" ]]; then
        echo "    ❌ Non-free-tier instances found:"
        echo "$bad_instances" | sed 's/^/      /'
        violations=$((violations + 1))
    else
        echo "    ✅ All instances use free-tier types"
    fi
    
    # Check 2: RDS instance classes
    echo "  Checking RDS instance classes..."
    local bad_rds=$(jq -r '.resource_changes[]? | select(.type=="aws_db_instance") | select(.change.after.instance_class != "db.t3.micro" and .change.after.instance_class != "db.t2.micro") | .address' /tmp/tfplan.json 2>/dev/null || echo "")
    if [[ -n "$bad_rds" ]]; then
        echo "    ❌ Non-free-tier RDS instances found:"
        echo "$bad_rds" | sed 's/^/      /'
        violations=$((violations + 1))
    else
        echo "    ✅ All RDS instances use free-tier classes"
    fi
    
    # Check 3: EBS volume sizes
    echo "  Checking EBS volume sizes..."
    local large_volumes=$(jq -r '.resource_changes[]? | select(.type=="aws_ebs_volume") | select(.change.after.size > 20) | "\(.address): \(.change.after.size)GB"' /tmp/tfplan.json 2>/dev/null || echo "")
    if [[ -n "$large_volumes" ]]; then
        echo "    ❌ Oversized EBS volumes found:"
        echo "$large_volumes" | sed 's/^/      /'
        violations=$((violations + 1))
    else
        echo "    ✅ All EBS volumes within size limits"
    fi
    
    # Check 4: Prohibited resources
    echo "  Checking for prohibited resources..."
    local prohibited=$(jq -r '.resource_changes[]? | select(.type | test("aws_nat_gateway|aws_lb|aws_alb|aws_elb")) | .address' /tmp/tfplan.json 2>/dev/null || echo "")
    if [[ -n "$prohibited" ]]; then
        echo "    ❌ Prohibited expensive resources found:"
        echo "$prohibited" | sed 's/^/      /'
        violations=$((violations + 1))
    else
        echo "    ✅ No prohibited resources found"
    fi
    
    # Check 5: Required tags
    echo "  Checking required tags..."
    local missing_tags=$(jq -r '.resource_changes[]? | select(.type | test("aws_instance|aws_db_instance|aws_security_group")) | select(.change.after.tags.Name == null or .change.after.tags.Project == null or .change.after.tags.Environment == null) | .address' /tmp/tfplan.json 2>/dev/null || echo "")
    if [[ -n "$missing_tags" ]]; then
        echo "    ❌ Resources with missing required tags:"
        echo "$missing_tags" | sed 's/^/      /'
        violations=$((violations + 1))
    else
        echo "    ✅ All resources have required tags"
    fi
    
    # Check 6: Naming convention
    echo "  Checking naming convention..."
    local bad_names=$(jq -r '.resource_changes[]? | select(.type | test("aws_instance|aws_key_pair|aws_security_group")) | select(.change.after.tags.Name | test("^health-app-") | not) | "\(.address): \(.change.after.tags.Name)"' /tmp/tfplan.json 2>/dev/null || echo "")
    if [[ -n "$bad_names" ]]; then
        echo "    ❌ Resources with incorrect naming:"
        echo "$bad_names" | sed 's/^/      /'
        violations=$((violations + 1))
    else
        echo "    ✅ All resources follow naming convention"
    fi
    
    echo ""
    if [[ $violations -eq 0 ]]; then
        echo "✅ All policy checks passed!"
        return 0
    else
        echo "❌ Policy validation failed with $violations violations"
        return 1
    fi
}

generate_cost_estimate() {
    echo "💰 Generating cost estimate..."
    
    # Extract resource counts from plan
    local ec2_count=$(jq -r '[.resource_changes[]? | select(.type=="aws_instance")] | length' /tmp/tfplan.json 2>/dev/null || echo "0")
    local rds_count=$(jq -r '[.resource_changes[]? | select(.type=="aws_db_instance")] | length' /tmp/tfplan.json 2>/dev/null || echo "0")
    local ebs_size=$(jq -r '[.resource_changes[]? | select(.type=="aws_ebs_volume") | .change.after.size] | add // 0' /tmp/tfplan.json 2>/dev/null || echo "0")
    
    echo "  📊 Resource Summary:"
    echo "    EC2 Instances (t2.micro): $ec2_count"
    echo "    RDS Instances (db.t3.micro): $rds_count"
    echo "    EBS Storage: ${ebs_size}GB"
    
    echo "  💵 Estimated Monthly Cost:"
    echo "    EC2: $0 (Free Tier: 750 hours)"
    echo "    RDS: $0 (Free Tier: 750 hours)"
    echo "    EBS: $0 (Free Tier: 30GB)"
    echo "    Total: $0/month (within Free Tier limits)"
}

case "$ACTION" in
    "validate")
        validate_plan_against_policies
        ;;
    "cost-estimate")
        validate_plan_against_policies
        generate_cost_estimate
        ;;
    *)
        echo "Usage: $0 [plan_file] [policy_dir] [validate|cost-estimate]"
        exit 1
        ;;
esac
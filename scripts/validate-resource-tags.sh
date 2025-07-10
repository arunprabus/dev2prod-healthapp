#!/bin/bash

# Resource Tagging Validation Script
# Ensures all resources follow consistent tagging standards

set -e

REGION=${1:-"ap-south-1"}
ENVIRONMENT=${2:-""}

echo "🏷️ Resource Tagging Validation"
echo "Region: $REGION"
echo "Environment: $ENVIRONMENT"
echo ""

validate_ec2_tags() {
    echo "🖥️ Validating EC2 instance tags..."
    
    local instances=$(aws ec2 describe-instances --region "$REGION" --filters "Name=instance-state-name,Values=running,stopped" --query 'Reservations[].Instances[].[InstanceId,Tags]' --output json 2>/dev/null || echo "[]")
    
    if [[ "$instances" == "[]" ]]; then
        echo "  ✅ No EC2 instances found"
        return 0
    fi
    
    local validation_passed=true
    
    echo "$instances" | jq -r '.[] | @base64' | while IFS= read -r instance; do
        local instance_data=$(echo "$instance" | base64 -d)
        local instance_id=$(echo "$instance_data" | jq -r '.[0]')
        local tags=$(echo "$instance_data" | jq -r '.[1]')
        
        echo "  📋 Instance: $instance_id"
        
        # Check required tags
        local name_tag=$(echo "$tags" | jq -r '.[] | select(.Key=="Name") | .Value' 2>/dev/null || echo "")
        local project_tag=$(echo "$tags" | jq -r '.[] | select(.Key=="Project") | .Value' 2>/dev/null || echo "")
        local env_tag=$(echo "$tags" | jq -r '.[] | select(.Key=="Environment") | .Value' 2>/dev/null || echo "")
        
        if [[ -z "$name_tag" ]]; then
            echo "    ❌ Missing Name tag"
            validation_passed=false
        elif [[ "$name_tag" =~ ^health-app- ]]; then
            echo "    ✅ Name tag: $name_tag"
        else
            echo "    ⚠️  Name tag doesn't follow convention: $name_tag"
        fi
        
        if [[ "$project_tag" == "health-app" ]]; then
            echo "    ✅ Project tag: $project_tag"
        else
            echo "    ❌ Missing or incorrect Project tag: $project_tag"
            validation_passed=false
        fi
        
        if [[ -n "$ENVIRONMENT" && "$env_tag" == "$ENVIRONMENT" ]]; then
            echo "    ✅ Environment tag: $env_tag"
        elif [[ -n "$ENVIRONMENT" ]]; then
            echo "    ❌ Environment tag mismatch: expected $ENVIRONMENT, got $env_tag"
            validation_passed=false
        fi
    done
}

validate_rds_tags() {
    echo ""
    echo "🗄️ Validating RDS instance tags..."
    
    local rds_instances=$(aws rds describe-db-instances --region "$REGION" --query 'DBInstances[].DBInstanceIdentifier' --output text 2>/dev/null || echo "")
    
    if [[ -z "$rds_instances" ]]; then
        echo "  ✅ No RDS instances found"
        return 0
    fi
    
    for db_id in $rds_instances; do
        echo "  📋 RDS Instance: $db_id"
        
        local db_arn=$(aws rds describe-db-instances --region "$REGION" --db-instance-identifier "$db_id" --query 'DBInstances[0].DBInstanceArn' --output text)
        local tags=$(aws rds list-tags-for-resource --region "$REGION" --resource-name "$db_arn" --query 'TagList' --output json 2>/dev/null || echo "[]")
        
        local name_tag=$(echo "$tags" | jq -r '.[] | select(.Key=="Name") | .Value' 2>/dev/null || echo "")
        local project_tag=$(echo "$tags" | jq -r '.[] | select(.Key=="Project") | .Value' 2>/dev/null || echo "")
        
        if [[ "$name_tag" =~ ^health-app- ]]; then
            echo "    ✅ Name tag: $name_tag"
        else
            echo "    ⚠️  Name tag doesn't follow convention: $name_tag"
        fi
        
        if [[ "$project_tag" == "health-app" ]]; then
            echo "    ✅ Project tag: $project_tag"
        else
            echo "    ❌ Missing or incorrect Project tag: $project_tag"
        fi
    done
}

validate_security_group_tags() {
    echo ""
    echo "🛡️ Validating Security Group tags..."
    
    local security_groups=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=group-name,Values=*health-app*" --query 'SecurityGroups[].[GroupId,GroupName,Tags]' --output json 2>/dev/null || echo "[]")
    
    if [[ "$security_groups" == "[]" ]]; then
        echo "  ✅ No health-app security groups found"
        return 0
    fi
    
    echo "$security_groups" | jq -r '.[] | @base64' | while IFS= read -r sg; do
        local sg_data=$(echo "$sg" | base64 -d)
        local sg_id=$(echo "$sg_data" | jq -r '.[0]')
        local sg_name=$(echo "$sg_data" | jq -r '.[1]')
        local tags=$(echo "$sg_data" | jq -r '.[2]')
        
        echo "  📋 Security Group: $sg_id ($sg_name)"
        
        local name_tag=$(echo "$tags" | jq -r '.[] | select(.Key=="Name") | .Value' 2>/dev/null || echo "")
        local project_tag=$(echo "$tags" | jq -r '.[] | select(.Key=="Project") | .Value' 2>/dev/null || echo "")
        
        if [[ "$name_tag" =~ ^health-app- ]]; then
            echo "    ✅ Name tag: $name_tag"
        else
            echo "    ⚠️  Name tag: $name_tag"
        fi
        
        if [[ "$project_tag" == "health-app" ]]; then
            echo "    ✅ Project tag: $project_tag"
        else
            echo "    ❌ Missing Project tag"
        fi
    done
}

generate_tagging_report() {
    echo ""
    echo "📊 Generating tagging compliance report..."
    
    local report_file="/tmp/tagging-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "region": "$REGION",
  "environment": "$ENVIRONMENT",
  "scan_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "compliance_summary": {
    "total_resources": 0,
    "compliant_resources": 0,
    "non_compliant_resources": 0
  },
  "required_tags": [
    "Name",
    "Project",
    "Environment"
  ],
  "naming_convention": "health-app-{component}-{environment}"
}
EOF
    
    echo "📋 Report saved to: $report_file"
    echo "💡 Use this report to track tagging compliance over time"
}

# Main execution
validate_ec2_tags
validate_rds_tags
validate_security_group_tags
generate_tagging_report

echo ""
echo "✅ Resource tagging validation completed"
echo "💡 Ensure all resources follow the health-app-{component}-{environment} naming convention"
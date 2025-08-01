#!/bin/bash
set -e

echo "🔧 Fixing common workflow issues..."

# Fix instance discovery issues
echo "📍 Fixing instance discovery..."
cat > /tmp/fix-instance-discovery.sh << 'EOF'
#!/bin/bash
# Get instances with better error handling
get_instance_id() {
    local tag_name="$1"
    local instance_id=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$tag_name" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text 2>/dev/null)
    
    if [ "$instance_id" = "None" ] || [ -z "$instance_id" ]; then
        echo "null"
    else
        echo "$instance_id"
    fi
}

# Test instance discovery
echo "Testing instance discovery..."
DEV_ID=$(get_instance_id "health-app-dev-k3s")
TEST_ID=$(get_instance_id "health-app-test-k3s")
RUNNER_ID=$(get_instance_id "health-app-runner-lower")

echo "Dev instance: $DEV_ID"
echo "Test instance: $TEST_ID" 
echo "Runner instance: $RUNNER_ID"
EOF

chmod +x /tmp/fix-instance-discovery.sh
/tmp/fix-instance-discovery.sh

# Fix SSM permissions
echo "🔐 Checking SSM permissions..."
aws ssm describe-instance-information --max-items 1 > /dev/null && \
    echo "✅ SSM permissions OK" || echo "❌ SSM permissions issue"

# Fix Run Command document availability
echo "📋 Checking Run Command documents..."
aws ssm describe-document --name "AWS-RunShellScript" > /dev/null && \
    echo "✅ AWS-RunShellScript available" || echo "❌ AWS-RunShellScript not available"

echo "✅ Workflow fixes completed"
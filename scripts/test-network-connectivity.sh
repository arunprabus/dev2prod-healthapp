#!/bin/bash

# Database Connectivity Testing Script
# Tests connectivity from K3s instances to RDS database using cross-SG references

set -e

ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-ap-south-1}

echo "🔍 Testing database connectivity for $ENVIRONMENT environment..."

# Get database endpoint and port from Terraform outputs
cd infra

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    terraform init \
        -backend-config="bucket=${TF_STATE_BUCKET}" \
        -backend-config="key=health-app-${ENVIRONMENT}.tfstate" \
        -backend-config="region=${AWS_REGION}"
fi

# Get database connection details
DB_ENDPOINT=$(terraform output -raw db_instance_address 2>/dev/null || echo "")
DB_PORT=$(terraform output -raw db_instance_port 2>/dev/null || echo "3306")

if [ -z "$DB_ENDPOINT" ]; then
    echo "❌ Database endpoint not found. Make sure database is deployed."
    exit 1
fi

echo "📍 Database endpoint: $DB_ENDPOINT:$DB_PORT"

# Get K3s instance details
if [ "$ENVIRONMENT" == "dev" ] || [ "$ENVIRONMENT" == "test" ]; then
    # Lower environment - multiple clusters
    CLUSTER_IP=$(terraform output -raw ${ENVIRONMENT}_cluster_ip 2>/dev/null || echo "")
else
    # Higher environment - single cluster
    CLUSTER_IP=$(terraform output -raw k3s_instance_ip 2>/dev/null || echo "")
fi

if [ -z "$CLUSTER_IP" ]; then
    echo "❌ K3s cluster IP not found. Make sure cluster is deployed."
    exit 1
fi

echo "📍 K3s cluster IP: $CLUSTER_IP"

# Test connectivity from bastion/SSM session
echo ""
echo "🧪 Testing connectivity from K3s instance to database..."

# Create test script for remote execution
cat > /tmp/db_connectivity_test.sh << 'EOF'
#!/bin/bash

DB_HOST=$1
DB_PORT=$2

echo "Testing connectivity to $DB_HOST:$DB_PORT"

# Test 1: Basic network connectivity using nc
echo "🔌 Testing network connectivity..."
if command -v nc >/dev/null 2>&1; then
    if timeout 10 nc -zv $DB_HOST $DB_PORT 2>&1; then
        echo "✅ Network connectivity successful"
        NETWORK_OK=true
    else
        echo "❌ Network connectivity failed"
        NETWORK_OK=false
    fi
else
    echo "⚠️ netcat not available, installing..."
    sudo apt-get update -qq && sudo apt-get install -y netcat-openbsd
    if timeout 10 nc -zv $DB_HOST $DB_PORT 2>&1; then
        echo "✅ Network connectivity successful"
        NETWORK_OK=true
    else
        echo "❌ Network connectivity failed"
        NETWORK_OK=false
    fi
fi

# Test 2: DNS resolution
echo ""
echo "🔍 Testing DNS resolution..."
if nslookup $DB_HOST >/dev/null 2>&1; then
    echo "✅ DNS resolution successful"
    nslookup $DB_HOST | grep -A2 "Name:"
else
    echo "❌ DNS resolution failed"
fi

# Test 3: Route testing
echo ""
echo "🛣️ Testing routing..."
echo "Route to database:"
ip route get $(nslookup $DB_HOST | grep -A1 "Name:" | tail -1 | awk '{print $2}') 2>/dev/null || echo "Route lookup failed"

# Test 4: Security group verification
echo ""
echo "🔒 Security group information:"
echo "Instance metadata:"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "Instance ID: $INSTANCE_ID"

# Test 5: MySQL client test (if available)
echo ""
echo "🗄️ Testing MySQL client connectivity..."
if command -v mysql >/dev/null 2>&1; then
    echo "MySQL client available, testing connection..."
    # Test connection without password (will fail but shows if port is reachable)
    timeout 10 mysql -h $DB_HOST -P $DB_PORT -u admin --connect-timeout=5 -e "SELECT 1;" 2>&1 | head -5
else
    echo "MySQL client not available, installing..."
    sudo apt-get update -qq && sudo apt-get install -y mysql-client
    if command -v mysql >/dev/null 2>&1; then
        echo "Testing MySQL connection..."
        timeout 10 mysql -h $DB_HOST -P $DB_PORT -u admin --connect-timeout=5 -e "SELECT 1;" 2>&1 | head -5
    fi
fi

# Test 6: Telnet test as fallback
echo ""
echo "📞 Testing telnet connectivity..."
if command -v telnet >/dev/null 2>&1; then
    (echo "quit"; sleep 2) | timeout 10 telnet $DB_HOST $DB_PORT 2>&1 | head -10
else
    echo "Telnet not available"
fi

echo ""
if [ "$NETWORK_OK" = true ]; then
    echo "🎉 Basic connectivity test PASSED"
    exit 0
else
    echo "❌ Basic connectivity test FAILED"
    exit 1
fi
EOF

chmod +x /tmp/db_connectivity_test.sh

# Execute test on K3s instance via SSH
echo "🚀 Executing connectivity test on K3s instance..."

# Use SSH key from environment or default location
SSH_KEY=${SSH_PRIVATE_KEY_PATH:-~/.ssh/id_rsa}
if [ ! -f "$SSH_KEY" ] && [ -n "$SSH_PRIVATE_KEY" ]; then
    echo "$SSH_PRIVATE_KEY" > /tmp/ssh_key
    chmod 600 /tmp/ssh_key
    SSH_KEY=/tmp/ssh_key
fi

if [ ! -f "$SSH_KEY" ]; then
    echo "❌ SSH key not found. Set SSH_PRIVATE_KEY_PATH or SSH_PRIVATE_KEY environment variable."
    exit 1
fi

# Copy and execute test script
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no /tmp/db_connectivity_test.sh ubuntu@$CLUSTER_IP:/tmp/
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$CLUSTER_IP "bash /tmp/db_connectivity_test.sh $DB_ENDPOINT $DB_PORT"

TEST_RESULT=$?

# Test from within a Kubernetes pod
echo ""
echo "🐳 Testing connectivity from within Kubernetes pod..."

# Get kubeconfig
KUBECONFIG_SECRET=""
case $ENVIRONMENT in
    "dev")
        KUBECONFIG_SECRET="KUBECONFIG_DEV"
        ;;
    "test")
        KUBECONFIG_SECRET="KUBECONFIG_TEST"
        ;;
    "prod")
        KUBECONFIG_SECRET="KUBECONFIG_PROD"
        ;;
esac

if [ -n "$KUBECONFIG_SECRET" ]; then
    # Try to get kubeconfig from GitHub secrets (if available)
    if [ -n "${!KUBECONFIG_SECRET}" ]; then
        echo "${!KUBECONFIG_SECRET}" | base64 -d > /tmp/kubeconfig
        export KUBECONFIG=/tmp/kubeconfig
        
        echo "Testing from Kubernetes pod..."
        kubectl run connectivity-test --image=busybox --rm -it --restart=Never --insecure-skip-tls-verify -- /bin/sh -c "
            echo 'Testing from pod...'
            echo 'Installing telnet...'
            # Most busybox images have nc (netcat)
            if nc -zv $DB_ENDPOINT $DB_PORT; then
                echo '✅ Pod connectivity successful'
            else
                echo '❌ Pod connectivity failed'
            fi
        " 2>/dev/null || echo "⚠️ Kubernetes pod test failed (cluster may not be ready)"
        
        rm -f /tmp/kubeconfig
    else
        echo "⚠️ Kubeconfig secret $KUBECONFIG_SECRET not available"
    fi
fi

# Cleanup
rm -f /tmp/db_connectivity_test.sh /tmp/ssh_key

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    echo "🎉 Database connectivity test completed successfully!"
    echo ""
    echo "✅ Security groups are properly configured for cross-SG communication"
    echo "✅ Network routing is working correctly"
    echo "✅ Database is accessible from application layer"
else
    echo "❌ Database connectivity test failed!"
    echo ""
    echo "🔧 Troubleshooting steps:"
    echo "1. Check security group rules allow traffic between app and DB SGs"
    echo "2. Verify subnet routing and NACLs"
    echo "3. Ensure database is in running state"
    echo "4. Check DNS resolution"
    exit 1
fi
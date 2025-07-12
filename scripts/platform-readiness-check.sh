#!/bin/bash

# Platform Readiness Check Script
# Usage: ./platform-readiness-check.sh <network_tier> <check_type>

NETWORK_TIER=${1:-lower}
CHECK_TYPE=${2:-full}

echo "🔍 Platform Readiness Check Started"
echo "Network Tier: $NETWORK_TIER"
echo "Check Type: $CHECK_TYPE"
echo "Runner: $(hostname)"
echo "Date: $(date)"

# Determine environments and database for this network
if [ "$NETWORK_TIER" = "lower" ]; then
    ENVIRONMENTS="dev,test"
    DB_INSTANCE="health-app-lower-db"
elif [ "$NETWORK_TIER" = "higher" ]; then
    ENVIRONMENTS="prod"
    DB_INSTANCE="health-app-higher-db"
else
    ENVIRONMENTS="monitoring"
    DB_INSTANCE="none"
fi

# Runner Health Check
if [ "$CHECK_TYPE" = "full" ] || [ "$CHECK_TYPE" = "runner-only" ]; then
    echo "🤖 Checking Runner Health for $NETWORK_TIER network..."
    
    # Install missing tools
    if ! command -v kubectl &> /dev/null; then
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
    
    if ! command -v psql &> /dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y postgresql-client
    fi
    
    # System info
    RUNNER_HOSTNAME=$(hostname)
    RUNNER_DISK=$(df -h / | tail -1 | awk '{print $5}')
    RUNNER_MEMORY=$(free -h | grep Mem | awk '{print $3"/"$2}')
    
    # Network connectivity
    RUNNER_GITHUB_API=$(curl -s https://api.github.com/zen > /dev/null && echo "✅ Connected" || echo "❌ Failed")
    RUNNER_INTERNET=$(ping -c 3 8.8.8.8 > /dev/null 2>&1 && echo "✅ Connected" || echo "❌ Failed")
    
    # Software versions
    RUNNER_DOCKER=$(docker --version 2>/dev/null || echo "Not installed")
    RUNNER_KUBECTL=$(kubectl version --client --short 2>/dev/null || echo "Installed")
fi

# Database Health Check
if [ "$CHECK_TYPE" = "full" ] || [ "$CHECK_TYPE" = "database-only" ]; then
    if [ "$DB_INSTANCE" != "none" ]; then
        echo "🗄️ Checking Database Health for $NETWORK_TIER network..."
        
        # List all RDS instances first
        echo "=== All RDS Instances ==="
        aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]' --output table 2>/dev/null || echo "No RDS instances found"
        
        # Get RDS endpoint - try multiple possible names
        DB_ENDPOINT="not-found"
        
        # Try the expected name first
        DB_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE --query 'DBInstances[0].Endpoint.Address' --output text 2>/dev/null || echo "not-found")
        
        # If not found, try alternative names
        if [ "$DB_ENDPOINT" = "not-found" ]; then
            echo "Trying alternative database names..."
            for ALT_NAME in "health-app-$NETWORK_TIER-db" "healthapi-db-$NETWORK_TIER" "health-app-db"; do
                ALT_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $ALT_NAME --query 'DBInstances[0].Endpoint.Address' --output text 2>/dev/null || echo "")
                if [ -n "$ALT_ENDPOINT" ] && [ "$ALT_ENDPOINT" != "None" ]; then
                    DB_ENDPOINT=$ALT_ENDPOINT
                    echo "Found database: $ALT_NAME -> $DB_ENDPOINT"
                    break
                fi
            done
        fi
        
        if [ "$DB_ENDPOINT" != "not-found" ]; then
            # Test connectivity
            DB_CONNECTION=$(pg_isready -h $DB_ENDPOINT -p 5432 -U postgres > /dev/null 2>&1 && echo "✅ Connected" || echo "❌ Failed")
            
            if [[ "$DB_CONNECTION" == *"Connected"* ]]; then
                DB_VERSION=$(PGPASSWORD=postgres123 psql -h $DB_ENDPOINT -U postgres -d healthapi -t -c "SELECT version();" 2>/dev/null | head -1 | xargs || echo "Access denied")
                DB_TABLE_COUNT=$(PGPASSWORD=postgres123 psql -h $DB_ENDPOINT -U postgres -d healthapi -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | xargs || echo "0")
            else
                DB_VERSION="Connection failed"
                DB_TABLE_COUNT="0"
            fi
        else
            DB_CONNECTION="❌ RDS not found"
            DB_VERSION="N/A"
            DB_TABLE_COUNT="0"
        fi
    fi
fi

# Kubernetes Health Check
if [ "$CHECK_TYPE" = "full" ] || [ "$CHECK_TYPE" = "kubernetes-only" ]; then
    if [ "$NETWORK_TIER" != "monitoring" ]; then
        echo "☸️ Checking Kubernetes Health for $NETWORK_TIER network..."
        
        # List all EC2 instances first
        echo "=== All Running EC2 Instances ==="
        aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],InstanceId,PublicIpAddress]' --output table 2>/dev/null || echo "No running instances"
        
        # Find K3s cluster - try multiple possible names
        K3S_IP=""
        
        # Try different naming patterns
        for K3S_NAME in "health-app-$NETWORK_TIER-k3s-node" "health-app-k3s-$NETWORK_TIER" "health-app-k3s-node"; do
            K3S_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$K3S_NAME" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo "")
            if [ -n "$K3S_IP" ] && [ "$K3S_IP" != "None" ]; then
                echo "Found K3s cluster: $K3S_NAME -> $K3S_IP"
                break
            fi
        done
        
        if [ -n "$K3S_IP" ] && [ "$K3S_IP" != "None" ]; then
            echo "Found K3s cluster at: $K3S_IP"
            
            # Download actual kubeconfig with proper authentication
            if command -v ssh &> /dev/null; then
                echo "Downloading kubeconfig with SSH key authentication..."
                
                # Use SSH key from environment or default location
                SSH_KEY="/tmp/ssh_key"
                if [ -n "$SSH_PRIVATE_KEY" ]; then
                    echo "$SSH_PRIVATE_KEY" > $SSH_KEY
                    chmod 600 $SSH_KEY
                elif [ -f "/home/ubuntu/.ssh/id_rsa" ]; then
                    SSH_KEY="/home/ubuntu/.ssh/id_rsa"
                else
                    echo "No SSH key available for K3s access"
                    K8S_CONNECTION="❌ No SSH key for authentication"
                    K8S_NODES="0"
                    K8S_DETAILS="SSH key required for K3s access"
                    return
                fi
                
                # Download kubeconfig from K3s cluster
                if scp -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$K3S_IP:/etc/rancher/k3s/k3s.yaml /tmp/kubeconfig 2>/dev/null; then
                    # Update server IP in kubeconfig (K3s defaults to 127.0.0.1)
                    sed -i "s/127.0.0.1/$K3S_IP/g" /tmp/kubeconfig
                    
                    # Test connectivity with real authentication
                    export KUBECONFIG=/tmp/kubeconfig
                    if kubectl cluster-info > /dev/null 2>&1; then
                        K8S_CONNECTION="✅ Connected (authenticated)"
                        K8S_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
                        K8S_DETAILS="Connected with K3s server certificate"
                    else
                        K8S_CONNECTION="❌ Authentication failed"
                        K8S_NODES="0"
                        K8S_DETAILS="Kubeconfig downloaded but authentication failed"
                    fi
                else
                    K8S_CONNECTION="❌ Cannot download kubeconfig"
                    K8S_NODES="0"
                    K8S_DETAILS="SSH connection to K3s cluster failed"
                fi
                
                # Cleanup
                rm -f /tmp/kubeconfig
                if [ "$SSH_KEY" = "/tmp/ssh_key" ]; then
                    rm -f $SSH_KEY
                fi
            else
                K8S_CONNECTION="❌ SSH not available"
                K8S_NODES="0"
                K8S_DETAILS="SSH required to download kubeconfig"
            fi
        else
            K8S_CONNECTION="❌ K3s cluster not found"
            K8S_NODES="0"
            K8S_DETAILS="No K3s cluster found"
        fi
    fi
fi

# Generate Summary
echo ""
echo "## 🏥 Platform Readiness Check - $NETWORK_TIER Network"
echo ""
echo "### 📊 Network Details"
echo "Network Tier: $NETWORK_TIER"
echo "Environments: $ENVIRONMENTS"
echo "Check Type: $CHECK_TYPE"
echo "Date: $(date)"
echo ""

if [ "$CHECK_TYPE" = "full" ] || [ "$CHECK_TYPE" = "runner-only" ]; then
    echo "### 🤖 GitHub Runner Status"
    echo "Hostname: $RUNNER_HOSTNAME"
    echo "Disk Usage: $RUNNER_DISK"
    echo "Memory Usage: $RUNNER_MEMORY"
    echo "GitHub API: $RUNNER_GITHUB_API"
    echo "Internet: $RUNNER_INTERNET"
    echo "Docker: $RUNNER_DOCKER"
    echo "kubectl: $RUNNER_KUBECTL"
    echo ""
fi

if [ "$CHECK_TYPE" = "full" ] || [ "$CHECK_TYPE" = "database-only" ]; then
    if [ "$DB_INSTANCE" != "none" ]; then
        echo "### 🗄️ Database Status"
        echo "Instance: $DB_INSTANCE"
        echo "Endpoint: $DB_ENDPOINT"
        echo "Connection: $DB_CONNECTION"
        echo "Version: $DB_VERSION"
        echo "Tables: $DB_TABLE_COUNT"
        echo ""
    fi
fi

if [ "$CHECK_TYPE" = "full" ] || [ "$CHECK_TYPE" = "kubernetes-only" ]; then
    if [ "$NETWORK_TIER" != "monitoring" ]; then
        echo "### ☸️ Kubernetes Status"
        echo "Connection: $K8S_CONNECTION"
        echo "Nodes: $K8S_NODES"
        echo "Details: $K8S_DETAILS"
        echo ""
    fi
fi

# Overall status
OVERALL_STATUS="✅ Ready"
if [[ "$RUNNER_GITHUB_API" == *"Failed"* ]] || [[ "$DB_CONNECTION" == *"Failed"* ]] || [[ "$K8S_CONNECTION" == *"Failed"* ]]; then
    OVERALL_STATUS="❌ Issues Detected"
fi

echo "### 🎯 Overall Network Status"
echo "Status: $OVERALL_STATUS"
echo "Network Ready: $([[ "$OVERALL_STATUS" == *"Ready"* ]] && echo "Yes" || echo "No")"

echo "🏥 Platform readiness check completed for $NETWORK_TIER network"
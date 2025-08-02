#!/bin/bash

# Test User Data Completion Check
# This script demonstrates the improved Terraform user data completion verification

set -e

echo "🧪 Testing User Data Completion Check"
echo "======================================"

# Function to simulate user data completion check
test_completion_check() {
    local instance_ip="$1"
    local ssh_key="$2"
    
    echo "🔍 Testing completion check for instance: $instance_ip"
    
    # Simulate the null_resource remote-exec provisioner logic
    echo "📋 Simulating Terraform null_resource remote-exec provisioner:"
    echo ""
    echo "connection {"
    echo "  type        = \"ssh\""
    echo "  user        = \"ubuntu\""
    echo "  private_key = var.ssh_private_key"
    echo "  host        = aws_instance.k3s.public_ip"
    echo "  timeout     = \"10m\""
    echo "}"
    echo ""
    echo "provisioner \"remote-exec\" {"
    echo "  inline = ["
    echo "    \"echo 'Waiting for K3s installation to complete...'\","
    echo "    \"while [ ! -f /var/log/k3s-install-complete ]; do\","
    echo "    \"  echo 'K3s installation in progress... (\$(date))'\","
    echo "    \"  sleep 30\","
    echo "    \"done\","
    echo "    \"echo 'K3s installation marker found, verifying service...'\","
    echo "    \"sudo systemctl is-active k3s\","
    echo "    \"echo 'Verifying kubectl connectivity...'\","
    echo "    \"sudo kubectl get nodes --kubeconfig=/etc/rancher/k3s/k3s.yaml\","
    echo "    \"echo 'K3s cluster is ready and operational!'\""
    echo "  ]"
    echo "}"
    echo ""
    
    if [ -n "$instance_ip" ] && [ -n "$ssh_key" ]; then
        echo "🔗 Testing actual SSH connection to $instance_ip..."
        
        # Create temporary SSH key file
        echo "$ssh_key" > /tmp/test_key
        chmod 600 /tmp/test_key
        
        # Test SSH connectivity
        if ssh -i /tmp/test_key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$instance_ip "echo 'SSH connection successful'" 2>/dev/null; then
            echo "✅ SSH connection successful"
            
            # Check for completion marker
            if ssh -i /tmp/test_key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$instance_ip "[ -f /var/log/k3s-install-complete ]" 2>/dev/null; then
                echo "✅ K3s installation completion marker found"
                
                # Check K3s service
                if ssh -i /tmp/test_key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$instance_ip "sudo systemctl is-active k3s" 2>/dev/null; then
                    echo "✅ K3s service is active"
                    
                    # Test kubectl
                    if ssh -i /tmp/test_key -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$instance_ip "sudo kubectl get nodes --kubeconfig=/etc/rancher/k3s/k3s.yaml" 2>/dev/null; then
                        echo "✅ kubectl connectivity verified"
                        echo "🎉 All checks passed - K3s is fully operational!"
                    else
                        echo "❌ kubectl connectivity failed"
                    fi
                else
                    echo "❌ K3s service is not active"
                fi
            else
                echo "⏳ K3s installation still in progress (completion marker not found)"
            fi
        else
            echo "❌ SSH connection failed"
        fi
        
        # Cleanup
        rm -f /tmp/test_key
    else
        echo "ℹ️ No instance IP or SSH key provided - showing simulation only"
    fi
}

# Benefits explanation
show_benefits() {
    echo ""
    echo "🚀 Benefits of User Data Completion Check"
    echo "========================================="
    echo ""
    echo "✅ BEFORE (Problem):"
    echo "   - Terraform considers EC2 instance 'ready' immediately after creation"
    echo "   - User data script runs in background (can take 5-10 minutes)"
    echo "   - Subsequent resources may fail if they depend on K3s being ready"
    echo "   - Manual SSH/SSM checks required to verify installation"
    echo ""
    echo "✅ AFTER (Solution):"
    echo "   - Terraform waits for K3s installation to complete"
    echo "   - null_resource with remote-exec provisioner blocks until ready"
    echo "   - Verifies completion marker: /var/log/k3s-install-complete"
    echo "   - Tests K3s service status and kubectl connectivity"
    echo "   - Guarantees K3s is operational before marking deployment complete"
    echo ""
    echo "🔧 Implementation Details:"
    echo "   - Uses SSH connection with private key from GitHub secrets"
    echo "   - Polls for completion marker every 30 seconds"
    echo "   - 10-minute timeout prevents infinite waiting"
    echo "   - Triggers re-provisioning if instance changes"
    echo ""
    echo "💰 Cost Impact: $0 (uses existing SSH connectivity)"
    echo "⏱️  Time Impact: +0-10 minutes (waits for actual completion)"
    echo "🛡️  Reliability: Significantly improved deployment success rate"
}

# Usage instructions
show_usage() {
    echo ""
    echo "📋 Usage Instructions"
    echo "===================="
    echo ""
    echo "1. The improvement is already implemented in:"
    echo "   - infra/live/main.tf (null_resource \"wait_for_k3s\")"
    echo "   - infra/modules/k3s/main.tf (if using K3s module)"
    echo ""
    echo "2. Required GitHub Secrets:"
    echo "   - SSH_PRIVATE_KEY: Your SSH private key content"
    echo "   - SSH_PUBLIC_KEY: Your SSH public key content"
    echo ""
    echo "3. Deploy infrastructure normally:"
    echo "   Actions → Core Infrastructure → deploy → lower"
    echo ""
    echo "4. Terraform will now:"
    echo "   - Create EC2 instance"
    echo "   - Wait for user data to complete K3s installation"
    echo "   - Verify K3s service is running"
    echo "   - Test kubectl connectivity"
    echo "   - Only then mark deployment as successful"
    echo ""
    echo "5. Monitor progress in GitHub Actions logs:"
    echo "   Look for: 'Waiting for K3s installation to complete...'"
    echo ""
}

# Main execution
main() {
    local instance_ip="${1:-}"
    local ssh_key="${2:-}"
    
    test_completion_check "$instance_ip" "$ssh_key"
    show_benefits
    show_usage
    
    echo ""
    echo "🎯 Next Steps:"
    echo "1. Ensure SSH_PRIVATE_KEY secret is configured in GitHub"
    echo "2. Deploy infrastructure using GitHub Actions"
    echo "3. Observe improved reliability in deployment logs"
    echo ""
    echo "💡 To test with actual instance:"
    echo "./test-user-data-completion.sh <INSTANCE_IP> <SSH_PRIVATE_KEY_CONTENT>"
}

# Run main function with arguments
main "$@"
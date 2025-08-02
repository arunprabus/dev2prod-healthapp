#!/bin/bash

# Test SSM-based User Data Completion Check
# This script demonstrates the SSM implementation

set -e

echo "🔧 Testing SSM-based User Data Completion Check"
echo "==============================================="

# Function to test SSM completion check
test_ssm_completion() {
    local instance_id="$1"
    
    echo "🔍 Testing SSM completion check for instance: $instance_id"
    
    if [ -n "$instance_id" ]; then
        echo "📋 Checking SSM agent status..."
        
        # Check if SSM agent is online
        SSM_STATUS=$(aws ssm describe-instance-information \
            --filters "Key=InstanceIds,Values=$instance_id" \
            --query "InstanceInformationList[0].PingStatus" \
            --output text 2>/dev/null || echo "Unknown")
        
        echo "SSM Agent Status: $SSM_STATUS"
        
        if [ "$SSM_STATUS" = "Online" ]; then
            echo "✅ SSM agent is online"
            
            # Test completion marker check
            echo "📋 Testing completion marker check..."
            RESULT=$(aws ssm send-command \
                --instance-ids "$instance_id" \
                --document-name "AWS-RunShellScript" \
                --parameters 'commands=["test -f /var/log/k3s-install-complete && echo COMPLETE || echo WAITING"]' \
                --query "Command.CommandId" --output text)
            
            echo "Command ID: $RESULT"
            
            # Wait for command to complete
            sleep 10
            
            # Get command result
            STATUS=$(aws ssm get-command-invocation \
                --command-id "$RESULT" \
                --instance-id "$instance_id" \
                --query "StandardOutputContent" --output text 2>/dev/null || echo "FAILED")
            
            echo "Completion Status: $STATUS"
            
            if echo "$STATUS" | grep -q "COMPLETE"; then
                echo "✅ K3s installation completed!"
                
                # Test service verification
                echo "📋 Testing service verification..."
                VERIFY_CMD=$(aws ssm send-command \
                    --instance-ids "$instance_id" \
                    --document-name "AWS-RunShellScript" \
                    --parameters 'commands=["systemctl is-active k3s && kubectl get nodes --kubeconfig=/etc/rancher/k3s/k3s.yaml"]' \
                    --query "Command.CommandId" --output text)
                
                sleep 5
                
                VERIFY_RESULT=$(aws ssm get-command-invocation \
                    --command-id "$VERIFY_CMD" \
                    --instance-id "$instance_id" \
                    --query "StandardOutputContent" --output text 2>/dev/null || echo "FAILED")
                
                echo "Service Status: $VERIFY_RESULT"
                
                if echo "$VERIFY_RESULT" | grep -q "active"; then
                    echo "✅ K3s service is active and kubectl works!"
                else
                    echo "❌ K3s service verification failed"
                fi
            else
                echo "⏳ K3s installation still in progress"
            fi
        else
            echo "❌ SSM agent is not online"
        fi
    else
        echo "ℹ️ No instance ID provided - showing simulation only"
        
        # Show the Terraform implementation
        echo ""
        echo "📋 Terraform SSM Implementation:"
        echo "================================"
        cat << 'EOF'
resource "null_resource" "wait_for_k3s" {
  depends_on = [aws_instance.k3s]
  
  provisioner "local-exec" {
    command = <<-EOT
      # Wait for SSM agent to be ready
      for i in {1..20}; do
        if aws ssm describe-instance-information \
           --filters "Key=InstanceIds,Values=${aws_instance.k3s.id}" \
           --query "InstanceInformationList[0].PingStatus" \
           --output text | grep -q "Online"; then
          echo "SSM agent is online"
          break
        fi
        sleep 30
      done
      
      # Check for K3s completion marker
      for i in {1..20}; do
        RESULT=$(aws ssm send-command \
          --instance-ids "${aws_instance.k3s.id}" \
          --document-name "AWS-RunShellScript" \
          --parameters 'commands=["test -f /var/log/k3s-install-complete && echo COMPLETE || echo WAITING"]' \
          --query "Command.CommandId" --output text)
        
        sleep 10
        
        STATUS=$(aws ssm get-command-invocation \
          --command-id "$RESULT" \
          --instance-id "${aws_instance.k3s.id}" \
          --query "StandardOutputContent" --output text)
        
        if echo "$STATUS" | grep -q "COMPLETE"; then
          echo "K3s installation completed!"
          exit 0
        fi
        
        sleep 30
      done
    EOT
  }
}
EOF
    fi
}

# Benefits of SSM approach
show_ssm_benefits() {
    echo ""
    echo "🚀 SSM Benefits vs SSH"
    echo "======================"
    echo ""
    echo "✅ **No SSH Key Management**"
    echo "   - No need for SSH_PRIVATE_KEY secret"
    echo "   - No SSH key rotation required"
    echo "   - No network connectivity issues"
    echo ""
    echo "✅ **Better Security**"
    echo "   - Uses IAM roles instead of SSH keys"
    echo "   - No open SSH ports required"
    echo "   - AWS-managed secure channel"
    echo ""
    echo "✅ **More Reliable**"
    echo "   - Works even if SSH is blocked"
    echo "   - Built-in retry mechanisms"
    echo "   - Better error handling"
    echo ""
    echo "✅ **Easier Setup**"
    echo "   - SSM agent pre-installed on instances"
    echo "   - No additional configuration needed"
    echo "   - Works with existing IAM roles"
    echo ""
    echo "💰 **Cost**: $0 additional (SSM is free for basic usage)"
    echo "🔧 **Setup**: Already configured in your infrastructure"
}

# Usage instructions
show_usage() {
    echo ""
    echo "📋 Usage Instructions"
    echo "===================="
    echo ""
    echo "1. **No Additional Setup Required**"
    echo "   - SSM agent already installed via user data"
    echo "   - IAM role already has SSM permissions"
    echo "   - No SSH keys needed"
    echo ""
    echo "2. **Deploy Infrastructure**"
    echo "   Actions → Core Infrastructure → deploy → lower"
    echo ""
    echo "3. **Monitor Progress**"
    echo "   Look for: 'Waiting for K3s installation to complete via SSM...'"
    echo ""
    echo "4. **Test Manually**"
    echo "   ./test-ssm-completion.sh <INSTANCE_ID>"
}

# Main execution
main() {
    local instance_id="${1:-}"
    
    test_ssm_completion "$instance_id"
    show_ssm_benefits
    show_usage
    
    echo ""
    echo "🎯 Next Steps:"
    echo "1. Deploy infrastructure using GitHub Actions"
    echo "2. Observe SSM-based completion check in logs"
    echo "3. No SSH key management required!"
}

# Run main function
main "$@"
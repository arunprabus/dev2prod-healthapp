#!/bin/bash
# Alternative without SSM - using user data and S3

# Option 1: User Data Script (runs at boot)
cat > user-data-runner-fix.sh << 'EOF'
#!/bin/bash
cd /home/ubuntu/actions-runner
if [ ! -f "svc.sh" ]; then
  # Create svc.sh and install service
  # ... (same svc.sh content)
  ./svc.sh install ubuntu
  ./svc.sh start
fi
EOF

# Option 2: S3 + CloudWatch Events
# Upload script to S3, trigger via CloudWatch when instance starts

# Option 3: Lambda + EC2 API
# Lambda function triggered by EC2 state change events
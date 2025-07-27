#!/bin/bash

echo "🔧 Fixing kubeconfigs with correct IPs..."

DEV_IP="13.127.9.5"
TEST_IP="15.207.14.184"

# Generate dev kubeconfig
echo "Generating dev kubeconfig..."
ssh -o StrictHostKeyChecking=no ubuntu@$DEV_IP "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/kubeconfig-dev
sed "s/127.0.0.1/$DEV_IP/g" /tmp/kubeconfig-dev > /tmp/kubeconfig-dev-fixed

# Generate test kubeconfig  
echo "Generating test kubeconfig..."
ssh -o StrictHostKeyChecking=no ubuntu@$TEST_IP "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/kubeconfig-test
sed "s/127.0.0.1/$TEST_IP/g" /tmp/kubeconfig-test > /tmp/kubeconfig-test-fixed

echo "✅ Kubeconfigs generated!"
echo ""
echo "Add these to GitHub Secrets:"
echo "KUBECONFIG_DEV:"
base64 -w 0 /tmp/kubeconfig-dev-fixed
echo ""
echo ""
echo "KUBECONFIG_TEST:"
base64 -w 0 /tmp/kubeconfig-test-fixed

rm -f /tmp/kubeconfig-*
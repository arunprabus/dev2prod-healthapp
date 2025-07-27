#!/bin/bash

echo "🔧 Auto-fixing kubeconfigs and updating GitHub secrets..."

DEV_IP="13.127.9.5"
TEST_IP="15.207.14.184"

# Install GitHub CLI if not present
if ! command -v gh &> /dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update && sudo apt install gh -y
fi

# Generate and upload dev kubeconfig
echo "📝 Generating dev kubeconfig..."
ssh -o StrictHostKeyChecking=no ubuntu@$DEV_IP "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/kubeconfig-dev
sed "s/127.0.0.1/$DEV_IP/g" /tmp/kubeconfig-dev > /tmp/kubeconfig-dev-fixed
base64 -w 0 /tmp/kubeconfig-dev-fixed | gh secret set KUBECONFIG_DEV --repo $GITHUB_REPOSITORY
echo "✅ KUBECONFIG_DEV updated"

# Generate and upload test kubeconfig
echo "📝 Generating test kubeconfig..."
ssh -o StrictHostKeyChecking=no ubuntu@$TEST_IP "sudo cat /etc/rancher/k3s/k3s.yaml" > /tmp/kubeconfig-test
sed "s/127.0.0.1/$TEST_IP/g" /tmp/kubeconfig-test > /tmp/kubeconfig-test-fixed
base64 -w 0 /tmp/kubeconfig-test-fixed | gh secret set KUBECONFIG_TEST --repo $GITHUB_REPOSITORY
echo "✅ KUBECONFIG_TEST updated"

# Test connections
echo "🧪 Testing connections..."
export KUBECONFIG=/tmp/kubeconfig-dev-fixed
kubectl get nodes && echo "✅ Dev cluster accessible"

export KUBECONFIG=/tmp/kubeconfig-test-fixed
kubectl get nodes && echo "✅ Test cluster accessible"

rm -f /tmp/kubeconfig-*
echo "🎉 Kubeconfigs fixed and secrets updated!"
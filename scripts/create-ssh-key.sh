#!/bin/bash

# Create SSH key for cluster access
# Usage: ./create-ssh-key.sh

SSH_KEY_PATH=~/.ssh/aws-key

echo "🔑 Creating SSH key for cluster access..."

# Create SSH directory
mkdir -p ~/.ssh

# Generate SSH key if it doesn't exist
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -q
    echo "✅ SSH key created at: $SSH_KEY_PATH"
else
    echo "✅ SSH key already exists at: $SSH_KEY_PATH"
fi

# Set permissions
chmod 600 "$SSH_KEY_PATH"
chmod 644 "$SSH_KEY_PATH.pub"

echo "📋 Public key content:"
cat "$SSH_KEY_PATH.pub"
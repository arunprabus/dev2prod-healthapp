#!/usr/bin/env python3
import json
import os
import sys

# This script generates a dynamic inventory for Ansible based on Terraform outputs
# It reads the cluster IP from environment variables or from Terraform output

def get_inventory():
    # Get environment variables
    cluster_ip = os.environ.get('CLUSTER_IP')
    environment = os.environ.get('ENVIRONMENT', 'dev')
    
    # If no cluster IP is provided, try to get it from Terraform output
    if not cluster_ip:
        try:
            import subprocess
            result = subprocess.run(
                ['terraform', 'output', '-raw', 'k3s_public_ip'],
                cwd='../../infra/two-network-setup',
                capture_output=True,
                text=True
            )
            cluster_ip = result.stdout.strip()
        except Exception:
            # Fallback to a default or exit
            sys.stderr.write("Error: Could not determine cluster IP\n")
            sys.exit(1)
    
    # Create inventory structure
    inventory = {
        '_meta': {
            'hostvars': {
                'k3s_master': {
                    'ansible_host': cluster_ip,
                    'ansible_user': 'ubuntu',
                    'ansible_ssh_private_key_file': '/tmp/ssh_key',
                    'ansible_ssh_common_args': '-o StrictHostKeyChecking=no',
                    'environment': environment
                }
            }
        },
        'k3s_clusters': {
            'hosts': ['k3s_master'],
            'vars': {
                'environment': environment
            }
        }
    }
    
    return inventory

if __name__ == '__main__':
    inventory = get_inventory()
    print(json.dumps(inventory, indent=2))
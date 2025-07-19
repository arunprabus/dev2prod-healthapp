# Ansible Configuration for Health App Infrastructure

This directory contains Ansible playbooks and roles for managing the Health App infrastructure.

## Directory Structure

```
ansible/
├── inventory/                # Inventory files
│   ├── dynamic_inventory.yml # Dynamic inventory configuration
│   └── static_inventory.ini  # Static inventory file
├── playbooks/                # Playbooks
│   ├── cluster-setup.yml     # K3s cluster setup playbook
│   ├── github-runner-setup.yml # GitHub runner setup playbook
│   └── kubeconfig-setup.yml  # Kubeconfig management playbook
├── roles/                    # Roles
│   ├── k3s/                  # K3s role
│   │   ├── defaults/         # Default variables
│   │   └── tasks/            # Tasks
│   └── monitoring/           # Monitoring role
│       ├── defaults/         # Default variables
│       ├── tasks/            # Tasks
│       └── templates/        # Templates
└── scripts/                  # Helper scripts
    └── get_k3s_hosts.py      # Dynamic inventory script
```

## Playbooks

### cluster-setup.yml

This playbook configures a K3s cluster and sets up the necessary components for the Health App.

```bash
# Run the playbook
ansible-playbook playbooks/cluster-setup.yml -e "github_token=YOUR_TOKEN repo_name=YOUR_REPO"
```

### github-runner-setup.yml

This playbook sets up a GitHub runner on a host.

```bash
# Run the playbook
ansible-playbook playbooks/github-runner-setup.yml -e "github_token=YOUR_TOKEN repo_name=YOUR_REPO network_tier=lower"
```

### kubeconfig-setup.yml

This playbook manages kubeconfig files for K3s clusters.

```bash
# Run the playbook
ansible-playbook playbooks/kubeconfig-setup.yml -e "github_token=YOUR_TOKEN repo_name=YOUR_REPO"
```

## Roles

### k3s

This role configures a K3s cluster and sets up the necessary components.

### monitoring

This role sets up monitoring tools like Prometheus and Grafana.

## Usage from GitHub Actions

The Ansible playbooks are integrated with GitHub Actions workflows. The `core-infrastructure.yml` workflow uses Ansible to configure K3s clusters and manage kubeconfig files.

## Requirements

- Ansible 2.9+
- Python 3.6+
- Kubernetes Python client (`pip install kubernetes`)
- Ansible Kubernetes collection (`ansible-galaxy collection install kubernetes.core`)
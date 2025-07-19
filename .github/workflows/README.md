# GitHub Workflows

This directory contains the GitHub Actions workflows for the Health App infrastructure.

## Core Workflows

These are the essential workflows that should be kept:

1. **core-infrastructure.yml** - Manages infrastructure deployment and destruction
2. **core-deployment.yml** - Handles application deployment
3. **core-operations.yml** - Performs monitoring, scaling, and maintenance operations
4. **script-executor.yml** - Consolidated workflow for running various scripts
5. **maintenance-operations.yml** - Combined workflow for runner cleanup, secret updates, and platform readiness checks
6. **reference-workflows.yml** - Contains important logic from deleted workflows for reference purposes (not for direct execution)

## Workflow Usage

### Infrastructure Management

```
Actions → Core Infrastructure
- action: deploy | destroy | plan | redeploy
- environment: lower | higher | monitoring | all
```

### Application Deployment

```
Actions → Core Deployment
- app: health-api
- image: your-image:tag
- environment: dev | test | prod
```

### Operations

```
Actions → Core Operations
- action: monitor | scale | backup | cleanup | health-check | all
- environment: dev | test | prod | all
```

### Script Execution

```
Actions → Script Executor
- script_name: [select from dropdown]
- environment: dev | test | prod | monitoring | lower | higher | all
- action: [select from dropdown]
- additional_params: [optional parameters]
```

### Maintenance Operations

```
Actions → Maintenance Operations
- operation: cleanup-github-runners | update-secrets | platform-readiness-check
- environment: dev | test | prod | monitoring | all
- check_type: full | kubernetes-only | database-only | runner-only (for platform-readiness-check)
- secret_type: kubeconfig | ssh-key | aws-credentials | github-token | database (for update-secrets)
- secret_value: [optional new secret value] (for update-secrets)
```

## Consolidated Workflows

The `script-executor.yml` workflow now includes functionality from these workflows:

- kubeconfig-access.yml
- quick-kubeconfig-fix.yml
- maintenance.yml
- auto-kubeconfig-setup.yml
- apply-scaling.yml

The `maintenance-operations.yml` workflow includes functionality from these workflows:

- cleanup-github-runners.yml
- update-secrets.yml
- platform-readiness-check.yml

The `reference-workflows.yml` file preserves important logic from these workflows for reference:

- argo-rollout-deploy.yml - Advanced deployment strategies with Argo Rollouts
- app-deploy.yml - Dynamic application deployment with environment-specific configurations
- apply-scaling.yml - Advanced auto-scaling configurations with custom metrics
- kubeconfig-access.yml - Secure kubeconfig management and user-specific access
- quick-kubeconfig-fix.yml - Robust kubeconfig troubleshooting and regeneration

These workflows can be safely deleted as their functionality has been consolidated into the script-executor, maintenance-operations, and reference-workflows files.
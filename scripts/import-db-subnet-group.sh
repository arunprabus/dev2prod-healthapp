#!/bin/bash
# Import existing DB subnet group
cd infra
terraform import -var-file="environments/lower.tfvars" -var="ssh_public_key=dummy" -var="github_pat=dummy" 'module.rds[0].aws_db_subnet_group.health_db' health-app-shared-db-subnet-group
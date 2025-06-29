# Clean Terraform Environment Management

.PHONY: help init-dev init-qa init-prod plan-dev plan-qa plan-prod apply-dev apply-qa apply-prod destroy-dev destroy-qa destroy-prod

ENV ?= dev

help: ## Show this help message
	@echo "Clean Terraform Environment Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development Environment
init-dev: ## Initialize dev environment
	@cd envs/dev && terraform init -backend-config=../../backend-configs/dev.tfbackend

plan-dev: ## Plan dev environment
	@cd envs/dev && terraform plan

apply-dev: ## Apply dev environment
	@cd envs/dev && terraform apply

destroy-dev: ## Destroy dev environment
	@cd envs/dev && terraform destroy

# QA Environment
init-qa: ## Initialize qa environment
	@cd envs/qa && terraform init -backend-config=../../backend-configs/qa.tfbackend

plan-qa: ## Plan qa environment
	@cd envs/qa && terraform plan

apply-qa: ## Apply qa environment
	@cd envs/qa && terraform apply

destroy-qa: ## Destroy qa environment
	@cd envs/qa && terraform destroy

# Production Environment
init-prod: ## Initialize prod environment
	@cd envs/prod && terraform init -backend-config=../../backend-configs/prod.tfbackend

plan-prod: ## Plan prod environment
	@cd envs/prod && terraform plan

apply-prod: ## Apply prod environment
	@cd envs/prod && terraform apply

destroy-prod: ## Destroy prod environment
	@cd envs/prod && terraform destroy

# Generic commands
init: ## Initialize environment (ENV=dev|qa|prod)
	@cd envs/$(ENV) && terraform init -backend-config=../../backend-configs/$(ENV).tfbackend

plan: ## Plan environment (ENV=dev|qa|prod)
	@cd envs/$(ENV) && terraform plan

apply: ## Apply environment (ENV=dev|qa|prod)
	@cd envs/$(ENV) && terraform apply

destroy: ## Destroy environment (ENV=dev|qa|prod)
	@cd envs/$(ENV) && terraform destroy
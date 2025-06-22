# Health App Infrastructure Management

.PHONY: help infra-up-all infra-down-all infra-up infra-down infra-plan infra-destroy

# Default environment
ENV ?= dev
TF_DIR = infra

help: ## Show this help message
	@echo "Health App Infrastructure Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$\' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Infrastructure Commands
infra-up-all: ## Deploy all environments (dev, test, prod)
	@echo "🚀 Deploying all environments..."
	@$(MAKE) infra-up ENV=dev
	@$(MAKE) infra-up ENV=test
	@$(MAKE) infra-up ENV=prod
	@echo "✅ All environments deployed!"

infra-down-all: ## Destroy all environments
	@echo "🛑 Destroying all environments..."
	@$(MAKE) infra-down ENV=dev
	@$(MAKE) infra-down ENV=test
	@$(MAKE) infra-down ENV=prod
	@echo "✅ All environments destroyed!"

infra-up: ## Deploy specific environment (ENV=dev|test|prod)
	@echo "🚀 Deploying $(ENV) environment..."
	@cd $(TF_DIR) && terraform init -backend-config="key=health-app-$(ENV).tfstate"
	@cd $(TF_DIR) && terraform plan -var-file="environments/$(ENV).tfvars"
	@cd $(TF_DIR) && terraform apply -var-file="environments/$(ENV).tfvars" -auto-approve
	@echo "✅ $(ENV) environment deployed!"

infra-down: ## Destroy specific environment (ENV=dev|test|prod)
	@echo "🛑 Destroying $(ENV) environment..."
	@cd $(TF_DIR) && terraform init -backend-config="key=health-app-$(ENV).tfstate"
	@cd $(TF_DIR) && terraform destroy -var-file="environments/$(ENV).tfvars" -auto-approve
	@echo "✅ $(ENV) environment destroyed!"

infra-plan: ## Plan infrastructure changes (ENV=dev|test|prod)
	@echo "📋 Planning $(ENV) environment..."
	@cd $(TF_DIR) && terraform init -backend-config="key=health-app-$(ENV).tfstate"
	@cd $(TF_DIR) && terraform plan -var-file="environments/$(ENV).tfvars"

# Utility Commands
infra-status: ## Show Terraform state for environment (ENV=dev|test|prod)
	@echo "📊 Checking $(ENV) environment status..."
	@cd $(TF_DIR) && terraform init -backend-config="key=health-app-$(ENV).tfstate"
	@cd $(TF_DIR) && terraform show

infra-output: ## Show Terraform outputs for environment (ENV=dev|test|prod)
	@echo "📋 Showing $(ENV) environment outputs..."
	@cd $(TF_DIR) && terraform init -backend-config="key=health-app-$(ENV).tfstate"
	@cd $(TF_DIR) && terraform output

infra-clean: ## Clean Terraform cache
	@echo "🧹 Cleaning Terraform cache..."
	@cd $(TF_DIR) && rm -rf .terraform .terraform.lock.hcl
	@echo "✅ Terraform cache cleaned!"

# Kubernetes Commands
k8s-config: ## Update kubeconfig for environment (ENV=dev|test|prod)
	@echo "⚙️ Updating kubeconfig for $(ENV)..."
	@aws eks update-kubeconfig --region ap-south-1 --name health-app-$(ENV)-cluster

k8s-status: ## Show Kubernetes cluster status
	@echo "📊 Kubernetes cluster status:"
	@kubectl get nodes
	@kubectl get pods --all-namespaces

# Cost Management
shutdown-all: ## 🚨 DESTROY ALL ENVIRONMENTS (Cost Saving)
	@echo "⚠️  WARNING: This will destroy ALL environments!"
	@echo "💰 This action saves costs by destroying all AWS resources"
	@read -p "Type 'DESTROY' to confirm: " confirm && [ "$$confirm" = "DESTROY" ] || exit 1
	@$(MAKE) infra-down ENV=dev
	@$(MAKE) infra-down ENV=test
	@$(MAKE) infra-down ENV=prod
	@echo "💸 All environments destroyed - costs saved!"

status-all: ## Show status of all environments
	@echo "📊 Infrastructure Status:"
	@echo "Dev Environment:"
	@$(MAKE) infra-status ENV=dev || echo "❌ Dev not deployed"
	@echo "Test Environment:"
	@$(MAKE) infra-status ENV=test || echo "❌ Test not deployed"
	@echo "Prod Environment:"
	@$(MAKE) infra-status ENV=prod || echo "❌ Prod not deployed"
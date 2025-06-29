# Health App Management

.PHONY: help dev dev-debug prod individual-api individual-frontend

# Default environment
ENV ?= dev
TF_DIR = infra

help: ## Show this help message
	@echo "Health App Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$\' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Local Development
dev: ## Start app in production-like mode (API not exposed)
	@echo "🚀 Starting production-like mode..."
	@docker-compose up
	@echo "✅ Access frontend: http://localhost:3000"

dev-debug: ## Start app in development mode (API exposed for debugging)
	@echo "🔧 Starting development mode with API access..."
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
	@echo "✅ Frontend: http://localhost:3000"
	@echo "✅ API: http://localhost:8080"

individual-api: ## Run backend individually
	@echo "🔧 Starting backend individually..."
	@cd health-api && npm run dev

individual-frontend: ## Run frontend individually  
	@echo "🔧 Starting frontend individually..."
	@cd frontend && npm start

stop: ## Stop all services
	@echo "🛑 Stopping all services..."
	@docker-compose down
	@echo "✅ All services stopped!"

# Infrastructure Commands (for AWS deployment)
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
cost-check: ## Check current AWS costs
	@echo "💰 Checking current costs..."
	@bash scripts/cost-breakdown.sh

cost-cleanup: ## Run automated cost cleanup
	@echo "🧹 Running cost cleanup..."
	@bash scripts/cost-cleanup-auto.sh

rds-monitor: ## Monitor RDS runtime and auto-stop at 120h
	@echo "📊 Monitoring RDS runtime..."
	@bash scripts/rds-monitor.sh

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
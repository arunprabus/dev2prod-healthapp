# Two-Network Setup Makefile

.PHONY: help deploy-all deploy-lower deploy-higher destroy-all status deploy-apps

ENV ?= dev

help: ## Show this help message
	@echo "Two-Network Setup Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Network Deployment
deploy-all: ## Deploy all environments (dev, test in lower network, prod in higher network)
	@echo "🚀 Deploying all environments..."
	@$(MAKE) deploy-lower ENV=dev
	@$(MAKE) deploy-lower ENV=test
	@$(MAKE) deploy-higher ENV=prod
	@echo "✅ All environments deployed!"
	@echo "💰 Total cost: ₹0 (within free tier)"

deploy-lower: ## Deploy environment in lower network (ENV=dev|test)
	@echo "🌐 Deploying $(ENV) in lower network (10.0.0.0/16)..."
	@terraform init
	@terraform workspace select $(ENV) || terraform workspace new $(ENV)
	@terraform plan -var-file="environments/$(ENV).tfvars"
	@terraform apply -var-file="environments/$(ENV).tfvars" -auto-approve
	@echo "✅ $(ENV) environment deployed in lower network!"

deploy-higher: ## Deploy environment in higher network (ENV=prod)
	@echo "🔒 Deploying $(ENV) in higher network (10.1.0.0/16)..."
	@terraform init
	@terraform workspace select $(ENV) || terraform workspace new $(ENV)
	@terraform plan -var-file="environments/$(ENV).tfvars"
	@terraform apply -var-file="environments/$(ENV).tfvars" -auto-approve
	@echo "✅ $(ENV) environment deployed in higher network!"

# Application Deployment
deploy-apps: ## Deploy frontend and backend apps to environment (ENV=dev|test|prod)
	@echo "📱 Deploying applications to $(ENV) environment..."
	@terraform workspace select $(ENV)
	@PUBLIC_IP=$$(terraform output -raw k3s_public_ip); \
	RDS_ENDPOINT=$$(terraform output -raw rds_endpoint); \
	sed "s/RDS_ENDPOINT_PLACEHOLDER/$$RDS_ENDPOINT/g; s/ENV_PASSWORD_PLACEHOLDER/$(ENV)123!/g" app-deployments.yaml > /tmp/$(ENV)-apps.yaml; \
	scp -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no /tmp/$(ENV)-apps.yaml ubuntu@$$PUBLIC_IP:/tmp/apps.yaml; \
	ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$$PUBLIC_IP "sudo kubectl apply -f /tmp/apps.yaml"; \
	echo "✅ Applications deployed!"; \
	echo "🌐 Frontend: http://$$PUBLIC_IP:30080"; \
	echo "🔗 Backend: http://$$PUBLIC_IP:30081"

# Resource Management
destroy-all: ## Destroy all environments
	@echo "🛑 Destroying all environments..."
	@for env in dev test prod; do \
		terraform workspace select $$env 2>/dev/null && terraform destroy -var-file="environments/$$env.tfvars" -auto-approve || true; \
	done
	@echo "✅ All environments destroyed!"

status: ## Show status of all environments
	@echo "📊 Environment Status:"
	@echo ""
	@for env in dev test prod; do \
		echo "=== $$env Environment ==="; \
		terraform workspace select $$env 2>/dev/null && terraform output 2>/dev/null || echo "Not deployed"; \
		echo ""; \
	done

# SSH Access
ssh: ## SSH into environment K3s cluster (ENV=dev|test|prod)
	@terraform workspace select $(ENV)
	@PUBLIC_IP=$$(terraform output -raw k3s_public_ip 2>/dev/null); \
	if [ -n "$$PUBLIC_IP" ]; then \
		echo "🔗 Connecting to $(ENV) K3s cluster..."; \
		ssh -i ~/.ssh/id_rsa ubuntu@$$PUBLIC_IP; \
	else \
		echo "❌ $(ENV) environment not found. Deploy first."; \
	fi

# Monitoring
check-apps: ## Check application status in environment (ENV=dev|test|prod)
	@terraform workspace select $(ENV)
	@PUBLIC_IP=$$(terraform output -raw k3s_public_ip 2>/dev/null); \
	if [ -n "$$PUBLIC_IP" ]; then \
		echo "🔍 Checking applications in $(ENV)..."; \
		ssh -i ~/.ssh/id_rsa ubuntu@$$PUBLIC_IP "sudo kubectl get pods,services"; \
	else \
		echo "❌ $(ENV) environment not found."; \
	fi

# Cost Management
stop-all: ## Stop all EC2 instances to save costs
	@echo "⏹️ Stopping all instances..."
	@aws ec2 describe-instances --filters "Name=tag:Project,Values=Learning" --query 'Reservations[].Instances[?State.Name==`running`].InstanceId' --output text | xargs -r aws ec2 stop-instances --instance-ids
	@echo "✅ All instances stopped!"

start-all: ## Start all stopped EC2 instances
	@echo "▶️ Starting all instances..."
	@aws ec2 describe-instances --filters "Name=tag:Project,Values=Learning" --query 'Reservations[].Instances[?State.Name==`stopped`].InstanceId' --output text | xargs -r aws ec2 start-instances --instance-ids
	@echo "✅ All instances started!"

# Network Testing
test-connectivity: ## Test connectivity between networks
	@echo "🔗 Testing network connectivity..."
	@echo "Lower Network (Dev/Test): 10.0.0.0/16"
	@echo "Higher Network (Prod): 10.1.0.0/16"
	@for env in dev test prod; do \
		terraform workspace select $$env 2>/dev/null && \
		echo "$$env: $$(terraform output -raw vpc_cidr 2>/dev/null)" || true; \
	done
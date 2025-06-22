# Learning Setup Makefile

.PHONY: help deploy destroy start stop status cost-check

help: ## Show this help message
	@echo "Learning Setup Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Setup Commands
deploy: ## Deploy learning infrastructure (FREE TIER)
	@echo "🚀 Deploying cost-optimized learning setup..."
	@terraform init
	@terraform plan
	@terraform apply -auto-approve
	@echo "✅ Learning setup deployed!"
	@echo "💰 Estimated cost: ₹0 (within free tier)"

destroy: ## Destroy all resources (SAVE COSTS)
	@echo "🛑 Destroying learning setup..."
	@terraform destroy -auto-approve
	@echo "✅ All resources destroyed!"
	@echo "💸 Cost savings: ₹0 (was already free)"

# Resource Management
start: ## Start stopped EC2 and RDS instances
	@echo "▶️ Starting learning resources..."
	@INSTANCE_ID=$$(terraform output -raw k3s_instance_id 2>/dev/null || echo ""); \
	if [ -n "$$INSTANCE_ID" ]; then \
		aws ec2 start-instances --instance-ids $$INSTANCE_ID; \
		echo "Started EC2 instance: $$INSTANCE_ID"; \
	fi
	@aws rds start-db-instance --db-instance-identifier learning-db 2>/dev/null || echo "RDS already running or not found"
	@echo "✅ Resources started!"

stop: ## Stop EC2 and RDS instances (SAVE COSTS)
	@echo "⏹️ Stopping learning resources..."
	@INSTANCE_ID=$$(terraform output -raw k3s_instance_id 2>/dev/null || echo ""); \
	if [ -n "$$INSTANCE_ID" ]; then \
		aws ec2 stop-instances --instance-ids $$INSTANCE_ID; \
		echo "Stopped EC2 instance: $$INSTANCE_ID"; \
	fi
	@aws rds stop-db-instance --db-instance-identifier learning-db 2>/dev/null || echo "RDS already stopped or not found"
	@echo "✅ Resources stopped - costs minimized!"

status: ## Show status of learning resources
	@echo "📊 Learning Setup Status:"
	@echo ""
	@echo "EC2 Instances:"
	@aws ec2 describe-instances \
		--filters "Name=tag:Project,Values=Learning" \
		--query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType,IP:PublicIpAddress}' \
		--output table 2>/dev/null || echo "No EC2 instances found"
	@echo ""
	@echo "RDS Instances:"
	@aws rds describe-db-instances \
		--db-instance-identifier learning-db \
		--query 'DBInstances[].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Class:DBInstanceClass,Endpoint:Endpoint.Address}' \
		--output table 2>/dev/null || echo "No RDS instances found"

# Cost Management
cost-check: ## Check current AWS costs and free tier usage
	@echo "💰 Cost Analysis:"
	@echo ""
	@echo "Free Tier Usage (approximate):"
	@echo "- EC2 t2.micro: Check AWS Console > Billing > Free Tier"
	@echo "- RDS db.t3.micro: Check AWS Console > Billing > Free Tier"
	@echo ""
	@echo "Current Month Costs:"
	@aws ce get-cost-and-usage \
		--time-period Start=2024-01-01,End=2024-01-31 \
		--granularity MONTHLY \
		--metrics BlendedCost \
		--query 'ResultsByTime[0].Total.BlendedCost.Amount' 2>/dev/null || echo "Unable to fetch cost data"

# SSH and Access
ssh: ## SSH into K3s instance
	@PUBLIC_IP=$$(terraform output -raw k3s_public_ip 2>/dev/null); \
	if [ -n "$$PUBLIC_IP" ]; then \
		echo "🔗 Connecting to K3s instance..."; \
		ssh -i ~/.ssh/id_rsa ubuntu@$$PUBLIC_IP; \
	else \
		echo "❌ No public IP found. Run 'make deploy' first."; \
	fi

k3s-status: ## Check K3s cluster status
	@PUBLIC_IP=$$(terraform output -raw k3s_public_ip 2>/dev/null); \
	if [ -n "$$PUBLIC_IP" ]; then \
		echo "🔍 Checking K3s status..."; \
		ssh -i ~/.ssh/id_rsa ubuntu@$$PUBLIC_IP "sudo kubectl get nodes && sudo kubectl get pods --all-namespaces"; \
	else \
		echo "❌ No public IP found. Run 'make deploy' first."; \
	fi

# Learning Exercises
deploy-sample: ## Deploy sample application to K3s
	@PUBLIC_IP=$$(terraform output -raw k3s_public_ip 2>/dev/null); \
	if [ -n "$$PUBLIC_IP" ]; then \
		echo "🚀 Deploying sample nginx application..."; \
		ssh -i ~/.ssh/id_rsa ubuntu@$$PUBLIC_IP "sudo kubectl create deployment nginx --image=nginx && sudo kubectl expose deployment nginx --port=80 --type=NodePort"; \
		echo "✅ Sample app deployed! Check with: make k3s-status"; \
	else \
		echo "❌ No public IP found. Run 'make deploy' first."; \
	fi

# Cleanup
clean: ## Clean Terraform cache
	@echo "🧹 Cleaning Terraform cache..."
	@rm -rf .terraform .terraform.lock.hcl terraform.tfstate* auto_stop.zip
	@echo "✅ Cache cleaned!"
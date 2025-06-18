# Health App Orchestration Makefile

.PHONY: help up-dev up-test up-prod down-dev down-test down-prod logs clean

# Default environment
ENV ?= dev

help: ## Show this help message
	@echo "Health App Orchestration Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$\' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Development Environment
up-dev: ## Start development environment
	@echo "🚀 Starting development environment..."
	@cp .env.dev .env
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
	@echo "✅ Development environment started!"
	@echo "🌐 Frontend: http://localhost:8080"
	@echo "🔗 API: http://localhost:3001"

down-dev: ## Stop development environment
	@echo "🛑 Stopping development environment..."
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml down
	@echo "✅ Development environment stopped!"

logs-dev: ## View development logs
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f

# Test Environment
up-test: ## Start test environment
	@echo "🧪 Starting test environment..."
	@cp .env.test .env
	@docker-compose -f docker-compose.yml -f docker-compose.test.yml up -d
	@echo "✅ Test environment started!"
	@echo "🌐 Frontend: http://localhost:8081"
	@echo "🔗 API: http://localhost:3002"

down-test: ## Stop test environment
	@echo "🛑 Stopping test environment..."
	@docker-compose -f docker-compose.yml -f docker-compose.test.yml down
	@echo "✅ Test environment stopped!"

test: ## Run integration tests
	@echo "🧪 Running integration tests..."
	@cp .env.test .env
	@docker-compose -f docker-compose.yml -f docker-compose.test.yml up -d test-runner
	@docker-compose -f docker-compose.yml -f docker-compose.test.yml logs test-runner

# Production Environment
up-prod: ## Start production environment
	@echo "🚀 Starting production environment..."
	@cp .env.prod .env
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
	@echo "✅ Production environment started!"

down-prod: ## Stop production environment
	@echo "🛑 Stopping production environment..."
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml down
	@echo "✅ Production environment stopped!"

# Utility Commands
logs: ## View logs for current environment
	@docker-compose logs -f

status: ## Show status of all services
	@docker-compose ps

clean: ## Clean up all containers, networks, and volumes
	@echo "🧹 Cleaning up all environments..."
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml down -v --remove-orphans
	@docker-compose -f docker-compose.yml -f docker-compose.test.yml down -v --remove-orphans
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml down -v --remove-orphans
	@docker system prune -f
	@echo "✅ Cleanup complete!"

# Database Commands
db-migrate: ## Run database migrations
	@echo "📊 Running database migrations for $(ENV) environment..."
	@docker-compose exec api npm run migrate:$(ENV)

db-seed: ## Seed database with sample data
	@echo "🌱 Seeding database for $(ENV) environment..."
	@docker-compose exec api npm run seed:$(ENV)

# Development Helpers
shell-api: ## Open shell in API container
	@docker-compose exec api sh

shell-frontend: ## Open shell in frontend container
	@docker-compose exec frontend sh

shell-db: ## Open MySQL shell
	@docker-compose exec database mysql -u health_user -p health_app_$(ENV)

# Pull latest images
pull: ## Pull latest container images
	@echo "📥 Pulling latest images..."
	@docker-compose pull
	@echo "✅ Images updated!"

# Build local images (for development)
build: ## Build images locally
	@echo "🔨 Building images locally..."
	@docker-compose build
	@echo "✅ Images built!"
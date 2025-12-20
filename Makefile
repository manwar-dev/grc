# GRC Microservices - Makefile
# Convenient shortcuts for Docker commands

.PHONY: help build up down restart status logs clean

# Default target
.DEFAULT_GOAL := help

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

# Docker Compose command
DOCKER_COMPOSE := docker compose

help: ## Show this help message
	@echo "$(BLUE)GRC Microservices - Docker Commands$(NC)"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

build: ## Build all Docker images
	@echo "$(BLUE)Building all images...$(NC)"
	@bash docker-build.sh

build-service: ## Build specific service (usage: make build-service SERVICE=back)
	@echo "$(BLUE)Building $(SERVICE)...$(NC)"
	@bash docker-build.sh --service $(SERVICE)

build-no-cache: ## Build all images without cache
	@echo "$(BLUE)Building without cache...$(NC)"
	@bash docker-build.sh --no-cache

up: ## Start all services
	@echo "$(GREEN)Starting all services...$(NC)"
	@bash docker-up.sh

up-prod: ## Start with production profile (includes gateway)
	@echo "$(GREEN)Starting production services...$(NC)"
	@bash docker-up.sh --production

up-build: ## Build and start services
	@echo "$(GREEN)Building and starting services...$(NC)"
	@bash docker-up.sh --build

down: ## Stop all services
	@echo "$(YELLOW)Stopping all services...$(NC)"
	@bash docker-down.sh

down-volumes: ## Stop and remove volumes (WARNING: deletes data!)
	@echo "$(YELLOW)Stopping and removing volumes...$(NC)"
	@bash docker-down.sh --volumes

restart: ## Restart all services
	@echo "$(YELLOW)Restarting all services...$(NC)"
	@$(DOCKER_COMPOSE) restart

restart-service: ## Restart specific service (usage: make restart-service SERVICE=back)
	@echo "$(YELLOW)Restarting $(SERVICE)...$(NC)"
	@$(DOCKER_COMPOSE) restart $(SERVICE)

status: ## Show service status
	@bash docker-status.sh

ps: ## Show running containers
	@$(DOCKER_COMPOSE) ps

logs: ## Show logs for all services
	@bash docker-logs.sh

logs-service: ## Show logs for specific service (usage: make logs-service SERVICE=back)
	@bash docker-logs.sh --service $(SERVICE)

logs-follow: ## Follow logs for all services
	@$(DOCKER_COMPOSE) logs -f

exec: ## Execute bash in a service (usage: make exec SERVICE=back)
	@$(DOCKER_COMPOSE) exec $(SERVICE) bash

exec-root: ## Execute bash as root in a service (usage: make exec-root SERVICE=back)
	@$(DOCKER_COMPOSE) exec -u root $(SERVICE) bash

shell-mongodb: ## Open MongoDB shell
	@$(DOCKER_COMPOSE) exec mongodb mongosh -u admin -p admin123 --authenticationDatabase admin

shell-redis: ## Open Redis CLI
	@$(DOCKER_COMPOSE) exec redis redis-cli

artisan: ## Run artisan command (usage: make artisan SERVICE=back CMD="migrate")
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan $(CMD)

composer: ## Run composer command (usage: make composer SERVICE=back CMD="install")
	@$(DOCKER_COMPOSE) exec $(SERVICE) composer $(CMD)

npm: ## Run npm command in frontend (usage: make npm CMD="install")
	@$(DOCKER_COMPOSE) exec frontend npm $(CMD)

clean: ## Clean up Docker resources
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	@docker system prune -f
	@echo "$(GREEN)Cleanup complete$(NC)"

clean-all: ## Clean up all Docker resources (WARNING: removes everything!)
	@echo "$(YELLOW)Removing all Docker resources...$(NC)"
	@docker system prune -a --volumes -f
	@echo "$(GREEN)Complete cleanup done$(NC)"

backup-mongodb: ## Backup MongoDB data
	@echo "$(BLUE)Backing up MongoDB...$(NC)"
	@mkdir -p backups
	@$(DOCKER_COMPOSE) exec mongodb mongodump --out=/tmp/backup
	@docker cp grc-mongodb:/tmp/backup ./backups/mongodb-$$(date +%Y%m%d-%H%M%S)
	@echo "$(GREEN)Backup completed$(NC)"

restore-mongodb: ## Restore MongoDB from backup (usage: make restore-mongodb BACKUP=./backups/mongodb-20250101)
	@echo "$(BLUE)Restoring MongoDB from $(BACKUP)...$(NC)"
	@docker cp $(BACKUP) grc-mongodb:/tmp/restore
	@$(DOCKER_COMPOSE) exec mongodb mongorestore /tmp/restore
	@echo "$(GREEN)Restore completed$(NC)"

test: ## Run tests in a service (usage: make test SERVICE=back)
	@echo "$(BLUE)Running tests in $(SERVICE)...$(NC)"
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan test

migrate: ## Run database migrations (usage: make migrate SERVICE=back)
	@echo "$(BLUE)Running migrations in $(SERVICE)...$(NC)"
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan migrate

seed: ## Seed database (usage: make seed SERVICE=back)
	@echo "$(BLUE)Seeding database in $(SERVICE)...$(NC)"
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan db:seed

fresh: ## Fresh migration with seed (usage: make fresh SERVICE=back)
	@echo "$(BLUE)Fresh migration with seed in $(SERVICE)...$(NC)"
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan migrate:fresh --seed

cache-clear: ## Clear Laravel cache (usage: make cache-clear SERVICE=back)
	@echo "$(BLUE)Clearing cache in $(SERVICE)...$(NC)"
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan cache:clear
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan config:clear
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan route:clear
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan view:clear
	@echo "$(GREEN)Cache cleared$(NC)"

optimize: ## Optimize Laravel (usage: make optimize SERVICE=back)
	@echo "$(BLUE)Optimizing $(SERVICE)...$(NC)"
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan config:cache
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan route:cache
	@$(DOCKER_COMPOSE) exec $(SERVICE) php artisan view:cache
	@echo "$(GREEN)Optimization complete$(NC)"

stats: ## Show Docker stats
	@docker stats --no-stream

volumes: ## List all volumes
	@docker volume ls | grep grc

networks: ## List all networks
	@docker network ls | grep grc

images: ## List all images
	@docker images | grep grc

health: ## Check health of all services
	@echo "$(BLUE)Checking service health...$(NC)"
	@for container in $$(docker ps --format "{{.Names}}" | grep "^grc-"); do \
		health=$$(docker inspect --format='{{.State.Health.Status}}' $$container 2>/dev/null || echo "no healthcheck"); \
		status=$$(docker inspect --format='{{.State.Status}}' $$container); \
		if [ "$$health" = "healthy" ] || ([ "$$health" = "no healthcheck" ] && [ "$$status" = "running" ]); then \
			echo "$(GREEN)✓$(NC) $$container: $$status"; \
		else \
			echo "$(YELLOW)⚠$(NC) $$container: $$status (health: $$health)"; \
		fi \
	done

pull: ## Pull latest base images
	@echo "$(BLUE)Pulling latest base images...$(NC)"
	@docker pull mongo:7.0
	@docker pull redis:7-alpine
	@docker pull php:8.2-fpm
	@docker pull nginx:alpine
	@docker pull node:20-alpine
	@echo "$(GREEN)Pull complete$(NC)"

# Development targets
dev-up: ## Start in development mode (with mounted volumes)
	@echo "$(GREEN)Starting development environment...$(NC)"
	@$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml up -d

dev-down: ## Stop development environment
	@echo "$(YELLOW)Stopping development environment...$(NC)"
	@$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml down

# Production targets
prod-deploy: build up-prod ## Build and deploy to production
	@echo "$(GREEN)Production deployment complete$(NC)"

# Quick commands
start: up ## Alias for 'up'
stop: down ## Alias for 'down'
rebuild: down build up ## Rebuild and restart all services
	@echo "$(GREEN)Rebuild complete$(NC)"

# Info
info: ## Show environment information
	@echo "$(BLUE)GRC Platform Information$(NC)"
	@echo ""
	@echo "Docker version: $$(docker --version)"
	@echo "Docker Compose version: $$(docker compose version)"
	@echo ""
	@echo "Running containers:"
	@$(DOCKER_COMPOSE) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "Service URLs:"
	@echo "  Frontend:       http://localhost"
	@echo "  Backend:        http://localhost:9090"
	@echo "  User Service:   http://localhost:7070"
	@echo "  Notification:   http://localhost:6060"
	@echo "  Regulator:      http://localhost:3030"
	@echo "  Strategic:      http://localhost:8080"
	@echo "  KPIs:           http://localhost:5050"
	@echo "  API Gateway:    http://localhost:8000 (production)"
	@echo ""

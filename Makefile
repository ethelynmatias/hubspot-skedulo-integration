# Makefile for the HubSpot–Skedulo integration.
# Everything runs inside the Docker Compose stack defined in docker-compose.yml.

DC      := docker compose
APP     := $(DC) exec app

.DEFAULT_GOAL := help

# Pass extra words after the target through to artisan/composer/npm targets:
#   make artisan cmd="migrate --seed"
cmd ?=

.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} \
		/^##@ / {printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next} \
		/^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Setup

.PHONY: init
init: env build up install key migrate ## First-time setup: env, build, start, install deps, key, migrate
	@echo "Ready: http://localhost:$$(grep -E '^APP_PORT=' .env | cut -d= -f2)"

.PHONY: env
env: ## Create .env from .env.example and set DOCKER_UID/GID to your user
	@test -f .env || cp .env.example .env
	@sed -i -e "s/^DOCKER_UID=.*/DOCKER_UID=$$(id -u)/" -e "s/^DOCKER_GID=.*/DOCKER_GID=$$(id -g)/" .env
	@echo ".env ready (DOCKER_UID=$$(id -u), DOCKER_GID=$$(id -g))"

.PHONY: install
install: ## Install PHP and JS dependencies
	$(APP) composer install
	npm install

.PHONY: key
key: ## Generate the application key
	$(APP) php artisan key:generate

##@ Containers

.PHONY: build
build: ## Build the app image
	$(DC) build

.PHONY: up
up: ## Start the stack in the background
	$(DC) up -d

.PHONY: down
down: ## Stop the stack
	$(DC) down

.PHONY: restart
restart: down up ## Restart the stack

.PHONY: fresh-start
fresh-start: ## Stop the stack and delete its volumes (drops the database)
	$(DC) down -v

.PHONY: ps
ps: ## Show container status
	$(DC) ps

.PHONY: logs
logs: ## Tail logs for all containers
	$(DC) logs -f

.PHONY: shell
shell: ## Open a shell in the app container
	$(APP) bash

##@ Application

.PHONY: artisan
artisan: ## Run artisan: make artisan cmd="route:list"
	$(APP) php artisan $(cmd)

.PHONY: composer
composer: ## Run composer: make composer cmd="require vendor/pkg"
	$(APP) composer $(cmd)

.PHONY: migrate
migrate: ## Run database migrations
	$(APP) php artisan migrate

.PHONY: migrate-fresh
migrate-fresh: ## Drop all tables, re-run migrations and seeders
	$(APP) php artisan migrate:fresh --seed

.PHONY: seed
seed: ## Run database seeders
	$(APP) php artisan db:seed

.PHONY: tinker
tinker: ## Open a Tinker REPL
	$(APP) php artisan tinker

.PHONY: queue
queue: ## Run the queue worker in the foreground
	$(APP) php artisan queue:work

.PHONY: fresh
fresh: ## Clear cached config, routes, views and events
	$(APP) php artisan optimize:clear

##@ Frontend

.PHONY: dev
dev: ## Run the Vite dev server on the host
	npm run dev

.PHONY: assets
assets: ## Build frontend assets for production
	npm run build

##@ Quality

.PHONY: test
test: ## Run the test suite
	$(APP) php artisan test

.PHONY: lint
lint: ## Format PHP with Pint
	$(APP) ./vendor/bin/pint

.PHONY: lint-check
lint-check: ## Check PHP formatting without changing files
	$(APP) ./vendor/bin/pint --test

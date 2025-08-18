# Dock2Tauri - Docker to Desktop Bridge Makefile

# Configuration
PROJECT_NAME = dock2tauri
VERSION = 1.0.0
DEFAULT_HOST_PORT = 8088
DEFAULT_CONTAINER_PORT = 80

# Install-deps configuration (override via: make install-deps APPIMAGE=1 ARM64=1 YES=1)
APPIMAGE ?= 0
ARM64 ?= 0
YES ?= 0
# Compose flags for scripts/install_deps.sh
INSTALL_DEPS_FLAGS = $(if $(filter 1,$(APPIMAGE)),--with-appimage,) \
                     $(if $(filter 1,$(ARM64)),--arm64,) \
                     $(if $(filter 1,$(YES)),-y,)

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

.PHONY: help install install-deps install-deps-dry-run test-install dev build run clean test nginx grafana jupyter portainer launch stop-all list logs status examples

# Default target
all: help

help: ## Show this help message
	@echo "$(BLUE)🐳🦀 Dock2Tauri - Docker to Desktop Bridge$(NC)"
	@echo "$(YELLOW)Available commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

install: ## Install dependencies and setup project
	@echo "$(BLUE)🔧 Installing Dock2Tauri...$(NC)"
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "$(RED)❌ Docker not found. Please install Docker first.$(NC)"; \
		exit 1; \
	fi
	@if ! command -v cargo >/dev/null 2>&1; then \
		echo "$(YELLOW)⚠️  Rust not found. Installing...$(NC)"; \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; \
		source ~/.cargo/env; \
	fi
	@if ! command -v tauri >/dev/null 2>&1; then \
		echo "$(YELLOW)📦 Installing Tauri CLI...$(NC)"; \
		cargo install tauri-cli; \
	fi
	@echo "$(BLUE)📦 Installing system bundling dependencies...$(NC)"
	@bash scripts/install_deps.sh $(INSTALL_DEPS_FLAGS)
	@chmod +x scripts/*.sh scripts/*.py scripts/*.js
	@echo "$(GREEN)✅ Installation complete!$(NC)"

install-deps: ## Install system bundling deps (APPIMAGE=1 ARM64=1 YES=1 to enable extras)
	@echo "$(BLUE)📦 Installing system bundling dependencies...$(NC)"
	@bash scripts/install_deps.sh $(INSTALL_DEPS_FLAGS)

install-deps-dry-run: ## Dry-run of dependency installation (no changes)
	@echo "$(BLUE)🧪 Dry-run dependency installation...$(NC)"
	@bash scripts/install_deps.sh --dry-run $(INSTALL_DEPS_FLAGS)

test-install: ## Validate install scripts (syntax + dry-run)
	@echo "$(BLUE)🧪 Validating install scripts...$(NC)"
	@bash -n scripts/install_deps.sh
	@bash scripts/install_deps.sh --dry-run
	@echo "$(GREEN)✅ Install scripts validated (syntax + dry-run)$(NC)"

kill-port: ## Kill any process using port 8081
	@echo "$(BLUE)🧹 Cleaning port 8081...$(NC)"
	@lsof -ti:8081 | xargs kill -9 2>/dev/null || echo "$(GREEN)✅ Port 8081 is free$(NC)"

dev: kill-port ## Start development mode with control panel
	@echo "$(BLUE)🚀 Starting Dock2Tauri development mode...$(NC)"
	@cd src-tauri && cargo tauri dev

build: ## Build production version
	@echo "$(BLUE)🏗️  Building Dock2Tauri...$(NC)"
	@cd src-tauri && cargo tauri build

run: ## Run latest built application (detects OS and package type)
	@echo "$(BLUE)🚀 Running latest Dock2Tauri build...$(NC)"
	@./scripts/run-app.sh

# Testing targets
test: test-bash test-rust test-python ## Run all tests (bash, rust, python)
	@echo "$(GREEN)✅ All tests completed$(NC)"

test-e2e: test-playwright test-cypress ## Run all E2E tests (playwright, cypress)
	@echo "$(GREEN)✅ All E2E tests completed$(NC)"

test-all: test test-e2e ## Run all tests including E2E
	@echo "$(GREEN)✅ All tests and E2E tests completed$(NC)"

test-bash: ## Run Bash script tests
	@echo "$(BLUE)🧪 Running Bash script tests...$(NC)"
	@chmod +x tests/bash/test_scripts.sh
	@./tests/bash/test_scripts.sh

test-rust: ## Run Rust integration tests
	@echo "$(BLUE)🧪 Running Rust integration tests...$(NC)"
	@cd tests/integration && cargo test

test-python: ## Run Python workflow tests
	@echo "$(BLUE)🧪 Running Python workflow tests...$(NC)"
	@cd tests/workflow && python3 test_build_install.py

test-playwright: ## Run Playwright E2E tests
	@echo "$(BLUE)🧪 Running Playwright E2E tests...$(NC)"
	@cd tests/e2e && npm test

test-playwright-ui: ## Run Playwright tests with UI
	@echo "$(BLUE)🧪 Running Playwright E2E tests with UI...$(NC)"
	@cd tests/e2e && npm run test:ui

test-cypress: ## Run Cypress E2E tests
	@echo "$(BLUE)🧪 Running Cypress E2E tests...$(NC)"
	@cd tests/e2e && npx cypress run

test-cypress-open: ## Open Cypress test runner
	@echo "$(BLUE)🧪 Opening Cypress test runner...$(NC)"
	@cd tests/e2e && npx cypress open

test-setup: ## Setup test dependencies
	@echo "$(BLUE)🔧 Setting up test dependencies...$(NC)"
	@cd tests/e2e && npm install
	@cd tests/e2e && npx playwright install
	@echo "$(GREEN)✅ Test dependencies installed$(NC)"

test-clean: ## Clean test outputs and dependencies
	@echo "$(BLUE)🧹 Cleaning test outputs...$(NC)"
	@rm -rf tests/bash/output/
	@rm -rf tests/e2e/node_modules/
	@rm -rf tests/e2e/test-results/
	@rm -rf tests/e2e/playwright-report/
	@rm -rf tests/integration/target/
	@find tests/ -name "*.log" -delete
	@echo "$(GREEN)✅ Test outputs cleaned$(NC)"

test-docker-build: ## Build Docker test environment
	@echo "$(BLUE)🐳 Building Docker test environment...$(NC)"
	@docker build -f Dockerfile.test -t dock2tauri-test .
	@echo "$(GREEN)✅ Docker test environment built$(NC)"

test-docker: test-docker-build ## Run all tests in Docker isolation
	@echo "$(BLUE)🐳 Running tests in Docker isolation...$(NC)"
	@docker run --rm dock2tauri-test
	@echo "$(GREEN)✅ Docker tests completed$(NC)"

test-docker-shell: test-docker-build ## Open interactive shell in Docker test environment
	@echo "$(BLUE)🐳 Opening Docker test shell...$(NC)"
	@docker run --rm -it dock2tauri-test bash

# Quick launch presets
nginx: ## Launch Nginx web server (port 8088)
	@echo "$(GREEN)🌐 Launching Nginx as desktop app...$(NC)"
	@./scripts/dock2tauri.sh nginx:alpine 8088 80

grafana: ## Launch Grafana dashboard (port 3001)
	@echo "$(GREEN)📊 Launching Grafana as desktop app...$(NC)"
	@./scripts/dock2tauri.sh grafana/grafana 3001 3000

jupyter: ## Launch Jupyter notebook (port 8888)
	@echo "$(GREEN)📓 Launching Jupyter as desktop app...$(NC)"
	@./scripts/dock2tauri.sh jupyter/scipy-notebook 8888 8888

portainer: ## Launch Portainer Docker UI (port 9000)
	@echo "$(GREEN)🐳 Launching Portainer as desktop app...$(NC)"
	@./scripts/dock2tauri.sh portainer/portainer-ce 9000 9000

# Generic launch command
launch: ## Launch custom container (usage: make launch IMAGE=image:tag HOST_PORT=8088 CONTAINER_PORT=80)
	@if [ -z "$(IMAGE)" ]; then \
		echo "$(RED)❌ IMAGE parameter is required. Usage: make launch IMAGE=nginx:alpine HOST_PORT=8088 CONTAINER_PORT=80$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)🚀 Launching $(IMAGE) as desktop app...$(NC)"
	@./scripts/dock2tauri.sh $(IMAGE) $(or $(HOST_PORT),$(DEFAULT_HOST_PORT)) $(or $(CONTAINER_PORT),$(DEFAULT_CONTAINER_PORT))

# Container management
stop-all: ## Stop all dock2tauri containers
	@echo "$(YELLOW)🛑 Stopping all Dock2Tauri containers...$(NC)"
	@docker ps --filter "name=dock2tauri-*" -q | xargs -r docker stop
	@docker ps -a --filter "name=dock2tauri-*" -q | xargs -r docker rm
	@echo "$(GREEN)✅ All containers stopped and removed$(NC)"

list: ## List active dock2tauri containers
	@echo "$(BLUE)📦 Active Dock2Tauri containers:$(NC)"
	@docker ps --filter "name=dock2tauri-*" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

# Testing
test: test-scripts test-integration ## Run all tests

test-scripts: ## Test all script launchers (bash, python, nodejs)
	@echo "$(BLUE)🧪 Testing script launchers...$(NC)"
	@timeout 10 ./scripts/dock2tauri.sh nginx:alpine 8081 80 >/dev/null 2>&1 || true
	@sleep 2
	@if curl -s http://localhost:8081 >/dev/null; then \
		echo "$(GREEN)✅ Bash launcher: PASSED$(NC)"; \
		docker stop $$(docker ps -q --filter "publish=8081") 2>/dev/null || true; \
	else \
		echo "$(RED)❌ Bash launcher: FAILED$(NC)"; \
	fi

test-integration: ## Test build and integration workflows
	@echo "$(BLUE)🧪 Testing integration workflows...$(NC)"
	@cd tests/workflow && python3 test_build_install.py

test-nodejs: ## Test Node.js script launcher
	@echo "$(BLUE)🧪 Testing Node.js launcher...$(NC)"
	@timeout 10 node scripts/dock2tauri.js nginx:alpine 8083 80 >/dev/null 2>&1 || true &
	@sleep 3
	@if curl -s http://localhost:8083 >/dev/null; then \
		echo "$(GREEN)✅ Node.js launcher: PASSED$(NC)"; \
		docker stop $$(docker ps -q --filter "publish=8083") 2>/dev/null || true; \
	else \
		echo "$(RED)❌ Node.js launcher: FAILED$(NC)"; \
	fi

# Development helpers
clean: ## Clean build artifacts and stop containers
	@echo "$(YELLOW)🧹 Cleaning up...$(NC)"
	@cd src-tauri && cargo clean
	@docker ps --filter "name=dock2tauri-*" -q | xargs -r docker stop
	@docker ps -a --filter "name=dock2tauri-*" -q | xargs -r docker rm
	@echo "$(GREEN)✅ Cleanup complete$(NC)"

logs: ## Show logs from running containers
	@echo "$(BLUE)📋 Container logs:$(NC)"
	@docker ps --filter "name=dock2tauri-*" -q | xargs -I {} sh -c 'echo "=== Container {} ===" && docker logs --tail 20 {}'

status: ## Show system status
	@echo "$(BLUE)💻 Dock2Tauri System Status:$(NC)"
	@echo "Docker: $$(docker --version 2>/dev/null || echo 'Not installed')"
	@echo "Rust: $$(rustc --version 2>/dev/null || echo 'Not installed')"
	@echo "Tauri: $$(tauri --version 2>/dev/null || echo 'Not installed')"
	@echo "Node.js: $$(node --version 2>/dev/null || echo 'Not installed')"
	@echo "Python: $$(python3 --version 2>/dev/null || echo 'Not installed')"
	@echo "Active containers: $$(docker ps --filter 'name=dock2tauri-*' | wc -l | xargs expr -1 +)"

# Examples
examples: ## Show usage examples
	@echo "$(BLUE)📖 Dock2Tauri Usage Examples:$(NC)"
	@echo ""
	@echo "$(YELLOW)Quick Launch Presets:$(NC)"
	@echo "  make nginx        # Launch Nginx web server"
	@echo "  make grafana      # Launch Grafana dashboard"
	@echo "  make jupyter      # Launch Jupyter notebook"
	@echo "  make portainer    # Launch Portainer Docker UI"
	@echo ""
	@echo "$(YELLOW)Custom Launch:$(NC)"
	@echo "  make launch IMAGE=redis:alpine HOST_PORT=6379 CONTAINER_PORT=6379"
	@echo "  make launch IMAGE=mysql:8 HOST_PORT=3306 CONTAINER_PORT=3306"
	@echo ""
	@echo "$(YELLOW)Script Launchers:$(NC)"
	@echo "  ./scripts/dock2tauri.sh nginx:alpine 8088 80"
	@echo "  python3 scripts/dock2tauri.py --image nginx:alpine --host-port 8088"
	@echo "  node scripts/dock2tauri.js grafana/grafana 3001 3000"

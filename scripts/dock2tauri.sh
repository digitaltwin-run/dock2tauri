#!/bin/bash

# Dock2Tauri Bash Launcher
# Usage: ./dock2tauri.sh <docker-image> <host-port> <container-port>

set -e

# Base directory of the project
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOCKER_IMAGE="${1:-nginx:alpine}"
HOST_PORT="${2:-8088}"
CONTAINER_PORT="${3:-80}"
CONTAINER_NAME="dock2tauri-$(echo $DOCKER_IMAGE | sed 's/[^a-zA-Z0-9]/-/g')-$HOST_PORT"

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not found. Please install Docker first."
        exit 1
    fi
    
    if ! command -v cargo >/dev/null 2>&1; then
        log_warning "Rust/Cargo not found. Some features may not work."
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon not running. Please start Docker."
        exit 1
    fi
    
    log_success "Dependencies check passed"
}

stop_existing_container() {
    log_info "Stopping existing containers on port $HOST_PORT..."
    
    # Stop containers using the same port
    EXISTING=$(docker ps -q --filter "publish=$HOST_PORT" 2>/dev/null || true)
    if [ -n "$EXISTING" ]; then
        echo "$EXISTING" | xargs -r docker stop
        log_success "Stopped existing containers"
    fi
    
    # Remove old container with same name
    if docker ps -a --filter "name=$CONTAINER_NAME" | grep -q "$CONTAINER_NAME"; then
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
        log_success "Removed old container: $CONTAINER_NAME"
    fi
}

launch_container() {
    log_info "Launching Docker container..."
    log_info "Image: $DOCKER_IMAGE"
    log_info "Host Port: $HOST_PORT"
    log_info "Container Port: $CONTAINER_PORT"
    
    # Launch container with error capture
    set +e
    RESULT=$(docker run -d \
        -p "$HOST_PORT:$CONTAINER_PORT" \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        "$DOCKER_IMAGE" 2>&1)
    RC=$?
    set -e
    if [ $RC -eq 0 ]; then
        CONTAINER_ID="$RESULT"
        log_success "Container launched: $CONTAINER_ID"
        log_success "Access at: http://localhost:$HOST_PORT"
    else
        log_error "Failed to launch container: $RESULT"
        exit $RC
    fi
}

wait_for_service() {
    log_info "Waiting for service to be ready..."
    
    for i in {1..30}; do
        if curl -s --connect-timeout 1 "http://localhost:$HOST_PORT" >/dev/null 2>&1; then
            log_success "Service is ready!"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    
    log_warning "Service might not be ready yet, but continuing..."
}

update_tauri_config() {
    log_info "Updating Tauri configuration..."
    CONFIG_FILE="$BASE_DIR/src-tauri/tauri.conf.json"
    if [ -f "$CONFIG_FILE" ]; then
        # Create backup
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
        # Update configuration (Tauri v1 schema)
        cat > "$CONFIG_FILE" << EOF
{
  "\$schema": "../node_modules/@tauri-apps/cli/schema.json",
  "build": {
    "beforeBuildCommand": "",
    "beforeDevCommand": "",
    "distDir": "../app",
    "devPath": "http://localhost:$HOST_PORT"
  },
  "package": {
    "productName": "Dock2Tauri - $(echo $DOCKER_IMAGE | cut -d':' -f1)",
    "version": "1.0.0"
  },
  "tauri": {
    "bundle": {
      "active": true,
      "identifier": "com.dock2tauri.$(echo $DOCKER_IMAGE | sed 's/[^a-zA-Z0-9]//g')",
      "publisher": "Dock2Tauri",
      "createUpdaterArtifacts": false
    },
    "windows": [
      {
        "title": "Dock2Tauri - $DOCKER_IMAGE",
        "width": 1200,
        "height": 800,
        "minWidth": 600,
        "minHeight": 400,
        "resizable": true,
        "fullscreen": false
      }
    ],
    "security": {
      "csp": null
    }
  },
  "plugins": {}
}
EOF
        log_success "Tauri configuration updated"
    else
        log_warning "Tauri config not found, skipping update"
    fi
}

launch_tauri() {
    log_info "Launching Tauri application..."
    
    cd "$BASE_DIR/src-tauri" || exit 1
    
    # Check if we have Tauri CLI
    if command -v tauri >/dev/null 2>&1; then
        tauri dev
    elif command -v cargo >/dev/null 2>&1; then
        cargo tauri dev
    else
        log_error "Neither Tauri CLI nor Cargo found. Please install Rust and Tauri CLI."
        log_info "Container is running at: http://localhost:$HOST_PORT"
        log_info "Container ID: $CONTAINER_ID"
        exit 1
    fi
}

cleanup() {
    log_info "Cleaning up..."
    if [ -n "$CONTAINER_ID" ]; then
        docker stop "$CONTAINER_ID" 2>/dev/null || true
        docker rm "$CONTAINER_ID" 2>/dev/null || true
        log_success "Container stopped and removed"
    fi
    
    # Restore config backup if exists
    CONFIG_FILE="$BASE_DIR/src-tauri/tauri.conf.json"
    if [ -f "$CONFIG_FILE.backup" ]; then
        mv "$CONFIG_FILE.backup" "$CONFIG_FILE"
        log_success "Tauri configuration restored"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🐳🦀 Dock2Tauri - Docker to Desktop Bridge${NC}"
    echo "=================================================="
    
    # Set up cleanup trap
    trap cleanup EXIT INT TERM
    
    check_dependencies
    stop_existing_container
    launch_container
    wait_for_service
    update_tauri_config
    
    # Launch Tauri (this will block until app exits)
    launch_tauri
}

# Help function
show_help() {
    echo "Dock2Tauri - Docker to Desktop Bridge"
    echo ""
    echo "Usage: $0 [IMAGE] [HOST_PORT] [CONTAINER_PORT]"
    echo ""
    echo "Arguments:"
    echo "  IMAGE           Docker image to run (default: nginx:alpine)"
    echo "  HOST_PORT       Host port to bind to (default: 8088)"
    echo "  CONTAINER_PORT  Container port to expose (default: 80)"
    echo ""
    echo "Examples:"
    echo "  $0 nginx:alpine 8088 80"
    echo "  $0 grafana/grafana 3001 3000"
    echo "  $0 jupyter/scipy-notebook 8888 8888"
    echo ""
    echo "Environment Variables:"
    echo "  DOCK2TAURI_DEBUG=1    Enable debug mode"
}

# Parse arguments
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    "")
        log_warning "No arguments provided, using defaults"
        ;;
esac

# Enable debug mode if requested
if [ "$DOCK2TAURI_DEBUG" = "1" ]; then
    set -x
fi

# Run main function
main

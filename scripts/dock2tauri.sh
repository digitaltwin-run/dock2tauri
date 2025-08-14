#!/bin/bash

# Dock2Tauri Bash Launcher
# Usage: ./dock2tauri.sh <docker-image|Dockerfile> <host-port> <container-port> [--build] [--target=<triple>]
#   --build (-b)        Build Tauri release bundles instead of running `tauri dev`
#   --target=<triple>   Pass target triple to `cargo tauri build`, e.g. --target=x86_64-pc-windows-gnu

set -e

# Base directory of the project
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging helpers (defined early so they are available before first call)
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

# Configuration
INPUT_IMAGE_OR_DOCKERFILE="${1:-nginx:alpine}"
# If the first argument is a file that exists (Dockerfile) build a local image
if [ -f "$INPUT_IMAGE_OR_DOCKERFILE" ]; then
    DOCKERFILE_PATH="$INPUT_IMAGE_OR_DOCKERFILE"
    DOCKER_BUILD_CTX="$(dirname "$DOCKERFILE_PATH")"
    # Docker tags must be lowercase and may include [a-z0-9_.-]
    TAG_BASE="$(basename "$DOCKERFILE_PATH")"
    TAG_BASE="$(echo "$TAG_BASE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_.-]/-/g')"
    TAG="dock2tauri-local-${TAG_BASE}-$(date +%s)"
    log_info "Building Docker image from $DOCKERFILE_PATH (context: $DOCKER_BUILD_CTX) as $TAG ..."
    docker build -f "$DOCKERFILE_PATH" -t "$TAG" "$DOCKER_BUILD_CTX"
    DOCKER_IMAGE="$TAG"
else
    DOCKER_IMAGE="$INPUT_IMAGE_OR_DOCKERFILE"
fi
HOST_PORT="${2:-8088}"
CONTAINER_PORT="${3:-80}"
BUILD_RELEASE=false
BUILD_TARGET=""
for arg in "$@"; do
  if [ "$arg" = "--build" ] || [ "$arg" = "-b" ]; then
    BUILD_RELEASE=true
  elif [[ "$arg" == --target=* ]]; then
    BUILD_TARGET="${arg#*=}"
  fi
done
CONTAINER_NAME="dock2tauri-$(echo "$DOCKER_IMAGE" | sed 's/[^a-zA-Z0-9]/-/g')-$HOST_PORT"

# Functions
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
        # Update configuration (Tauri v2 schema)
        cat > "$CONFIG_FILE" << EOF
{
  "\$schema": "../node_modules/@tauri-apps/cli/schema.json",
  "productName": "Dock2Tauri - $(echo $DOCKER_IMAGE | cut -d':' -f1)",
  "version": "1.0.0",
  "identifier": "com.dock2tauri.$(echo $DOCKER_IMAGE | sed 's/[^a-zA-Z0-9]//g')",
  "build": {
    "beforeBuildCommand": "",
    "beforeDevCommand": "",
    "devUrl": "http://localhost:$HOST_PORT",
    "frontendDist": "../app"
  },
  "app": {
    "security": {
      "csp": null
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
    ]
  },
  "bundle": {
    "active": true,
    "targets": ["appimage", "deb", "rpm"],
    "icon": [],
    "resources": [],
    "externalBin": [],
    "copyright": "",
    "category": "DeveloperTool",
    "shortDescription": "Docker App in Tauri",
    "longDescription": "Running $DOCKER_IMAGE as desktop application"
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
    if $BUILD_RELEASE; then
        log_info "Building Tauri release bundles (cargo tauri build)..."
        if [ -n "$BUILD_TARGET" ]; then
            (cd "$BASE_DIR/src-tauri" && cargo tauri build --target "$BUILD_TARGET")
        else
            (cd "$BASE_DIR/src-tauri" && cargo tauri build)
        fi
    else
        log_info "Launching Tauri application (dev)..."
        (cd "$BASE_DIR/src-tauri" && cargo tauri dev)
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
    echo "Usage: $0 <docker-image|Dockerfile> <host-port> <container-port> [--build] [--target=<triple>]"
    echo ""
    echo "Arguments:"
    echo "  IMAGE           Docker image to run OR path to Dockerfile (default: nginx:alpine)"
    echo "  HOST_PORT       Host port to bind to (default: 8088)"
    echo "  CONTAINER_PORT  Container port to expose (default: 80)"
    echo ""
    echo "Options:"
    echo "  --build (-b)        Build Tauri release bundles instead of running 'tauri dev'"
    echo "  --target=<triple>   Pass target triple to 'cargo tauri build'"
    echo ""
    echo "Examples:"
    echo "  $0 nginx:alpine 8088 80"
    echo "  $0 ./Dockerfile 8088 80"
    echo "  $0 grafana/grafana 3001 3000 --build"
    echo "  $0 jupyter/scipy-notebook 8888 8888 --target=x86_64-pc-windows-gnu"
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

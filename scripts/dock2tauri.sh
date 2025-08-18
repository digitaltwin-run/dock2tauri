#!/bin/bash

# Dock2Tauri Bash Launcher
# Usage: ./dock2tauri.sh <docker-image|Dockerfile> <host-port> <container-port> [--build] [--target=<triple>] [--health-url=<url>] [--timeout=<seconds>] [--cross]

# Load environment configuration
load_env_config() {
  local project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  local env_file="$project_root/.env"
  local env_example="$project_root/.env.example"
  
  # Create .env from .env.example if it doesn't exist
  if [ ! -f "$env_file" ] && [ -f "$env_example" ]; then
    echo "🔧 Creating .env from .env.example..."
    cp "$env_example" "$env_file"
    echo "✅ .env file created. You can customize it as needed."
  fi
  
  # Load .env if it exists
  if [ -f "$env_file" ]; then
    echo "🔧 Loading configuration from .env..."
    set -a  # automatically export all variables
    source "$env_file" 2>/dev/null || true
    set +a
    echo "✅ Configuration loaded from .env"
  fi
  
  # Set defaults for critical variables if not set
  export BUILD_TIMEOUT="${BUILD_TIMEOUT:-600}"
  export DOCKER_TIMEOUT="${DOCKER_TIMEOUT:-30}"
  export RPM_CLEANUP_AUTO="${RPM_CLEANUP_AUTO:-true}"
  export DEV_PORT="${DEV_PORT:-8081}"
  export APP_NAME="${APP_NAME:-Dock2Tauri}"
  export RPM_FORCE_INSTALL="${RPM_FORCE_INSTALL:-true}"
}
#   --build (-b)        Build Tauri release bundles instead of running `tauri dev`
#   --target=<triple>   Pass target triple to `cargo tauri build`, e.g. --target=x86_64-pc-windows-gnu
#   --health-url=<url>  Override readiness URL (default: http://localhost:HOST_PORT)
#   --timeout=<seconds> Readiness timeout in seconds (default: 30)
#   --cross             Attempt best-effort cross-target builds (requires proper toolchains)

set -e

# Base directory of the project
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Load environment configuration
load_env_config

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

# RPM conflict prevention - automatically cleanup existing dock2tauri packages
cleanup_existing_rpm_packages() {
  if ! command -v rpm >/dev/null 2>&1; then
    log_info "RPM not available, skipping package cleanup"
    return 0
  fi
  
  log_info "Checking for existing dock2tauri RPM packages..."
  local existing_packages
  existing_packages=$(rpm -qa | grep -E "(dock2.*tauri|tauri.*dock)" 2>/dev/null || true)
  
  if [ -z "$existing_packages" ]; then
    log_info "No existing dock2tauri packages found"
    return 0
  fi
  
  log_warning "Found existing dock2tauri packages, removing to prevent conflicts:"
  echo "$existing_packages" | while read -r pkg; do
    echo "  - $pkg"
  done
  
  # Automatically remove conflicting packages without asking
  log_info "Automatically removing conflicting packages..."
  log_info "DEBUG: Found packages to remove:"
  echo "$existing_packages" | while read -r pkg; do
    echo "  - $pkg"
  done
  
  # Method 1: Try dnf remove first (handles dependencies better)
  if command -v dnf >/dev/null 2>&1; then
    log_info "Attempting removal with dnf..."
    if echo "$existing_packages" | xargs sudo dnf remove -y 2>/dev/null; then
      log_success "Successfully removed packages with dnf"
      return 0
    else
      log_warning "dnf removal failed, trying rpm..."
    fi
  fi
  
  # Method 2: Try rpm with --allmatches to remove all versions
  if echo "$existing_packages" | xargs sudo rpm -e --force --nodeps --allmatches 2>/dev/null; then
    log_success "Successfully removed packages with rpm --allmatches"
    return 0
  else
    log_warning "Standard removal failed. Attempting individual package removal..."
  fi
  
  # Method 3: Remove packages one by one with maximum force
  local removal_success=0
  echo "$existing_packages" | while read -r pkg; do
    if [ -n "$pkg" ]; then
      log_info "  Removing: $pkg"
      if sudo rpm -e --force --nodeps --noscripts --allmatches "$pkg" 2>/dev/null; then
        log_success "    ✅ Removed: $pkg"
        removal_success=1
      else
        log_warning "    ❌ Failed to remove: $pkg"
        # Try with different approach - get all matching packages
        local matching_packages=$(rpm -qa | grep "$pkg" | head -10)
        if [ -n "$matching_packages" ]; then
          echo "$matching_packages" | xargs sudo rpm -e --force --nodeps --noscripts 2>/dev/null || true
        fi
      fi
    fi
  done
  
  # Final verification
  local remaining=$(rpm -qa | grep dock2-tauri | wc -l)
  if [ "$remaining" -eq 0 ]; then
    log_success "✅ All conflicting packages successfully removed"
  else
    log_warning "⚠️ $remaining packages may still remain. Continuing with installation..."
    log_info "Remaining packages:"
    rpm -qa | grep dock2-tauri | while read -r pkg; do
      echo "  - $pkg"
    done
  fi
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
BUILD_FLAG_PASSED=false
BUILD_TARGET=""
HEALTH_URL=""
TIMEOUT=30
# Export settings
EXPORT_BUNDLES=false
EXPORT_DIR="$BASE_DIR/dist"
# Whether to attempt cross targets automatically
CROSS_BUILD=false
# Candidate cross targets we may attempt if installed (best-effort)
CANDIDATE_TARGETS=("x86_64-unknown-linux-gnu" "aarch64-unknown-linux-gnu" "x86_64-pc-windows-gnu" "x86_64-apple-darwin" "aarch64-apple-darwin")
# Override candidate targets via environment variable (comma-separated)
if [ -n "${DOCK2TAURI_CROSS_TARGETS:-}" ]; then
  IFS=',' read -ra CANDIDATE_TARGETS <<< "$DOCK2TAURI_CROSS_TARGETS"
fi
for arg in "$@"; do
  if [ "$arg" = "--build" ] || [ "$arg" = "-b" ]; then
    BUILD_RELEASE=true
    BUILD_FLAG_PASSED=true
  elif [[ "$arg" == --target=* ]]; then
    BUILD_TARGET="${arg#*=}"
  elif [[ "$arg" == --health-url=* ]]; then
    HEALTH_URL="${arg#*=}"
  elif [[ "$arg" == --timeout=* ]]; then
    TIMEOUT="${arg#*=}"
  elif [ "$arg" = "--cross" ]; then
    CROSS_BUILD=true
  fi
done
CONTAINER_NAME="dock2tauri-$(echo "$DOCKER_IMAGE" | sed 's/[^a-zA-Z0-9]/-/g')-$HOST_PORT"

# If input was a Dockerfile and user did NOT pass --build explicitly, default to building release bundles and exporting them.
if [ -n "${DOCKERFILE_PATH:-}" ] && [ "$BUILD_FLAG_PASSED" = "false" ]; then
  BUILD_RELEASE=true
  EXPORT_BUNDLES=true
  log_info "Dockerfile input detected; defaulting to build and export bundles."
fi

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
    local url
    if [ -n "$HEALTH_URL" ]; then
        url="$HEALTH_URL"
    else
        url="http://localhost:$HOST_PORT"
    fi
    local i=0
    while [ $i -lt $TIMEOUT ]; do
        if curl -s --connect-timeout 1 "$url" >/dev/null 2>&1; then
            log_success "Service is ready!"
            return 0
        fi
        echo -n "."
        sleep 1
        i=$((i+1))
    done
    echo
    log_warning "Service might not be ready yet, but continuing..."
}

generate_tauri_config_json() {
    log_info "Preparing Tauri configuration (ephemeral)..."
    TAURI_CONFIG_PATH=$(mktemp -t tauri.conf.XXXXXX.json)
    # Determine frontendDist: if building from a Dockerfile, use its context app folder
    local FRONTEND_DIST
    if [ -n "${DOCKERFILE_PATH:-}" ]; then
        FRONTEND_DIST="$(cd "$DOCKER_BUILD_CTX" && pwd)/app"
    else
        FRONTEND_DIST="../app"
    fi
    # devUrl is used only in dev; during build we set it to null
    local DEV_URL
    if $BUILD_RELEASE; then
      DEV_URL=null
    else
      DEV_URL="\"http://localhost:$HOST_PORT\""
    fi
    # Determine bundler targets dynamically to avoid failures if external tools are missing
    local OS
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    local targets
    targets=()
    local BUNDLE_ACTIVE=true
    if [ "$OS" = "linux" ]; then
      if command -v dpkg-deb >/dev/null 2>&1; then
        targets+=("deb")
      else
        log_warning "dpkg-deb not found; skipping DEB bundle."
      fi
      if command -v rpmbuild >/dev/null 2>&1; then
        targets+=("rpm")
      else
        log_warning "rpmbuild not found; skipping RPM bundle."
      fi
      # Auto-skip AppImage in cross-build mode (often fails) unless explicitly enabled
      if [ "${DOCK2TAURI_SKIP_APPIMAGE:-0}" = "1" ] || ([ "$CROSS_BUILD" = "true" ] && [ "${DOCK2TAURI_FORCE_APPIMAGE:-0}" != "1" ]); then
        if [ "$CROSS_BUILD" = "true" ] && [ "${DOCK2TAURI_SKIP_APPIMAGE:-0}" != "1" ]; then
          log_warning "Cross-build mode detected; skipping AppImage (use DOCK2TAURI_FORCE_APPIMAGE=1 to override)."
        else
          log_warning "DOCK2TAURI_SKIP_APPIMAGE=1 set; skipping AppImage bundle."
        fi
      else
        if command -v linuxdeploy >/dev/null 2>&1 && command -v appimagetool >/dev/null 2>&1; then
          # Verify the AppImage tools are actually runnable on this system (e.g., FUSE-less mode)
          if APPIMAGE_EXTRACT_AND_RUN=1 linuxdeploy --version >/dev/null 2>&1 \
             && APPIMAGE_EXTRACT_AND_RUN=1 appimagetool --version >/dev/null 2>&1; then
            targets+=("appimage")
          else
            log_warning "linuxdeploy/appimagetool present but not runnable; skipping AppImage bundle."
          fi
        else
          log_warning "linuxdeploy/appimagetool not found; skipping AppImage bundle."
        fi
      fi
      if [ ${#targets[@]} -eq 0 ]; then
        BUNDLE_ACTIVE=false
        log_warning "No Linux packagers found (dpkg-deb/rpmbuild/appimagetool). Bundling will be disabled."
      fi
    elif [ "$OS" = "darwin" ]; then
      targets=("dmg" "app")
    elif echo "$OS" | grep -qi "msys\|mingw\|cygwin"; then
      targets=("nsis" "msi")
    fi
    # Build JSON array string
    local BUNDLE_TARGETS_JSON="["
    local first=true
    for t in "${targets[@]}"; do
      if $first; then BUNDLE_TARGETS_JSON+="\"$t\""; first=false; else BUNDLE_TARGETS_JSON+=", \"$t\""; fi
    done
    BUNDLE_TARGETS_JSON+="]"
    cat > "$TAURI_CONFIG_PATH" << EOF
{
  "\$schema": "../node_modules/@tauri-apps/cli/schema.json",
  "productName": "Dock2Tauri-$(echo $DOCKER_IMAGE | cut -d':' -f1 | sed 's|[/\:*?"<>|]||g')",
  "version": "1.0.0",
  "identifier": "com.dock2tauri.$(echo $DOCKER_IMAGE | sed 's/[^a-zA-Z0-9]//g')",
  "build": {
    "beforeBuildCommand": "",
    "beforeDevCommand": "",
    "devUrl": $DEV_URL,
    "frontendDist": "$FRONTEND_DIST"
  },
  "app": {
    "security": {
      "csp": null
    },
    "windows": [
      {
        "title": "Dock2Tauri-$DOCKER_IMAGE",
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
    "active": $BUNDLE_ACTIVE,
    "targets": $BUNDLE_TARGETS_JSON,
    "icon": ["$BASE_DIR/src-tauri/icons/icon.png"],
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
    log_success "Ephemeral Tauri configuration prepared at $TAURI_CONFIG_PATH"
}

launch_tauri() {
    log_info "Launching Tauri application (dev)..."
    (cd "$BASE_DIR/src-tauri" && cargo tauri dev --config "$TAURI_CONFIG_PATH")
}

# Map rust target triple to platform folder name
map_target_to_platform() {
  local t="$1"
  if [ -z "$t" ]; then
    # native
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    case "$os" in
      linux) if [ "$arch" = "x86_64" ]; then echo "linux-x64"; else echo "linux-$arch"; fi ;;
      darwin) if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then echo "macos-arm64"; else echo "macos-x64"; fi ;;
      msys*|mingw*|cygwin*) echo "windows-x64" ;;
      *) echo "${os}-${arch}" ;;
    esac
  else
    case "$t" in
      aarch64-unknown-linux-gnu) echo "linux-arm64" ;;
      x86_64-unknown-linux-gnu) echo "linux-x64" ;;
      x86_64-pc-windows-gnu) echo "windows-x64" ;;
      x86_64-apple-darwin) echo "macos-x64" ;;
      aarch64-apple-darwin) echo "macos-arm64" ;;
      *) echo "$t" ;;
    esac
  fi
}

# Check if a rust target is installed
is_rust_target_installed() {
  local t="$1"
  command -v rustup >/dev/null 2>&1 || return 1
  rustup target list --installed | awk '{print $1}' | grep -qx "$t"
}

# Check if cross-compilation toolchain is available for a target
can_cross_compile_target() {
  local t="$1"
  case "$t" in
    x86_64-unknown-linux-gnu)
      # Native or same arch, usually OK
      return 0
      ;;
    aarch64-unknown-linux-gnu)
      # Check for ARM64 cross compiler and pkg-config
      if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1 && \
         (command -v aarch64-linux-gnu-pkg-config >/dev/null 2>&1 || [ -n "${PKG_CONFIG:-}" ]); then
        return 0
      fi
      return 1
      ;;
    x86_64-pc-windows-gnu)
      # Check for MinGW cross compiler
      if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
        return 0
      fi
      return 1
      ;;
    x86_64-apple-darwin|aarch64-apple-darwin)
      # Check for osxcross or macOS SDK
      if [ -n "${OSXCROSS_ROOT:-}" ] && command -v o64-clang >/dev/null 2>&1; then
        return 0
      fi
      if command -v x86_64-apple-darwin-clang >/dev/null 2>&1 || command -v aarch64-apple-darwin-clang >/dev/null 2>&1; then
        return 0
      fi
      return 1
      ;;
    *)
      # Unknown target, assume possible
      return 0
      ;;
  esac
}

# Filter cross targets to only those that are feasible
get_feasible_cross_targets() {
  local feasible=()
  local host_os=$(uname -s | tr '[:upper:]' '[:lower:]')
  
  for t in "${CANDIDATE_TARGETS[@]}"; do
    # Skip if rust target not installed
    if ! is_rust_target_installed "$t"; then
      continue
    fi
    
    # Filter by host OS (avoid obvious mismatches unless tools are present)
    case "$host_os" in
      linux)
        case "$t" in
          *-apple-darwin) 
            if ! can_cross_compile_target "$t"; then
              continue
            fi
            ;;
          *-pc-windows-*)
            if ! can_cross_compile_target "$t"; then
              continue
            fi
            ;;
        esac
        ;;
      darwin)
        case "$t" in
          *-unknown-linux-*|*-pc-windows-*)
            # macOS to Linux/Windows cross-compilation is complex
            if ! can_cross_compile_target "$t"; then
              continue
            fi
            ;;
        esac
        ;;
    esac
    
    feasible+=("$t")
  done
  
  printf '%s\n' "${feasible[@]}"
}

# Build for a specific target (or native if empty)
build_for_target() {
  local t="$1"; local args=(tauri build --config "$TAURI_CONFIG_PATH")
  if [ -n "$t" ]; then args+=(--target "$t"); fi
  log_info "Building bundles for target: ${t:-native} ..."
  (
    set +e
    # Allow running AppImage tools (linuxdeploy/appimagetool) without FUSE by extracting on the fly
    if command -v linuxdeploy >/dev/null 2>&1 || command -v appimagetool >/dev/null 2>&1; then
      export APPIMAGE_EXTRACT_AND_RUN="${APPIMAGE_EXTRACT_AND_RUN:-1}"
    fi
    cd "$BASE_DIR/src-tauri" && cargo "${args[@]}"
    rc=$?
    set -e
    exit $rc
  )
}

# Copy built bundles into dist/<platform>
copy_bundles_to_dist() {
  local t="$1"; local platform; platform=$(map_target_to_platform "$t")
  local src_dir
  if [ -n "$t" ]; then
    src_dir="$BASE_DIR/src-tauri/target/$t/release/bundle"
  else
    src_dir="$BASE_DIR/src-tauri/target/release/bundle"
  fi
  if [ ! -d "$src_dir" ]; then
    log_warning "No bundles found at $src_dir"
    return 0
  fi
  local dest_dir="$EXPORT_DIR/$platform"
  mkdir -p "$dest_dir"
  # Copy all files from bundle subfolders (appimage, deb, rpm, nsis, msi, dmg, app)
  find "$src_dir" -maxdepth 2 -type f -print0 2>/dev/null | xargs -0 -I {} cp -f {} "$dest_dir" 2>/dev/null || true
  # Also copy folder structure for completeness
  cp -r "$src_dir"/* "$dest_dir"/ 2>/dev/null || true
  log_success "Exported bundles to $dest_dir"
  generate_platform_readme "$dest_dir" "$platform"
}

# Generate README.md with usage instructions
generate_platform_readme() {
  local dest_dir="$1"; local platform="$2"
  {
    printf '%s\n' "# Dock2Tauri - ${platform}" ""
    printf '%s\n' "This folder contains packaged desktop application bundles produced by Tauri for platform: ${platform}." ""
    printf '%s\n' "## Install & Run" ""
    printf '%s\n' "### Linux (AppImage)" "- Make executable and run:" "  \`\`\`bash" "  chmod +x ./*.AppImage" "  ./Dock2Tauri*.AppImage" "  \`\`\`" ""
    printf '%s\n' "### Linux (.deb)" "- Install with APT:" "  \`\`\`bash" "  sudo apt install ./Dock2Tauri*.deb" "  # then run from desktop menu or:" "  Dock2Tauri" "  \`\`\`" ""
    printf '%s\n' "### Linux (.rpm)" "- Install with DNF/RPM:" "  \`\`\`bash" "  sudo dnf install ./Dock2Tauri*.rpm" "  # or" "  sudo rpm -i ./Dock2Tauri*.rpm" "  \`\`\`" ""
    printf '%s\n' "### Windows (.exe / NSIS)" "- Run the installer (or portable exe) and follow the prompts." ""
    printf '%s\n' "### Windows (.msi)" "- Double click the MSI and follow the installer." ""
    printf '%s\n' "### macOS (.dmg / .app)" "- Open the DMG, drag the app to Applications, then launch it." ""
    printf '%s\n' "## Notes" "- Some bundle formats may not be present depending on your host OS and installed packagers." "- To build additional targets, ensure Rust target toolchains and packaging tools are installed."
  } > "$dest_dir/README.md"
}

build_and_export() {
  log_info "Building Tauri release bundles (multi-target export)..."
  
  # Automatically cleanup existing RPM packages to prevent conflicts
  cleanup_existing_rpm_packages
  
  mkdir -p "$EXPORT_DIR"

  # If user specified a single target, build only that
  if [ -n "$BUILD_TARGET" ]; then
    if build_for_target "$BUILD_TARGET"; then
      :
    else
      log_warning "Build failed for target $BUILD_TARGET; exporting any bundles produced before failure."
    fi
    copy_bundles_to_dist "$BUILD_TARGET"
  else
    # Always build native
    if build_for_target ""; then
      :
    else
      log_warning "Build failed for native target; exporting any bundles produced before failure."
    fi
    copy_bundles_to_dist ""
    # Best-effort cross targets (only when explicitly enabled)
    if [ "$CROSS_BUILD" = "true" ]; then
      # Get feasible targets (with toolchain filtering)
      local feasible_targets
      mapfile -t feasible_targets < <(get_feasible_cross_targets)
      
      if [ ${#feasible_targets[@]} -eq 0 ]; then
        log_warning "No feasible cross-compilation targets found. Install toolchains or use DOCK2TAURI_CROSS_TARGETS to override."
      else
        log_info "Attempting cross-builds for feasible targets: ${feasible_targets[*]}"
        for t in "${feasible_targets[@]}"; do
          if build_for_target "$t"; then
            :
          else
            log_warning "Build failed for target $t; exporting any bundles produced before failure."
          fi
          copy_bundles_to_dist "$t"
        done
      fi
    else
      log_info "Cross-target builds disabled by default. Use --cross to attempt them."
    fi
  fi

  generate_dist_root_readme
  build_android_best_effort || true
  log_success "All available bundles exported to: $EXPORT_DIR"
  
  # Offer to install and run RPM package if built successfully
  install_and_run_rpm
}

# Generate root dist/README.md listing built platforms
generate_dist_root_readme() {
  local readme="$EXPORT_DIR/README.md"
  {
    echo "# Dock2Tauri - Distribution Artifacts"
    echo
    echo "This directory contains packaged application bundles per platform."
    echo
    echo "## Available Platforms"
    for d in "$EXPORT_DIR"/*/ ; do
      [ -d "$d" ] || continue
      bn=$(basename "$d")
      echo "- $bn"
    done
    echo
    echo "Each platform folder has its own README.md with installation instructions."
  } > "$readme"
}

# Build Android APK if tooling present (best-effort)
build_android_best_effort() {
  # Check for Tauri CLI
  if ! command -v cargo >/dev/null 2>&1; then
    return 0
  fi
  if ! cargo tauri --help >/dev/null 2>&1; then
    log_warning "Tauri CLI not available; skipping Android build."
    return 0
  fi
  # Check Android SDK presence
  if [ -z "$ANDROID_SDK_ROOT$ANDROID_HOME" ] && ! command -v sdkmanager >/dev/null 2>&1; then
    log_warning "Android SDK not detected; skipping Android build."
    return 0
  fi
  # Ensure Android project is initialized
  if [ ! -d "$BASE_DIR/src-tauri/gen/android" ]; then
    log_warning "Android project not initialized; run 'cargo tauri android init' once (in src-tauri). Skipping Android build."
    return 0
  fi
  log_info "Attempting Android APK build (best-effort)..."
  set +e
  (cd "$BASE_DIR/src-tauri" && cargo tauri android build --config "$TAURI_CONFIG_PATH" -- --release)
  rc=$?
  set -e
  if [ $rc -ne 0 ]; then
    log_warning "Android build failed; skipping export."
    return 0
  fi
  local dest_dir="$EXPORT_DIR/android-apk"
  mkdir -p "$dest_dir"
  # Copy APK artifacts
  find "$BASE_DIR/src-tauri" -type f -name "*.apk" -print0 2>/dev/null | xargs -0 -I {} cp -f {} "$dest_dir" 2>/dev/null || true
  if [ -z "$(ls -A "$dest_dir" 2>/dev/null)" ]; then
    log_warning "No APK artifacts found after build."
    return 0
  fi
  # Write README without heredoc to keep patch portability
  printf '%s\n' \
    '# Dock2Tauri - Android APK' \
    '' \
    'This folder contains Android APK builds (best-effort).' \
    '' \
    'Install:' \
    '- Enable installing from unknown sources.' \
    '- Transfer the APK and install, or use:' \
    '  adb install <file.apk>' \
    '' \
    'Note: Requires Android SDK/NDK, Java, and Gradle properly configured.' \
    > "$dest_dir/README.md"
  log_success "Exported Android APKs to: $dest_dir"
}

# Install and run the built RPM package if successful
install_and_run_rpm() {
  log_info "Checking for built RPM packages..."
  
  # First, cleanup any existing conflicting packages
  cleanup_existing_rpm_packages
  
  local rpm_dir="$BASE_DIR/src-tauri/target/release/bundle/rpm"
  if [ ! -d "$rpm_dir" ]; then
    log_warning "No RPM directory found at $rpm_dir"
    return 0
  fi
  
  local rpm_files
  mapfile -t rpm_files < <(find "$rpm_dir" -name "Dock2Tauri*.rpm" -type f 2>/dev/null)
  
  if [ ${#rpm_files[@]} -eq 0 ]; then
    log_warning "No Dock2Tauri RPM packages found in $rpm_dir"
    return 0
  fi
  
  local rpm_file="${rpm_files[0]}"
  log_success "Found RPM package: $(basename "$rpm_file")"
  
  # Ask user if they want to install and run
  if [ -t 0 ]; then  # Only prompt if running interactively
    echo
    echo -e "${YELLOW}Do you want to install and run the RPM package? [y/N]${NC}"
    read -r response
    case "$response" in
      [yY]|[yY][eE][sS])
        ;;
      *)
        log_info "Skipping RPM installation."
        log_info "To install manually: sudo dnf install \"$rpm_file\""
        return 0
        ;;
    esac
  else
    log_info "Non-interactive mode - skipping automatic RPM installation"
    log_info "To install manually: sudo dnf install \"$rpm_file\""
    return 0
  fi
  
  # Install the RPM
  log_info "Installing RPM package..."
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y --allowerasing "$rpm_file"
  elif command -v rpm >/dev/null 2>&1; then
    sudo rpm -i --force --replacepkgs "$rpm_file"
  else
    log_warning "Neither dnf nor rpm command found - cannot install RPM"
    return 1
  fi
  
  if [ $? -eq 0 ]; then
    log_success "RPM package installed successfully!"
    
    # Try to run the application
    log_info "Attempting to launch Dock2Tauri..."
    if command -v dock2tauri >/dev/null 2>&1; then
      dock2tauri &
      log_success "Dock2Tauri launched! Check your desktop for the application window."
    elif command -v Dock2Tauri >/dev/null 2>&1; then
      Dock2Tauri &
      log_success "Dock2Tauri launched! Check your desktop for the application window."
    else
      log_info "Application installed. You can find Dock2Tauri in your applications menu."
    fi
  else
    log_warning "RPM installation failed"
    return 1
  fi
}

cleanup() {
    log_info "Cleaning up..."
    if [ -n "$CONTAINER_ID" ]; then
        docker stop "$CONTAINER_ID" 2>/dev/null || true
        docker rm "$CONTAINER_ID" 2>/dev/null || true
        log_success "Container stopped and removed"
    fi
    # Remove ephemeral Tauri config
    if [ -n "$TAURI_CONFIG_PATH" ] && [ -f "$TAURI_CONFIG_PATH" ]; then
        rm -f "$TAURI_CONFIG_PATH"
        log_success "Removed ephemeral Tauri config"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🐳🦀 Dock2Tauri - Docker to Desktop Bridge${NC}"
    echo "=================================================="
    
    # Set up cleanup trap
    trap cleanup EXIT INT TERM
    
    check_dependencies
    if $BUILD_RELEASE; then
        generate_tauri_config_json
        build_and_export
    else
        stop_existing_container
        launch_container
        wait_for_service
        generate_tauri_config_json
        # Launch Tauri (this will block until app exits)
        launch_tauri
    fi
}

# Help function
show_help() {
    echo "Dock2Tauri - Docker to Desktop Bridge"
    echo ""
    echo "Usage: $0 <docker-image|Dockerfile> <host-port> <container-port> [--build] [--target=<triple>] [--health-url=<url>] [--timeout=<seconds>] [--cross]"
    echo ""
    echo "Arguments:"
    echo "  IMAGE           Docker image to run OR path to Dockerfile (default: nginx:alpine)"
    echo "  HOST_PORT       Host port to bind to (default: 8088)"
    echo "  CONTAINER_PORT  Container port to expose (default: 80)"
    echo ""
    echo "Options:"
    echo "  --build (-b)        Build Tauri release bundles instead of running 'tauri dev'"
    echo "  --target=<triple>   Pass target triple to 'cargo tauri build'"
    echo "  --health-url=<url>  Override readiness URL (default: http://localhost:HOST_PORT)"
    echo "  --timeout=<seconds> Readiness timeout in seconds (default: 30)"
    echo "  --cross             Attempt best-effort cross-target builds (requires toolchains; may fail without proper setup)"
    echo ""
    echo "Behavior:"
    echo "  - If the first argument is a Dockerfile and --build is NOT provided, the script defaults to building and exporting bundles into dist/."
    echo "  - If Android SDK is detected, the script will attempt to build an Android APK (best-effort)."
    echo "  - On Linux, AppImage will be skipped if linuxdeploy/appimagetool are missing; RPM will be skipped if rpmbuild is missing."
    echo ""
    echo "Examples:"
    echo "  $0 nginx:alpine 8088 80"
    echo "  $0 ./Dockerfile 8088 80"
    echo "  $0 grafana/grafana 3001 3000 --build"
    echo "  $0 jupyter/scipy-notebook 8888 8888 --target=x86_64-pc-windows-gnu"
    echo "  $0 ./examples/pwa-hello/Dockerfile 8088 80 --build --cross"
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

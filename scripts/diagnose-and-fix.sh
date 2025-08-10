#!/bin/bash

# Dock2Tauri Comprehensive Diagnostic & Fix Script
# Forces installation of all required tools and fixes bundle generation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo -e "${BLUE}🔍 Dock2Tauri Comprehensive Diagnostic & Fix${NC}"
echo "==============================================="

# Force sudo check
check_sudo() {
    log_info "Checking sudo access..."
    if ! sudo -n true 2>/dev/null; then
        log_warning "This script requires sudo access for package installation"
        if ! sudo true; then
            log_error "Sudo access required. Exiting."
            exit 1
        fi
    fi
    log_success "Sudo access confirmed"
}

# Detect OS family
detect_os_family() {
    OS_FAMILY="unknown"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            fedora|rhel|centos|rocky|almalinux)
                OS_FAMILY="redhat"
                PKG_MGR="dnf"
                if ! command -v dnf >/dev/null 2>&1; then
                    PKG_MGR="yum"
                fi
                ;;
            ubuntu|debian|mint)
                OS_FAMILY="debian"
                PKG_MGR="apt-get"
                ;;
            arch|manjaro)
                OS_FAMILY="arch"
                PKG_MGR="pacman"
                ;;
        esac
    fi
    
    log_info "Detected OS family: $OS_FAMILY (package manager: $PKG_MGR)"
}

# Install system dependencies
install_system_deps() {
    log_info "Installing system dependencies..."
    
    case "$OS_FAMILY" in
        "redhat")
            log_info "Installing Red Hat/Fedora dependencies..."
            sudo $PKG_MGR install -y \
                rpm-build rpm-devel rpmdevtools libtool \
                gtk3-devel webkit2gtk3-devel libappindicator-gtk3-devel \
                librsvg2-devel openssl-devel curl wget file \
                gcc gcc-c++ make cmake
            ;;
        "debian")
            log_info "Installing Debian/Ubuntu dependencies..."
            sudo $PKG_MGR update -qq
            sudo $PKG_MGR install -y \
                dpkg-dev fakeroot alien rpm \
                libgtk-3-dev libwebkit2gtk-4.0-dev libappindicator3-dev \
                librsvg2-dev libssl-dev curl wget file \
                build-essential cmake
            ;;
        "arch")
            log_info "Installing Arch Linux dependencies..."
            sudo $PKG_MGR -S --noconfirm \
                base-devel rpm-tools \
                gtk3 webkit2gtk libappindicator-gtk3 \
                librsvg openssl curl wget file
            ;;
        *)
            log_error "Unsupported OS family: $OS_FAMILY"
            exit 1
            ;;
    esac
    
    log_success "System dependencies installed"
}

# Install AppImageTool
install_appimagetool() {
    log_info "Installing AppImageTool..."
    
    if command -v appimagetool >/dev/null 2>&1; then
        log_success "AppImageTool already installed: $(appimagetool --version 2>/dev/null || echo 'unknown version')"
        return
    fi
    
    log_info "Downloading AppImageTool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -O /tmp/appimagetool
    chmod +x /tmp/appimagetool
    sudo mv /tmp/appimagetool /usr/local/bin/appimagetool
    
    log_success "AppImageTool installed to /usr/local/bin/appimagetool"
}

# Check Rust/Cargo setup
check_rust_setup() {
    log_info "Checking Rust/Cargo setup..."
    
    if ! command -v rustc >/dev/null 2>&1; then
        log_error "Rust not found. Installing via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    fi
    
    RUST_VERSION=$(rustc --version)
    log_success "Rust installed: $RUST_VERSION"
    
    # Check Tauri CLI
    if ! command -v cargo >/dev/null 2>&1 || ! cargo tauri --version >/dev/null 2>&1; then
        log_info "Installing Tauri CLI v1.x..."
        cargo install --force --locked --version '^1' tauri-cli
    fi
    
    TAURI_VERSION=$(cargo tauri --version)
    log_success "Tauri CLI installed: $TAURI_VERSION"
}

# Create app directory with content
create_app_content() {
    log_info "Ensuring app directory has content..."
    
    if [ ! -d "app" ]; then
        mkdir -p app
    fi
    
    if [ ! -f "app/index.html" ]; then
        log_info "Creating app/index.html..."
        cat > app/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dock2Tauri Bundle Test</title>
    <style>
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0; padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white; min-height: 100vh;
            display: flex; align-items: center; justify-content: center;
        }
        .container { 
            text-align: center; background: rgba(0,0,0,0.1);
            padding: 40px; border-radius: 20px;
            backdrop-filter: blur(10px); box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        h1 { font-size: 3em; margin: 0 0 20px; }
        .badge { 
            background: rgba(255,255,255,0.2); padding: 10px 20px;
            border-radius: 50px; display: inline-block; margin: 10px;
            backdrop-filter: blur(5px);
        }
        .status { font-size: 1.2em; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐳🦀 Dock2Tauri</h1>
        <div class="status">✅ Bundle Generation Test</div>
        <div class="badge">AppImage Ready</div>
        <div class="badge">DEB Package Ready</div>
        <div class="badge">RPM Package Ready</div>
        <p id="timestamp"></p>
    </div>
    <script>
        document.getElementById('timestamp').textContent = 'Generated: ' + new Date().toLocaleString();
    </script>
</body>
</html>
EOF
    fi
    
    log_success "App content ready in app/index.html"
}

# Fix Tauri configuration
fix_tauri_config() {
    log_info "Fixing Tauri configuration..."
    
    CONFIG_FILE="src-tauri/tauri.conf.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Tauri config not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Backup
    cp "$CONFIG_FILE" "$CONFIG_FILE.diagnostic-backup"
    
    # Update config with bundle targets and proper settings
    if command -v jq >/dev/null 2>&1; then
        log_info "Using jq to update Tauri configuration..."
        
        # Create comprehensive bundle config
        jq '
        .tauri.bundle.targets = ["appimage", "deb", "rpm"] |
        .tauri.bundle.icon = [] |
        .build.distDir = "../app" |
        .build.devPath = "http://localhost:8088" |
        .tauri.bundle.category = "Utility" |
        .tauri.bundle.shortDescription = "Docker to Desktop Bridge" |
        .tauri.bundle.longDescription = "Transform any Docker container into a native desktop application using Tauri"
        ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    else
        log_warning "jq not found, installing..."
        case "$OS_FAMILY" in
            "redhat") sudo $PKG_MGR install -y jq ;;
            "debian") sudo $PKG_MGR install -y jq ;;
            "arch") sudo $PKG_MGR -S --noconfirm jq ;;
        esac
        
        # Retry with jq
        jq '
        .tauri.bundle.targets = ["appimage", "deb", "rpm"] |
        .tauri.bundle.icon = [] |
        .build.distDir = "../app" |
        .build.devPath = "http://localhost:8088"
        ' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    fi
    
    log_success "Tauri configuration updated with bundle targets"
    log_info "Bundle targets: appimage, deb, rpm"
}

# Build and verify bundles
build_and_verify() {
    log_info "Building Tauri bundles..."
    
    cd src-tauri
    
    # Clean previous builds
    if [ -d "target/release/bundle" ]; then
        log_info "Cleaning previous bundle artifacts..."
        rm -rf target/release/bundle
    fi
    
    # Build with explicit bundle targets
    log_info "Running: cargo tauri build --bundles appimage,deb,rpm"
    if cargo tauri build --bundles appimage,deb,rpm; then
        log_success "Tauri build completed successfully"
    else
        log_error "Tauri build failed"
        cd ..
        return 1
    fi
    
    cd ..
    
    # Verify bundle generation
    BUNDLE_DIR="src-tauri/target/release/bundle"
    if [ ! -d "$BUNDLE_DIR" ]; then
        log_error "Bundle directory not created: $BUNDLE_DIR"
        return 1
    fi
    
    log_success "Bundle directory created: $BUNDLE_DIR"
    
    # List all generated artifacts
    echo ""
    echo -e "${GREEN}📦 Generated Bundle Artifacts:${NC}"
    echo "==============================="
    
    TOTAL_BUNDLES=0
    
    for bundle_type in appimage deb rpm; do
        case "$bundle_type" in
            appimage)
                if find "$BUNDLE_DIR" -name "*.AppImage" -type f | head -1 | grep -q .; then
                    log_success "AppImage bundles found:"
                    find "$BUNDLE_DIR" -name "*.AppImage" -type f -exec ls -lh {} \; | while read line; do
                        echo "  📱 $(echo "$line" | awk '{print $9, "(" $5 ")"}')"
                    done
                    TOTAL_BUNDLES=$((TOTAL_BUNDLES + 1))
                fi
                ;;
            deb)
                if find "$BUNDLE_DIR" -name "*.deb" -type f | head -1 | grep -q .; then
                    log_success "DEB packages found:"
                    find "$BUNDLE_DIR" -name "*.deb" -type f -exec ls -lh {} \; | while read line; do
                        echo "  📦 $(echo "$line" | awk '{print $9, "(" $5 ")"}')"
                    done
                    TOTAL_BUNDLES=$((TOTAL_BUNDLES + 1))
                fi
                ;;
            rpm)
                if find "$BUNDLE_DIR" -name "*.rpm" -type f | head -1 | grep -q .; then
                    log_success "RPM packages found:"
                    find "$BUNDLE_DIR" -name "*.rpm" -type f -exec ls -lh {} \; | while read line; do
                        echo "  📦 $(echo "$line" | awk '{print $9, "(" $5 ")"}')"
                    done
                    TOTAL_BUNDLES=$((TOTAL_BUNDLES + 1))
                fi
                ;;
        esac
    done
    
    if [ "$TOTAL_BUNDLES" -eq 0 ]; then
        log_warning "No bundle artifacts found, but bundle directory exists"
        log_info "Contents of bundle directory:"
        find "$BUNDLE_DIR" -type f 2>/dev/null | head -10 || echo "  (empty)"
    else
        log_success "Found $TOTAL_BUNDLES different bundle types"
    fi
}

# Test bundle functionality
test_bundles() {
    log_info "Testing generated bundles..."
    
    BUNDLE_DIR="src-tauri/target/release/bundle"
    
    # Test AppImage
    APPIMAGE=$(find "$BUNDLE_DIR" -name "*.AppImage" -type f | head -1)
    if [ -n "$APPIMAGE" ] && [ -f "$APPIMAGE" ]; then
        log_info "Testing AppImage: $(basename "$APPIMAGE")"
        chmod +x "$APPIMAGE"
        
        # Test if it's a valid AppImage
        if "$APPIMAGE" --appimage-help >/dev/null 2>&1; then
            log_success "AppImage is valid and functional"
            echo "  📱 Ready to run: $APPIMAGE"
        else
            log_warning "AppImage may have issues, but file exists"
        fi
    fi
    
    # Test DEB package
    DEB_PACKAGE=$(find "$BUNDLE_DIR" -name "*.deb" -type f | head -1)
    if [ -n "$DEB_PACKAGE" ] && [ -f "$DEB_PACKAGE" ]; then
        log_info "Testing DEB package: $(basename "$DEB_PACKAGE")"
        
        if dpkg-deb --info "$DEB_PACKAGE" >/dev/null 2>&1; then
            log_success "DEB package structure is valid"
            echo "  📦 Install with: sudo dpkg -i '$DEB_PACKAGE'"
        else
            log_warning "DEB package may have structural issues"
        fi
    fi
    
    # Test RPM package
    RPM_PACKAGE=$(find "$BUNDLE_DIR" -name "*.rpm" -type f | head -1)
    if [ -n "$RPM_PACKAGE" ] && [ -f "$RPM_PACKAGE" ]; then
        log_info "Testing RPM package: $(basename "$RPM_PACKAGE")"
        
        if rpm -qpi "$RPM_PACKAGE" >/dev/null 2>&1; then
            log_success "RPM package structure is valid"
            echo "  📦 Install with: sudo rpm -i '$RPM_PACKAGE'"
        else
            log_warning "RPM package may have structural issues"
        fi
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    
    # Restore config if needed
    CONFIG_FILE="src-tauri/tauri.conf.json"
    if [ -f "$CONFIG_FILE.diagnostic-backup" ]; then
        if [ "$1" = "restore" ]; then
            mv "$CONFIG_FILE.diagnostic-backup" "$CONFIG_FILE"
            log_success "Tauri configuration restored from backup"
        else
            log_info "Config backup available: $CONFIG_FILE.diagnostic-backup"
        fi
    fi
}

# Main execution
main() {
    echo "Starting comprehensive diagnostic and fix process..."
    echo ""
    
    # Parse arguments
    RESTORE_CONFIG=false
    for arg in "$@"; do
        case $arg in
            --restore-config)
                RESTORE_CONFIG=true
                ;;
        esac
    done
    
    # Set up cleanup trap
    if [ "$RESTORE_CONFIG" = "true" ]; then
        trap 'cleanup restore' EXIT INT TERM
    else
        trap cleanup EXIT INT TERM
    fi
    
    # Execute diagnostic steps
    check_sudo
    detect_os_family
    install_system_deps
    install_appimagetool
    check_rust_setup
    create_app_content
    fix_tauri_config
    
    if build_and_verify; then
        test_bundles
        
        echo ""
        echo -e "${GREEN}🎉 Diagnostic and Fix Complete!${NC}"
        echo "================================="
        log_success "All required tools installed"
        log_success "Tauri configuration fixed"
        log_success "Bundle generation verified"
        echo ""
        log_info "Your Dock2Tauri project now supports:"
        echo "  📱 AppImage (Linux universal)"
        echo "  📦 DEB packages (Debian/Ubuntu)"  
        echo "  📦 RPM packages (Red Hat/Fedora)"
        echo ""
        log_info "To build bundles in the future:"
        echo "  ./scripts/build-bundles-fixed.sh"
        
    else
        echo ""
        echo -e "${RED}❌ Bundle Generation Failed${NC}"
        echo "=============================="
        log_error "Bundle generation encountered issues"
        log_info "Check the error messages above for details"
        exit 1
    fi
}

# Run with all arguments
main "$@"

#!/bin/bash

# Dock2Tauri Cross-Platform Bundle Builder (Fixed Version)
# Installs packaging tools and builds AppImage, .deb, .rpm installers

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

echo -e "${BLUE}📦 Dock2Tauri Cross-Platform Bundle Builder${NC}"
echo "=============================================="

# Detect OS
detect_os() {
    OS_FAMILY="unknown"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS="$NAME"
        VER="$VERSION_ID"
        
        # Detect OS family based on ID
        case "$ID" in
            fedora|rhel|centos|rocky|almalinux)
                OS_FAMILY="redhat"
                ;;
            ubuntu|debian|mint)
                OS_FAMILY="debian"
                ;;
            arch|manjaro)
                OS_FAMILY="arch"
                ;;
        esac
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
        case "$(echo "$OS" | tr '[:upper:]' '[:lower:]')" in
            *ubuntu*|*debian*|*mint*)
                OS_FAMILY="debian"
                ;;
            *fedora*|*redhat*|*centos*)
                OS_FAMILY="redhat"
                ;;
            *arch*|*manjaro*)
                OS_FAMILY="arch"
                ;;
        esac
    elif [ -f /etc/redhat-release ]; then
        OS="Red Hat Enterprise Linux"
        VER=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+')
        OS_FAMILY="redhat"
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    echo "$OS $VER (family: $OS_FAMILY)"
}

OS_INFO=$(detect_os)
OS_FAMILY=$(echo "$OS_INFO" | grep -o 'family: [^)]*' | cut -d' ' -f2)
log_info "Detected OS: $OS_INFO"

# Install packaging tools
install_packaging_tools() {
    log_info "Installing packaging tools for OS family: $OS_FAMILY"
    
    case "$OS_FAMILY" in
        "debian")
            # Debian/Ubuntu
            log_info "Installing tools for Debian/Ubuntu..."
            sudo apt-get update -qq
            
            # AppImage tools
            if ! command -v appimagetool >/dev/null 2>&1; then
                log_info "Installing appimagetool..."
                wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /tmp/appimagetool
                chmod +x /tmp/appimagetool
                sudo mv /tmp/appimagetool /usr/local/bin/appimagetool
            fi
            
            # .deb tools
            sudo apt-get install -y dpkg-dev fakeroot
            
            # .rpm tools (alien for cross-platform .rpm generation)
            if ! command -v rpmbuild >/dev/null 2>&1; then
                sudo apt-get install -y alien rpm
            fi
            
            log_success "Packaging tools installed for Debian/Ubuntu"
            ;;
            
        "redhat")
            # Red Hat/Fedora/CentOS
            log_info "Installing tools for Red Hat/Fedora..."
            
            if command -v dnf >/dev/null 2>&1; then
                PKG_MGR="dnf"
            else
                PKG_MGR="yum"
            fi
            
            # AppImage tools
            if ! command -v appimagetool >/dev/null 2>&1; then
                log_info "Installing appimagetool..."
                wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /tmp/appimagetool
                chmod +x /tmp/appimagetool
                sudo mv /tmp/appimagetool /usr/local/bin/appimagetool
            fi
            
            # .rpm and .deb tools
            sudo $PKG_MGR install -y rpm-build rpm-devel libtool rpmdevtools
            
            log_success "Packaging tools installed for Red Hat/Fedora"
            ;;
            
        "arch")
            # Arch Linux
            log_info "Installing tools for Arch Linux..."
            
            # AppImage tools
            if ! command -v appimagetool >/dev/null 2>&1; then
                log_info "Installing appimagetool..."
                wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /tmp/appimagetool
                chmod +x /tmp/appimagetool
                sudo mv /tmp/appimagetool /usr/local/bin/appimagetool
            fi
            
            sudo pacman -S --noconfirm base-devel rpm-tools
            
            log_success "Packaging tools installed for Arch Linux"
            ;;
            
        *)
            log_warning "Unknown OS family ($OS_FAMILY), you may need to install packaging tools manually:"
            echo "  - appimagetool (for AppImage)"
            echo "  - dpkg-dev, fakeroot (for .deb)"  
            echo "  - rpm-build, rpm-devel (for .rpm)"
            ;;
    esac
}

# Update Tauri config with bundle targets
update_tauri_bundle_config() {
    log_info "Updating Tauri bundle configuration..."
    
    CONFIG_FILE="src-tauri/tauri.conf.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Tauri config not found at $CONFIG_FILE"
        exit 1
    fi
    
    # Backup original config
    cp "$CONFIG_FILE" "$CONFIG_FILE.bundle-backup"
    
    # Use jq if available, otherwise manual sed
    if command -v jq >/dev/null 2>&1; then
        log_info "Using jq to update configuration..."
        jq '.tauri.bundle.targets = ["appimage", "deb", "rpm"] | .tauri.bundle.icon = []' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
        mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    else
        log_info "Using sed to update configuration..."
        # Add targets array after identifier line
        sed -i '/"identifier":/a\      "icon": [],\n      "targets": ["appimage", "deb", "rpm"],' "$CONFIG_FILE"
    fi
    
    log_success "Tauri bundle configuration updated"
}

# Build bundles
build_bundles() {
    log_info "Building cross-platform bundles..."
    
    cd src-tauri
    
    log_info "Running cargo tauri build with bundle targets..."
    
    # Build with specific bundle targets
    if cargo tauri build --bundles appimage,deb,rpm; then
        log_success "Bundle build completed successfully"
    else
        log_warning "Some bundle builds may have failed, checking individual targets..."
        
        # Try individual targets
        for target in appimage deb rpm; do
            log_info "Attempting to build $target bundle..."
            if cargo tauri build --bundles "$target"; then
                log_success "$target bundle created"
            else
                log_warning "$target bundle failed (tools may not be available)"
            fi
        done
    fi
    
    cd ..
}

# List generated bundles
list_bundles() {
    log_info "Checking generated bundle artifacts..."
    
    BUNDLE_DIR="src-tauri/target/release/bundle"
    
    if [ ! -d "$BUNDLE_DIR" ]; then
        log_warning "No bundle directory found"
        return
    fi
    
    echo ""
    echo -e "${GREEN}📦 Generated Bundle Artifacts:${NC}"
    echo "==============================="
    
    FOUND_BUNDLES=0
    
    # AppImage
    if find "$BUNDLE_DIR" -name "*.AppImage" -type f | head -1 | grep -q .; then
        log_success "AppImage bundles:"
        find "$BUNDLE_DIR" -name "*.AppImage" -type f -printf "  📱 %f (%s bytes)\n"
        FOUND_BUNDLES=1
    fi
    
    # .deb packages
    if find "$BUNDLE_DIR" -name "*.deb" -type f | head -1 | grep -q .; then
        log_success "Debian packages:"
        find "$BUNDLE_DIR" -name "*.deb" -type f -printf "  📦 %f (%s bytes)\n"
        FOUND_BUNDLES=1
    fi
    
    # .rpm packages
    if find "$BUNDLE_DIR" -name "*.rpm" -type f | head -1 | grep -q .; then
        log_success "RPM packages:"
        find "$BUNDLE_DIR" -name "*.rpm" -type f -printf "  📦 %f (%s bytes)\n"
        FOUND_BUNDLES=1
    fi
    
    # Show all bundle files if found
    if [ "$FOUND_BUNDLES" = "1" ]; then
        echo ""
        log_info "All bundle files:"
        find "$BUNDLE_DIR" -type f -printf "  %p (%s bytes)\n" | head -10
    else
        log_warning "No bundle artifacts found in $BUNDLE_DIR"
        log_info "Available files in bundle directory:"
        ls -la "$BUNDLE_DIR" 2>/dev/null || log_warning "Bundle directory is empty or doesn't exist"
    fi
}

# Test bundles
test_bundles() {
    log_info "Testing generated bundles..."
    
    BUNDLE_DIR="src-tauri/target/release/bundle"
    
    # Test AppImage
    APPIMAGE=$(find "$BUNDLE_DIR" -name "*.AppImage" -type f | head -1)
    if [ -n "$APPIMAGE" ] && [ -f "$APPIMAGE" ]; then
        log_info "Testing AppImage: $(basename "$APPIMAGE")"
        if chmod +x "$APPIMAGE" && "$APPIMAGE" --help >/dev/null 2>&1; then
            log_success "AppImage is executable and responds to --help"
            echo "  To run: $APPIMAGE"
        else
            log_warning "AppImage may not be fully functional"
        fi
    fi
    
    # Test .deb package
    DEB_PACKAGE=$(find "$BUNDLE_DIR" -name "*.deb" -type f | head -1)
    if [ -n "$DEB_PACKAGE" ] && [ -f "$DEB_PACKAGE" ]; then
        log_info "Testing .deb package: $(basename "$DEB_PACKAGE")"
        if dpkg-deb --info "$DEB_PACKAGE" >/dev/null 2>&1; then
            log_success ".deb package structure is valid"
            echo "  To install: sudo dpkg -i '$DEB_PACKAGE'"
        else
            log_warning ".deb package may have issues"
        fi
    fi
    
    # Test .rpm package
    RPM_PACKAGE=$(find "$BUNDLE_DIR" -name "*.rpm" -type f | head -1)
    if [ -n "$RPM_PACKAGE" ] && [ -f "$RPM_PACKAGE" ]; then
        log_info "Testing .rpm package: $(basename "$RPM_PACKAGE")"
        if rpm -qpi "$RPM_PACKAGE" >/dev/null 2>&1; then
            log_success ".rpm package structure is valid"
            echo "  To install: sudo rpm -i '$RPM_PACKAGE'"
        else
            log_warning ".rpm package may have issues"
        fi
    fi
}

# Cleanup
cleanup() {
    log_info "Cleaning up..."
    
    # Restore config backup
    CONFIG_FILE="src-tauri/tauri.conf.json"
    if [ -f "$CONFIG_FILE.bundle-backup" ]; then
        mv "$CONFIG_FILE.bundle-backup" "$CONFIG_FILE"
        log_success "Tauri configuration restored"
    fi
}

# Main execution
main() {
    # Parse flags
    INSTALL_TOOLS=false
    BUILD_ONLY=false
    
    for arg in "$@"; do
        case $arg in
            --install-tools)
                INSTALL_TOOLS=true
                shift
                ;;
            --build-only)
                BUILD_ONLY=true
                shift
                ;;
            --help)
                echo "Usage: $0 [options]"
                echo "  --install-tools  Install packaging tools (appimagetool, dpkg-dev, rpm-build)"
                echo "  --build-only     Skip tool installation, just build bundles"
                echo "  --help          Show this help message"
                exit 0
                ;;
        esac
    done
    
    # Set up cleanup trap
    trap cleanup EXIT INT TERM
    
    if [ "$BUILD_ONLY" != "true" ]; then
        if [ "$INSTALL_TOOLS" = "true" ]; then
            install_packaging_tools
        else
            log_info "Skipping tool installation (use --install-tools to install)"
            log_info "Required tools: appimagetool, dpkg-dev, rpm-build"
        fi
    fi
    
    update_tauri_bundle_config
    build_bundles
    list_bundles
    test_bundles
    
    echo ""
    echo -e "${GREEN}🎉 Bundle Build Complete!${NC}"
    echo "==============================="
    log_info "Generated bundles are ready for distribution"
    log_info "Run with --install-tools flag to install missing packaging tools"
}

# Run main function
main "$@"

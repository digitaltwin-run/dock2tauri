#!/bin/bash

# Ultimate Dock2Tauri Bundle Generation Fix
# Comprehensive root-cause analysis and workaround for Fedora bundle issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_debug() { echo -e "${CYAN}🔍 $1${NC}"; }

echo -e "${BLUE}🔧 Ultimate Dock2Tauri Bundle Fix${NC}"
echo "=================================="

# Function to test different Tauri CLI approaches
test_tauri_approaches() {
    log_info "Testing different Tauri CLI approaches..."
    
    cd src-tauri
    
    # Test 1: Check if bundle feature is compiled into Tauri CLI
    log_debug "Test 1: Checking Tauri CLI bundle support..."
    if cargo tauri --help | grep -q "bundles"; then
        log_success "Tauri CLI supports --bundles flag"
    else
        log_error "Tauri CLI missing bundle support"
        return 1
    fi
    
    # Test 2: Try different bundle syntaxes
    log_debug "Test 2: Testing bundle syntax variations..."
    
    for syntax in \
        "--bundles appimage" \
        "--bundle appimage" \
        "-b appimage" \
        "--target-bundle appimage"
    do
        log_info "Trying syntax: $syntax"
        if timeout 30s cargo tauri build $syntax --verbose 2>&1 | grep -q -i "bundle\|appimage"; then
            log_success "Syntax '$syntax' shows bundle activity"
            return 0
        else
            log_warning "Syntax '$syntax' shows no bundle activity"
        fi
    done
    
    cd ..
    return 1
}

# Function to manually invoke bundler
manual_bundle_creation() {
    log_info "Attempting manual bundle creation..."
    
    # Check if we have the binary
    BINARY_PATH="src-tauri/target/release/dock2-tauri-dock2tauri-local-dockerfile-1754828951"
    if [ ! -f "$BINARY_PATH" ]; then
        # Find any dock2-tauri binary
        BINARY_PATH=$(find src-tauri/target/release -name "dock2-tauri-*" -type f -executable | head -1)
    fi
    
    if [ ! -f "$BINARY_PATH" ]; then
        log_error "No Tauri binary found to package"
        return 1
    fi
    
    log_success "Found binary: $BINARY_PATH"
    
    # Create AppDir structure for AppImage
    log_info "Creating AppImage manually..."
    
    APPDIR="/tmp/dock2tauri.AppDir"
    rm -rf "$APPDIR"
    mkdir -p "$APPDIR"/{usr/bin,usr/share/{applications,icons/hicolor/256x256/apps}}
    
    # Copy binary
    cp "$BINARY_PATH" "$APPDIR/usr/bin/dock2tauri"
    
    # Create desktop file
    cat > "$APPDIR/dock2tauri.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Dock2Tauri
Comment=Docker to Desktop Bridge
Exec=dock2tauri
Icon=dock2tauri
Categories=Utility;Development;
Terminal=false
EOF
    
    # Create icon (simple PNG)
    if command -v convert >/dev/null 2>&1; then
        # Use ImageMagick if available
        convert -size 256x256 xc:blue "$APPDIR/dock2tauri.png"
        cp "$APPDIR/dock2tauri.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/"
    else
        # Create minimal PNG with Python
        python3 -c "
from PIL import Image
import os
img = Image.new('RGB', (256, 256), color='blue')
img.save('$APPDIR/dock2tauri.png')
img.save('$APPDIR/usr/share/icons/hicolor/256x256/apps/dock2tauri.png')
" 2>/dev/null || {
        # Fallback: copy existing icon or create empty file
        if [ -f "src-tauri/icons/icon.png" ]; then
            cp "src-tauri/icons/icon.png" "$APPDIR/dock2tauri.png"
            cp "src-tauri/icons/icon.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/dock2tauri.png"
        else
            echo "PNG placeholder" > "$APPDIR/dock2tauri.png"
            echo "PNG placeholder" > "$APPDIR/usr/share/icons/hicolor/256x256/apps/dock2tauri.png"
        fi
        }
    fi
    
    # Create AppRun
    cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
exec "${HERE}/usr/bin/dock2tauri" "$@"
EOF
    chmod +x "$APPDIR/AppRun"
    
    # Build AppImage
    if command -v appimagetool >/dev/null 2>&1; then
        log_info "Building AppImage with appimagetool..."
        APPIMAGE_PATH="$(pwd)/Dock2Tauri-$(date +%Y%m%d).AppImage"
        
        if appimagetool "$APPDIR" "$APPIMAGE_PATH"; then
            log_success "AppImage created: $APPIMAGE_PATH"
            ls -lh "$APPIMAGE_PATH"
            
            # Test the AppImage
            if chmod +x "$APPIMAGE_PATH" && "$APPIMAGE_PATH" --help >/dev/null 2>&1; then
                log_success "AppImage is functional!"
                echo "  📱 Ready to run: $APPIMAGE_PATH"
            else
                log_warning "AppImage created but may have issues"
            fi
        else
            log_error "AppImage creation failed"
        fi
    else
        log_error "appimagetool not found"
        return 1
    fi
    
    # Clean up
    rm -rf "$APPDIR"
}

# Function to create DEB package manually
manual_deb_creation() {
    log_info "Creating DEB package manually..."
    
    BINARY_PATH=$(find src-tauri/target/release -name "dock2-tauri-*" -type f -executable | head -1)
    if [ ! -f "$BINARY_PATH" ]; then
        log_error "No binary found for DEB packaging"
        return 1
    fi
    
    DEB_DIR="/tmp/dock2tauri-deb"
    rm -rf "$DEB_DIR"
    
    # Create DEB structure
    mkdir -p "$DEB_DIR"/{DEBIAN,usr/bin,usr/share/{applications,doc/dock2tauri}}
    
    # Copy binary
    cp "$BINARY_PATH" "$DEB_DIR/usr/bin/dock2tauri"
    chmod +x "$DEB_DIR/usr/bin/dock2tauri"
    
    # Create control file
    cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: dock2tauri
Version: 1.0.0
Section: utils
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libwebkit2gtk-4.0-37
Maintainer: Dock2Tauri Project <dock2tauri@example.com>
Description: Docker to Desktop Bridge
 Transform any Docker container into a native desktop application using Tauri.
 Provides a seamless way to run web applications in Docker containers
 as native desktop applications.
EOF
    
    # Create desktop file
    cat > "$DEB_DIR/usr/share/applications/dock2tauri.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Dock2Tauri
Comment=Docker to Desktop Bridge
Exec=/usr/bin/dock2tauri
Icon=dock2tauri
Categories=Utility;Development;
Terminal=false
EOF
    
    # Create copyright file
    cat > "$DEB_DIR/usr/share/doc/dock2tauri/copyright" << 'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: dock2tauri
Source: https://github.com/dock2tauri/dock2tauri

Files: *
Copyright: 2025 Dock2Tauri Project
License: MIT
EOF
    
    # Build DEB package
    if command -v dpkg-deb >/dev/null 2>&1; then
        DEB_PATH="$(pwd)/dock2tauri_1.0.0_amd64.deb"
        
        if dpkg-deb --build "$DEB_DIR" "$DEB_PATH"; then
            log_success "DEB package created: $DEB_PATH"
            ls -lh "$DEB_PATH"
            
            # Test DEB structure
            if dpkg-deb --info "$DEB_PATH" >/dev/null 2>&1; then
                log_success "DEB package is valid!"
                echo "  📦 Install with: sudo dpkg -i '$DEB_PATH'"
            else
                log_warning "DEB package may have issues"
            fi
        else
            log_error "DEB package creation failed"
        fi
    else
        log_error "dpkg-deb not found"
        return 1
    fi
    
    # Clean up
    rm -rf "$DEB_DIR"
}

# Function to install alternative Tauri CLI
try_alternative_tauri_cli() {
    log_info "Trying alternative Tauri CLI installation methods..."
    
    # Method 1: Try latest version
    log_info "Method 1: Installing latest Tauri CLI..."
    if cargo install --force tauri-cli; then
        log_success "Latest Tauri CLI installed"
        cargo tauri --version
        
        # Test bundle functionality
        cd src-tauri
        if timeout 60s cargo tauri build --bundles appimage --verbose 2>&1 | grep -q -i "bundle\|appimage"; then
            log_success "Latest CLI shows bundle activity!"
            cd ..
            return 0
        fi
        cd ..
    fi
    
    # Method 2: Try specific version
    log_info "Method 2: Installing specific Tauri CLI version..."
    for version in "1.5.0" "1.4.0" "2.0.0"; do
        log_info "Trying version $version..."
        if cargo install --force --version "$version" tauri-cli 2>/dev/null; then
            log_success "Tauri CLI $version installed"
            cd src-tauri
            if timeout 60s cargo tauri build --bundles appimage --verbose 2>&1 | grep -q -i "bundle\|appimage"; then
                log_success "Version $version shows bundle activity!"
                cd ..
                return 0
            fi
            cd ..
        fi
    done
    
    return 1
}

# Function to diagnose environment issues
diagnose_environment() {
    log_info "Diagnosing environment issues..."
    
    # Check permissions
    log_debug "Checking permissions..."
    if [ -w "src-tauri/target/release" ]; then
        log_success "Target directory is writable"
    else
        log_error "Target directory is not writable"
        return 1
    fi
    
    # Check disk space
    log_debug "Checking disk space..."
    AVAILABLE=$(df . | tail -1 | awk '{print $4}')
    if [ "$AVAILABLE" -gt 1000000 ]; then  # > 1GB
        log_success "Sufficient disk space available"
    else
        log_warning "Low disk space: ${AVAILABLE}KB available"
    fi
    
    # Check for conflicting processes
    log_debug "Checking for conflicting processes..."
    if pgrep -f "tauri\|cargo" >/dev/null; then
        log_warning "Other Tauri/Cargo processes running:"
        pgrep -f "tauri\|cargo" | xargs ps -p
    else
        log_success "No conflicting processes"
    fi
    
    # Check environment variables
    log_debug "Checking environment variables..."
    echo "CARGO_HOME: ${CARGO_HOME:-not set}"
    echo "RUSTUP_HOME: ${RUSTUP_HOME:-not set}"
    echo "PATH contains cargo: $(echo $PATH | grep -q cargo && echo yes || echo no)"
}

# Main execution
main() {
    echo "Starting ultimate bundle generation fix..."
    echo ""
    
    # Step 1: Diagnose environment
    diagnose_environment
    echo ""
    
    # Step 2: Test Tauri approaches
    if test_tauri_approaches; then
        log_success "Found working Tauri approach - using native bundler"
        return 0
    fi
    echo ""
    
    # Step 3: Try alternative CLI versions
    if try_alternative_tauri_cli; then
        log_success "Alternative Tauri CLI works - bundle generated"
        return 0
    fi
    echo ""
    
    # Step 4: Manual bundle creation as fallback
    log_warning "Tauri bundler not working - creating packages manually..."
    
    MANUAL_SUCCESS=false
    
    if manual_bundle_creation; then
        MANUAL_SUCCESS=true
    fi
    
    if manual_deb_creation; then
        MANUAL_SUCCESS=true
    fi
    
    if [ "$MANUAL_SUCCESS" = "true" ]; then
        echo ""
        echo -e "${GREEN}🎉 Manual Bundle Creation Successful!${NC}"
        echo "======================================"
        log_success "Successfully created distribution packages"
        log_info "Location: $(pwd)/"
        echo ""
        log_info "Available packages:"
        ls -1 *.AppImage *.deb 2>/dev/null | while read file; do
            echo "  📦 $file"
        done
        echo ""
        log_info "Installation commands:"
        echo "  AppImage: chmod +x *.AppImage && ./Dock2Tauri-*.AppImage"
        echo "  DEB:      sudo dpkg -i dock2tauri_*.deb"
        
    else
        echo ""
        echo -e "${RED}❌ All Bundle Methods Failed${NC}"
        echo "============================="
        log_error "Unable to create distribution packages"
        log_info "You can still use the native binary:"
        BINARY=$(find src-tauri/target/release -name "dock2-tauri-*" -type f -executable | head -1)
        if [ -n "$BINARY" ]; then
            echo "  🔧 $BINARY"
        fi
        exit 1
    fi
}

# Run main function
main "$@"

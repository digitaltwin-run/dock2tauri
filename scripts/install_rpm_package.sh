#!/usr/bin/env bash
# RPM Package Installer with Conflict Resolution
# Automatically removes old dock2tauri packages and installs new one

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_ok()    { echo -e "${GREEN}✅ $*${NC}"; }
log_warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_err()   { echo -e "${RED}❌ $*${NC}"; }

usage() {
    cat <<EOF
Usage: $0 <rpm-package-path>

Automatically resolves dock2tauri RPM package conflicts by:
1. Removing all existing dock2tauri packages
2. Installing the new package

Example:
  $0 /path/to/Dock2Tauri-new-package.rpm
EOF
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            log_err "This script requires sudo or root privileges"
            exit 1
        fi
    fi
}

remove_existing_packages() {
    log_info "Checking for existing dock2tauri packages..."
    
    local existing_packages
    existing_packages=$(rpm -qa | grep dock2 || true)
    
    if [ -z "$existing_packages" ]; then
        log_ok "No existing dock2tauri packages found"
        return 0
    fi
    
    log_warn "Found existing packages:"
    echo "$existing_packages" | while read -r pkg; do
        echo "  - $pkg"
    done
    
    log_info "Removing existing packages..."
    
    # Try normal removal first
    if echo "$existing_packages" | xargs sudo rpm -e 2>/dev/null; then
        log_ok "Successfully removed existing packages"
    else
        log_warn "Normal removal failed, trying with --nodeps..."
        if echo "$existing_packages" | xargs sudo rpm -e --nodeps 2>/dev/null; then
            log_ok "Successfully removed existing packages (with --nodeps)"
        else
            log_err "Failed to remove existing packages"
            log_info "You may need to remove them manually:"
            echo "$existing_packages" | while read -r pkg; do
                echo "  sudo rpm -e --force --nodeps '$pkg'"
            done
            return 1
        fi
    fi
}

install_new_package() {
    local package_path="$1"
    
    if [ ! -f "$package_path" ]; then
        log_err "Package file not found: $package_path"
        return 1
    fi
    
    log_info "Installing new package: $(basename "$package_path")"
    
    if sudo rpm -i "$package_path"; then
        log_ok "Successfully installed new package"
    else
        log_warn "Normal installation failed, trying with --force..."
        if sudo rpm -i --force "$package_path"; then
            log_ok "Successfully installed new package (with --force)"
        else
            log_err "Failed to install new package"
            return 1
        fi
    fi
}

verify_installation() {
    log_info "Verifying installation..."
    
    local installed_packages
    installed_packages=$(rpm -qa | grep dock2 || true)
    
    if [ -z "$installed_packages" ]; then
        log_err "No dock2tauri packages found after installation"
        return 1
    fi
    
    log_ok "Installed packages:"
    echo "$installed_packages" | while read -r pkg; do
        echo "  - $pkg"
    done
    
    # Check if binary exists and is executable
    if [ -x "/usr/bin/my-tauri-app" ]; then
        log_ok "Binary installed and executable: /usr/bin/my-tauri-app"
    else
        log_warn "Binary not found or not executable: /usr/bin/my-tauri-app"
    fi
}

main() {
    if [ $# -ne 1 ]; then
        usage
    fi
    
    local package_path="$1"
    
    log_info "Dock2Tauri RPM Package Installer with Conflict Resolution"
    log_info "Package: $package_path"
    
    check_root
    remove_existing_packages
    install_new_package "$package_path"
    verify_installation
    
    log_ok "Package installation completed successfully!"
}

main "$@"

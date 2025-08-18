#!/bin/bash

# Dock2Tauri Application Runner
# Detects OS, finds built packages, and launches the application

set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_DIR="$BASE_DIR/src-tauri/target/release/bundle"
DIST_DIR="$BASE_DIR/dist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_success() { echo -e "${GREEN}✅ $*${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_error() { echo -e "${RED}❌ $*${NC}"; }

# Detect OS and package manager
detect_os() {
  local os_id=""
  if [ -r /etc/os-release ]; then
    . /etc/os-release
    os_id="${ID:-}"
  fi
  
  case "$os_id" in
    fedora|rhel|centos|rocky|alma)
      echo "rpm"
      ;;
    debian|ubuntu|linuxmint|pop)
      echo "deb"
      ;;
    arch|manjaro|endeavouros)
      echo "pacman"
      ;;
    opensuse*|sle*)
      echo "zypper"
      ;;
    *)
      # Fallback detection
      if command -v dnf >/dev/null 2>&1; then
        echo "rpm"
      elif command -v apt >/dev/null 2>&1; then
        echo "deb"
      elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
      elif command -v zypper >/dev/null 2>&1; then
        echo "zypper"
      else
        echo "unknown"
      fi
      ;;
  esac
}

# Open file manager to show package location
open_package_location() {
  local package_path="$1"
  local package_dir
  package_dir="$(dirname "$package_path")"
  
  log_info "Opening file manager at: $package_dir"
  
  # Try different file managers
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$package_dir" &
  elif command -v nautilus >/dev/null 2>&1; then
    nautilus "$package_dir" &
  elif command -v thunar >/dev/null 2>&1; then
    thunar "$package_dir" &
  elif command -v dolphin >/dev/null 2>&1; then
    dolphin "$package_dir" &
  elif command -v pcmanfm >/dev/null 2>&1; then
    pcmanfm "$package_dir" &
  else
    log_warning "No file manager found. Package location: $package_dir"
  fi
}

# Find and run RPM package
run_rpm_package() {
  local rpm_files
  mapfile -t rpm_files < <(find "$BUNDLE_DIR/rpm" -name "*.rpm" -type f 2>/dev/null | sort -V | tail -1)
  
  if [ ${#rpm_files[@]} -eq 0 ]; then
    log_error "No RPM packages found in $BUNDLE_DIR/rpm"
    return 1
  fi
  
  local rpm_file="${rpm_files[0]}"
  log_success "Found RPM package: $(basename "$rpm_file")"
  
  # Open file manager
  open_package_location "$rpm_file"
  
  # Check if already installed
  local package_name
  package_name=$(rpm -qp --queryformat '%{NAME}' "$rpm_file" 2>/dev/null || echo "unknown")
  
  if rpm -q "$package_name" >/dev/null 2>&1; then
    log_info "Package already installed. Launching application..."
    # Try to find and run the installed application
    if command -v dock2tauri >/dev/null 2>&1; then
      dock2tauri &
      log_success "Dock2Tauri launched!"
    elif command -v Dock2Tauri >/dev/null 2>&1; then
      Dock2Tauri &
      log_success "Dock2Tauri launched!"
    else
      log_info "Application installed. Check your applications menu for Dock2Tauri."
    fi
  else
    # Install and run
    echo
    echo -e "${YELLOW}Package not installed. Install and run? [Y/n]${NC}"
    read -r response
    case "$response" in
      [nN]|[nN][oO])
        log_info "Skipping installation. You can install manually:"
        echo "  sudo dnf install '$rpm_file'"
        return 0
        ;;
    esac
    
    log_info "Installing RPM package..."
    if command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y "$rpm_file"
    elif command -v rpm >/dev/null 2>&1; then
      sudo rpm -i "$rpm_file"
    else
      log_error "Neither dnf nor rpm command found"
      return 1
    fi
    
    # Launch after installation
    if command -v dock2tauri >/dev/null 2>&1; then
      dock2tauri &
      log_success "Dock2Tauri installed and launched!"
    elif command -v Dock2Tauri >/dev/null 2>&1; then
      Dock2Tauri &
      log_success "Dock2Tauri installed and launched!"
    else
      log_info "Application installed. Check your applications menu for Dock2Tauri."
    fi
  fi
}

# Find and run DEB package
run_deb_package() {
  local deb_files
  mapfile -t deb_files < <(find "$BUNDLE_DIR/deb" -name "*.deb" -type f 2>/dev/null | sort -V | tail -1)
  
  if [ ${#deb_files[@]} -eq 0 ]; then
    log_error "No DEB packages found in $BUNDLE_DIR/deb"
    return 1
  fi
  
  local deb_file="${deb_files[0]}"
  log_success "Found DEB package: $(basename "$deb_file")"
  
  # Open file manager
  open_package_location "$deb_file"
  
  # Check if already installed
  local package_name
  package_name=$(dpkg-deb -f "$deb_file" Package 2>/dev/null || echo "unknown")
  
  if dpkg -s "$package_name" >/dev/null 2>&1; then
    log_info "Package already installed. Launching application..."
    if command -v dock2tauri >/dev/null 2>&1; then
      dock2tauri &
      log_success "Dock2Tauri launched!"
    elif command -v Dock2Tauri >/dev/null 2>&1; then
      Dock2Tauri &
      log_success "Dock2Tauri launched!"
    else
      log_info "Application installed. Check your applications menu for Dock2Tauri."
    fi
  else
    # Install and run
    echo
    echo -e "${YELLOW}Package not installed. Install and run? [Y/n]${NC}"
    read -r response
    case "$response" in
      [nN]|[nN][oO])
        log_info "Skipping installation. You can install manually:"
        echo "  sudo apt install '$deb_file'"
        return 0
        ;;
    esac
    
    log_info "Installing DEB package..."
    if command -v apt >/dev/null 2>&1; then
      sudo apt install -y "$deb_file"
    elif command -v dpkg >/dev/null 2>&1; then
      sudo dpkg -i "$deb_file" || sudo apt install -f -y
    else
      log_error "Neither apt nor dpkg command found"
      return 1
    fi
    
    # Launch after installation
    if command -v dock2tauri >/dev/null 2>&1; then
      dock2tauri &
      log_success "Dock2Tauri installed and launched!"
    elif command -v Dock2Tauri >/dev/null 2>&1; then
      Dock2Tauri &
      log_success "Dock2Tauri installed and launched!"
    else
      log_info "Application installed. Check your applications menu for Dock2Tauri."
    fi
  fi
}

# Find and run AppImage
run_appimage() {
  local appimage_files
  mapfile -t appimage_files < <(find "$BUNDLE_DIR/appimage" -name "*.AppImage" -type f 2>/dev/null | sort -V | tail -1)
  
  if [ ${#appimage_files[@]} -eq 0 ]; then
    log_error "No AppImage files found in $BUNDLE_DIR/appimage"
    return 1
  fi
  
  local appimage_file="${appimage_files[0]}"
  log_success "Found AppImage: $(basename "$appimage_file")"
  
  # Open file manager
  open_package_location "$appimage_file"
  
  # Make executable and run
  chmod +x "$appimage_file"
  log_info "Launching AppImage..."
  "$appimage_file" &
  log_success "Dock2Tauri launched!"
}

# Main function
main() {
  echo -e "${BLUE}🚀 Dock2Tauri Application Runner${NC}"
  echo "=================================="
  
  # Check if bundles exist
  if [ ! -d "$BUNDLE_DIR" ]; then
    log_error "No build artifacts found at $BUNDLE_DIR"
    log_info "Please run: make build"
    exit 1
  fi
  
  # Detect OS
  local os_type
  os_type=$(detect_os)
  log_info "Detected system: $os_type"
  
  # Try to run based on OS type
  case "$os_type" in
    rpm)
      if run_rpm_package; then
        exit 0
      fi
      ;;
    deb)
      if run_deb_package; then
        exit 0
      fi
      ;;
    pacman|zypper)
      log_warning "Native package support for $os_type not implemented yet"
      log_info "Trying AppImage..."
      if run_appimage; then
        exit 0
      fi
      ;;
    unknown)
      log_warning "Unknown package manager"
      log_info "Trying AppImage..."
      if run_appimage; then
        exit 0
      fi
      ;;
  esac
  
  # Fallback - try all formats
  log_warning "Trying all available package formats..."
  
  if [ -d "$BUNDLE_DIR/appimage" ] && run_appimage; then
    exit 0
  elif [ -d "$BUNDLE_DIR/rpm" ] && run_rpm_package; then
    exit 0
  elif [ -d "$BUNDLE_DIR/deb" ] && run_deb_package; then
    exit 0
  fi
  
  log_error "No suitable package found or installation failed"
  log_info "Available bundles:"
  find "$BUNDLE_DIR" -name "*.rpm" -o -name "*.deb" -o -name "*.AppImage" 2>/dev/null | sed 's/^/  /'
  exit 1
}

# Show help
show_help() {
  echo "Dock2Tauri Application Runner"
  echo ""
  echo "Usage: $0 [--help]"
  echo ""
  echo "Automatically detects your OS and runs the appropriate Dock2Tauri package:"
  echo "  - RPM (Fedora/RHEL/CentOS)"
  echo "  - DEB (Debian/Ubuntu)"
  echo "  - AppImage (fallback)"
  echo ""
  echo "The script will:"
  echo "  1. Find the latest built package"
  echo "  2. Open file manager to show package location"
  echo "  3. Install package if needed (asks for confirmation)"
  echo "  4. Launch the application"
  echo ""
}

# Parse arguments
case "${1:-}" in
  -h|--help)
    show_help
    exit 0
    ;;
esac

# Run main function
main "$@"

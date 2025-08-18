#!/usr/bin/env bash
# Install system dependencies for Dock2Tauri bundling on Linux
# - Installs tools needed to build .deb and .rpm bundles
# - Optionally installs AppImage tooling (linuxdeploy, appimagetool)
# - Optionally installs cross-compile toolchain for aarch64 (ARM64)
#
# Usage:
#   scripts/install_deps.sh [--with-appimage] [--arm64] [--yes] [--dry-run]
#
# Notes:
# - This script uses sudo for system package installs when necessary.
# - --dry-run prints the actions without executing them.
# - AppImage tooling is optional; in many environments AppImage build fails without FUSE.

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

dry_run=0
with_appimage=0
with_arm64=0
auto_yes=0

log_info()  { echo -e "${BLUE}ℹ️  $*${NC}"; }
log_ok()    { echo -e "${GREEN}✅ $*${NC}"; }
log_warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_err()   { echo -e "${RED}❌ $*${NC}"; }

run() {
  if [ "$dry_run" -eq 1 ]; then
    echo "+ $*"
  else
    eval "$@"
  fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_sudo() {
  if [ "$dry_run" -eq 1 ]; then
    return 0
  fi
  if [ "$EUID" -ne 0 ]; then
    if need_cmd sudo; then
      :
    else
      log_err "sudo is required to install system packages. Please install sudo or run as root."
      exit 1
    fi
  fi
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --with-appimage) with_appimage=1 ;;
      --arm64)         with_arm64=1 ;;
      -y|--yes)        auto_yes=1 ;;
      --dry-run)       dry_run=1 ;;
      -h|--help)
        cat <<EOF
Dock2Tauri dependency installer
Usage: $0 [--with-appimage] [--arm64] [--yes] [--dry-run]
Options:
  --with-appimage   Install linuxdeploy and appimagetool (optional)
  --arm64           Install cross toolchain for aarch64-unknown-linux-gnu (compiler and pkg-config)
  -y, --yes         Non-interactive mode (assume yes)
  --dry-run         Print actions without executing
EOF
        exit 0
        ;;
      *)
        log_warn "Unknown option: $1" ;;
    esac
    shift
  done
}

# Detect package manager and ID
get_pm() {
  local pm id like
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"
    like="${ID_LIKE:-}"
  fi
  
  # Prioritize package manager based on OS ID first, then availability
  case "$id" in
    fedora|rhel|centos|rocky|alma)
      if need_cmd dnf; then pm=dnf; elif need_cmd yum; then pm=yum; else pm=""; fi
      ;;
    debian|ubuntu|linuxmint|pop)
      if need_cmd apt-get; then pm=apt; else pm=""; fi
      ;;
    arch|manjaro|endeavouros)
      if need_cmd pacman; then pm=pacman; else pm=""; fi
      ;;
    opensuse*|sle*)
      if need_cmd zypper; then pm=zypper; else pm=""; fi
      ;;
    *)
      # Fallback to detection by availability (old logic)
      if need_cmd dnf; then pm=dnf; elif need_cmd apt-get; then pm=apt; elif need_cmd yum; then pm=yum; elif need_cmd pacman; then pm=pacman; elif need_cmd zypper; then pm=zypper; else pm=""; fi
      ;;
  esac
  
  echo "$pm,$id,$like"
}

confirm() {
  if [ "$auto_yes" -eq 1 ] || [ "$dry_run" -eq 1 ]; then
    return 0
  fi
  read -rp "Proceed with installation? [y/N] " ans || true
  case "$ans" in
    y|Y|yes|YES) return 0 ;;
    *) log_warn "Aborted by user"; exit 1 ;;
  esac
}

install_deps_apt() {
  log_info "Detected apt-based distro"
  run sudo apt-get update
  # Base build tools for Tauri on Linux
  run sudo apt-get install -y build-essential curl pkg-config libgtk-3-dev libayatana-appindicator3-dev librsvg2-dev patchelf file
  # Bundlers (deb is native via dpkg, rpm needs rpm)
  run sudo apt-get install -y rpm
  log_ok "Base deps installed (apt)"
}

install_deps_dnf() {
  log_info "Detected dnf-based distro"
  run sudo dnf install -y @development-tools curl pkgconf-pkg-config gtk3-devel libappindicator-gtk3 librsvg2-tools patchelf file rpm-build rpm
  # Additional GTK/WebKit dependencies needed for Tauri (v4.1 with libsoup3)
  run sudo dnf install -y webkit2gtk4.1-devel libsoup3-devel javascriptcoregtk4.1-devel glib2-devel cairo-devel pango-devel gdk-pixbuf2-devel atk-devel
  # dpkg might be available on Fedora for building .deb
  if ! need_cmd dpkg-deb; then
    run sudo dnf install -y dpkg || true
  fi
  log_ok "Base deps installed (dnf)"
}

install_deps_yum() {
  log_info "Detected yum-based distro"
  run sudo yum groupinstall -y "Development Tools" || true
  run sudo yum install -y curl pkgconfig gtk3-devel librsvg2-tools patchelf file rpm-build rpm || true
  if ! need_cmd dpkg-deb; then
    run sudo yum install -y dpkg || true
  fi
  log_ok "Base deps installed (yum)"
}

install_deps_pacman() {
  log_info "Detected pacman-based distro"
  run sudo pacman -Sy --noconfirm --needed base-devel curl pkgconf gtk3 librsvg patchelf file rpm-tools dpkg
  log_ok "Base deps installed (pacman)"
}

install_deps_zypper() {
  log_info "Detected zypper-based distro"
  run sudo zypper -n install -y -t pattern devel_basis || true
  run sudo zypper -n install -y curl pkg-config gtk3-devel librsvg-devel patchelf file rpm dpkg || true
  log_ok "Base deps installed (zypper)"
}

install_appimage_tools() {
  log_info "Installing AppImage tooling (linuxdeploy, appimagetool)"
  # Install into /usr/local/bin
  ensure_sudo
  local dir=/usr/local/bin
  local linuxdeploy_url="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
  local appimagetool_url="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
  run "sudo curl -fsSL -o $dir/linuxdeploy $linuxdeploy_url"
  run "sudo curl -fsSL -o $dir/appimagetool $appimagetool_url"
  run sudo chmod +x "$dir/linuxdeploy" "$dir/appimagetool"
  log_ok "AppImage tools installed to $dir (use APPIMAGE_EXTRACT_AND_RUN=1 in FUSE-less envs)"
}

install_arm64_cross_apt() {
  log_info "Installing ARM64 cross toolchain (apt)"
  run sudo apt-get install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu pkg-config-aarch64-linux-gnu
  log_ok "ARM64 compiler and pkg-config installed"
  cat <<'EONOTE'
Notes for ARM64 cross:
- You may still need ARM64 dev libraries (GTK/GLib). On Debian/Ubuntu, enable multiarch and install :arm64 packages, e.g.:
    sudo dpkg --add-architecture arm64
    sudo apt-get update
    sudo apt-get install -y libgtk-3-dev:arm64 libglib2.0-dev:arm64 libpango1.0-dev:arm64 libcairo2-dev:arm64 libgdk-pixbuf-2.0-dev:arm64
- Then set environment before building:
    export PKG_CONFIG=aarch64-linux-gnu-pkg-config
    export PKG_CONFIG_SYSROOT_DIR=/
    export PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig
EONOTE
}

install_arm64_cross_dnf() {
  log_info "Installing ARM64 cross toolchain (dnf)"
  run sudo dnf install -y gcc-aarch64-linux-gnu cross-aarch64-linux-gnu-binutils || true
  log_warn "For full GTK/GLib stack, additional aarch64 -devel packages and a sysroot may be required."
}

install_arm64_cross_pacman() {
  log_info "Installing ARM64 cross toolchain (pacman)"
  run sudo pacman -S --noconfirm --needed aarch64-linux-gnu-gcc aarch64-linux-gnu-binutils || true
  log_warn "aarch64 pkg-config and dev libs may require AUR or a custom sysroot."
}

main() {
  parse_args "$@"
  log_info "Dock2Tauri dependency installer"
  IFS=',' read -r pm id like <<<"$(get_pm)"
  if [ -z "$pm" ]; then
    log_err "Unsupported or undetected package manager. Please install build tools, gtk3 dev, rpm, patchelf manually."
    exit 1
  fi

  confirm

  case "$pm" in
    apt)    install_deps_apt ;;
    dnf)    install_deps_dnf ;;
    yum)    install_deps_yum ;;
    pacman) install_deps_pacman ;;
    zypper) install_deps_zypper ;;
    *)      log_err "Unknown package manager: $pm"; exit 1 ;;
  esac

  if [ "$with_appimage" -eq 1 ]; then
    install_appimage_tools || log_warn "AppImage tools installation failed; continuing"
  else
    log_warn "Skipping AppImage tooling (use --with-appimage to install)."
  fi

  if [ "$with_arm64" -eq 1 ]; then
    case "$pm" in
      apt)    install_arm64_cross_apt ;;
      dnf)    install_arm64_cross_dnf ;;
      pacman) install_arm64_cross_pacman ;;
      *)      log_warn "ARM64 cross toolchain install not implemented for $pm" ;;
    esac
  fi

  log_ok "Dependency setup completed"
}

main "$@"

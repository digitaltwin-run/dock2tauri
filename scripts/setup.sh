#!/usr/bin/env bash
#
# Dock2Tauri - setup helper for bundling tools (AppImage, RPM) and core deps
# This script complements scripts/install.sh by installing linuxdeploy,
# appimagetool and FUSE2 libraries required for AppImage creation and execution.
#
# Usage:
#   ./scripts/setup.sh [--with-docker] [--system] [--rpm] [--skip-core]
#
#   --with-docker  Also ensure Docker (delegated to scripts/install.sh)
#   --system       Install AppImage tools into /usr/local/bin (requires sudo)
#                  Default installs to $HOME/.local/bin
#   --rpm          Also install RPM tooling (rpmbuild) where supported
#   --skip-core    Skip calling scripts/install.sh (core dev deps)
#
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}ℹ️  ${*}${NC}"; }
ok() { echo -e "${GREEN}✅ ${*}${NC}"; }
warn() { echo -e "${YELLOW}⚠️  ${*}${NC}"; }
err() { echo -e "${RED}❌ ${*}${NC}"; }

require_cmd() { command -v "$1" >/dev/null 2>&1; }
need_sudo() { if [[ $EUID -ne 0 ]]; then echo sudo; else echo; fi }

usage() {
  sed -n '1,40p' "$0"
}

WITH_DOCKER=0
INSTALL_SYSTEM=0
INSTALL_RPM=0
SKIP_CORE=0

for arg in "$@"; do
  case "$arg" in
    --with-docker) WITH_DOCKER=1 ;;
    --system) INSTALL_SYSTEM=1 ;;
    --rpm) INSTALL_RPM=1 ;;
    --skip-core) SKIP_CORE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown argument: $arg" ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

get_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

install_fuse_deps() {
  local os="$1"
  local SUDO; SUDO=$(need_sudo)
  case "$os" in
    debian|ubuntu)
      $SUDO apt-get update -y
      # FUSE2 runtime for AppImage
      $SUDO apt-get install -y libfuse2 || warn "Could not install libfuse2 (try: apt-cache search libfuse2)"
      ;;
    fedora|rhel|centos)
      $SUDO dnf install -y fuse || warn "Could not install fuse (try: dnf search fuse)"
      ;;
    arch|manjaro)
      $SUDO pacman -Sy --noconfirm fuse2 || warn "Could not install fuse2 (try: pacman -Ss fuse2)"
      ;;
    *)
      warn "Unknown distro for FUSE install. Please install FUSE2 manually."
      ;;
  esac
}

install_rpm_tools() {
  local os="$1"
  local SUDO; SUDO=$(need_sudo)
  case "$os" in
    debian|ubuntu)
      $SUDO apt-get update -y
      $SUDO apt-get install -y rpm || warn "Could not install rpm on Debian/Ubuntu"
      ;;
    fedora|rhel|centos)
      $SUDO dnf install -y rpm-build || warn "Could not install rpm-build"
      ;;
    arch|manjaro)
      warn "RPM build tools are not available in official Arch repos. Use AUR (e.g., rpm-org) if needed."
      ;;
    *)
      warn "Unknown distro for RPM tools. Install rpmbuild manually if required."
      ;;
  esac
}

install_appimage_tools() {
  local dest_dir="$1"
  local SUDO=""
  if [[ "$dest_dir" == "/usr/local/bin" ]]; then SUDO=$(need_sudo); fi

  mkdir -p "$dest_dir"

  local LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
  local APPIMAGETOOL_URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"

  log "Installing linuxdeploy to $dest_dir ..."
  if require_cmd curl; then
    curl -fsSL "$LINUXDEPLOY_URL" -o "$dest_dir/linuxdeploy"
  else
    wget -qO "$dest_dir/linuxdeploy" "$LINUXDEPLOY_URL"
  fi
  $SUDO chmod +x "$dest_dir/linuxdeploy"
  ok "linuxdeploy installed"

  log "Installing appimagetool to $dest_dir ..."
  if require_cmd curl; then
    curl -fsSL "$APPIMAGETOOL_URL" -o "$dest_dir/appimagetool"
  else
    wget -qO "$dest_dir/appimagetool" "$APPIMAGETOOL_URL"
  fi
  $SUDO chmod +x "$dest_dir/appimagetool"
  ok "appimagetool installed"

  if [[ "$dest_dir" == "$HOME/.local/bin" ]]; then
    if ! echo ":$PATH:" | grep -q ":$HOME/.local/bin:"; then
      warn "~/.local/bin not in PATH. Add to your shell rc, e.g.: export PATH=\"$HOME/.local/bin:$PATH\""
    fi
  fi
}

main() {
  log "Dock2Tauri setup starting..."
  local OS; OS=$(get_os)
  log "Detected OS: $OS"

  if [[ $SKIP_CORE -eq 0 ]]; then
    log "Running core dependency installer (scripts/install.sh) ..."
    if [[ $WITH_DOCKER -eq 1 ]]; then
      "$ROOT_DIR/scripts/install.sh" --with-docker
    else
      "$ROOT_DIR/scripts/install.sh"
    fi
  else
    warn "Skipping core dependency installation as requested (--skip-core)."
  fi

  install_fuse_deps "$OS"

  if [[ $INSTALL_RPM -eq 1 || "$OS" == "fedora" || "$OS" == "rhel" || "$OS" == "centos" ]]; then
    install_rpm_tools "$OS"
  else
    warn "Skipping RPM tooling (use --rpm to install rpmbuild on Debian/Ubuntu)."
  fi

  local DEST_DIR
  if [[ $INSTALL_SYSTEM -eq 1 ]]; then
    DEST_DIR="/usr/local/bin"
    log "Installing AppImage tools system-wide to $DEST_DIR"
  else
    DEST_DIR="$HOME/.local/bin"
    log "Installing AppImage tools for current user to $DEST_DIR"
  fi
  install_appimage_tools "$DEST_DIR"

  ok "Setup complete. You can now build AppImage bundles."
  echo
  echo "Next steps:"
  echo "  - Re-run your build, e.g.: ./scripts/dock2tauri.sh ./examples/pwa-hello/Dockerfile 8088 80"
  echo "  - If installed to ~/.local/bin, ensure it's on PATH (see warning above)."
}

main "$@"

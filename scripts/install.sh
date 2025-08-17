#!/usr/bin/env bash
#
# Dock2Tauri - installer for dependencies and environment
# Supports Debian/Ubuntu, Fedora/RHEL, and Arch Linux
#
# Usage:
#   ./scripts/install.sh [--with-docker]
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

NEED_DOCKER=0
if [[ "${1:-}" == "--with-docker" ]]; then
  NEED_DOCKER=1
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

need_sudo() {
  if [[ $EUID -ne 0 ]]; then echo sudo; else echo; fi
}

get_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

install_pkgs_debian() {
  local SUDO; SUDO=$(need_sudo)
  $SUDO apt-get update -y
  $SUDO apt-get install -y \
    build-essential pkg-config curl wget file ca-certificates \
    libssl-dev libgtk-3-dev libwebkit2gtk-4.0-dev \
    libsoup2.4-dev libjavascriptcoregtk-4.0-dev \
    libayatana-appindicator3-dev librsvg2-dev patchelf
}

install_pkgs_fedora() {
  local SUDO; SUDO=$(need_sudo)
  $SUDO dnf install -y \
    gcc gcc-c++ make pkgconf-pkg-config curl wget ca-certificates \
    openssl-devel glib2-devel gtk3-devel webkit2gtk4.0-devel \
    libsoup-devel libappindicator-gtk3-devel librsvg2-devel patchelf
}

install_pkgs_arch() {
  local SUDO; SUDO=$(need_sudo)
  $SUDO pacman -Sy --noconfirm \
    base-devel pkgconf curl wget ca-certificates \
    openssl glib2 gtk3 webkit2gtk libsoup patchelf
}

install_docker_debian() {
  local SUDO; SUDO=$(need_sudo)
  # Simple path: distro docker.io package
  $SUDO apt-get update -y
  $SUDO apt-get install -y docker.io
  $SUDO systemctl enable --now docker || true
}

install_docker_fedora() {
  local SUDO; SUDO=$(need_sudo)
  $SUDO dnf install -y docker
  $SUDO systemctl enable --now docker || true
}

install_docker_arch() {
  local SUDO; SUDO=$(need_sudo)
  $SUDO pacman -Sy --noconfirm docker
  $SUDO systemctl enable --now docker || true
}

ensure_user_in_docker_group() {
  local SUDO; SUDO=$(need_sudo)
  if ! groups "$USER" | grep -q docker; then
    $SUDO usermod -aG docker "$USER" || true
    warn "Added $USER to docker group. You must log out/in or run: newgrp docker"
  fi
}

install_rust_and_tauri() {
  if ! require_cmd cargo; then
    warn "Rust/Cargo not found. Installing rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # shellcheck disable=SC1090
    source "$HOME/.cargo/env"
    ok "Rust installed"
  fi
  # Ensure Tauri CLI v2.x for compatibility with this project
  local NEED_INSTALL=0
  if require_cmd tauri; then
    local VER MAJOR
    VER=$(tauri --version 2>/dev/null | awk '{print $2}')
    MAJOR=${VER%%.*}
    if [[ -z "$MAJOR" || "$MAJOR" != "2" ]]; then
      warn "Tauri CLI v$VER detected; installing compatible v2.x"
      NEED_INSTALL=1
    fi
  else
    NEED_INSTALL=1
  fi
  if [[ $NEED_INSTALL -eq 1 ]]; then
    warn "Installing Tauri CLI v2.x via cargo..."
    cargo install --force --locked --version '^2' tauri-cli
    ok "Tauri CLI v2 installed"
  else
    ok "Tauri CLI v2 detected ($VER)"
  fi
}

main() {
  log "Dock2Tauri setup starting..."
  local OS; OS=$(get_os)
  log "Detected OS: $OS"

  case "$OS" in
    debian|ubuntu)
      install_pkgs_debian
      ;;
    fedora|rhel|centos)
      install_pkgs_fedora
      ;;
    arch|manjaro)
      install_pkgs_arch
      ;;
    *)
      warn "Unsupported/unknown distro ($OS). Skipping system package installation."
      warn "Please manually install: GTK3 dev, WebKitGTK dev, libsoup2.4 dev, JavaScriptCoreGTK dev, OpenSSL dev, build tools, patchelf."
      ;;
  esac
  ok "System development dependencies installed"

  if [[ $NEED_DOCKER -eq 1 ]]; then
    if ! require_cmd docker; then
      log "Docker not found. Installing..."
      case "$OS" in
        debian|ubuntu) install_docker_debian ;;
        fedora|rhel|centos) install_docker_fedora ;;
        arch|manjaro) install_docker_arch ;;
        *) warn "Unknown distro; please install Docker manually." ;;
      esac
    else
      ok "Docker already installed"
    fi
    if require_cmd docker; then
      ensure_user_in_docker_group
      if ! docker info >/dev/null 2>&1; then
        warn "Docker daemon not running or permission denied. Try: systemctl start docker or newgrp docker"
      fi
    fi
  else
    warn "Skipping Docker installation. Run with --with-docker to install and configure Docker."
  fi

  install_rust_and_tauri

  # Final touches
  chmod +x scripts/*.sh || true

  ok "Dock2Tauri setup complete!"
  echo
  echo "Next steps:"
  echo "  - If Docker was installed, log out/in or run: newgrp docker"
  echo "  - Try: make nginx   or   ./scripts/dock2tauri.sh nginx:alpine 8088 80"
}

main "$@"

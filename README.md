# 🐳🦀 Dock2Tauri - Docker to Desktop Bridge

Transform any Docker container into a native desktop application using Tauri.

## 🎯 Overview

Dock2Tauri is a lightweight bridge that allows you to run any Docker container as a native desktop application. It provides a modern control panel interface and multiple ways to launch containerized applications with unified CLI across Bash, Python, and Node.js launchers.

## ✨ Features

- 🚀 **One-click Docker Launch**: Run containers as desktop apps instantly
- 🎮 **Control Panel**: Modern web-based interface with preset configurations  
- 🔧 **Multi-language Support**: Bash, Python, and Node.js launchers with unified CLI
- 📦 **Dockerfile Support**: Build and serve local images from Dockerfiles
- 🏗️ **Cross-platform Builds**: Build native bundles for multiple platforms
- 📊 **Container Management**: Start, stop, and monitor containers
- 🌐 **Auto Browser Integration**: Automatically opens container web interfaces
- ⚡ **Hot Configuration**: Dynamic port mapping and container settings
- 🔧 **Tauri v2 Compatible**: Proper schema validation and configuration
- 🧪 **Health Checks**: Configurable readiness URL and timeout
- 🧹 **Ephemeral Tauri config**: Generated on the fly and passed via `--config`; no mutations to `src-tauri/tauri.conf.json`

## 🚀 Quick Start

### Prerequisites
- Docker installed and running
- Rust toolchain with Tauri CLI (for native builds)
- Node.js (for Node.js launcher)
- Python 3.x (for Python launcher)

### Installation

```bash
git clone https://github.com/digitaltwin-run/dock2tauri.git
cd dock2tauri
make install
```

### Automated installer (scripts/install.sh)

If you prefer a single script to prepare your environment (system packages, Rust + Tauri CLI, and optionally Docker), use the installer:

```bash
# Install all dev dependencies required by Tauri/WebKitGTK
./scripts/install.sh

# Additionally install and enable Docker, and add current user to the docker group
./scripts/install.sh --with-docker
```

What it does:
- Detects distro (Debian/Ubuntu, Fedora/RHEL, Arch/Manjaro)
- Installs system dev packages: GTK3, WebKit2GTK, libsoup2.4, JavaScriptCoreGTK, OpenSSL, build tools, patchelf
- Installs Rust (rustup) and Tauri CLI (cargo)
- Optionally installs and enables Docker; adds your user to the docker group

After installation:
- If Docker group membership was changed, re-login or run: `newgrp docker`
- Verify tools:
  - `docker --version`
  - `cargo --version`
  - `cargo tauri --version`

Troubleshooting:
- If Tauri build complains about missing `.pc` files (e.g. `libsoup-2.4.pc`, `javascriptcoregtk-4.0.pc`), ensure the dev packages above are installed by the script.
- For non-standard installations, set `PKG_CONFIG_PATH` to include the directory with the `.pc` files, e.g.:

```bash
export PKG_CONFIG_PATH=/custom/pc/dir:$PKG_CONFIG_PATH
```

## 📋 Usage Modes

Dock2Tauri supports three main run modes across all launchers:

### 1. Development Mode (Default)
Runs `cargo tauri dev` for development with hot reload:
```bash
./scripts/dock2tauri.sh nginx:alpine 8088 80
```

### 2. Release Build Mode
Builds distributable bundles (AppImage, .deb, .rpm, .msi, .dmg):
```bash
./scripts/dock2tauri.sh nginx:alpine 8088 80 --build
```

### 3. Cross-Platform Build Mode
Builds for specific target architectures:
```bash
./scripts/dock2tauri.sh nginx:alpine 8088 80 --build --target=x86_64-pc-windows-gnu
```

## 🔧 Unified CLI Interface

All three launchers (Bash, Python, Node.js) now support the same flags and functionality:

### Common Flags
- `--build` / `-b`: Build Tauri release bundles instead of dev mode
- `--target=<triple>`: Specify target architecture for cross-compilation
- `--help` / `-h`: Show help information
 - `--health-url=<url>`: Override readiness URL (default: `http://localhost:HOST_PORT`)
 - `--timeout=<seconds>`: Readiness timeout (default: `30`)

### Dockerfile Support
All launchers can build and serve local Docker images from Dockerfiles:
```bash
# If first argument is a Dockerfile path, builds local image
./scripts/dock2tauri.sh ./Dockerfile 8088 80
```

The `./app` folder content will be served by the built container.

## 🛠️ Launcher Scripts

### Method 1: Bash Script (Recommended)
```bash
# Basic usage
./scripts/dock2tauri.sh <docker-image|Dockerfile> <host-port> <container-port> [--build] [--target=<triple>] [--health-url=<url>] [--timeout=<seconds>]

# Examples
./scripts/dock2tauri.sh nginx:alpine 8088 80
./scripts/dock2tauri.sh ./Dockerfile 8088 80
./scripts/dock2tauri.sh grafana/grafana 3001 3000 --build
./scripts/dock2tauri.sh jupyter/scipy-notebook 8888 8888 --target=x86_64-pc-windows-gnu
./scripts/dock2tauri.sh grafana/grafana 3001 3000 --health-url=http://localhost:3001/login --timeout=60
```

### Method 2: Python Script
```bash
# Basic usage
python3 scripts/dock2tauri.py --image <image> --host-port <port> --container-port <port> [--build|-b] [--target <triple>] [--health-url <url>] [--timeout <seconds>]

# Examples
python3 scripts/dock2tauri.py --image nginx:alpine --host-port 8088 --container-port 80
python3 scripts/dock2tauri.py --image grafana/grafana --host-port 3001 --container-port 3000 --build
python3 scripts/dock2tauri.py --image jupyter/scipy-notebook --host-port 8888 --container-port 8888 --target x86_64-pc-windows-gnu
python3 scripts/dock2tauri.py -i grafana/grafana -p 3001 -c 3000 --health-url http://localhost:3001/login --timeout 60
```

### Method 3: Node.js Script
```bash
# Basic usage
node scripts/dock2tauri.js [image|Dockerfile] [host-port] [container-port] [--build|-b] [--target=<triple>] [--health-url=<url>] [--timeout=<seconds>]

# Examples
node scripts/dock2tauri.js nginx:alpine 8088 80
node scripts/dock2tauri.js grafana/grafana 3001 3000 --build
node scripts/dock2tauri.js jupyter/scipy-notebook 8888 8888 --target=x86_64-pc-windows-gnu
node scripts/dock2tauri.js grafana/grafana 3001 3000 --health-url=http://localhost:3001/login --timeout=60
```

### Method 4: Makefile Commands
```bash
# Launch Nginx as desktop app
make nginx

# Launch Grafana dashboard  
make grafana

# Launch custom container
make launch IMAGE=my-app:latest HOST_PORT=8088 CONTAINER_PORT=80
```

## 📦 Building Native Bundles

### Building for Current Platform
```bash
# Any launcher with --build flag
./scripts/dock2tauri.sh nginx:alpine 8088 80 --build
python3 scripts/dock2tauri.py --image nginx:alpine --host-port 8088 --container-port 80 --build
node scripts/dock2tauri.js nginx:alpine 8088 80 --build
```

### Cross-Platform Building
```bash
# Build for Windows from Linux/macOS
./scripts/dock2tauri.sh nginx:alpine 8088 80 --build --target=x86_64-pc-windows-gnu

# Build for Linux ARM64
./scripts/dock2tauri.sh nginx:alpine 8088 80 --build --target=aarch64-unknown-linux-gnu
```

### Build Artifacts Location
Built bundles are saved to:
- `src-tauri/target/release/bundle/` (native platform builds)
- `src-tauri/target/<target-triple>/release/bundle/` (cross-platform builds)

Supported bundle formats:
- **Linux**: AppImage, .deb, .rpm
- **Windows**: .msi, .nsis (installer)
- **macOS**: .dmg, .app bundle

### Manual Packaging (Fedora Workaround)
On some Fedora systems, the Tauri CLI may not generate bundles despite successful builds. Use the manual packaging script as a workaround:
```bash
./scripts/build-bundles.sh
```

This script provides automatic fallback to manual AppImage and .deb creation.

## ⚠️ Known Issues & Warnings

### WebKitGTK Warning (Harmless)
You may see this warning during development - it's harmless and can be ignored:
```
Gdk-Message: 15:34:22.123: Unable to load webkit2gtk-web-extension: ...
```

### Fedora Bundle Generation
On some Fedora systems, the Tauri CLI may not generate bundles despite successful builds. Use the manual packaging script as a workaround.

## 🔧 Technical Details

### Tauri Configuration
All launchers generate valid Tauri v2 configuration with:
- Proper JSON schema validation
- Dynamic port and identifier configuration  
- Bundle targets for AppImage, .deb, .rpm
- Security policies and window settings
- Icon handling with fallback generation
 - Ephemeral config path passed via `cargo tauri --config` without modifying `src-tauri/tauri.conf.json`

### Build System
- Uses `build.rs` to generate valid PNG icons automatically
- Disables default icon loading during development
- Supports both static and dynamic Tauri configurations
- Cross-platform Rust toolchain integration

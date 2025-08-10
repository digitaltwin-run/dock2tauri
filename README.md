# 🐳🦀 Dock2Tauri - Docker to Desktop Bridge

Transform any Docker container into a native desktop application using Tauri.

## 🎯 Overview

Dock2Tauri is a lightweight bridge that allows you to run any Docker container as a native desktop application. It provides a modern control panel interface and multiple ways to launch containerized applications.

## ✨ Features

- 🚀 **One-click Docker Launch**: Run containers as desktop apps instantly
- 🎮 **Control Panel**: Modern web-based interface with preset configurations  
- 🔧 **Multi-language Support**: Bash, Python, and Node.js launchers
- 📊 **Container Management**: Start, stop, and monitor containers
- 🌐 **Auto Browser Integration**: Automatically opens container web interfaces
- ⚡ **Hot Configuration**: Dynamic port mapping and container settings

## 🚀 Quick Start

### Prerequisites
- Docker installed and running
- Rust toolchain (for native builds)
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

What it does
- Detects distro (Debian/Ubuntu, Fedora/RHEL, Arch/Manjaro)
- Installs system dev packages: GTK3, WebKit2GTK, libsoup2.4, JavaScriptCoreGTK, OpenSSL, build tools, patchelf
- Installs Rust (rustup) and Tauri CLI (cargo)
- Optionally installs and enables Docker; adds your user to the docker group

After installation
- If Docker group membership was changed, re-login or run: `newgrp docker`
- Verify tools:
  - `docker --version`
  - `cargo --version`
  - `tauri --version`

Troubleshooting
- If Tauri build complains about missing `.pc` files (e.g. `libsoup-2.4.pc`, `javascriptcoregtk-4.0.pc`), ensure the dev packages above are installed by the script.
- For non-standard installations, set `PKG_CONFIG_PATH` to include the directory with the `.pc` files, e.g.:

```bash
export PKG_CONFIG_PATH=/custom/pc/dir:$PKG_CONFIG_PATH
```

### Usage

#### Method 1: Makefile Commands
```bash
# Launch Nginx as desktop app
make nginx

# Launch Grafana dashboard  
make grafana

# Launch custom container
make launch IMAGE=my-app:latest HOST_PORT=8088 CONTAINER_PORT=80
```

#### Method 2: Bash Script
```bash
./scripts/dock2tauri.sh nginx:alpine 8088 80

# Build a local image from a Dockerfile in this directory and launch on port 8088
./scripts/dock2tauri.sh ./Dockerfile 8088 80
```

If the first argument passed to the script is a path to a `Dockerfile`, the launcher will:
1. `docker build -f <Dockerfile> -t dock2tauri-local-<timestamp> <context>`
2. Use the freshly built image instead of pulling from a registry.

This is handy when you have a static site or custom backend you want to embed. Place your web assets in the `app/` folder (copied into `/usr/share/nginx/html` by the default `Dockerfile`).

##### Building native bundles

To build distributable bundles (dmg/msi/AppImage etc.) instead of launching the dev server, add `--build` (or `-b`). Optionally specify a target triple:

```bash
# Build for current platform
./scripts/dock2tauri.sh ./Dockerfile 8088 80 --build

# Cross–compile for Windows 64-bit
./scripts/dock2tauri.sh ./Dockerfile 8088 80 --build --target=x86_64-pc-windows-gnu
```

The script calls `cargo tauri build [--target <triple>]` in `src-tauri/` after updating the Tauri config.

**Note**  
Bundles (AppImage / dmg / msi) are created only if Tauri’s bundler can find a built frontend in the `distDir` (configured as `app/` here) **and** all system packaging dependencies are installed (e.g. `appimagetool` on Linux, `osx dmg tools` on macOS, WiX on Windows).  
If these tools are missing, `cargo tauri build` still succeeds but produces only the native executable:  
`src-tauri/target/release/dock2-tauri-<image>-<timestamp>`  
You can run this binary directly for a portable app without an installer.

After a successful build, distributable bundles are created under:

```text
src-tauri/target/release/bundle/
└── <platform>/
    ├── Dock2Tauri_<version>_<arch>.AppImage   # Linux example
    ├── Dock2Tauri Setup <version>.msi         # Windows example
    └── Dock2Tauri_<version>.dmg              # macOS example
```

Simply double-click the file for your OS or install it with your package manager. On Linux you can test the AppImage directly:

```bash
chmod +x src-tauri/target/release/bundle/appimage/Dock2Tauri_*.AppImage
./src-tauri/target/release/bundle/appimage/Dock2Tauri_*.AppImage
```

If you specified `--target=<triple>`, the artifacts will appear under `bundle/<triple>/`.

#### Method 3: Python Script
```bash
python scripts/dock2tauri.py --image nginx:alpine --host-port 8088 --container-port 80
```

#### Method 4: Node.js Script
```bash
node scripts/dock2tauri.js nginx:alpine 8088 80
```

#### Method 5: Control Panel (Development Mode)
```bash
make dev
```

### 🚦 Run Modes Summary

| Mode | Command | Output |
|------|---------|--------|
| **Dev (hot-reload)** | `./scripts/dock2tauri.sh ./Dockerfile 8088 80` | Runs `cargo tauri dev` with live reload. |
| **Installers / Bundles** | `./scripts/dock2tauri.sh ./Dockerfile 8088 80 --build` | Creates AppImage/dmg/msi in `src-tauri/target/release/bundle/` *(requires packaging tools and built frontend in `app/`)* |
| **Portable Binary** | `./scripts/dock2tauri.sh ./Dockerfile 8088 80 --build` + run `src-tauri/target/release/dock2-tauri-*` | A single native executable (no installer). |

The portable binary is useful when packaging tools aren’t installed or you only need a self-contained executable. Launch it in the background:

```bash
./src-tauri/target/release/dock2-tauri-dock2tauri-local-dockerfile-* &
```

> 💡 The console may print a WebKitGTK deprecation warning:
> `webkit_settings_set_enable_offline_web_application_cache is deprecated and does nothing.`  
> This is harmless and can be ignored.

## 📋 Available Presets

| Service | Command | Description |
|---------|---------|-------------|
| **Nginx** | `make nginx` | Web server on port 8088 |
| **Grafana** | `make grafana` | Analytics dashboard on port 3001 |
| **Jupyter** | `make jupyter` | Notebook server on port 8888 |
| **Portainer** | `make portainer` | Docker UI on port 9000 |

## 🏗️ Project Structure

```
dock2tauri/
├── app/                    # Frontend control panel
│   ├── index.html         # Main interface
│   ├── index.css          # Styling
│   └── index.js           # JavaScript logic
├── src-tauri/             # Rust backend
│   ├── src/main.rs        # Docker integration logic
│   ├── Cargo.toml         # Dependencies
│   └── tauri.conf.json    # Tauri configuration
├── scripts/               # Launcher scripts
│   ├── dock2tauri.sh      # Bash launcher
│   ├── dock2tauri.py      # Python launcher
│   └── dock2tauri.js      # Node.js launcher
├── docs/                  # Documentation
├── examples/              # Usage examples
└── Makefile              # Build and launch commands
```

## 🔧 Configuration

### Custom Container Configuration

Create a `dock2tauri.conf.json`:

```json
{
  "presets": {
    "my-app": {
      "image": "my-custom-app:latest",
      "hostPort": 3000,
      "containerPort": 8088,
      "windowTitle": "My Custom App",
      "windowSize": {
        "width": 1200,
        "height": 800
      }
    }
  }
}
```

### Environment Variables

- `DOCK2TAURI_DEFAULT_PORT`: Default host port (default: 8088)
- `DOCK2TAURI_WINDOW_WIDTH`: Default window width (default: 1200)
- `DOCK2TAURI_WINDOW_HEIGHT`: Default window height (default: 800)

## 🧪 Testing

```bash
# Test all launchers
make test

# Test specific launcher
make test-bash
make test-python  
make test-nodejs
```

## 🐛 Troubleshooting

### Common Issues

1. **Port already in use**
   ```bash
   docker ps --filter "publish=8088" -q | xargs docker stop
   ```

2. **Docker not found**
   ```bash
   # Install Docker
   curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
   ```

3. **Tauri build fails**
   ```bash
   # Install system dependencies (Ubuntu/Debian)
   sudo apt install libwebkit2gtk-4.0-dev libgtk-3-dev
   ```

## 📖 Examples

See the `examples/` directory for:
- Custom application configurations
- Integration with CI/CD
- Docker Compose setups
- Advanced use cases

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open pull request

## 📜 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Tauri](https://tauri.app/) - Rust-based desktop app framework
- [Docker](https://docker.com/) - Containerization platform
- Community contributors and testers

## Examples & Tests

### Bash Launcher
```bash
# Launch nginx container on host port 8080
./scripts/dock2tauri.sh nginx:alpine 8080 80
```
Expected output snippet:
```
🐳🦀 Dock2Tauri - Docker to Desktop Bridge
ℹ️  Checking dependencies... ✅ Dependencies check passed
ℹ️  Launching Docker container... ✅ Container launched: <container-id>
✅ Service is ready!
ℹ️  Updating Tauri configuration... ⚠️ Tauri config not found, skipping update
ℹ️  Launching Tauri application...
```

### Python Launcher
```bash
# Launch Grafana container on host port 3001
python3 scripts/dock2tauri.py --image grafana/grafana --host-port 3001 --container-port 3000
```
Expected output snippet:
```
🐳🦀 Dock2Tauri - Docker to Desktop Bridge
✅ Dependencies check passed
✅ Container launched: <container-id>
✅ Service is ready!
```

### Node.js Launcher
```bash
# Launch Jupyter notebook container on host port 8888
node scripts/dock2tauri.js jupyter/scipy-notebook 8888 8888
```
Expected output snippet:
```
🐳🦀 Dock2Tauri - Docker to Desktop Bridge
✅ Container launched: <container-id>
✅ Service is ready! ✅ Tauri configuration updated
```

### Automated Tests
```bash
# Run all launcher tests
make test
# Or individual tests:
make test-bash      # Bash script
make test-python    # Python script
make test-nodejs    # Node.js script
```
All tests should pass without errors, verifying that each launcher yields a running Docker container and a Tauri app window.

---

**Made with ❤️ for the Docker and Desktop App communities**

# Troubleshooting Guide

This guide helps resolve common issues when using Dock2Tauri.

## Quick Diagnostics

Run the system status check to identify potential issues:
```bash
make status
```

## Common Issues

### 1. Build and Compilation Problems

#### ❌ AppImage Build Failures
**Symptoms:**
- `failed to run linuxdeploy` errors
- AppImage tools not found or not executable

**Solutions:**
```bash
# Skip AppImage bundling (recommended for most environments)
export DOCK2TAURI_SKIP_APPIMAGE=1
./scripts/dock2tauri.sh <image> <host-port> <container-port> --build

# OR install AppImage tools with FUSE support
make install-deps APPIMAGE=1 YES=1

# OR force AppImage in cross-compilation mode
export DOCK2TAURI_FORCE_APPIMAGE=1
```

**Root cause:** Many CI/CD environments and containers lack FUSE support required for AppImage tools.

#### ❌ Cross-compilation Failures (ARM64)
**Symptoms:**
- `pkg-config has not been configured to support cross-compilation`
- GTK/GLib build errors for `aarch64-unknown-linux-gnu`

**Solutions:**
```bash
# Install ARM64 cross-compilation toolchain
make install-deps ARM64=1 YES=1

# Setup multiarch for ARM64 dev libraries (Debian/Ubuntu)
sudo dpkg --add-architecture arm64
sudo apt update
sudo apt install -y libgtk-3-dev:arm64 libglib2.0-dev:arm64 \
  libpango1.0-dev:arm64 libcairo2-dev:arm64 libgdk-pixbuf-2.0-dev:arm64

# Configure environment for ARM64 builds
export PKG_CONFIG=aarch64-linux-gnu-pkg-config
export PKG_CONFIG_SYSROOT_DIR=/
export PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig

# Then build for ARM64
./scripts/dock2tauri.sh <image> <host-port> <container-port> --build --target=aarch64-unknown-linux-gnu
```

#### ❌ macOS Cross-compilation on Linux
**Symptoms:**
- `cc: error: unrecognized command-line option '-arch'`
- `objc2-exception-helper` build failures

**Solutions:**
```bash
# Skip macOS targets (recommended)
export DOCK2TAURI_CROSS_TARGETS="x86_64-unknown-linux-gnu"
./scripts/dock2tauri.sh <image> <host-port> <container-port> --build --cross

# OR install osxcross (advanced)
# See: https://github.com/tpoechtrager/osxcross
```

**Root cause:** macOS cross-compilation requires Apple SDK and osxcross toolchain.

#### ❌ ARM64/aarch64 Cross-Compilation Failures
**Symptoms:**
- `pkg-config has not been configured to support cross-compilation`
- GTK/GLib/Cairo build failures for aarch64-unknown-linux-gnu
- Errors in glib-sys, gobject-sys, gdk-sys, etc.

**Solutions:**
```bash
# Install ARM64 multiarch support (Ubuntu/Debian)
sudo dpkg --add-architecture arm64
sudo apt update
sudo apt install -y libgtk-3-dev:arm64 libglib2.0-dev:arm64 libpango1.0-dev:arm64 libcairo2-dev:arm64 libgdk-pixbuf-2.0-dev:arm64

# Configure pkg-config for cross-compilation
export PKG_CONFIG=aarch64-linux-gnu-pkg-config
export PKG_CONFIG_SYSROOT_DIR=/
export PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig

# Verify pkg-config works
aarch64-linux-gnu-pkg-config --exists gtk+-3.0

# Skip problematic targets temporarily
export DOCK2TAURI_CROSS_TARGETS="x86_64-unknown-linux-gnu"
./scripts/dock2tauri.sh image 8088 80 --build --cross
```

**Root cause:** ARM64 cross-compilation requires proper sysroot, multiarch libraries, and pkg-config configuration for the target architecture.

#### ❌ RPM Package Conflicts
**Symptoms:**
- `file /usr/bin/my-tauri-app from install of... conflicts with file from package...`
- Cannot install new RPM due to file conflicts

**Solutions:**
```bash
# Option 1: Remove old package first (recommended)
rpm -qa | grep dock2
sudo rpm -e <old-package-name>
sudo rpm -i <new-package.rpm>

# Option 2: Use upgrade instead of install
sudo rpm -U <new-package.rpm>

# Option 3: Remove with dependencies ignored
sudo rpm -e --nodeps <old-package-name>
sudo rpm -i <new-package.rpm>
```

**Root cause:** Each build creates RPM with same package name and file paths but different timestamps, causing conflicts.

**Automatic resolution:** Dock2Tauri now automatically detects and attempts to remove conflicting packages before building. However, this requires sudo access and may fail in non-interactive environments.

#### ❌ Tauri Schema Validation Errors
**Symptoms:**
- Schema validation warnings
- Invalid configuration errors

**Solutions:**
```bash
# Check Tauri CLI version
cargo tauri --version

# Ensure Tauri v2 compatibility
cargo install tauri-cli --version "^2.0"

# Regenerate configuration
rm -f /tmp/tauri.conf.*
./scripts/dock2tauri.sh <image> <host-port> <container-port> --build
```

### 2. Docker-related Issues

#### ❌ Docker Permission Denied
**Symptoms:**
- `permission denied while trying to connect to the Docker daemon socket`
- Docker commands fail with permission errors

**Solutions:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Re-login or activate group
newgrp docker

# Verify access
docker ps
```

#### ❌ Port Already in Use
**Symptoms:**
- `bind: address already in use`
- Port conflicts when starting containers

**Solutions:**
```bash
# Check what's using the port
sudo netstat -tulpn | grep :<port>
sudo lsof -i :<port>

# Stop conflicting containers
make stop-all

# Use a different port
./scripts/dock2tauri.sh <image> <different-port> <container-port>
```

#### ❌ Container Fails to Start
**Symptoms:**
- Container exits immediately
- Service not ready timeouts

**Solutions:**
```bash
# Check container logs
docker logs <container-name>

# Debug container directly
docker run -it --rm <image> /bin/sh

# Use custom health check URL
./scripts/dock2tauri.sh <image> <host-port> <container-port> \
  --health-url=http://localhost:<port>/health --timeout=60
```

### 3. Package Manager Issues

#### ❌ Package Manager Detection Issues (Fedora/Mixed Systems)
**Symptoms:**
- `install_deps.sh` tries to use `apt-get` on Fedora systems
- Installation fails with "Unable to locate package" for standard packages
- System has multiple package managers installed (e.g., `apt` and `dnf`)

**Root cause:** 
Systems with both `apt` and `dnf` installed (common in development environments) may have the installer script incorrectly detect `apt` as the primary package manager on Fedora-based systems.

**Solutions:**
```bash
# Option 1: Use the corrected install script (recommended)
make install-deps YES=1

# Option 2: Manual installation with correct package manager
# For Fedora/RHEL/CentOS systems:
sudo dnf install -y @development-tools curl pkgconf-pkg-config \
  gtk3-devel libappindicator-gtk3 librsvg2-tools patchelf file rpm-build \
  webkit2gtk4.0-devel glib2-devel cairo-devel pango-devel gdk-pixbuf2-devel atk-devel

# Option 3: Verify which package manager to use
cat /etc/os-release  # Check your OS ID
# If ID=fedora, use dnf; if ID=ubuntu/debian, use apt
```

**Prevention:**
The issue has been fixed in the latest version of `scripts/install_deps.sh` which now prioritizes package manager detection based on OS ID rather than command availability.

#### ❌ APT Repository Errors
**Symptoms:**
- `The repository does not have a Release file`
- APT update failures

**Solutions:**
```bash
# Check Ubuntu version
cat /etc/os-release

# Fix sources.list for your Ubuntu version
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup

# For Ubuntu 20.04 LTS (focal)
sudo tee /etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu focal main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu focal-security main restricted universe multiverse
EOF

# Or use closest mirror
sudo sed -i 's|http://archive.ubuntu.com|http://us.archive.ubuntu.com|g' /etc/apt/sources.list

sudo apt update
```

#### ❌ Missing System Dependencies
**Symptoms:**
- `libgtk-3-dev` not found
- `pkg-config` missing
- Build tools unavailable

**Solutions:**
```bash
# Install base dependencies
make install-deps YES=1

# Manual installation (Debian/Ubuntu)
sudo apt update
sudo apt install -y build-essential curl pkg-config libgtk-3-dev \
  libayatana-appindicator3-dev librsvg2-dev patchelf file rpm

# Manual installation (Fedora/RHEL)
sudo dnf install -y @development-tools curl pkgconf-pkg-config \
  gtk3-devel libappindicator-gtk3 librsvg2-tools patchelf file rpm-build
# Additional GTK/WebKit dependencies needed for Tauri
sudo dnf install -y webkit2gtk4.0-devel glib2-devel cairo-devel pango-devel gdk-pixbuf2-devel atk-devel

# Manual installation (Arch/Manjaro)
sudo pacman -Sy --needed base-devel curl pkgconf gtk3 librsvg patchelf file rpm-tools
```

### 4. Performance Issues

#### ❌ Slow Build Times
**Symptoms:**
- Rust compilation takes >5 minutes
- Cross-compilation extremely slow

**Solutions:**
```bash
# Enable parallel compilation
export CARGO_BUILD_JOBS=$(nproc)

# Use release build optimizations
export CARGO_PROFILE_RELEASE_LTO=false

# Skip unnecessary targets
export DOCK2TAURI_CROSS_TARGETS="x86_64-unknown-linux-gnu"

# Use cargo cache
cargo install sccache
export RUSTC_WRAPPER=sccache
```

#### ❌ Large Bundle Sizes
**Symptoms:**
- Bundle files >100MB
- Slow installation/distribution

**Solutions:**
```bash
# Strip debug symbols
export CARGO_PROFILE_RELEASE_STRIP=true

# Optimize bundle configuration
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
export CARGO_PROFILE_RELEASE_PANIC=abort
```

### 5. Runtime Issues

#### ❌ WebKitGTK Warnings (Harmless)
**Symptoms:**
```
Gdk-Message: Unable to load webkit2gtk-web-extension
```

**Solutions:**
These warnings are harmless and can be ignored. They don't affect functionality.

#### ❌ Application Won't Start
**Symptoms:**
- Desktop application crashes on startup
- No GUI appears

**Solutions:**
```bash
# Check system requirements
pkg-config --modversion gtk+-3.0
pkg-config --modversion webkit2gtk-4.0

# Run in development mode for debugging
cargo tauri dev

# Check for missing libraries
ldd ./target/release/my-tauri-app

# Install missing WebKitGTK dependencies
sudo apt install -y webkit2gtk-4.0-dev  # Debian/Ubuntu
sudo dnf install -y webkit2gtk3-devel   # Fedora/RHEL
```

### 6. Environment-specific Issues

#### ❌ GitHub Actions / CI Failures
**Symptoms:**
- Docker not available in CI
- AppImage/FUSE issues in containers

**Solutions:**
```yaml
# .github/workflows/build.yml
- name: Set up Docker
  uses: docker/setup-buildx-action@v2

- name: Skip AppImage in CI
  run: echo "DOCK2TAURI_SKIP_APPIMAGE=1" >> $GITHUB_ENV

- name: Install dependencies
  run: make install-deps YES=1
```

#### ❌ WSL (Windows Subsystem for Linux) Issues
**Symptoms:**
- Docker daemon not accessible
- GUI applications don't display

**Solutions:**
```bash
# Install Docker Desktop for Windows with WSL2 integration
# OR install Docker in WSL
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# For GUI support in WSL2
sudo apt install -y xvfb
export DISPLAY=:99
Xvfb :99 -screen 0 1024x768x24 &
```

## Debug Mode

Enable verbose logging for all operations:
```bash
export DOCK2TAURI_DEBUG=1
./scripts/dock2tauri.sh <image> <host-port> <container-port>
```

### 7. Custom Build Paths Configuration Issues

#### ❌ Custom Output Directory Not Working
**Symptoms:**
- Files still exported to default `./dist` directory
- Custom `--output-dir` argument ignored

**Solutions:**
```bash
# Ensure proper argument syntax (use = sign)
./scripts/dock2tauri.sh --output-dir="/path/to/builds" nginx:alpine 8088 80 --build

# Check resolved export path in logs
# Should show: "Resolved export path: /path/to/builds"

# Verify directory permissions
mkdir -p "/path/to/builds" && ls -la "/path/to/builds"
```

#### ❌ Additional Output Directories Copy Failures
**Symptoms:**
- `⚠️ Partial copy to: /dir` warnings
- `❌ Failed to create directory` errors

**Solutions:**
```bash
# Check directory permissions and create manually
sudo mkdir -p /target/directory
sudo chown $USER:$USER /target/directory

# Use comma-separated paths without spaces
--copy-to="/home/user/apps,/opt/deployments"

# Verify paths exist and are writable
ls -la /target/parent/directory
```

#### ❌ Custom App Name Not Applied
**Symptoms:**
- Package names still use auto-generated names
- `productName` not updated in tauri.conf.json

**Solutions:**
```bash
# Verify custom app name parsing in logs
# Should show: "Using custom app name: MyApp"

# Check .env configuration
cat .env | grep CUSTOM_APP_NAME

# Ensure no special characters in app name
--app-name="MyCleanAppName"  # Good
--app-name="My/App:Name"     # Problematic
```

#### ❌ Environment Configuration Issues
**Symptoms:**
- `.env` file not loaded
- Default values not applied

**Solutions:**
```bash
# Verify .env file exists and is readable
ls -la .env
cat .env

# Recreate from example if corrupted
cp .env.example .env

# Check environment loading in logs
# Should show: "✅ Configuration loaded from .env"

# Manual verification
source .env && echo $OUTPUT_DIR
```

## Getting Help

1. **Check system status**: `make status`
2. **Review logs**: Check container logs and build output
3. **Search issues**: Look for similar problems in project issues
4. **Create minimal reproduction**: Simplify to smallest failing case
5. **Gather environment info**:
   ```bash
   # System information
   uname -a
   docker --version
   cargo --version
   cargo tauri --version
   
   # Dock2Tauri environment
   echo "DOCK2TAURI_* environment variables:"
   env | grep DOCK2TAURI
   ```

## Known Limitations

- **AppImage**: Requires FUSE support (not available in many containers/CI)
- **Cross-compilation**: Requires extensive toolchain setup
- **macOS builds**: Limited to macOS hosts (osxcross is complex)
- **Windows builds**: Best done on Windows hosts
- **Container networking**: Limited to localhost by design

## Reporting Issues

When reporting issues, please include:
1. Operating system and version
2. Docker version
3. Rust/Cargo/Tauri CLI versions
4. Complete command that failed
5. Full error output
6. Output of `make status`
7. Environment variables (sanitized)

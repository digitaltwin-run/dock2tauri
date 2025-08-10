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
git clone <repository>
cd dock2tauri
make install
```

### Usage

#### Method 1: Makefile Commands
```bash
# Launch Nginx as desktop app
make nginx

# Launch Grafana dashboard  
make grafana

# Launch custom container
make launch IMAGE=my-app:latest HOST_PORT=8080 CONTAINER_PORT=80
```

#### Method 2: Bash Script
```bash
./scripts/dock2tauri.sh nginx:alpine 8080 80
```

#### Method 3: Python Script
```bash
python scripts/dock2tauri.py --image nginx:alpine --host-port 8080 --container-port 80
```

#### Method 4: Node.js Script
```bash
node scripts/dock2tauri.js nginx:alpine 8080 80
```

#### Method 5: Control Panel (Development Mode)
```bash
make dev
```

## 📋 Available Presets

| Service | Command | Description |
|---------|---------|-------------|
| **Nginx** | `make nginx` | Web server on port 8080 |
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
      "containerPort": 8080,
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

- `DOCK2TAURI_DEFAULT_PORT`: Default host port (default: 8080)
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
   docker ps --filter "publish=8080" -q | xargs docker stop
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

---

**Made with ❤️ for the Docker and Desktop App communities**

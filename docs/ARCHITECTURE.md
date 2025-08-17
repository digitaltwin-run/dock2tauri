# Dock2Tauri Architecture

This document provides a high-level overview of Dock2Tauri's architecture, components, and data flow.

## Overview

Dock2Tauri is a bridge that transforms Docker containers into native desktop applications using Tauri. It consists of multiple launcher interfaces, a Tauri desktop application, and supporting infrastructure.

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   User Input    │    │    Launchers     │    │  Tauri Desktop  │
│                 │    │                  │    │   Application   │
│ • Docker Image  │───▶│ • Bash Script    │───▶│                 │
│ • Dockerfile    │    │ • Python CLI     │    │ • WebView       │
│ • Host/Cont Port│    │ • Node.js Script │    │ • Container     │
│ • Build Flags   │    │ • Makefile       │    │   Proxy/Bridge  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │ Docker Container │    │  Native Bundle  │
                       │                  │    │                 │
                       │ • Web App/Service│    │ • .deb, .rpm    │
                       │ • Port Mapping   │    │ • .AppImage     │
                       │ • Auto-restart   │    │ • .msi, .dmg    │
                       └──────────────────┘    └─────────────────┘
```

## Components

### 1. Launchers (Frontend Interface)

Multiple entry points providing unified CLI across different environments:

#### Bash Script (`scripts/dock2tauri.sh`)
- **Primary launcher** with full feature set
- Intelligent cross-compilation gating
- Dynamic bundler detection (DEB/RPM/AppImage)
- Auto-skip problematic targets in cross-mode
- Environment-based configuration

#### Python CLI (`scripts/dock2tauri.py` + `taurido` package)
- Standalone Python package for integration into Python workflows
- Same feature parity as Bash launcher
- Project root detection and management
- Cross-platform Python compatibility

#### Node.js Script (`scripts/dock2tauri.js`)
- JavaScript/Node.js integration
- Consistent API with other launchers
- JSON-based configuration handling

#### Makefile Targets
- Quick-start presets (nginx, grafana, jupyter, portainer)
- Development workflow integration
- Dependency installation automation

### 2. Configuration System

#### Ephemeral Tauri Config
- **Dynamic generation**: Creates temporary `tauri.conf.json` per run
- **No git pollution**: Avoids modifying `src-tauri/tauri.conf.json`
- **Platform-aware bundlers**: Detects available tools (dpkg-deb, rpmbuild, linuxdeploy)
- **Schema validation**: Tauri v2 compatible JSON schema

#### Environment Variables
- `DOCK2TAURI_SKIP_APPIMAGE=1` - Skip AppImage bundling
- `DOCK2TAURI_FORCE_APPIMAGE=1` - Force AppImage in cross-mode
- `DOCK2TAURI_CROSS_TARGETS="x,y,z"` - Override cross-compilation targets
- `DOCK2TAURI_DEBUG=1` - Enable debug mode

### 3. Tauri Desktop Application

#### Core Architecture
```
┌─────────────────────────────────────────────────────────┐
│                    Tauri App                            │
│  ┌─────────────────┐  ┌─────────────────────────────────┐ │
│  │     Frontend    │  │           Backend              │ │
│  │                 │  │                                │ │
│  │ • HTML/CSS/JS   │  │ • Rust Core                    │ │
│  │ • WebView       │◄─┤ • Docker Integration          │ │
│  │ • Control Panel │  │ • Container Management        │ │
│  │                 │  │ • Bundle Generation           │ │
│  └─────────────────┘  └─────────────────────────────────┘ │
│                                     │                    │
└─────────────────────────────────────┼────────────────────┘
                                      │
                                      ▼
                           ┌─────────────────┐
                           │ Docker Daemon   │
                           │                 │
                           │ • Container     │
                           │   Lifecycle     │
                           │ • Port Mapping  │
                           │ • Health Checks │
                           └─────────────────┘
```

#### Frontend (`app/`)
- Modern web interface for container management
- Real-time status updates
- Configuration forms for ports, volumes, environment variables
- Build progress monitoring

#### Backend (`src-tauri/`)
- Rust-based Tauri application
- Docker SDK integration for container operations
- Cross-platform native bundling
- File system operations for Dockerfile builds

### 4. Build and Packaging System

#### Bundle Generation Pipeline
```
Source → Docker Build → Tauri Config → Native Compile → Bundle Creation
   │           │              │              │              │
   ▼           ▼              ▼              ▼              ▼
Dockerfile  Container     temp.json       Binary      .deb/.rpm/etc
   │        Ready         Generated       Compiled       Generated
   │           │              │              │              │
   └───────────┴──────────────┴──────────────┴──────────────┘
                               │
                               ▼ (Export to dist/)
                    ┌─────────────────────────────┐
                    │     Platform Folders       │
                    │                             │
                    │ • dist/linux-x64/          │
                    │ • dist/linux-arm64/        │
                    │ • dist/windows-x64/        │
                    │ • dist/macos-x64/          │
                    │ • dist/macos-arm64/        │
                    │ • dist/android-apk/        │
                    └─────────────────────────────┘
```

#### Cross-Compilation Intelligence
- **Target Detection**: Checks for required toolchains (gcc, pkg-config, osxcross)
- **Graceful Degradation**: Skips unavailable targets with clear messaging
- **Toolchain Validation**: Verifies cross-compilation prerequisites
- **Platform Filtering**: Host OS aware target selection

### 5. Docker Integration

#### Container Lifecycle Management
1. **Image Resolution**: Handle both images and Dockerfiles
2. **Build Process**: Local Dockerfile builds with context
3. **Container Launch**: Port mapping, networking, restart policies
4. **Health Monitoring**: Readiness checks with configurable timeouts
5. **Cleanup**: Automatic container removal on app exit

#### Network Architecture
```
Desktop App (Tauri)    Host System         Docker Container
       │                    │                      │
       │ ┌─────────────────┐ │ ┌─────────────────┐  │
       └─┤   WebView       ├─┼─┤   Port Forward  ├──┘
         │ localhost:HOST  │ │ │ HOST:CONTAINER  │
         └─────────────────┘ │ └─────────────────┘
                             │
                             │ ┌─────────────────┐
                             └─┤ Docker Daemon   │
                               └─────────────────┘
```

## Data Flow

### Development Mode (`cargo tauri dev`)
1. **Configuration**: Generate ephemeral `tauri.conf.json` with devUrl
2. **Container Start**: Launch Docker container with port mapping
3. **Health Check**: Wait for service readiness
4. **Tauri Launch**: Start development server with WebView pointing to container
5. **Live Development**: Hot reload and debugging capabilities

### Production Build (`--build`)
1. **Multi-target Detection**: Scan for installed Rust targets and toolchains
2. **Bundle Generation**: Create native packages per platform
3. **Export Organization**: Copy artifacts to `dist/<platform>/` with README
4. **Cross-compilation**: Attempt feasible targets based on available tools
5. **Final Artifacts**: Ready-to-distribute native applications

### Configuration Flow
```
CLI Args → Environment Variables → Default Values
    │              │                    │
    ▼              ▼                    ▼
┌─────────────────────────────────────────────┐
│          Unified Configuration             │
│                                            │
│ • Docker image/Dockerfile                  │
│ • Host/Container ports                     │
│ • Build targets and flags                  │
│ • Health check configuration              │
│ • Bundler preferences                      │
└─────────────────────────────────────────────┘
                     │
                     ▼
            ┌─────────────────┐
            │ Tauri Config    │
            │ Generator       │
            └─────────────────┘
                     │
                     ▼
            ┌─────────────────┐
            │  temp.json      │
            │ (ephemeral)     │
            └─────────────────┘
```

## Extension Points

### Adding New Launchers
1. Implement unified CLI interface
2. Generate compatible Tauri configuration
3. Handle container lifecycle (start, stop, cleanup)
4. Support Dockerfile and image inputs
5. Maintain feature parity with existing launchers

### Custom Bundlers
1. Extend `generate_tauri_config_json()` in launchers
2. Add bundler detection logic
3. Update platform mapping in `map_target_to_platform()`
4. Ensure cleanup and error handling

### Cross-compilation Targets
1. Add target to `CANDIDATE_TARGETS` array
2. Implement toolchain detection in `can_cross_compile_target()`
3. Update platform mapping
4. Document required dependencies

## Security Considerations

### Container Isolation
- Docker provides process and filesystem isolation
- No privileged container requirements
- User-space Docker daemon interaction

### Network Security
- Port binding limited to localhost by default
- No external network exposure without explicit configuration
- Container-to-host communication only through mapped ports

### Build Security
- Dockerfile builds run in isolated Docker context
- No arbitrary code execution in host environment
- Tauri's built-in security policies for WebView

## Performance Characteristics

### Build Times
- **Development**: ~2-5 seconds (container start + health check)
- **Production**: ~30-120 seconds (Rust compilation + bundling)
- **Cross-compilation**: Additional ~30-60 seconds per target

### Resource Usage
- **Memory**: ~50-200MB (Tauri app + WebView + container overhead)
- **Disk**: ~10-50MB per native bundle
- **Network**: Container image download (cached after first pull)

### Optimization Opportunities
- Parallel cross-compilation builds
- Incremental compilation caching
- Bundle size optimization
- Startup time improvements

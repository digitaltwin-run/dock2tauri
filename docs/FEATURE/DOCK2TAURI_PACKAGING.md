# FEATURE: Web-to-Desktop Tauri Packaging Pipeline

## Context
Web applications and dashboards (like Willman Console, PWA webapps, or static UI frontends) need to run as native, standalone desktop applications on Linux (RPM/AppImage), macOS, and Windows without the memory overhead of Chromium or Electron. `dock2tauri` orchestrates this conversion.

## Scope & Implementation
1. **Core CLI (`taurido`)**: Python-based runner wrapping Tauri CLI and Cargo toolchains.
2. **Template Scaffolding (`src-tauri`)**: Standardized Rust Tauri wrapper with pre-configured CSP, system tray integration, and custom protocol handlers.
3. **Multi-Target Bundling**: Build automation via `scripts/build-bundles.sh` targeting Debian, Fedora RPM, and universal AppImage formats.
4. **Conformance**: Adheres to `wellmanifest/docs` (Compact v2) and `wellmanifest/reuse` for cross-project asset sharing.

## Verification
- Unit and CLI tests: `pytest tests/ -v`.
- Bash test runners: `bash tests/bash/run_tests.sh`.
- Packaging contract validation: `pytest tests/test_launcher_contract.py`.

## Consequences
- Enables instant generation of lightweight desktop binaries for any local web server or static asset directory.
- Reusable across the fleet for local desktop companion apps.

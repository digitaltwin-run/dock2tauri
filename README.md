# taurido

Python CLI that bridges Dockerized web apps into Tauri desktop apps. It mirrors the Dock2Tauri Bash launcher behavior.

- Detects available Linux bundlers (DEB/RPM/AppImage) dynamically
- Builds Tauri bundles and exports artifacts to `dist/<platform>/`
- Auto-detects (or can be pointed to) the Dock2Tauri project root that contains `src-tauri/`

## Installation (editable for development)

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
```

## Usage

From the Dock2Tauri repo root (the directory that contains `src-tauri/`):

```bash
# Build from a Dockerfile (defaults to bundling & export)
# Example provided in Dock2Tauri repo

taurido ./examples/pwa-hello/Dockerfile 8088 80
```

From the taurido repo (or any other directory), you can either rely on auto-detection or point to the project root explicitly:

```bash
# Explicit project root
taurido --project-root ../dock2tauri ./examples/pwa-hello/Dockerfile 8088 80

# Or via env var
TAURIDO_PROJECT_ROOT=../dock2tauri taurido ./examples/pwa-hello/Dockerfile 8088 80
```

Makefile convenience targets (in this repository):

```bash
make dev-install   # editable install with dev deps
make run-example   # runs example build against ../dock2tauri
```

Options are aligned with the Bash launcher:

- `--build, -b`
- `--target=<triple>`
- `--health-url=<url>`
- `--timeout=<seconds>`
- `--cross` (best-effort, requires proper toolchains)
- `--project-root <path>` (directory containing `src-tauri/`; auto-detected if omitted)

Environment toggles:

- `DOCK2TAURI_SKIP_APPIMAGE=1` to force skipping AppImage target on Linux
- `TAURIDO_PROJECT_ROOT=<path>` to specify the Dock2Tauri project root (alternative to `--project-root`)

Project root detection order (first match wins):

1. `TAURIDO_PROJECT_ROOT` env var
2. `--project-root` (when provided)
3. Current working directory
4. Sibling `../dock2tauri` (common layout when repos are side-by-side)
5. Parent walk from provided Dockerfile path

## Notes

- Linux AppImage tools (`linuxdeploy`, `appimagetool`) are AppImages themselves. This CLI sets `APPIMAGE_EXTRACT_AND_RUN=1` during bundling to run them without FUSE.
- Android build is best-effort and requires `cargo tauri android init` done once, plus JDK/SDK/NDK/Gradle installed.

Behavioral details:

- When the input is a Dockerfile path and `--build` is not provided, the CLI defaults to build mode and exports bundles.
- If `--target` is provided, only that target is built; without `--target`, the native target is built, and with `--cross`, best-effort cross targets are attempted if toolchains are installed.

# taurido

Python CLI that bridges Dockerized web apps into Tauri desktop apps. It mirrors the Dock2Tauri Bash launcher behavior.

- Detects available Linux bundlers (DEB/RPM/AppImage) dynamically
- Builds Tauri bundles and exports artifacts to `dist/<platform>/`
- Works best when executed from the Dock2Tauri repository root (expects `src-tauri/` there)

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

Options are aligned with the Bash launcher:

- `--build, -b`
- `--target=<triple>`
- `--health-url=<url>`
- `--timeout=<seconds>`
- `--cross` (best-effort, requires proper toolchains)

Environment toggles:

- `DOCK2TAURI_SKIP_APPIMAGE=1` to force skipping AppImage target on Linux

## Notes

- Linux AppImage tools (`linuxdeploy`, `appimagetool`) are AppImages themselves. This CLI sets `APPIMAGE_EXTRACT_AND_RUN=1` during bundling to run them without FUSE.
- Android build is best-effort and requires `cargo tauri android init` done once, plus JDK/SDK/NDK/Gradle installed.

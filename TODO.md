# Dock2Tauri — TODO and Progress Tracking

Last updated: 2025-08-17

This document tracks immediate tasks and priorities for improving Dock2Tauri. For comprehensive roadmap and long-term planning, see [docs/ROADMAP.md](docs/ROADMAP.md).

Conventions
- Priority: P0 (critical) • P1 (important) • P2 (nice-to-have)
- Status: [ ] TODO • [/] IN PROGRESS • [x] DONE • [b] BLOCKED
- Areas: tauri, launchers, ui, docs, ci, dx, packaging, security

## P0 — Immediate

- [ ] Align Tauri version across codebase (area: tauri) [P0]
  - Current state: Cargo.toml uses Tauri 2.0 crates; README/scripts claim “Tauri v1 compliant”; generated `tauri.conf.json` appears v1-style. This creates drift and potential runtime issues.
  - Decide on a single supported major (recommended: Tauri v2), then:
    - [ ] Update config generators in `scripts/dock2tauri.{sh,py,js}` to the correct schema for the chosen version.
    - [ ] Verify frontend API usage matches chosen version (e.g., `@tauri-apps/api` imports for v2).
    - [ ] Adjust installer: stop forcing CLI v1; detect via `cargo tauri --version` and enforce compatible range.
    - [ ] Smoke tests: `cargo tauri dev` and `cargo tauri build` succeed; app opens and proxies to container.
  - Acceptance: Clean build on Linux; no schema warnings; UI works.

- [ ] Launcher parity & deduplication (area: launchers, dx) [P0]
  - [ ] Add Dockerfile-path build support to Python and Node launchers (bash already supports it).
  - [ ] Normalize flags and help across bash/python/node (`--build`, `--target`, Dockerfile handling, consistent messages).
  - [ ] Extract shared logic (config writer, wait-for-service, cleanup) to a small common module or keep a single source of truth (e.g., JSON template + substitutions) to eliminate drift.
  - Acceptance: README examples work identically across all 3 launchers.

- [x] Ephemeral Tauri config (area: tauri, dx) [P0] - COMPLETED 2025-08-17
  - Problem: `src-tauri/tauri.conf.json` is mutated per run (productName/devUrl), creating noisy git diffs.
  - [x] Generate per-run config to a temporary file (or use env `TAURI_CONFIG`), keep a stable base template in repo.
  - [x] Ensure backups are cleaned up; confirm `.gitignore` covers temporary artifacts.
  - Acceptance: Running launchers does not leave uncommitted changes unless intended.

- [ ] Readiness & health checks (area: launchers, ux) [P0]
  - [ ] Prefer Docker HEALTHCHECK or configurable readiness URL/timeout over a hardcoded GET `/`.
  - [ ] Improve error messages for common failures (port in use, image not found, daemon not running).

## P1 — Important

- [ ] Developer Experience (area: dx)
  - [ ] Pre-commit hooks: `shellcheck`/`shfmt` for bash, `ruff`/`black` for Python, `eslint`/`prettier` for Node, `rustfmt`/`clippy` for Rust.
  - [ ] Makefile targets: `lint`, `format`, `test` (unified across languages).
  - [ ] Consistent logging helpers across launchers with `DOCK2TAURI_DEBUG`.

- [ ] CI/CD (area: ci)
  - [ ] GitHub Actions: lint matrix (bash/python/node/rust), minimal `cargo tauri build` check.
  - [ ] Optional docker-in-docker to test quick launch flows (best-effort, may be flaky on runners).

- [x] Documentation (area: docs) - COMPLETED 2025-08-17
  - [x] Populate `docs/`:
    - [x] `ARCHITECTURE.md` — comprehensive overview with component diagrams
    - [x] `TROUBLESHOOTING.md` — detailed guide for common issues and solutions
    - [x] `CONTRIBUTING.md` — development setup and contribution workflow
    - [x] `ROADMAP.md` — long-term vision and version planning
  - [ ] README refresh: clarify supported Tauri major; link to docs; ensure examples mirror launcher parity.

- [ ] UX improvements (area: ui, launchers)
  - [ ] Add environment variables and volume mounts configuration (UI + launcher flags).
  - [ ] Port conflict detection & suggestion of free port(s).
  - [ ] Persist user presets.

- [ ] Feature enhancements (area: launchers, packaging)
  - [ ] Volume mounting for non-Dockerfile images (map `./app` into the container via an opt-in flag).
  - [ ] Integrate manual bundling fallback (`build-bundles.sh`) when CLI bundling fails, with clear logs.

## P2 — Nice-to-have

- [ ] Cross-platform reliability (area: packaging)
  - [ ] Validate Windows/macOS builds; document codesigning/notarization and necessary SDKs.

- [ ] Telemetry (opt-in) (area: dx)
  - [ ] Basic anonymous usage metrics to understand most-used flows (behind a clear consent gate).

- [ ] Preset ecosystem (area: ux)
  - [ ] Curated presets for popular images (Grafana, Jupyter, Nginx, Portainer) with sensible defaults.

## Bugs/Tech Debt (grab bag)
- [ ] Ensure `install.sh` CLI detection uses `cargo tauri --version` and enforces the chosen major.
- [ ] Makefile `status` target: confirm it detects CLI correctly on environments where only `cargo tauri` exists.
- [ ] Improve `wait_for_service`: retries with exponential backoff, optional HEAD request.

## Recent Achievements (August 2025) ✅

- [x] **Package Manager Detection Fix** (2025-08-18)
  - Fixed `scripts/install_deps.sh` to correctly detect `dnf` on Fedora systems
  - Prioritized package manager detection based on OS ID rather than command availability
  - Added comprehensive WebKitGTK dependencies for Tauri builds on Fedora/RHEL
  - Updated troubleshooting documentation with specific Fedora installation guidance

- [x] **Cross-compilation Intelligence** (2025-08-17)
  - Intelligent target filtering based on available toolchains
  - Automatic AppImage skipping in cross-mode with override option
  - Environment variable configuration (`DOCK2TAURI_CROSS_TARGETS`)
  - Graceful handling of build failures with clear messaging

- [x] **System Dependency Management** (2025-08-17)
  - Created `scripts/install_deps.sh` with multi-distro support
  - Makefile integration with configurable flags (`APPIMAGE=1 ARM64=1 YES=1`)
  - ARM64 cross-compilation toolchain installer
  - AppImage tools installation with FUSE-less environment support

- [x] **Ephemeral Tauri Configuration** (2025-08-17)
  - Generate per-run config to temporary files
  - No git pollution or src-tauri mutations
  - Proper cleanup and `.gitignore` coverage
  - Uses `--config` flag for clean separation

- [x] **Comprehensive Documentation Suite** (2025-08-17)
  - `docs/ARCHITECTURE.md` — detailed system architecture with diagrams
  - `docs/TROUBLESHOOTING.md` — comprehensive problem-solving guide
  - `docs/CONTRIBUTING.md` — development setup and contribution workflow
  - `docs/ROADMAP.md` — long-term vision and version planning

## Done (Previous)

- [x] Create structured TODO.md and seed backlog (2025-08-16)
- [x] Multi-launcher support (Bash, Python, Node.js, Makefile)
- [x] Docker container to desktop application bridging
- [x] Cross-platform bundling (DEB, RPM, AppImage, DMG, MSI)
- [x] PWA examples and Dockerfile support

## How we work this backlog
- Prefer small, self-contained PRs.
- Every PR updates this file (section + status + date) and, when applicable, adds documentation/tests.
- Keep parity across launchers as a hard requirement for new flags/features.

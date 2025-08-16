# Dock2Tauri — TODO and Roadmap

Last updated: 2025-08-16

This document tracks tasks and priorities for improving Dock2Tauri. It focuses on alignment across Tauri version(s), launcher parity, developer experience, documentation, and packaging.

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

- [ ] Ephemeral Tauri config (area: tauri, dx) [P0]
  - Problem: `src-tauri/tauri.conf.json` is mutated per run (productName/devUrl), creating noisy git diffs.
  - [ ] Generate per-run config to a temporary file (or use env `TAURI_CONFIG`), keep a stable base template in repo.
  - [ ] Ensure backups are cleaned up; confirm `.gitignore` covers temporary artifacts.
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

- [ ] Documentation (area: docs)
  - [ ] Populate `docs/`:
    - `architecture.md` — high-level overview (launchers, Tauri app, config flow).
    - `troubleshooting.md` — Docker permissions, WebKitGTK warnings, Fedora bundling workaround.
    - `launcher-parity.md` — flag matrix and support table.
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

## Done

- [x] Create structured TODO.md and seed backlog (2025-08-16).

## How we work this backlog
- Prefer small, self-contained PRs.
- Every PR updates this file (section + status + date) and, when applicable, adds documentation/tests.
- Keep parity across launchers as a hard requirement for new flags/features.

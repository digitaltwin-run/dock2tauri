# Tauridock migration

`digitaltwin-run/dock2tauri` is the canonical Docker-to-Tauri bridge and build tool.
The former `digitaltwin-run/tauridock` repository is retained as an archived prototype.

## Why it was archived

The prototype duplicated Dock2Tauri's Docker, Tauri, platform and artifact-building responsibilities. Its package metadata and tests referenced a missing `tauri_builder` module while the implementation lived in a single `tauridock.py` file, so the published CLI could not be installed as declared and test collection failed.

Moving that implementation directly would also reintroduce a large dependency set and platform-build promises that were not backed by portable build environments.

## Capabilities to retain

Useful ideas from the prototype should be implemented in the canonical repository behind tests and narrow interfaces:

1. Build matrices belong in CI workflows with native runners for Linux, Windows and macOS.
2. Release publication and checksums belong in GitHub Actions, without passing user tokens through the application CLI.
3. Declarative build configuration may be added as a documented schema that maps directly to existing CLI options.
4. Artifact manifests and SHA-256 checksums may be generated after successful native builds.
5. A remote build API should remain a separate service adapter instead of being embedded in the local builder.

The archived repository remains available for historical reference, but new issues and changes should target Dock2Tauri.

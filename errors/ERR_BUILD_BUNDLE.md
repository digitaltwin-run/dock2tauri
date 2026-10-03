# ERR_BUILD_BUNDLE: Packaging Bundle Failure

## Error Code
`ERR_BUILD_BUNDLE`

## Description
Occurs when `tauri build` fails during binary bundling (RPM, Deb, or AppImage generation) due to invalid icons, missing metadata in `src-tauri/tauri.conf.json`, or lack of write permissions in `src-tauri/target/release/bundle/`.

## Diagnosis
```bash
ls -la src-tauri/icons/
grep -i "bundle" src-tauri/tauri.conf.json
```

## Remediation Protocol
1. Verify `src-tauri/icons/icon.png` (min 512x512) and `src-tauri/icons/icon.icns` / `.ico` exist.
2. Ensure `bundle.active` is set to `true` and targets match host OS (`["appimage", "rpm"]` on Fedora).
3. Clean old target cache:
   ```bash
   cargo clean --manifest-path src-tauri/Cargo.toml
   ```
4. Re-run `./scripts/build-bundles.sh`.

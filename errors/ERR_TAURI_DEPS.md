# ERR_TAURI_DEPS: Missing Native System Dependencies

## Error Code
`ERR_TAURI_DEPS`

## Description
Occurs when the host system lacks required native development libraries (such as `webkit2gtk-4.1-devel`, `openssl-devel`, or `cargo/rustc`) necessary for compiling the Tauri desktop wrapper.

## Diagnosis
```bash
cargo --version || rustc --version
pkg-config --modversion webkit2gtk-4.1 || pkg-config --modversion webkit2gtk-4.0
```

## Remediation Protocol
1. **Fedora / RHEL**:
   ```bash
   sudo dnf install -y webkit2gtk4.1-devel openssl-devel curl wget squashfs-tools
   ```
2. **Debian / Ubuntu**:
   ```bash
   sudo apt-get install -y libwebkit2gtk-4.1-dev build-essential curl wget libssl-dev libgtk-3-dev
   ```
3. Re-run `taurido check` or `cargo check --manifest-path src-tauri/Cargo.toml`.

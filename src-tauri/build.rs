fn main() {
  // Ensure a placeholder icon exists to satisfy tauri-build during dev
  ensure_placeholder_icon();
  tauri_build::build()
}

fn ensure_placeholder_icon() {
  use std::fs;
  use std::io::Write;
  use std::path::Path;

  let icons_dir = Path::new("icons");
  let icon_path = icons_dir.join("icon.png");
  if icon_path.exists() {
    return;
  }
  // Create directory if needed
  if !icons_dir.exists() {
    if let Err(e) = fs::create_dir_all(&icons_dir) {
      eprintln!("warning: failed to create icons directory: {e}");
      return;
    }
  }
  // Minimal 1x1 PNG (opaque black pixel)
  // This is a valid PNG file content.
  const ICON_BYTES: &[u8] = &[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
    0xDE, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
    0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D, 0x8F, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
    0x44, 0xAE, 0x42, 0x60, 0x82,
  ];
  match fs::File::create(&icon_path) {
    Ok(mut f) => {
      if let Err(e) = f.write_all(ICON_BYTES) {
        eprintln!("warning: failed to write placeholder icon: {e}");
      }
    }
    Err(e) => eprintln!("warning: failed to create placeholder icon: {e}"),
  }
}

// Note: do not set TAURI_CONFIG here; the env var is expected to contain JSON, not a file path.

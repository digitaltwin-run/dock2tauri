fn main() {
  // Rebuild only if these files change
  println!("cargo:rerun-if-changed=build.rs");
  println!("cargo:rerun-if-changed=icons/icon.png");
  // Ensure a placeholder icon exists to satisfy tauri-build during dev
  ensure_placeholder_icon();
  tauri_build::build()
}

fn ensure_placeholder_icon() {
  use std::fs;
  use std::path::Path;

  let icons_dir = Path::new("icons");
  let icon_path = icons_dir.join("icon.png");
  // Create directory if needed
  if !icons_dir.exists() {
    if let Err(e) = fs::create_dir_all(&icons_dir) {
      eprintln!("warning: failed to create icons directory: {e}");
      return;
    }
  }
  if icon_path.exists() {
    // Leave existing icon untouched to avoid dev rebuild loops
    return;
  } else {
    write_placeholder_rgba_png(&icon_path);
  }
}

fn write_placeholder_rgba_png<P: AsRef<std::path::Path>>(path: P) {
  use image::{Rgba, RgbaImage};
  let mut img = RgbaImage::new(1, 1);
  img.put_pixel(0, 0, Rgba([0, 0, 0, 0]));
  if let Err(e) = img.save(path) {
    eprintln!("warning: failed to write placeholder RGBA icon: {e}");
  }
}

// Note: do not set TAURI_CONFIG here; the env var is expected to contain JSON, not a file path.

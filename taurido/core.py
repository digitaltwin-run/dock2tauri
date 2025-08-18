from __future__ import annotations

import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import time
from glob import glob
from pathlib import Path
from typing import Iterable, List, Optional


BLUE = "\033[0;34m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
NC = "\033[0m"


def log_info(msg: str) -> None:
    print(f"{BLUE}ℹ️  {msg}{NC}")


def log_success(msg: str) -> None:
    print(f"{GREEN}✅ {msg}{NC}")


def log_warning(msg: str) -> None:
    print(f"{YELLOW}⚠️  {msg}{NC}")


def log_error(msg: str) -> None:
    print(f"{RED}❌ {msg}{NC}")


class Runner:
    def __init__(self, base_dir: Optional[Path] = None, export_dir: Optional[Path] = None, launch_after_build: bool = False, list_bundles: bool = False) -> None:
        self.base_dir = Path(base_dir) if base_dir else Path.cwd()
        self.src_tauri = self.base_dir / "src-tauri"
        self.export_dir = Path(export_dir) if export_dir else self.base_dir / "dist"
        self.launch_after_build = launch_after_build
        self.list_bundles = list_bundles
        self.tauri_config_path: Optional[Path] = None
        self.container_name: Optional[str] = None
        # Candidate cross targets
        self.candidate_targets = [
            "x86_64-unknown-linux-gnu",
            "aarch64-unknown-linux-gnu",
            "x86_64-pc-windows-gnu",
            "x86_64-apple-darwin",
            "aarch64-apple-darwin",
        ]

    # ---------- Public flows ----------
    def dev_flow(
        self,
        image_or_dockerfile: str,
        host_port: str,
        container_port: str,
        health_url: Optional[str],
        timeout: int,
    ) -> None:
        self._check_docker()
        self._ensure_project_root(image_or_dockerfile)
        image, dockerfile = self._build_docker_if_needed(image_or_dockerfile)
        self._launch_container(image, host_port, container_port)
        self._wait_for_service(health_url or f"http://localhost:{host_port}", timeout)
        self._generate_tauri_config(
            docker_image=image,
            host_port=host_port,
            build_release=False,
            dockerfile_path=dockerfile,
            docker_build_ctx=dockerfile.parent if dockerfile else None,
        )
        self._cargo_tauri_dev()

    def build_flow(
        self,
        image_or_dockerfile: str,
        host_port: str,
        container_port: str,
        target: str,
        cross: bool,
        health_url: Optional[str],
        timeout: int,
    ) -> None:
        self._check_docker()
        self._ensure_project_root(image_or_dockerfile)
        image, dockerfile = self._build_docker_if_needed(image_or_dockerfile)
        self._generate_tauri_config(
            docker_image=image,
            host_port=host_port,
            build_release=True,
            dockerfile_path=dockerfile,
            docker_build_ctx=dockerfile.parent if dockerfile else None,
        )
        self.export_dir.mkdir(parents=True, exist_ok=True)
        # If explicit target provided, build only that
        if target:
            self._build_for_target(target)
            self._copy_bundles_to_dist(target)
        else:
            # Build native first
            self._build_for_target("")
            self._copy_bundles_to_dist("")
            # Cross best-effort
            if cross:
                for t in self.candidate_targets:
                    if t and self._is_rust_target_installed(t):
                        self._build_for_target(t)
                        self._copy_bundles_to_dist(t)
                    else:
                        log_warning(f"Skipping target {t} (rustup target not installed)")
        # Android best-effort
        self._build_android_best_effort()
        self._generate_dist_root_readme()
        log_success(f"All available bundles exported to: {self.export_dir}")
        
        # List bundle contents if requested
        if self.list_bundles:
            self._list_bundle_contents()
            
        # Launch application if requested
        if self.launch_after_build:
            self._launch_application()

    def cleanup(self) -> None:
        if self.tauri_config_path and self.tauri_config_path.exists():
            try:
                self.tauri_config_path.unlink()
                log_success("Removed ephemeral Tauri config")
            except Exception:
                pass
        if self.container_name:
            # Best-effort stop and remove
            subprocess.run(["docker", "stop", self.container_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["docker", "rm", self.container_name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            log_success("Container stopped and removed")

    # ---------- Helpers ----------
    def _check_docker(self) -> None:
        log_info("Checking dependencies...")
        if shutil.which("docker") is None:
            log_error("Docker not found. Please install Docker first.")
            raise SystemExit(1)
        if shutil.which("cargo") is None:
            log_warning("Rust/Cargo not found. Some features may not work.")
        # Check daemon
        rc = subprocess.run(["docker", "info"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
        if rc != 0:
            log_error("Docker daemon not running. Please start Docker.")
            raise SystemExit(1)
        log_success("Dependencies check passed")

    def _build_docker_if_needed(self, image_or_dockerfile: str) -> tuple[str, Optional[Path]]:
        p = Path(image_or_dockerfile)
        dockerfile: Optional[Path] = None
        # Resolve relative to CWD first, then project root if not found
        if p.is_file():
            dockerfile = p
        elif not p.is_absolute():
            candidate = (self.base_dir / p)
            if candidate.is_file():
                dockerfile = candidate
        if dockerfile is not None:
            ctx = dockerfile.parent
            tag_base = re.sub(r"[^a-z0-9_.-]", "-", dockerfile.name.lower())
            tag = f"dock2tauri-local-{tag_base}-{int(time.time())}"
            log_info(f"Building Docker image from {dockerfile} (context: {ctx}) as {tag} ...")
            cmd = ["docker", "build", "-f", str(dockerfile), "-t", tag, str(ctx)]
            self._run(cmd)
            return tag, dockerfile
        return image_or_dockerfile, None

    def _launch_container(self, image: str, host_port: str, container_port: str) -> None:
        safe_name = re.sub(r"[^a-zA-Z0-9]", "-", image)
        self.container_name = f"dock2tauri-{safe_name}-{host_port}"
        log_info("Launching Docker container...")
        log_info(f"Image: {image}")
        log_info(f"Host Port: {host_port}")
        log_info(f"Container Port: {container_port}")
        cmd = [
            "docker",
            "run",
            "-d",
            "-p",
            f"{host_port}:{container_port}",
            "--name",
            self.container_name,
            "--restart",
            "unless-stopped",
            image,
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            log_success(f"Container launched: {res.stdout.strip()}")
            log_success(f"Access at: http://localhost:{host_port}")
        else:
            log_error(f"Failed to launch container: {res.stderr.strip() or res.stdout.strip()}")
            raise SystemExit(res.returncode)

    def _wait_for_service(self, url: str, timeout: int) -> None:
        import urllib.request
        log_info("Waiting for service to be ready...")
        start = time.time()
        while (time.time() - start) < timeout:
            try:
                with urllib.request.urlopen(url, timeout=1):
                    log_success("Service is ready!")
                    return
            except Exception:
                time.sleep(1)
                print(".", end="", flush=True)
        print()
        log_warning("Service might not be ready yet, but continuing...")

    def _generate_tauri_config(
        self,
        docker_image: str,
        host_port: str,
        build_release: bool,
        dockerfile_path: Optional[str | Path],
        docker_build_ctx: Optional[Path],
    ) -> None:
        log_info("Preparing Tauri configuration (ephemeral)...")
        fd, tmp_path = tempfile.mkstemp(prefix="tauri.conf.", suffix=".json")
        os.close(fd)
        self.tauri_config_path = Path(tmp_path)

        # frontendDist selection
        if dockerfile_path:
            frontend_dist = str((docker_build_ctx or Path(".")).resolve() / "app")
        else:
            frontend_dist = "../app"

        dev_url = None if build_release else f"http://localhost:{host_port}"

        # Dynamic bundler targets
        targets: List[str] = []
        bundle_active = True
        os_name = platform.system().lower()
        if os_name == "linux":
            if shutil.which("dpkg-deb"):
                targets.append("deb")
            else:
                log_warning("dpkg-deb not found; skipping DEB bundle.")
            if shutil.which("rpmbuild"):
                targets.append("rpm")
            else:
                log_warning("rpmbuild not found; skipping RPM bundle.")
            skip_appimage = os.environ.get("DOCK2TAURI_SKIP_APPIMAGE", "0") == "1"
            if skip_appimage:
                log_warning("DOCK2TAURI_SKIP_APPIMAGE=1 set; skipping AppImage bundle.")
            else:
                if shutil.which("linuxdeploy") and shutil.which("appimagetool"):
                    if self._appimage_tools_runnable():
                        targets.append("appimage")
                    else:
                        log_warning("linuxdeploy/appimagetool present but not runnable; skipping AppImage bundle.")
                else:
                    log_warning("linuxdeploy/appimagetool not found; skipping AppImage bundle.")
            if not targets:
                bundle_active = False
                log_warning("No Linux packagers found (dpkg-deb/rpmbuild/appimagetool). Bundling will be disabled.")
        elif os_name == "darwin":
            targets = ["dmg", "app"]
        elif os_name.startswith("msys") or os_name.startswith("mingw") or os_name.startswith("cygwin") or os_name == "windows":
            targets = ["nsis", "msi"]

        cfg = {
            "$schema": "../node_modules/@tauri-apps/cli/schema.json",
            "productName": f"Dock2Tauri-{re.sub(r'[/:*?\"<>|]', '', docker_image.split(':')[0])}",
            "version": "1.0.0",
            "identifier": f"com.dock2tauri.{re.sub(r'[^a-zA-Z0-9]', '', docker_image)}",
            "build": {
                "beforeBuildCommand": "",
                "beforeDevCommand": "",
                "devUrl": dev_url,
                "frontendDist": frontend_dist,
            },
            "app": {
                "security": {"csp": None},
                "windows": [
                    {
                        "title": f"Dock2Tauri-{docker_image}",
                        "width": 1200,
                        "height": 800,
                        "minWidth": 600,
                        "minHeight": 400,
                        "resizable": True,
                        "fullscreen": False,
                    }
                ],
            },
            "bundle": {
                "active": bundle_active,
                "targets": targets,
                "icon": [str(self.src_tauri / "icons" / "icon.png")],
                "resources": [],
                "externalBin": [],
                "copyright": "",
                "category": "DeveloperTool",
                "shortDescription": "Docker App in Tauri",
                "longDescription": f"Running {docker_image} as desktop application",
            },
            "plugins": {},
        }
        with open(self.tauri_config_path, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
        log_success(f"Ephemeral Tauri configuration prepared at {self.tauri_config_path}")

    # --- project root detection ---
    def _ensure_project_root(self, image_or_dockerfile: str) -> None:
        """Ensure self.base_dir points to a directory containing src-tauri/.

        Resolution order:
        1) TAURIDO_PROJECT_ROOT env var
        2) Provided self.base_dir if it has src-tauri
        3) Current working directory if it has src-tauri
        4) Sibling ../dock2tauri if it has src-tauri (common layout)
        5) Parent-walk from Dockerfile path (if it exists) to find src-tauri
        Fallback: keep current and error later if not found.
        """
        # 1) Env var
        env_root = os.environ.get("TAURIDO_PROJECT_ROOT")
        candidates = []
        if env_root:
            candidates.append(Path(env_root))
        # 2) Provided base_dir
        candidates.append(self.base_dir)
        # 3) CWD
        candidates.append(Path.cwd())
        # 4) Sibling ../dock2tauri
        candidates.append(Path.cwd().parent / "dock2tauri")
        # 5) Parent-walk from Dockerfile path
        p = Path(image_or_dockerfile)
        try:
            if p.is_file():
                for parent in [p.parent] + list(p.parents):
                    candidates.append(parent)
        except Exception:
            pass

        for c in candidates:
            try:
                if (c / "src-tauri").is_dir():
                    # Update internal paths
                    old_export_dir = self.export_dir
                    self.base_dir = c
                    self.src_tauri = c / "src-tauri"
                    # Only update export_dir if it wasn't explicitly set
                    if old_export_dir == self.base_dir / "dist":
                        self.export_dir = c / "dist"
                    return
            except Exception:
                continue
        # No change if not found; subsequent steps will fail with clear message when accessing src-tauri

    def _appimage_tools_runnable(self) -> bool:
        env = os.environ.copy()
        env.setdefault("APPIMAGE_EXTRACT_AND_RUN", "1")
        ok1 = subprocess.run(["linuxdeploy", "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env).returncode == 0
        ok2 = subprocess.run(["appimagetool", "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env).returncode == 0
        return ok1 and ok2

    def _cargo_tauri_dev(self) -> None:
        if not self.tauri_config_path:
            raise RuntimeError("Tauri config not generated")
        cmd = ["cargo", "tauri", "dev", "--config", str(self.tauri_config_path)]
        self._run(cmd, cwd=self.src_tauri)

    def _build_for_target(self, target: str) -> None:
        if not self.tauri_config_path:
            raise RuntimeError("Tauri config not generated")
        args = ["cargo", "tauri", "build", "--config", str(self.tauri_config_path)]
        if target:
            args += ["--target", target]
        env = os.environ.copy()
        # Help linuxdeploy/appimagetool work without FUSE
        if shutil.which("linuxdeploy") or shutil.which("appimagetool"):
            env.setdefault("APPIMAGE_EXTRACT_AND_RUN", "1")
        log_info(f"Building bundles for target: {target or 'native'} ...")
        res = subprocess.run(args, cwd=self.src_tauri, env=env)
        if res.returncode != 0:
            log_warning(f"Build failed for target {target or 'native'}; exporting any bundles produced before failure.")

    def _copy_bundles_to_dist(self, target: str) -> None:
        platform_folder = self._map_target_to_platform(target)
        if target:
            src_dir = self.src_tauri / "target" / target / "release" / "bundle"
        else:
            src_dir = self.src_tauri / "target" / "release" / "bundle"
        if not src_dir.exists():
            log_warning(f"No bundles found at {src_dir}")
            return
        dest_dir = self.export_dir / platform_folder
        dest_dir.mkdir(parents=True, exist_ok=True)
        # Copy files (depth up to 2) and subfolders
        for path in src_dir.rglob("*"):
            try:
                if path.is_file():
                    shutil.copy2(path, dest_dir / path.name)
            except Exception:
                pass
        try:
            # Also copy structure for completeness
            for sub in src_dir.iterdir():
                dst_sub = dest_dir / sub.name
                if sub.is_dir():
                    if dst_sub.exists():
                        continue
                    shutil.copytree(sub, dst_sub, dirs_exist_ok=True)
        except Exception:
            pass
        log_success(f"Exported bundles to {dest_dir}")
        self._generate_platform_readme(dest_dir, platform_folder)

    def _map_target_to_platform(self, t: str) -> str:
        if not t:
            os_name = platform.system().lower()
            arch = platform.machine().lower()
            if os_name == "linux":
                return "linux-x64" if arch in ("x86_64", "amd64") else f"linux-{arch}"
            if os_name == "darwin":
                return "macos-arm64" if arch in ("arm64", "aarch64") else "macos-x64"
            if os_name.startswith("msys") or os_name.startswith("mingw") or os_name.startswith("cygwin") or os_name == "windows":
                return "windows-x64"
            return f"{os_name}-{arch}"
        mapping = {
            "aarch64-unknown-linux-gnu": "linux-arm64",
            "x86_64-unknown-linux-gnu": "linux-x64",
            "x86_64-pc-windows-gnu": "windows-x64",
            "x86_64-apple-darwin": "macos-x64",
            "aarch64-apple-darwin": "macos-arm64",
        }
        return mapping.get(t, t)

    def _is_rust_target_installed(self, target: str) -> bool:
        if shutil.which("rustup") is None:
            return False
        res = subprocess.run(["rustup", "target", "list", "--installed"], capture_output=True, text=True)
        if res.returncode != 0:
            return False
        installed = [line.strip().split()[0] for line in res.stdout.splitlines() if line.strip()]
        return target in installed

    def _build_android_best_effort(self) -> None:
        if shutil.which("cargo") is None:
            return
        # Check tauri CLI
        if subprocess.run(["cargo", "tauri", "--help"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
            log_warning("Tauri CLI not available; skipping Android build.")
            return
        # Check Android SDK presence
        if not (os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME") or shutil.which("sdkmanager")):
            log_warning("Android SDK not detected; skipping Android build.")
            return
        # Ensure project initialized
        if not (self.src_tauri / "gen" / "android").is_dir():
            log_warning("Android project not initialized; run 'cargo tauri android init' once (in src-tauri). Skipping Android build.")
            return
        log_info("Attempting Android APK build (best-effort)...")
        args = [
            "cargo",
            "tauri",
            "android",
            "build",
            "--config",
            str(self.tauri_config_path),
            "--",
            "--release",
        ]
        res = subprocess.run(args, cwd=self.src_tauri)
        if res.returncode != 0:
            log_warning("Android build failed; skipping export.")
            return
        dest_dir = self.export_dir / "android-apk"
        dest_dir.mkdir(parents=True, exist_ok=True)
        for apk in self.src_tauri.rglob("*.apk"):
            try:
                shutil.copy2(apk, dest_dir / apk.name)
            except Exception:
                pass
        if not any(dest_dir.iterdir()):
            log_warning("No APK artifacts found after build.")
            return
        readme = dest_dir / "README.md"
        readme.write_text(
            "\n".join(
                [
                    "# Dock2Tauri - Android APK",
                    "",
                    "This folder contains Android APK builds (best-effort).",
                    "",
                    "Install:",
                    "- Enable installing from unknown sources.",
                    "- Transfer the APK and install, or use:",
                    "  adb install <file.apk>",
                    "",
                    "Note: Requires Android SDK/NDK, Java, and Gradle properly configured.",
                ]
            ),
            encoding="utf-8",
        )
        log_success(f"Exported Android APKs to: {dest_dir}")

    def _generate_platform_readme(self, dest_dir: Path, platform_folder: str) -> None:
        content = f"""# Dock2Tauri - {platform_folder}

This folder contains packaged desktop application bundles produced by Tauri for platform: {platform_folder}.

## Install & Run

### Linux (AppImage)
- Make executable and run:
  ```bash
  chmod +x ./*.AppImage
  ./Dock2Tauri*.AppImage
  ```

### Linux (.deb)
- Install the package:
  ```bash
  sudo dpkg -i ./Dock2Tauri*.deb || sudo apt --fix-broken install -y && sudo dpkg -i ./Dock2Tauri*.deb
  ```

### Linux (.rpm)
- Install the package:
  ```bash
  sudo dnf install ./Dock2Tauri*.rpm
  # or
  sudo rpm -i ./Dock2Tauri*.rpm
  ```

### Windows (.exe / NSIS)
- Run the installer (or portable exe) and follow the prompts.

### Windows (.msi)
- Double click the MSI and follow the installer.

### macOS (.dmg / .app)
- Open the DMG, drag the app to Applications, then launch it.

## Notes
- Some bundle formats may not be present depending on your host OS and installed packagers.
- To build additional targets, ensure Rust target toolchains and packaging tools are installed.
"""
        (dest_dir / "README.md").write_text(content, encoding="utf-8")

    def _generate_dist_root_readme(self) -> None:
        readme = self.export_dir / "README.md"
        lines = [
            "# Dock2Tauri - Distribution Artifacts",
            "",
            "This directory contains packaged application bundles per platform.",
            "",
            "## Available Platforms",
        ]
        for d in sorted(p.name for p in self.export_dir.iterdir() if p.is_dir()):
            lines.append(f"- {d}")
        lines.append("")
        lines.append("Each platform folder has its own README.md with installation instructions.")
        readme.write_text("\n".join(lines), encoding="utf-8")

    def _launch_application(self) -> None:
        """Launch the built application after successful bundle creation."""
        log_info("Attempting to launch the built application...")
        
        # Look for executables in the export directory
        linux_x64_dir = self.export_dir / "linux-x64"
        if not linux_x64_dir.exists():
            log_warning("No linux-x64 export directory found; cannot launch application.")
            return
            
        # Find the built executable in src-tauri/target/release/
        release_dir = self.src_tauri / "target" / "release"
        if not release_dir.exists():
            log_warning("No release build directory found; cannot launch application.")
            return
            
        # Look for the main executable (usually the app name from Cargo.toml)
        executable_path = None
        for potential_exe in release_dir.iterdir():
            if (potential_exe.is_file() and 
                potential_exe.stat().st_mode & 0o111 and  # Executable permission
                not potential_exe.name.endswith('.d') and
                not potential_exe.name.startswith('build-') and
                not potential_exe.name.startswith('deps')):
                executable_path = potential_exe
                break
                
        if not executable_path:
            log_warning("No executable found in release directory; cannot launch application.")
            return
            
        try:
            log_info(f"Launching application: {executable_path.name}")
            # Launch in background with nohup to detach from terminal
            subprocess.Popen(
                ["nohup", str(executable_path)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                preexec_fn=os.setsid  # Create new process group
            )
            log_success(f"✨ Application launched: {executable_path.name}")
        except Exception as e:
            log_error(f"Failed to launch application: {e}")

    # ---------- Utilities ----------
    def _run(self, cmd: List[str], cwd: Optional[Path] = None) -> None:
        res = subprocess.run(cmd, cwd=cwd, env=os.environ.copy())
        if res.returncode != 0:
            raise SystemExit(res.returncode)

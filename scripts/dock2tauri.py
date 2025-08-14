#!/usr/bin/env python3

"""
Dock2Tauri Python Launcher
Transform any Docker container into a native desktop application using Tauri.

Usage: python dock2tauri.py --image nginx:alpine --host-port 8088 --container-port 80
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

class Logger:
    @staticmethod
    def info(message):
        print(f"{Colors.BLUE}ℹ️  {message}{Colors.NC}")

    @staticmethod
    def success(message):
        print(f"{Colors.GREEN}✅ {message}{Colors.NC}")

    @staticmethod
    def error(message):
        print(f"{Colors.RED}❌ {message}{Colors.NC}")

    @staticmethod
    def warning(message):
        print(f"{Colors.YELLOW}⚠️  {message}{Colors.NC}")

class Dock2Tauri:
    def __init__(self, image, host_port, container_port, build_release=False, build_target=None):
        self.image = image
        self.host_port = str(host_port)
        self.container_port = str(container_port)
        self.container_name = f"dock2tauri-{image.replace(':', '-').replace('/', '-')}-{host_port}"
        self.container_id = None
        self.script_dir = Path(__file__).parent
        self.base_dir = self.script_dir.parent
        self.config_file = self.base_dir / "src-tauri" / "tauri.conf.json"
        self.build_release = build_release
        self.build_target = build_target

    def check_dependencies(self):
        """Check if required dependencies are available."""
        Logger.info("Checking dependencies...")
        
        if not self._command_exists("docker"):
            Logger.error("Docker not found. Please install Docker first.")
            return False
        
        if not self._command_exists("cargo"):
            Logger.warning("Rust/Cargo not found. Some features may not work.")
        
        try:
            subprocess.run(["docker", "info"], check=True, capture_output=True)
        except subprocess.CalledProcessError:
            Logger.error("Docker daemon not running. Please start Docker.")
            return False
        
        Logger.success("Dependencies check passed")
        return True

    def _command_exists(self, command):
        """Check if a command exists in the system PATH."""
        return subprocess.run(
            ["which", command], 
            capture_output=True, 
            text=True
        ).returncode == 0

    def stop_existing_containers(self):
        """Stop containers using the same port."""
        Logger.info(f"Stopping existing containers on port {self.host_port}...")
        
        try:
            # Get containers using the same port
            result = subprocess.run([
                "docker", "ps", "-q", "--filter", f"publish={self.host_port}"
            ], capture_output=True, text=True)
            
            if result.stdout.strip():
                container_ids = result.stdout.strip().split('\n')
                for container_id in container_ids:
                    subprocess.run(["docker", "stop", container_id], 
                                 capture_output=True)
                Logger.success("Stopped existing containers")
            
            # Remove old container with same name
            result = subprocess.run([
                "docker", "ps", "-a", "--filter", f"name={self.container_name}"
            ], capture_output=True, text=True)
            
            if self.container_name in result.stdout:
                subprocess.run(["docker", "rm", self.container_name], 
                             capture_output=True)
                Logger.success(f"Removed old container: {self.container_name}")
                
        except Exception as e:
            Logger.warning(f"Error during cleanup: {e}")

    def launch_container(self):
        """Launch the Docker container."""
        Logger.info("Launching Docker container...")
        Logger.info(f"Image: {self.image}")
        Logger.info(f"Host Port: {self.host_port}")
        Logger.info(f"Container Port: {self.container_port}")
        
        try:
            result = subprocess.run([
                "docker", "run", "-d",
                "-p", f"{self.host_port}:{self.container_port}",
                "--name", self.container_name,
                "--restart", "unless-stopped",
                self.image
            ], capture_output=True, text=True, check=True)
            
            self.container_id = result.stdout.strip()
            Logger.success(f"Container launched: {self.container_id}")
            Logger.success(f"Access at: http://localhost:{self.host_port}")
            return True
            
        except subprocess.CalledProcessError as e:
            Logger.error("Failed to launch container")
            Logger.error(f"Error: {e.stderr}")
            return False

    def wait_for_service(self):
        """Wait for the service to be ready."""
        Logger.info("Waiting for service to be ready...")
        
        for i in range(30):
            try:
                with urllib.request.urlopen(
                    f"http://localhost:{self.host_port}", 
                    timeout=1
                ) as response:
                    if response.status == 200:
                        Logger.success("Service is ready!")
                        return True
            except:
                print(".", end="", flush=True)
                time.sleep(1)
        
        print()  # New line
        Logger.warning("Service might not be ready yet, but continuing...")
        return False

    def update_tauri_config(self):
        """Update Tauri configuration with Docker URL."""
        Logger.info("Updating Tauri configuration...")
        
        # Create backup
        backup_file = self.config_file.with_suffix('.json.backup')
        if self.config_file.exists():
            import shutil
            shutil.copy2(self.config_file, backup_file)
        
        config = {
            "$schema": "../node_modules/@tauri-apps/cli/schema.json",
            "productName": f"Dock2Tauri - {''.join(c for c in self.image.split(':')[0] if c not in '/\\:*?\"<>|')}",
            "version": "1.0.0",
            "identifier": f"com.dock2tauri.{''.join(c for c in self.image if c.isalnum())}",
            "build": {
                "beforeBuildCommand": "",
                "beforeDevCommand": "",
                "devUrl": f"http://localhost:{self.host_port}",
                "frontendDist": "../app"
            },
            "app": {
                "security": {
                    "csp": None
                },
                "windows": [{
                    "title": f"Dock2Tauri - {self.image}",
                    "width": 1200,
                    "height": 800,
                    "minWidth": 600,
                    "minHeight": 400,
                    "resizable": True,
                    "fullscreen": False
                }]
            },
            "bundle": {
                "active": True,
                "targets": ["appimage", "deb", "rpm"],
                "icon": [],
                "resources": [],
                "externalBin": [],
                "copyright": "",
                "category": "DeveloperTool",
                "shortDescription": "Docker App in Tauri",
                "longDescription": f"Running {self.image} as desktop application"
            },
            "plugins": {}
        }
        
        try:
            with open(self.config_file, 'w') as f:
                json.dump(config, f, indent=2)
            Logger.success("Tauri configuration updated")
            return True
        except Exception as e:
            Logger.error(f"Failed to update Tauri config: {e}")
            return False

    def launch_tauri(self):
        """Launch the Tauri application."""
        if self.build_release:
            Logger.info("Building Tauri release bundles (cargo tauri build)...")
        else:
            Logger.info("Launching Tauri application (dev)...")
        
        tauri_dir = self.script_dir.parent / "src-tauri"
        
        try:
            os.chdir(tauri_dir)
            
            # Build command based on flags
            if self.build_release:
                if self.build_target:
                    cmd = ["cargo", "tauri", "build", "--target", self.build_target]
                else:
                    cmd = ["cargo", "tauri", "build"]
            else:
                cmd = ["cargo", "tauri", "dev"]
            
            # Try Tauri CLI first
            if self._command_exists("cargo"):
                subprocess.run(cmd, check=True)
            else:
                Logger.error("Cargo not found. Please install Rust and Tauri CLI.")
                Logger.info(f"Container is running at: http://localhost:{self.host_port}")
                Logger.info(f"Container ID: {self.container_id}")
                return False
                
        except subprocess.CalledProcessError as e:
            Logger.error(f"Failed to launch Tauri: {e}")
            return False
        except KeyboardInterrupt:
            Logger.info("Application interrupted by user")
            return True
        
        return True

    def cleanup(self):
        """Clean up resources."""
        Logger.info("Cleaning up...")
        
        if self.container_id:
            try:
                subprocess.run(["docker", "stop", self.container_id], 
                             capture_output=True)
                subprocess.run(["docker", "rm", self.container_id], 
                             capture_output=True)
                Logger.success("Container stopped and removed")
            except Exception as e:
                Logger.warning(f"Error during container cleanup: {e}")
        
        # Restore config backup
        backup_file = self.config_file.with_suffix('.json.backup')
        if backup_file.exists():
            backup_file.rename(self.config_file)
            Logger.success("Tauri configuration restored")

    def run(self):
        """Main execution flow."""
        print(f"{Colors.BLUE}🐳🦀 Dock2Tauri - Docker to Desktop Bridge{Colors.NC}")
        print("==================================================")
        
        try:
            if not self.check_dependencies():
                return False
            
            self.stop_existing_containers()
            
            if not self.launch_container():
                return False
            
            self.wait_for_service()
            self.update_tauri_config()
            
            # Launch Tauri (this will block until app exits)
            self.launch_tauri()
            
        except KeyboardInterrupt:
            Logger.info("Interrupted by user")
        except Exception as e:
            Logger.error(f"Unexpected error: {e}")
            return False
        finally:
            self.cleanup()
        
        return True

def main():
    parser = argparse.ArgumentParser(
        description="Dock2Tauri - Transform Docker containers into desktop apps"
    )
    parser.add_argument(
        "--image", "-i",
        default="nginx:alpine",
        help="Docker image to run (default: nginx:alpine)"
    )
    parser.add_argument(
        "--host-port", "-p",
        type=int,
        default=8088,
        help="Host port to bind to (default: 8088)"
    )
    parser.add_argument(
        "--container-port", "-c",
        type=int,
        default=80,
        help="Container port to expose (default: 80)"
    )
    parser.add_argument(
        "--build",
        action="store_true",
        help="Build Tauri application"
    )
    parser.add_argument(
        "--target",
        help="Build target for Tauri application"
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug mode"
    )
    
    args = parser.parse_args()
    
    if args.debug:
        import logging
        logging.basicConfig(level=logging.DEBUG)
    
    # Create and run Dock2Tauri instance
    dock2tauri = Dock2Tauri(args.image, args.host_port, args.container_port, args.build, args.target)
    
    success = dock2tauri.run()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

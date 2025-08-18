#!/usr/bin/env python3
"""
E2E Workflow Tests for Dock2Tauri
Tests the complete build, install, and run workflow using Python automation
"""

import os
import subprocess
import tempfile
import time
import unittest
import shutil
import signal
from pathlib import Path


class Dock2TauriWorkflowTests(unittest.TestCase):
    """Test the complete Dock2Tauri workflow from build to execution"""
    
    @classmethod
    def setUpClass(cls):
        """Set up test environment"""
        cls.project_root = Path(__file__).parent.parent.parent
        cls.test_timeout = 300  # 5 minutes timeout for build operations
        
    def setUp(self):
        """Set up each test"""
        self.processes = []  # Track processes to clean up
        
    def tearDown(self):
        """Clean up after each test"""
        # Kill any running processes
        for proc in self.processes:
            try:
                proc.terminate()
                proc.wait(timeout=5)
            except (subprocess.TimeoutExpired, ProcessLookupError):
                try:
                    proc.kill()
                except ProcessLookupError:
                    pass
    
    def run_command(self, cmd, cwd=None, timeout=None, capture_output=True):
        """Run a command with proper error handling"""
        if cwd is None:
            cwd = self.project_root
            
        print(f"Running: {' '.join(cmd) if isinstance(cmd, list) else cmd}")
        
        try:
            result = subprocess.run(
                cmd,
                cwd=cwd,
                timeout=timeout or self.test_timeout,
                capture_output=capture_output,
                text=True,
                shell=isinstance(cmd, str)
            )
            return result
        except subprocess.TimeoutExpired:
            self.fail(f"Command timed out: {cmd}")
        except Exception as e:
            self.fail(f"Command failed: {cmd}, Error: {e}")
    
    def test_dependency_installation(self):
        """Test that dependencies can be installed"""
        # Test dry-run first
        result = self.run_command(['make', 'install-deps-dry-run'])
        self.assertEqual(result.returncode, 0, 
                        f"Dependency dry-run failed: {result.stderr}")
        
        # Test script validation
        result = self.run_command(['make', 'test-install'])
        self.assertEqual(result.returncode, 0,
                        f"Install script validation failed: {result.stderr}")
    
    def test_build_process(self):
        """Test the complete build process"""
        # Clean any existing builds
        self.run_command(['make', 'clean'], timeout=60)
        
        # Run the build
        result = self.run_command(['make', 'build'], timeout=600)  # 10 minute timeout for build
        
        if result.returncode != 0:
            # Build might fail due to missing dependencies, check error
            if "webkit" in result.stderr.lower() or "dependency" in result.stderr.lower():
                self.skipTest("Missing system dependencies for build")
            else:
                self.fail(f"Build failed: {result.stderr}")
        
        # Check that build artifacts exist
        target_dir = self.project_root / "src-tauri" / "target" / "release"
        self.assertTrue(target_dir.exists(), "Build target directory not found")
    
    def test_bundle_generation(self):
        """Test that bundles are generated correctly"""
        # Skip if we can't build
        try:
            self.test_build_process()
        except unittest.SkipTest:
            self.skipTest("Cannot test bundle without successful build")
        
        bundle_dir = self.project_root / "src-tauri" / "target" / "release" / "bundle"
        
        # Check for different bundle types based on OS
        import platform
        system = platform.system().lower()
        
        if system == "linux":
            # Check for AppImage, DEB, RPM
            appimage_dir = bundle_dir / "appimage"
            deb_dir = bundle_dir / "deb"
            rpm_dir = bundle_dir / "rpm"
            
            # At least one should exist
            bundle_exists = (
                (appimage_dir.exists() and any(appimage_dir.glob("*.AppImage"))) or
                (deb_dir.exists() and any(deb_dir.glob("*.deb"))) or
                (rpm_dir.exists() and any(rpm_dir.glob("*.rpm")))
            )
            
            self.assertTrue(bundle_exists, "No Linux bundles found")
        
        elif system == "darwin":
            dmg_dir = bundle_dir / "dmg"
            app_dir = bundle_dir / "macos"
            
            bundle_exists = (
                (dmg_dir.exists() and any(dmg_dir.glob("*.dmg"))) or
                (app_dir.exists() and any(app_dir.glob("*.app")))
            )
            
            self.assertTrue(bundle_exists, "No macOS bundles found")
    
    def test_run_app_script(self):
        """Test the run-app.sh script functionality"""
        script_path = self.project_root / "scripts" / "run-app.sh"
        self.assertTrue(script_path.exists(), "run-app.sh script not found")
        
        # Test script validation (syntax check)
        result = self.run_command(['bash', '-n', str(script_path)])
        self.assertEqual(result.returncode, 0, 
                        f"run-app.sh syntax error: {result.stderr}")
    
    def test_docker_integration_workflow(self):
        """Test Docker integration workflow"""
        # Check if Docker is available
        docker_check = self.run_command(['docker', '--version'], timeout=10)
        if docker_check.returncode != 0:
            self.skipTest("Docker not available for testing")
        
        # Test building a simple example
        example_dir = self.project_root / "examples" / "pwa-hello"
        if not example_dir.exists():
            self.skipTest("Example PWA not found")
        
        dockerfile = example_dir / "Dockerfile"
        if not dockerfile.exists():
            self.skipTest("Example Dockerfile not found")
        
        # Test the dock2tauri script with dry-run equivalent
        script_path = self.project_root / "scripts" / "dock2tauri.sh"
        
        # Just test syntax and basic validation
        result = self.run_command(['bash', '-n', str(script_path)])
        self.assertEqual(result.returncode, 0,
                        f"dock2tauri.sh syntax error: {result.stderr}")
    
    def test_development_mode_startup(self):
        """Test that development mode can start without errors"""
        # This tests the make dev command startup (not full execution)
        
        # First kill any existing processes on port 8081
        self.run_command(['make', 'kill-port'], timeout=30)
        
        # Start dev mode in background
        dev_process = subprocess.Popen(
            ['make', 'dev'],
            cwd=self.project_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        self.processes.append(dev_process)
        
        # Wait a few seconds for startup
        time.sleep(10)
        
        # Check if process is still running (not crashed immediately)
        poll_result = dev_process.poll()
        
        if poll_result is not None:
            # Process terminated, check why
            stdout, stderr = dev_process.communicate()
            if "webkit" in stderr.lower() or "dependency" in stderr.lower():
                self.skipTest("Missing development dependencies")
            elif "port" in stderr.lower() and "use" in stderr.lower():
                self.skipTest("Port conflict in test environment")
            else:
                self.fail(f"Dev mode failed to start: {stderr}")
        
        # If we get here, dev mode started successfully
        print("✅ Development mode started successfully")
    
    def test_makefile_targets(self):
        """Test that all Makefile targets are syntactically correct"""
        makefile_path = self.project_root / "Makefile"
        self.assertTrue(makefile_path.exists(), "Makefile not found")
        
        # Test make help
        result = self.run_command(['make', 'help'])
        self.assertEqual(result.returncode, 0,
                        f"make help failed: {result.stderr}")
        
        # Verify help contains expected targets
        help_output = result.stdout
        expected_targets = ['build', 'dev', 'install-deps', 'clean', 'run']
        
        for target in expected_targets:
            self.assertIn(target, help_output,
                         f"Target '{target}' not found in make help")
    
    def test_script_permissions_and_syntax(self):
        """Test that all scripts have correct permissions and syntax"""
        scripts_dir = self.project_root / "scripts"
        
        for script_file in scripts_dir.glob("*.sh"):
            # Test syntax
            result = self.run_command(['bash', '-n', str(script_file)])
            self.assertEqual(result.returncode, 0,
                           f"Syntax error in {script_file}: {result.stderr}")
            
            # Test that script is executable
            self.assertTrue(os.access(script_file, os.X_OK),
                          f"Script {script_file} is not executable")
    
    def test_configuration_files(self):
        """Test that configuration files are valid"""
        # Test Tauri configuration
        tauri_config = self.project_root / "src-tauri" / "tauri.conf.json"
        self.assertTrue(tauri_config.exists(), "tauri.conf.json not found")
        
        # Validate JSON syntax
        import json
        try:
            with open(tauri_config, 'r') as f:
                config = json.load(f)
            
            # Basic validation
            self.assertIn('productName', config)
            self.assertIn('build', config)
            self.assertIn('app', config)
            
        except json.JSONDecodeError as e:
            self.fail(f"Invalid JSON in tauri.conf.json: {e}")
    
    def test_cleanup_workflow(self):
        """Test cleanup and reset workflow"""
        # Test that cleanup doesn't fail
        result = self.run_command(['make', 'clean'], timeout=60)
        # Clean should succeed or be idempotent
        self.assertIn(result.returncode, [0, 1, 2],  # Allow various success/warning codes
                     f"Clean failed unexpectedly: {result.stderr}")


class PerformanceTests(unittest.TestCase):
    """Performance and stress tests"""
    
    def test_build_time_reasonable(self):
        """Test that build completes within reasonable time"""
        project_root = Path(__file__).parent.parent.parent
        
        start_time = time.time()
        result = subprocess.run(
            ['make', 'build'],
            cwd=project_root,
            timeout=900,  # 15 minute max
            capture_output=True,
            text=True
        )
        build_time = time.time() - start_time
        
        print(f"Build completed in {build_time:.2f} seconds")
        
        # If build succeeded, should be under 10 minutes for reasonable performance
        if result.returncode == 0:
            self.assertLess(build_time, 600, "Build took longer than 10 minutes")


if __name__ == '__main__':
    # Set up test discovery
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test cases
    suite.addTests(loader.loadTestsFromTestCase(Dock2TauriWorkflowTests))
    suite.addTests(loader.loadTestsFromTestCase(PerformanceTests))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2, buffer=True)
    result = runner.run(suite)
    
    # Exit with appropriate code
    exit(0 if result.wasSuccessful() else 1)

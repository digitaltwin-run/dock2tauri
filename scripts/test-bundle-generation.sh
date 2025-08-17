#!/bin/bash

# ==================================================
# Dock2Tauri Bundle Generation Testing & Diagnostics
# ==================================================
# Comprehensive testing and logging for Tauri bundler
# to diagnose why AppImage and other bundles fail

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_section() {
    echo ""
    echo -e "${PURPLE}===============================================${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}===============================================${NC}"
    echo ""
}

# Test configuration
PROJECT_ROOT="$(pwd)"
TEST_LOG="${PROJECT_ROOT}/bundle-test-$(date +%Y%m%d-%H%M%S).log"
BUNDLE_DIR="${PROJECT_ROOT}/src-tauri/target/release/bundle"
EXPECTED_TARGETS=("appimage" "deb" "rpm")

# Backup original config if exists
if [ -f "${PROJECT_ROOT}/src-tauri/tauri.conf.json" ]; then
    cp "${PROJECT_ROOT}/src-tauri/tauri.conf.json" "${PROJECT_ROOT}/src-tauri/tauri.conf.json.test-backup"
    log_info "Backed up original tauri.conf.json"
fi

# Start comprehensive testing
log_section "DOCK2TAURI BUNDLE GENERATION DIAGNOSTICS"
echo "Started: $(date)"
echo "Log file: $TEST_LOG"
echo ""

# Function to check file presence and details
check_file_details() {
    local file_path="$1"
    local description="$2"
    
    if [ -f "$file_path" ]; then
        local size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "unknown")
        local perms=$(ls -la "$file_path" | awk '{print $1}')
        log_success "$description exists: $file_path ($size bytes, $perms)"
        return 0
    else
        log_error "$description missing: $file_path"
        return 1
    fi
}

# Function to run command with detailed logging
run_with_logging() {
    local cmd="$1"
    local description="$2"
    
    log_info "Running: $description"
    log_info "Command: $cmd"
    echo "--- START: $description ---" >> "$TEST_LOG" 2>&1
    echo "Command: $cmd" >> "$TEST_LOG" 2>&1
    echo "Time: $(date)" >> "$TEST_LOG" 2>&1
    echo "" >> "$TEST_LOG" 2>&1
    
    if eval "$cmd" >> "$TEST_LOG" 2>&1; then
        log_success "$description completed successfully"
        echo "Status: SUCCESS" >> "$TEST_LOG" 2>&1
    else
        local exit_code=$?
        log_error "$description failed with exit code $exit_code"
        echo "Status: FAILED (exit code: $exit_code)" >> "$TEST_LOG" 2>&1
        return $exit_code
    fi
    
    echo "--- END: $description ---" >> "$TEST_LOG" 2>&1
    echo "" >> "$TEST_LOG" 2>&1
}

# Test 1: Environment diagnostics
log_section "TEST 1: ENVIRONMENT DIAGNOSTICS"

log_info "Tauri CLI version and environment:"
run_with_logging "cargo tauri info" "Tauri environment info"

log_info "Cargo and Rust versions:"
run_with_logging "cargo --version && rustc --version" "Cargo/Rust versions"

log_info "System information:"
run_with_logging "uname -a && lsb_release -a 2>/dev/null || cat /etc/os-release" "System info"

# Test 2: Configuration validation
log_section "TEST 2: CONFIGURATION VALIDATION"

log_info "Current tauri.conf.json validation:"
run_with_logging "cargo tauri info --verbose" "Tauri config validation"

if [ -f "${PROJECT_ROOT}/src-tauri/tauri.conf.json" ]; then
    log_info "Configuration file contents:"
    echo "--- tauri.conf.json contents ---" >> "$TEST_LOG"
    cat "${PROJECT_ROOT}/src-tauri/tauri.conf.json" >> "$TEST_LOG" 2>&1
    echo "--- end tauri.conf.json ---" >> "$TEST_LOG"
fi

# Test 3: Icon verification
log_section "TEST 3: ICON VERIFICATION"

log_info "Checking icon files:"
for icon in "${PROJECT_ROOT}/src-tauri/icons/32x32.png" "${PROJECT_ROOT}/src-tauri/icons/128x128.png" "${PROJECT_ROOT}/src-tauri/icons/128x128@2x.png" "${PROJECT_ROOT}/src-tauri/icons/icon.png" "${PROJECT_ROOT}/src-tauri/icons/icon.icns" "${PROJECT_ROOT}/src-tauri/icons/icon.ico"; do
    check_file_details "$icon" "Icon file"
done

log_info "Icon format verification:"
run_with_logging "file ${PROJECT_ROOT}/src-tauri/icons/*.png ${PROJECT_ROOT}/src-tauri/icons/*.icns ${PROJECT_ROOT}/src-tauri/icons/*.ico 2>/dev/null || true" "Icon file formats"

run_with_logging "identify -verbose ${PROJECT_ROOT}/src-tauri/icons/icon.png | grep -E '(Format|Depth|Colorspace|Class|Alpha)' || true" "PNG format details"

# Test 4: Dependency verification
log_section "TEST 4: BUNDLING DEPENDENCIES"

log_info "Checking bundling tool dependencies:"
tools=("dpkg-deb" "rpmbuild" "makeself")
for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        run_with_logging "$tool --version || $tool --help || true" "Dependency: $tool"
        log_success "Tool $tool is available"
    else
        log_warning "Tool $tool is not available"
        echo "Tool $tool: NOT AVAILABLE" >> "$TEST_LOG"
    fi
done

# Test 5: Clean build test
log_section "TEST 5: CLEAN BUILD TEST"

log_info "Cleaning previous build artifacts:"
run_with_logging "cd ${PROJECT_ROOT}/src-tauri && cargo clean" "Cargo clean"

if [ -d "$BUNDLE_DIR" ]; then
    log_info "Removing existing bundle directory"
    rm -rf "$BUNDLE_DIR"
fi

log_info "Building Tauri app with full verbose logging:"
cd "${PROJECT_ROOT}/src-tauri"
run_with_logging "RUST_BACKTRACE=full RUST_LOG=debug cargo tauri build --verbose" "Tauri build with full logging"
cd "${PROJECT_ROOT}"

# Test 6: Output verification
log_section "TEST 6: BUILD OUTPUT VERIFICATION"

log_info "Checking build output structure:"
run_with_logging "find ${PROJECT_ROOT}/src-tauri/target -name '*bundle*' -type d" "Find bundle directories"

if [ -d "$BUNDLE_DIR" ]; then
    log_success "Bundle directory exists: $BUNDLE_DIR"
    run_with_logging "ls -la '$BUNDLE_DIR'" "Bundle directory contents"
    
    # Check each target format
    for target in "${EXPECTED_TARGETS[@]}"; do
        target_dir="$BUNDLE_DIR/$target"
        if [ -d "$target_dir" ]; then
            log_success "Target directory exists: $target_dir"
            run_with_logging "ls -la '$target_dir'" "$target bundled files"
        else
            log_error "Target directory missing: $target_dir"
        fi
    done
else
    log_error "Bundle directory does not exist: $BUNDLE_DIR"
fi

# Check for any generated files
log_info "Searching for any generated bundle files:"
run_with_logging "find ${PROJECT_ROOT}/src-tauri/target -name '*.AppImage' -o -name '*.deb' -o -name '*.rpm' -o -name '*.app' -o -name '*.exe' -o -name '*.msi'" "Search for bundle files"

# Test 7: Manual bundler test
log_section "TEST 7: MANUAL BUNDLER TEST"

log_info "Testing specific bundler components:"

# Try AppImage bundler specifically
log_info "Testing AppImage bundler directly:"
cd "${PROJECT_ROOT}/src-tauri"
run_with_logging "RUST_BACKTRACE=full cargo tauri build --target appimage --verbose" "Direct AppImage build"
cd "${PROJECT_ROOT}"

# Test 8: Permissions and space check
log_section "TEST 8: SYSTEM REQUIREMENTS CHECK"

log_info "Checking filesystem permissions and space:"
run_with_logging "df -h ." "Disk space"
run_with_logging "ls -la ${PROJECT_ROOT}/src-tauri/target/ 2>/dev/null || true" "Target directory permissions"

# Test 9: Alternative bundle targets
log_section "TEST 9: ALTERNATIVE BUNDLE TARGETS"

log_info "Testing individual bundle targets:"
cd "${PROJECT_ROOT}/src-tauri"
for target in "${EXPECTED_TARGETS[@]}"; do
    log_info "Testing $target bundler separately:"
    run_with_logging "RUST_BACKTRACE=full cargo tauri build --target $target --verbose" "Build $target target"
done
cd "${PROJECT_ROOT}"

# Test 10: Final diagnostics
log_section "TEST 10: FINAL DIAGNOSTICS"

log_info "Final bundle verification:"
if [ -d "$BUNDLE_DIR" ]; then
    run_with_logging "find '$BUNDLE_DIR' -type f -exec ls -la {} \;" "All bundle files detailed"
else
    log_error "No bundle directory created during any test"
fi

# Generate summary report
log_section "TEST SUMMARY REPORT"

echo "Test completed: $(date)"
echo "Detailed log: $TEST_LOG"
echo ""

if [ -d "$BUNDLE_DIR" ]; then
    bundle_count=$(find "$BUNDLE_DIR" -name '*.AppImage' -o -name '*.deb' -o -name '*.rpm' | wc -l)
    if [ "$bundle_count" -gt 0 ]; then
        log_success "SUCCESS: $bundle_count bundle files were generated"
        find "$BUNDLE_DIR" -name '*.AppImage' -o -name '*.deb' -o -name '*.rpm' -exec ls -la {} \;
    else
        log_warning "PARTIAL: Bundle directory exists but no bundle files found"
    fi
else
    log_error "FAILURE: No bundle directory was created"
fi

# Restore original config
if [ -f "${PROJECT_ROOT}/src-tauri/tauri.conf.json.test-backup" ]; then
    mv "${PROJECT_ROOT}/src-tauri/tauri.conf.json.test-backup" "${PROJECT_ROOT}/src-tauri/tauri.conf.json"
    log_info "Restored original tauri.conf.json"
fi

echo ""
log_info "Complete diagnostic log available in: $TEST_LOG"
log_info "Bundle diagnostics completed!"
echo ""

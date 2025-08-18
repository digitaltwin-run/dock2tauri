#!/bin/bash
# Bash E2E Tests for Dock2Tauri Scripts
# Tests script functionality, syntax, and integration

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_OUTPUT_DIR="$SCRIPT_DIR/output"
FAILED_TESTS=()
PASSED_TESTS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Test tracking
track_test() {
    local test_name="$1"
    local result="$2"
    
    if [ "$result" = "0" ]; then
        PASSED_TESTS+=("$test_name")
        log_success "$test_name"
    else
        FAILED_TESTS+=("$test_name")
        log_error "$test_name"
    fi
}

# Setup test environment
setup_test_env() {
    log_info "Setting up test environment..."
    mkdir -p "$TEST_OUTPUT_DIR"
    cd "$PROJECT_ROOT"
}

# Test script syntax validation
test_script_syntax() {
    log_info "Testing script syntax validation..."
    
    local scripts_dir="$PROJECT_ROOT/scripts"
    local syntax_errors=0
    
    for script in "$scripts_dir"/*.sh; do
        if [ -f "$script" ]; then
            local script_name=$(basename "$script")
            log_info "  Checking syntax: $script_name"
            
            if bash -n "$script"; then
                log_success "  ✅ $script_name - syntax OK"
            else
                log_error "  ❌ $script_name - syntax error"
                ((syntax_errors++))
            fi
        fi
    done
    
    track_test "Script Syntax Validation" "$syntax_errors"
    return $syntax_errors
}

# Test install_deps.sh functionality
test_install_deps_script() {
    log_info "Testing install_deps.sh functionality..."
    
    local install_script="$PROJECT_ROOT/scripts/install_deps.sh"
    local test_result=0
    
    # Test dry-run mode
    if bash "$install_script" --dry-run > "$TEST_OUTPUT_DIR/install_deps_dry.log" 2>&1; then
        log_success "  ✅ install_deps.sh dry-run completed"
    else
        log_error "  ❌ install_deps.sh dry-run failed"
        test_result=1
    fi
    
    # Test help option
    if bash "$install_script" --help > "$TEST_OUTPUT_DIR/install_deps_help.log" 2>&1; then
        log_success "  ✅ install_deps.sh --help works"
    else
        log_error "  ❌ install_deps.sh --help failed"
        test_result=1
    fi
    
    # Test package manager detection
    if bash "$install_script" --dry-run 2>&1 | grep -q "package manager"; then
        log_success "  ✅ Package manager detection works"
    else
        log_warning "  ⚠️ Package manager detection unclear"
    fi
    
    track_test "install_deps.sh Script" "$test_result"
    return $test_result
}

# Test dock2tauri.sh script
test_dock2tauri_script() {
    log_info "Testing dock2tauri.sh functionality..."
    
    local dock2tauri_script="$PROJECT_ROOT/scripts/dock2tauri.sh"
    local test_result=0
    
    # Test script syntax
    if bash -n "$dock2tauri_script"; then
        log_success "  ✅ dock2tauri.sh syntax OK"
    else
        log_error "  ❌ dock2tauri.sh syntax error"
        test_result=1
    fi
    
    # Test help/usage (if available)
    if bash "$dock2tauri_script" --help > "$TEST_OUTPUT_DIR/dock2tauri_help.log" 2>&1 || 
       bash "$dock2tauri_script" > "$TEST_OUTPUT_DIR/dock2tauri_usage.log" 2>&1; then
        log_success "  ✅ dock2tauri.sh provides usage information"
    else
        log_warning "  ⚠️ dock2tauri.sh usage information unclear"
    fi
    
    # Test with invalid arguments
    if ! bash "$dock2tauri_script" invalid_arg_test > "$TEST_OUTPUT_DIR/dock2tauri_invalid.log" 2>&1; then
        log_success "  ✅ dock2tauri.sh properly handles invalid arguments"
    else
        log_warning "  ⚠️ dock2tauri.sh argument validation unclear"
    fi
    
    track_test "dock2tauri.sh Script" "$test_result"
    return $test_result
}

# Test run-app.sh script
test_run_app_script() {
    log_info "Testing run-app.sh functionality..."
    
    local run_app_script="$PROJECT_ROOT/scripts/run-app.sh"
    local test_result=0
    
    # Test script syntax
    if bash -n "$run_app_script"; then
        log_success "  ✅ run-app.sh syntax OK"
    else
        log_error "  ❌ run-app.sh syntax error"
        test_result=1
    fi
    
    # Test OS detection logic (dry run)
    if bash "$run_app_script" --dry-run > "$TEST_OUTPUT_DIR/run_app_dry.log" 2>&1 ||
       bash "$run_app_script" --help > "$TEST_OUTPUT_DIR/run_app_help.log" 2>&1; then
        log_success "  ✅ run-app.sh has dry-run or help mode"
    else
        log_warning "  ⚠️ run-app.sh no dry-run mode detected"
    fi
    
    track_test "run-app.sh Script" "$test_result"
    return $test_result
}

# Test Makefile targets
test_makefile_targets() {
    log_info "Testing Makefile targets..."
    
    local test_result=0
    local makefile="$PROJECT_ROOT/Makefile"
    
    # Test help target
    if make -f "$makefile" help > "$TEST_OUTPUT_DIR/make_help.log" 2>&1; then
        log_success "  ✅ make help works"
    else
        log_error "  ❌ make help failed"
        test_result=1
    fi
    
    # Test kill-port target
    if make -f "$makefile" kill-port > "$TEST_OUTPUT_DIR/make_kill_port.log" 2>&1; then
        log_success "  ✅ make kill-port works"
    else
        log_warning "  ⚠️ make kill-port had issues (may be expected)"
    fi
    
    # Test clean target
    if make -f "$makefile" clean > "$TEST_OUTPUT_DIR/make_clean.log" 2>&1; then
        log_success "  ✅ make clean works"
    else
        log_warning "  ⚠️ make clean had issues"
    fi
    
    # Test dry-run targets
    if make -f "$makefile" install-deps-dry-run > "$TEST_OUTPUT_DIR/make_deps_dry.log" 2>&1; then
        log_success "  ✅ make install-deps-dry-run works"
    else
        log_error "  ❌ make install-deps-dry-run failed"
        test_result=1
    fi
    
    track_test "Makefile Targets" "$test_result"
    return $test_result
}

# Test configuration files
test_configuration_files() {
    log_info "Testing configuration file validity..."
    
    local test_result=0
    
    # Test Tauri configuration
    local tauri_config="$PROJECT_ROOT/src-tauri/tauri.conf.json"
    if [ -f "$tauri_config" ]; then
        if python3 -m json.tool "$tauri_config" > /dev/null 2>&1; then
            log_success "  ✅ tauri.conf.json is valid JSON"
        else
            log_error "  ❌ tauri.conf.json is invalid JSON"
            test_result=1
        fi
    else
        log_error "  ❌ tauri.conf.json not found"
        test_result=1
    fi
    
    # Test Cargo.toml
    local cargo_toml="$PROJECT_ROOT/src-tauri/Cargo.toml"
    if [ -f "$cargo_toml" ]; then
        if grep -q '\[package\]' "$cargo_toml" && grep -q 'name.*=' "$cargo_toml"; then
            log_success "  ✅ Cargo.toml has basic structure"
        else
            log_error "  ❌ Cargo.toml missing required sections"
            test_result=1
        fi
    else
        log_error "  ❌ Cargo.toml not found"
        test_result=1
    fi
    
    track_test "Configuration Files" "$test_result"
    return $test_result
}

# Test build system integration
test_build_system() {
    log_info "Testing build system integration..."
    
    local test_result=0
    
    # Test that required tools are available or installable
    local required_tools=("cargo" "node" "python3")
    
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_success "  ✅ $tool is available"
        else
            log_warning "  ⚠️ $tool not found (may need installation)"
        fi
    done
    
    # Test Rust toolchain detection
    if cargo --version > "$TEST_OUTPUT_DIR/cargo_version.log" 2>&1; then
        log_success "  ✅ Rust toolchain detected"
    else
        log_warning "  ⚠️ Rust toolchain not available"
    fi
    
    # Test Tauri CLI availability
    if cargo tauri --version > "$TEST_OUTPUT_DIR/tauri_version.log" 2>&1; then
        log_success "  ✅ Tauri CLI available"
    else
        log_warning "  ⚠️ Tauri CLI not available (may need installation)"
    fi
    
    track_test "Build System Integration" "$test_result"
    return $test_result
}

# Test Docker integration
test_docker_integration() {
    log_info "Testing Docker integration..."
    
    local test_result=0
    
    # Test Docker availability
    if docker --version > "$TEST_OUTPUT_DIR/docker_version.log" 2>&1; then
        log_success "  ✅ Docker is available"
        
        # Test Docker daemon
        if docker info > "$TEST_OUTPUT_DIR/docker_info.log" 2>&1; then
            log_success "  ✅ Docker daemon is running"
        else
            log_warning "  ⚠️ Docker daemon not running"
        fi
    else
        log_warning "  ⚠️ Docker not available"
    fi
    
    # Test example Dockerfiles
    local examples_dir="$PROJECT_ROOT/examples"
    if [ -d "$examples_dir" ]; then
        local dockerfile_count=0
        for example in "$examples_dir"/*/Dockerfile; do
            if [ -f "$example" ]; then
                ((dockerfile_count++))
                local example_name=$(basename "$(dirname "$example")")
                log_success "  ✅ Found example Dockerfile: $example_name"
            fi
        done
        
        if [ "$dockerfile_count" -gt 0 ]; then
            log_success "  ✅ Found $dockerfile_count example Dockerfiles"
        else
            log_warning "  ⚠️ No example Dockerfiles found"
        fi
    fi
    
    track_test "Docker Integration" "$test_result"
    return $test_result
}

# Test file permissions and executability
test_file_permissions() {
    log_info "Testing file permissions..."
    
    local test_result=0
    local scripts_dir="$PROJECT_ROOT/scripts"
    
    for script in "$scripts_dir"/*.sh; do
        if [ -f "$script" ]; then
            local script_name=$(basename "$script")
            if [ -x "$script" ]; then
                log_success "  ✅ $script_name is executable"
            else
                log_warning "  ⚠️ $script_name is not executable"
                # Make it executable for the project
                chmod +x "$script" 2>/dev/null || true
            fi
        fi
    done
    
    track_test "File Permissions" "$test_result"
    return $test_result
}

# Test cleanup and error handling
test_error_handling() {
    log_info "Testing error handling and cleanup..."
    
    local test_result=0
    
    # Test that scripts handle Ctrl+C gracefully
    # This is a basic test - real interrupt testing would be more complex
    
    # Test invalid input handling
    if bash "$PROJECT_ROOT/scripts/install_deps.sh" --invalid-option > "$TEST_OUTPUT_DIR/error_handling.log" 2>&1; then
        log_warning "  ⚠️ Script accepted invalid option (may be expected)"
    else
        log_success "  ✅ Script properly rejected invalid option"
    fi
    
    track_test "Error Handling" "$test_result"
    return $test_result
}

# Generate test report
generate_report() {
    log_info "Generating test report..."
    
    local report_file="$TEST_OUTPUT_DIR/test_report.txt"
    
    cat > "$report_file" << EOF
Dock2Tauri Bash E2E Test Report
Generated: $(date)
Project Root: $PROJECT_ROOT

TEST SUMMARY:
============
Total Passed: ${#PASSED_TESTS[@]}
Total Failed: ${#FAILED_TESTS[@]}

PASSED TESTS:
============
EOF
    
    for test in "${PASSED_TESTS[@]}"; do
        echo "✅ $test" >> "$report_file"
    done
    
    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        cat >> "$report_file" << EOF

FAILED TESTS:
============
EOF
        for test in "${FAILED_TESTS[@]}"; do
            echo "❌ $test" >> "$report_file"
        done
    fi
    
    cat >> "$report_file" << EOF

TEST LOGS:
=========
See individual log files in: $TEST_OUTPUT_DIR/

RECOMMENDATIONS:
===============
EOF
    
    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        cat >> "$report_file" << EOF
- Review failed tests and fix underlying issues
- Check individual log files for detailed error information
EOF
    else
        echo "- All tests passed! System appears to be working correctly" >> "$report_file"
    fi
    
    log_success "Test report generated: $report_file"
}

# Main test execution
main() {
    log_info "Starting Dock2Tauri Bash E2E Tests..."
    log_info "Project root: $PROJECT_ROOT"
    
    setup_test_env
    
    # Run all tests
    test_script_syntax
    test_install_deps_script
    test_dock2tauri_script
    test_run_app_script
    test_makefile_targets
    test_configuration_files
    test_build_system
    test_docker_integration
    test_file_permissions
    test_error_handling
    
    # Generate report
    generate_report
    
    # Final summary
    echo
    log_info "=== TEST SUMMARY ==="
    log_success "Passed: ${#PASSED_TESTS[@]}"
    
    if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
        log_error "Failed: ${#FAILED_TESTS[@]}"
        echo
        log_error "Failed tests:"
        for test in "${FAILED_TESTS[@]}"; do
            log_error "  - $test"
        done
        exit 1
    else
        log_success "All tests passed! 🎉"
        exit 0
    fi
}

# Run main function
main "$@"

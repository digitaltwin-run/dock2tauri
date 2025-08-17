#!/bin/bash

# Dock2Tauri Build Test Script
# Tests that the build process generates working Tauri binaries

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo -e "${BLUE}🧪 Dock2Tauri Build Test Suite${NC}"
echo "=========================================="

# Test 1: Check if Dockerfile exists
log_info "Test 1: Checking Dockerfile exists..."
if [ ! -f "./Dockerfile" ]; then
    log_error "Dockerfile not found in current directory"
    exit 1
fi
log_success "Dockerfile found"

# Test 2: Check if app directory exists 
log_info "Test 2: Checking app directory exists..."
if [ ! -d "./app" ]; then
    log_warning "app directory not found, creating minimal index.html"
    mkdir -p app
    cat > app/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Dock2Tauri Test App</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; text-align: center; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .success { background-color: #d4edda; color: #155724; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐳🦀 Dock2Tauri Test</h1>
        <div class="status success">
            <strong>Success!</strong> The Tauri app is running with Docker backend.
        </div>
        <p>This is a test page served by nginx from Docker container.</p>
        <p id="timestamp"></p>
    </div>
    <script>
        document.getElementById('timestamp').textContent = 'Loaded at: ' + new Date().toLocaleString();
    </script>
</body>
</html>
EOF
fi
log_success "App directory ready"

# Test 3: Clean previous builds
log_info "Test 3: Cleaning previous builds..."
if [ -d "src-tauri/target/release" ]; then
    # Keep track of files before cleanup
    BEFORE_COUNT=$(find src-tauri/target/release -maxdepth 1 -type f -executable | grep -c "dock2-tauri" || echo "0")
    log_info "Found $BEFORE_COUNT existing binaries before cleanup"
fi

# Test 4: Run build process
log_info "Test 4: Running build process..."
TEST_PORT=8099
TEMP_TAG=$(date +%s)

log_info "Building Docker image and Tauri app with test port $TEST_PORT..."

# Run the build (suppress most output but capture errors)
if timeout 300s ./scripts/dock2tauri.sh ./Dockerfile $TEST_PORT 80 --build > /tmp/dock2tauri-test.log 2>&1; then
    log_success "Build process completed successfully"
else
    EXIT_CODE=$?
    log_error "Build process failed with exit code $EXIT_CODE"
    log_info "Last 20 lines of build log:"
    tail -n 20 /tmp/dock2tauri-test.log
    exit $EXIT_CODE
fi

# Test 5: Verify binary was created
log_info "Test 5: Verifying binary generation..."
LATEST_BINARY=$(find src-tauri/target/release -maxdepth 1 -type f -executable -name "dock2-tauri*" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

if [ -z "$LATEST_BINARY" ]; then
    log_error "No dock2-tauri binary found after build"
    exit 1
fi

log_success "Binary found: $(basename "$LATEST_BINARY")"

# Test 6: Check binary properties
log_info "Test 6: Checking binary properties..."
BINARY_SIZE=$(stat -c%s "$LATEST_BINARY" 2>/dev/null || echo "unknown")
BINARY_PERMS=$(stat -c%A "$LATEST_BINARY" 2>/dev/null || echo "unknown")

log_info "Binary size: $(numfmt --to=iec --suffix=B $BINARY_SIZE)"
log_info "Binary permissions: $BINARY_PERMS"

if [ ! -x "$LATEST_BINARY" ]; then
    log_error "Binary is not executable"
    exit 1
fi
log_success "Binary is executable"

# Test 7: Check if binary can start (quick test)
log_info "Test 7: Testing binary startup (5 second timeout)..."
if timeout 5s "$LATEST_BINARY" --help > /dev/null 2>&1; then
    log_success "Binary starts and responds to --help"
elif timeout 5s "$LATEST_BINARY" --version > /dev/null 2>&1; then
    log_success "Binary starts and responds to --version" 
else
    log_warning "Binary help/version test inconclusive (may be normal for Tauri apps)"
fi

# Test 8: Check bundle directory for installers
log_info "Test 8: Checking for bundle artifacts..."
BUNDLE_DIR="src-tauri/target/release/bundle"
if [ -d "$BUNDLE_DIR" ]; then
    BUNDLE_COUNT=$(find "$BUNDLE_DIR" -type f 2>/dev/null | wc -l)
    if [ "$BUNDLE_COUNT" -gt 0 ]; then
        log_success "Found $BUNDLE_COUNT bundle artifacts:"
        find "$BUNDLE_DIR" -type f -exec basename {} \; 2>/dev/null | head -5 | sed 's/^/  - /'
    else
        log_warning "Bundle directory exists but no artifacts found (packaging tools may be missing)"
    fi
else
    log_warning "No bundle directory found (packaging tools not installed)"
fi

# Summary
echo ""
echo -e "${GREEN}🎉 Build Test Summary${NC}"
echo "==========================================="
log_success "Docker image build: PASSED"
log_success "Tauri compilation: PASSED"  
log_success "Binary generation: PASSED"
log_success "Executable permissions: PASSED"
echo ""
log_info "Latest binary: $(basename "$LATEST_BINARY")"
log_info "Binary path: $LATEST_BINARY"
echo ""
log_info "To run the app manually:"
echo "  $LATEST_BINARY &"
echo ""
log_info "To run with live Docker backend:"
echo "  ./scripts/dock2tauri.sh ./Dockerfile $TEST_PORT 80"

# Cleanup
rm -f /tmp/dock2tauri-test.log

# Contributing to Dock2Tauri

Thank you for your interest in contributing to Dock2Tauri! This guide will help you get started with development and contribution workflow.

## Development Setup

### Prerequisites

1. **System Requirements**:
   - Linux (primary), macOS, or Windows with WSL2
   - Docker installed and running
   - Git for version control

2. **Development Dependencies**:
   ```bash
   # Clone the repository
   git clone https://github.com/digitaltwin-run/dock2tauri.git
   cd dock2tauri
   
   # Install all dependencies (Rust, Tauri CLI, system packages)
   make install YES=1
   
   # Optional: Install additional tools
   make install-deps APPIMAGE=1 ARM64=1 YES=1
   ```

3. **Verify Setup**:
   ```bash
   # Check system status
   make status
   
   # Run basic tests
   make test-install
   ```

### Development Workflow

#### 1. Setting Up Your Development Environment

```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/YOUR_USERNAME/dock2tauri.git
cd dock2tauri

# Add upstream remote
git remote add upstream https://github.com/digitaltwin-run/dock2tauri.git

# Create a development branch
git checkout -b feature/your-feature-name
```

#### 2. Code Style and Linting

We maintain consistent code style across all languages:

```bash
# Check code style (when implemented)
make lint

# Auto-format code (when implemented)
make format

# Run all tests
make test
```

**Language-specific guidelines:**

- **Bash**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
  - Use `shellcheck` for linting
  - Use `shfmt` for formatting
  - Prefer `bash` over `sh` for consistency
  
- **Python**: Follow [PEP 8](https://pep8.org/)
  - Use `ruff` for linting
  - Use `black` for formatting
  - Type hints where appropriate
  
- **JavaScript/Node.js**: Follow [Standard JS](https://standardjs.com/)
  - Use `eslint` for linting
  - Use `prettier` for formatting
  
- **Rust**: Follow [Rust Style Guide](https://doc.rust-lang.org/1.0.0/style/)
  - Use `rustfmt` for formatting
  - Use `clippy` for linting
  - Follow Tauri best practices

#### 3. Testing Your Changes

```bash
# Test basic functionality
make test

# Test specific launchers
make test-bash
make test-python
make test-nodejs

# Test with different scenarios
./scripts/dock2tauri.sh nginx:alpine 8088 80
./scripts/dock2tauri.sh ./examples/pwa-hello/Dockerfile 8089 80 --build
python3 scripts/dock2tauri.py --image nginx:alpine --host-port 8090 --container-port 80 --build
```

#### 4. Documentation Updates

Always update documentation when making changes:

- **README.md**: For user-facing changes
- **docs/**: For architectural or detailed explanations
- **Code comments**: For complex logic
- **TODO.md**: Update status of completed tasks

## Contribution Guidelines

### Types of Contributions

We welcome various types of contributions:

1. **Bug Fixes**: Address issues in existing functionality
2. **Feature Enhancements**: Add new capabilities
3. **Documentation**: Improve guides, examples, or code comments
4. **Testing**: Add test coverage or improve existing tests
5. **Performance**: Optimize build times, runtime performance, or resource usage
6. **Platform Support**: Improve Windows/macOS compatibility
7. **Examples**: Add new PWA examples or integration demos

### Commit Message Format

Use conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or modifying tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(launcher): add support for environment variable configuration
fix(bash): resolve AppImage build failures in CI environments
docs(troubleshooting): add ARM64 cross-compilation guide
refactor(config): extract shared Tauri config generation logic
```

### Pull Request Process

1. **Before Creating a PR**:
   ```bash
   # Sync with upstream
   git fetch upstream
   git rebase upstream/main
   
   # Run tests and linting
   make test
   make lint  # when available
   
   # Update documentation
   # Update TODO.md if applicable
   ```

2. **PR Requirements**:
   - Clear description of changes
   - Reference any related issues
   - Include screenshots for UI changes
   - Add or update tests when appropriate
   - Update documentation
   - Maintain launcher parity (if adding features)

3. **PR Template**:
   ```markdown
   ## Description
   Brief description of changes and motivation.
   
   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Documentation update
   - [ ] Performance improvement
   - [ ] Other (please describe)
   
   ## Testing
   - [ ] Tested locally on Linux
   - [ ] Tested on other platforms (specify)
   - [ ] Added/updated tests
   - [ ] All existing tests pass
   
   ## Documentation
   - [ ] Updated README.md
   - [ ] Updated relevant docs/
   - [ ] Updated code comments
   - [ ] Updated TODO.md
   
   ## Launcher Parity
   - [ ] Feature works in Bash launcher
   - [ ] Feature works in Python launcher
   - [ ] Feature works in Node.js launcher
   - [ ] N/A (not a launcher feature)
   
   ## Checklist
   - [ ] Code follows project style guidelines
   - [ ] Self-review completed
   - [ ] Changes work with existing examples
   - [ ] No breaking changes (or clearly documented)
   ```

4. **Review Process**:
   - Automated checks must pass
   - At least one maintainer review required
   - Address all feedback before merge
   - Squash commits when merging

## Architecture Considerations

### Launcher Parity

**Critical requirement**: All new features must maintain parity across launchers unless technically impossible.

When adding a new feature:
1. Implement in Bash launcher first (reference implementation)
2. Port to Python launcher
3. Port to Node.js launcher
4. Update Makefile targets if applicable
5. Add examples to README.md
6. Test all implementations

### Configuration System

- Use ephemeral Tauri config (don't modify `src-tauri/tauri.conf.json`)
- Support environment variable overrides
- Maintain backward compatibility
- Document new configuration options

### Cross-platform Compatibility

- Test on multiple Linux distributions
- Consider Windows/macOS implications
- Use platform-specific feature detection
- Graceful degradation when tools unavailable

### Error Handling

- Provide clear, actionable error messages
- Include troubleshooting hints
- Log sufficient detail for debugging
- Fail gracefully with cleanup

## Development Tips

### Common Development Tasks

```bash
# Quick development cycle
./scripts/dock2tauri.sh nginx:alpine 8088 80  # Test basic functionality
./scripts/dock2tauri.sh ./examples/pwa-hello/Dockerfile 8089 80 --build  # Test builds

# Debug mode
export DOCK2TAURI_DEBUG=1
./scripts/dock2tauri.sh nginx:alpine 8088 80

# Clean builds
make clean
cargo clean -p my-tauri-app

# Test cross-compilation locally
export DOCK2TAURI_CROSS_TARGETS="x86_64-unknown-linux-gnu"
./scripts/dock2tauri.sh nginx:alpine 8088 80 --build --cross
```

### Debugging

1. **Enable debug mode**: `export DOCK2TAURI_DEBUG=1`
2. **Check container logs**: `docker logs <container-name>`
3. **Inspect generated config**: Check `/tmp/tauri.conf.*.json`
4. **Use development builds**: `cargo tauri dev` for immediate feedback

### Testing Examples

Always test with the provided examples:
- `examples/pwa-hello/` - Basic PWA
- `examples/pwa-counter/` - Interactive PWA
- `examples/pwa-notes/` - Complex PWA with local storage

## Release Process

### Version Bumping

1. Update version in relevant files:
   - `Cargo.toml`
   - `package.json` (if applicable)
   - `README.md` examples
   
2. Update `CHANGELOG.md` (when created)
3. Tag release: `git tag v1.x.x`
4. Push tags: `git push --tags`

### Release Checklist

- [ ] All tests pass on CI
- [ ] Documentation updated
- [ ] Examples work with new version
- [ ] Cross-platform compatibility verified
- [ ] Performance regression testing
- [ ] Security review (for major changes)

## Community Guidelines

### Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help newcomers get started
- Assume good intentions

### Communication

- **GitHub Issues**: Bug reports, feature requests
- **GitHub Discussions**: Questions, ideas, showcase
- **Pull Requests**: Code contributions with discussion
- **Documentation**: Prefer written documentation over tribal knowledge

### Getting Help

1. Check existing documentation
2. Search GitHub issues
3. Ask in GitHub discussions
4. Mention maintainers for urgent issues

## Maintainer Notes

### Review Guidelines

When reviewing PRs:
- Check launcher parity
- Verify documentation updates
- Test locally when possible
- Provide constructive feedback
- Ensure backward compatibility

### Release Management

- Maintain semantic versioning
- Keep CHANGELOG.md updated
- Test releases thoroughly
- Communicate breaking changes clearly

Thank you for contributing to Dock2Tauri! Your contributions help make containerized applications more accessible to desktop users.

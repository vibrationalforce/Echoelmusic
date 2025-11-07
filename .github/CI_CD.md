# CI/CD Pipeline Documentation

## 🚀 Overview

BLAB uses GitHub Actions for continuous integration and deployment across all platforms.

## 📋 Workflows

### 1. Rust Core Build (`rust-build.yml`)

**Triggers:**
- Push to `main`, `develop`, `claude/**` branches
- Pull requests to `main`, `develop`
- Changes in `blab-core/**` or `BlabCoreSwift/**`

**Jobs:**

#### Lint
- Runs `rustfmt` for code formatting
- Runs `clippy` for linting
- Fails on warnings

#### Test (Linux)
- Runs full test suite on Ubuntu
- Builds release binaries
- Validates cross-platform code

#### Build (iOS)
- macOS runner with Xcode
- Compiles for 3 targets:
  - `aarch64-apple-ios` (iOS devices)
  - `x86_64-apple-ios` (Intel simulator)
  - `aarch64-apple-ios-sim` (Apple Silicon simulator)
- Creates XCFramework
- Uploads artifacts:
  - `libblab_ffi.xcframework`
  - `BlabCore.h`

#### Build (Android)
- Currently disabled (marked `if: false`)
- Will compile for Android targets when ready

#### Benchmark
- Runs on `main` and `develop` pushes
- Executes `cargo bench` for performance tracking

#### Security Audit
- Runs `cargo audit` on every build
- Checks for known vulnerabilities in dependencies

### 2. iOS App Build (`ios-build.yml`)

Existing workflow for building the Swift/iOS app.

## 🔧 Local Development

### Run CI Checks Locally

```bash
# Format code
cd blab-core
cargo fmt --all

# Lint
cargo clippy --workspace --all-targets -- -D warnings

# Test
cargo test --workspace

# Build iOS
./build-ios.sh

# Benchmark
cargo bench --workspace

# Security audit
cargo install cargo-audit
cargo audit
```

### Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
set -e

echo "Running pre-commit checks..."

# Format Rust code
cd blab-core
cargo fmt --all -- --check

# Lint Rust code
cargo clippy --workspace -- -D warnings

# Run tests
cargo test --workspace --quiet

echo "✅ All checks passed!"
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## 📦 Artifacts

### Rust Core Builds

**iOS XCFramework:**
- Path: `blab-core/target/xcframework/libblab_ffi.xcframework`
- Retention: 7 days
- Use in: BlabCoreSwift Swift Package

**C Header:**
- Path: `blab-core/BlabCore.h`
- Retention: 7 days
- Use in: Swift FFI bridging

### iOS App Builds

**Release Archive:**
- Path: `build/Blab.xcarchive`
- Retention: 7 days
- Use for: TestFlight/App Store submission

## 🔐 Secrets & Environment Variables

### Required Secrets

None currently required for CI builds.

### Optional for Releases

- `APPLE_ID`: Apple Developer account
- `APP_STORE_CONNECT_API_KEY`: For automated TestFlight uploads
- `MATCH_PASSWORD`: For certificate management (fastlane)

## 📊 Performance Benchmarks

Benchmarks run on every push to `main`/`develop`:

**Metrics Tracked:**
- Audio processing latency
- Particle system throughput
- FFT computation speed
- Memory allocation patterns

**Results:**
- Stored as GitHub Actions artifacts
- Compare across commits

## 🛡️ Security

### Dependency Scanning

`cargo audit` runs on every build:
- Checks RustSec database
- Fails on HIGH/CRITICAL vulnerabilities
- Warns on MEDIUM

### Code Quality

- `clippy` configured with `-D warnings`
- All warnings treated as errors
- Enforces Rust best practices

## 🚢 Release Process

### Manual Release (Current)

1. Merge to `main` branch
2. CI builds and tests automatically
3. Download artifacts from Actions
4. Manual deployment

### Automated Release (Future)

```yaml
# Future workflow: release.yml
on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  release:
    - Build all platforms
    - Create GitHub release
    - Upload binaries
    - Publish to TestFlight (iOS)
    - Publish to Play Store (Android)
```

## 🔄 Caching Strategy

### Cargo Cache

**Registry:** `~/.cargo/registry`
**Git:** `~/.cargo/git`
**Target:** `blab-core/target`

**Cache Key:** Hash of `Cargo.lock`

### Swift Package Cache

**Path:** `~/Library/Caches/org.swift.swiftpm`
**Cache Key:** Hash of `Package.resolved`

### DerivedData Cache

**Path:** `~/Library/Developer/Xcode/DerivedData`
**Cache Key:** Hash of all `.swift` files

## 🐛 Troubleshooting

### Build Fails on iOS

**Issue:** XCFramework creation fails
**Solution:**
1. Check Xcode version matches runner
2. Verify all targets are installed: `rustup target list --installed`
3. Ensure cbindgen is installed

### Tests Fail on Linux

**Issue:** Audio tests fail (no audio device)
**Solution:**
- Tests should mock audio I/O
- Use `#[cfg(not(target_os = "linux"))]` for hardware tests

### Cache Stale

**Issue:** Old dependencies cached
**Solution:**
```bash
# In Actions UI, clear cache manually
# Or bump Cargo.lock version to invalidate
```

## 📈 Future Improvements

- [ ] Automated version bumping
- [ ] Changelog generation
- [ ] Docker builds for Linux
- [ ] Windows builds (cross-compilation)
- [ ] WebAssembly builds
- [ ] Performance regression detection
- [ ] Code coverage reporting
- [ ] Automated TestFlight uploads

## 🔗 Resources

- [GitHub Actions Docs](https://docs.github.com/actions)
- [Rust Toolchain Action](https://github.com/dtolnay/rust-toolchain)
- [cargo-audit](https://github.com/rustsec/rustsec/tree/main/cargo-audit)
- [cbindgen](https://github.com/eqrion/cbindgen)

---

**Last Updated:** 2025-11-07

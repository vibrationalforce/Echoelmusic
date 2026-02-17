# Multi-Platform Build Guide for Echoelmusic

## Overview

This guide explains how to build and distribute Echoelmusic on **all major platforms** without owning a Mac, using cloud services and CI/CD pipelines.

## Platform Coverage

| Platform | Build System | Distribution |
|----------|--------------|--------------|
| iOS | Xcode Cloud | App Store / TestFlight |
| macOS | Xcode Cloud | App Store / Direct |
| Android | Skip + GitHub Actions | Google Play Store |
| Windows | GitHub Actions | Microsoft Store |
| Linux | GitHub Actions | Snap Store / Flathub |

## Architecture

```
                        ┌─────────────────────────────────┐
                        │         GitHub Repository       │
                        │      (Source of Truth)          │
                        └───────────────┬─────────────────┘
                                        │
           ┌────────────────────────────┼────────────────────────────┐
           │                            │                            │
           ▼                            ▼                            ▼
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│    Xcode Cloud      │    │   GitHub Actions    │    │   GitHub Actions    │
│   (Apple's CI/CD)   │    │   (macOS Runner)    │    │ (Windows/Linux)     │
│                     │    │                     │    │                     │
│  • iOS builds       │    │  • Skip transpile   │    │  • Swift compile    │
│  • macOS builds     │    │  • Android APK/AAB  │    │  • MSIX package     │
│  • TestFlight       │    │  • Play Store ready │    │  • Snap/Flatpak     │
└──────────┬──────────┘    └──────────┬──────────┘    └──────────┬──────────┘
           │                          │                          │
           ▼                          ▼                          ▼
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│    App Store        │    │   Google Play       │    │  Microsoft Store    │
│    TestFlight       │    │   Store             │    │  Snap Store         │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

## Cost Summary

### One-Time Costs
| Item | Cost |
|------|------|
| Google Play Developer | $25 |
| **Total One-Time** | **$25** |

### Annual Costs
| Item | Cost/Year |
|------|-----------|
| Apple Developer Program | $99 |
| Xcode Cloud (25 hrs/mo) | $0 (included) |
| MacinCloud (optional) | ~$300 |
| GitHub Actions | $0 (free tier) |
| Microsoft Store | $0 (free) |
| **Total Annual** | **$99 - $399** |

## Quick Start

### Step 1: Create Developer Accounts

1. **Apple Developer** → [developer.apple.com](https://developer.apple.com) ($99/year)
2. **Google Play** → [play.google.com/console](https://play.google.com/console) ($25 one-time)
3. **Microsoft Partner** → [partner.microsoft.com](https://partner.microsoft.com) (FREE)

### Step 2: Connect GitHub

All workflows are in `.github/workflows/`:
- `android-skip.yml` - Android builds via Skip
- `windows-build.yml` - Windows builds
- `linux-build.yml` - Linux builds

iOS/macOS use Xcode Cloud (configured in App Store Connect).

### Step 3: Trigger Builds

**Automatic:** Push to `main` branch triggers all builds

**Manual:**
- GitHub: Actions tab → Select workflow → "Run workflow"
- Xcode Cloud: App Store Connect → Xcode Cloud → Start Build

## Platform-Specific Guides

### iOS & macOS
→ See [XCODE_CLOUD_SETUP.md](./XCODE_CLOUD_SETUP.md)

### Android
→ See [SKIP_ANDROID_SETUP.md](./SKIP_ANDROID_SETUP.md)

### Windows
- Swift compiles natively on Windows
- MSIX package for Microsoft Store
- No code changes needed

### Linux
- Swift compiles natively on Linux
- Snap and Flatpak packages supported
- AppImage for direct distribution

## Workflow Files Reference

```
.github/workflows/
├── android-skip.yml      # Android via Skip (macOS runner)
├── windows-build.yml     # Windows native + MSIX
├── linux-build.yml       # Linux + Snap + Flatpak
└── phase8000-ci.yml      # Existing CI (tests)

ci_scripts/
├── ci_post_clone.sh      # Xcode Cloud: after clone
├── ci_pre_xcodebuild.sh  # Xcode Cloud: before build
└── ci_post_xcodebuild.sh # Xcode Cloud: after build
```

## Build Triggers

| Trigger | Platforms Built |
|---------|-----------------|
| Push to `main` | All platforms |
| Push to `develop` | All platforms |
| Pull Request | Tests only |
| Manual dispatch | Selected platform |
| Git tag `v*.*.*` | Release builds |

## Artifacts & Downloads

After successful builds, download artifacts from:

| Platform | Location |
|----------|----------|
| iOS | App Store Connect → TestFlight |
| Android | GitHub Actions → Artifacts |
| Windows | GitHub Actions → Artifacts |
| Linux | GitHub Actions → Artifacts |

## Code Signing

### iOS/macOS (Automatic)
Xcode Cloud manages certificates automatically via "Cloud Managed" signing.

### Android
```bash
# Create keystore (one-time)
keytool -genkey -v -keystore echoelmusic.keystore \
  -alias echoelmusic -keyalg RSA -keysize 2048 -validity 10000

# Store in GitHub Secrets:
# - ANDROID_KEYSTORE (base64 encoded)
# - ANDROID_KEYSTORE_PASSWORD
# - ANDROID_KEY_ALIAS
# - ANDROID_KEY_PASSWORD
```

### Windows
- Self-signed for testing
- Microsoft Partner certificate for Store

## Versioning

Versions are managed in:
- `Package.swift` - Swift package version
- `skip.yml` - Android version
- `ci_scripts/ci_post_clone.sh` - Build numbers

## Monitoring Builds

### Xcode Cloud
- App Store Connect → Your App → Xcode Cloud
- Email notifications (configure in settings)

### GitHub Actions
- Repository → Actions tab
- Email notifications on failure

## Troubleshooting

### "Build failed: No scheme found"
- Ensure `Package.swift` has correct targets
- Check scheme is shared in Xcode

### "Signing failed"
- iOS: Let Xcode Cloud manage (automatic)
- Android: Verify keystore secrets
- Windows: Use self-signed for testing

### "Skip transpilation error"
- Check Swift 5.10+ compatibility
- Review Skip logs for specific Kotlin errors
- Some SwiftUI features may need Skip workarounds

### "GitHub Actions timeout"
- macOS runners have longer queue times
- Consider self-hosted runner for faster builds

## Release Checklist

- [ ] Update version in all configs
- [ ] Create git tag `vX.Y.Z`
- [ ] Wait for all builds to complete
- [ ] Download and test each artifact
- [ ] Submit to respective stores
- [ ] Create GitHub Release with artifacts

## Support

- **Xcode Cloud**: [Apple Developer Forums](https://developer.apple.com/forums/)
- **Skip Framework**: [Skip Discord](https://discord.gg/skip)
- **GitHub Actions**: [GitHub Community](https://github.community/)

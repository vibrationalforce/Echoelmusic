# TestFlight Deployment Tasks - Quantum Wise Genius Ralph Wiggum Loop Mode

## Overview

This document outlines all tasks required for successful TestFlight deployment of Echoelmusic across all Apple platforms.

---

## Pre-Deployment Checklist

### 1. Apple Developer Account Setup

| Task | Status | Notes |
|------|--------|-------|
| Apple Developer Program enrollment ($99/year) | ⬜ | [developer.apple.com/programs](https://developer.apple.com/programs) |
| App ID created for `com.echoelmusic.app` | ⬜ | Enable HealthKit, Background Modes (Audio) - used by all platforms |
| App ID created for `com.echoelmusic.app.auv3` | ⬜ | macOS AUv3 extension |
| Distribution Certificate created | ⬜ | Valid for 1 year |

### 2. App Store Connect Setup

| Task | Status | Notes |
|------|--------|-------|
| App created in App Store Connect | ⬜ | Bundle ID: `com.echoelmusic.app` |
| App Store Connect API Key generated | ⬜ | Save .p8 file immediately |
| TestFlight Internal Testers group created | ⬜ | Add your Apple ID |
| Export Compliance answered (ITSAppUsesNonExemptEncryption: false) | ⬜ | Set in Info.plist |

### 3. GitHub Repository Secrets

| Secret | Description | Status |
|--------|-------------|--------|
| `APP_STORE_CONNECT_KEY_ID` | API Key ID (e.g., ABC123XYZ) | ⬜ |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID (UUID format) | ⬜ |
| `APP_STORE_CONNECT_PRIVATE_KEY` | .p8 file content (plain text) | ⬜ |
| `APPLE_TEAM_ID` | Developer Team ID | ⬜ |
| `CI_KEYCHAIN_PASSWORD` | (Optional) Custom keychain password | ⬜ |
| `SLACK_WEBHOOK_URL` | (Optional) Slack notifications | ⬜ |
| `DISCORD_WEBHOOK_URL` | (Optional) Discord notifications | ⬜ |

**Configure secrets at:** `https://github.com/vibrationalforce/Echoelmusic/settings/secrets/actions`

---

## Deployment Workflow

### Automatic Deployment (Recommended)

```bash
# 1. Push to main branch triggers preflight checks
git push origin main

# 2. Manually trigger deployment via GitHub Actions
# Go to: https://github.com/vibrationalforce/Echoelmusic/actions
# Select "Deploy Apple Platforms" workflow
# Click "Run workflow" → Choose platform → Run

# 3. Monitor deployment
# Check Actions tab for progress
# Build artifacts available for 30 days
```

### Manual Deployment (Local)

```bash
# 1. Setup local environment
./scripts/setup.sh

# 2. Configure environment variables
export ASC_KEY_ID="your_key_id"
export ASC_ISSUER_ID="your_issuer_id"
export ASC_KEY_CONTENT="$(cat ~/path/to/AuthKey.p8)"
export APPLE_TEAM_ID="your_team_id"

# 3. Deploy to TestFlight
cd fastlane
fastlane ios beta          # iOS only
fastlane mac beta          # macOS only
fastlane beta_all          # All platforms
```

---

## Platform-Specific Tasks

### iOS (iPhone + iPad)

| Task | Status | Notes |
|------|--------|-------|
| Info.plist configured | ✅ | Resources/iOS/Info.plist |
| Entitlements configured | ✅ | Echoelmusic.entitlements |
| Privacy descriptions added | ✅ | Microphone, HealthKit, Camera, etc. |
| AUv3 integrated in main app | ✅ | No separate extension needed |
| Universal device support (1,2) | ✅ | iPhone + iPad |

### macOS

| Task | Status | Notes |
|------|--------|-------|
| Info.plist configured | ✅ | Resources/macOS/Info.plist |
| Entitlements configured | ✅ | EchoelmusicMac.entitlements |
| Hardened Runtime enabled | ✅ | Required for notarization |
| AUv3 embedded as extension | ✅ | EchoelmusicAUv3-macOS target |
| Universal binary (ARM64 + x86_64) | ⬜ | Set in build settings |

### watchOS

| Task | Status | Notes |
|------|--------|-------|
| Info.plist configured | ✅ | Resources/watchOS/Info.plist |
| Entitlements configured | ✅ | EchoelmusicWatch.entitlements |
| HealthKit permissions | ✅ | Heart rate, HRV access |
| Companion iOS app dependency | ✅ | Requires iOS app installed |

### tvOS

| Task | Status | Notes |
|------|--------|-------|
| Info.plist configured | ✅ | Resources/tvOS/Info.plist |
| Entitlements configured | ✅ | EchoelmusicTV.entitlements |
| Focus navigation support | ⬜ | Remote control navigation |
| Big screen UI optimization | ⬜ | 10-foot UI design |

### visionOS

| Task | Status | Notes |
|------|--------|-------|
| Info.plist configured | ✅ | Resources/visionOS/Info.plist |
| Entitlements configured | ✅ | EchoelmusicVision.entitlements |
| Hand tracking permission | ✅ | NSHandsTrackingUsageDescription |
| Eye tracking permission | ✅ | NSEyeTrackingUsageDescription |
| Spatial audio support | ⬜ | visionOS immersive mode |

---

## Version Management

### Bumping Versions

```bash
# Patch version (1.2.0 → 1.2.1)
./scripts/bump-version.sh patch

# Minor version (1.2.0 → 1.3.0)
./scripts/bump-version.sh minor

# Major version (1.2.0 → 2.0.0)
./scripts/bump-version.sh major
```

### Version Locations

| File | Property |
|------|----------|
| `project.yml` | `MARKETING_VERSION` |
| `.github/workflows/deploy.yml` | `VERSION` env var |
| `fastlane/metadata/release_notes.txt` | Release notes header |

---

## Post-Deployment Tasks

### After Successful Build

1. **Check App Store Connect** (10-30 min processing)
   - Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   - Navigate to your app → TestFlight
   - Wait for "Processing" to complete

2. **Add Testers**
   - Internal testers: Automatically notified
   - External testers: Requires beta review (1-2 days first time)

3. **Install via TestFlight**
   - Open TestFlight app on device
   - Find Echoelmusic
   - Tap "Install"

### After Failed Build

1. **Check GitHub Actions logs**
   - Find the failing step
   - Common issues:
     - Missing secrets
     - Code signing errors
     - Build compilation errors

2. **Common Fixes**
   - Secrets: Verify all secrets are configured correctly
   - Signing: Check certificate expiration, regenerate if needed
   - Build: Fix code errors, run `swift build` locally

---

## Troubleshooting

### Issue: "Code signing failed"

```bash
# Regenerate certificates via Fastlane
fastlane ios cert
fastlane ios sigh
```

### Issue: "Invalid Binary"

- Check Export Compliance (ITSAppUsesNonExemptEncryption)
- Verify all Info.plist entries
- Check minimum deployment targets

### Issue: "Build timeout"

- Increase timeout in workflow (default: 60 min)
- Use clean build: `clean_build: true`

### Issue: "TestFlight not showing build"

- Wait 10-30 minutes for processing
- Check "Processing" status in App Store Connect
- Look for compliance issues in App Store Connect

---

## Quick Reference Commands

```bash
# Local setup
./scripts/setup.sh

# Generate Xcode project
xcodegen generate --spec project.yml

# Open in Xcode
open Echoelmusic.xcodeproj

# Run tests
swift test

# Deploy iOS to TestFlight
fastlane ios beta

# Deploy all platforms
fastlane beta_all

# Bump version
./scripts/bump-version.sh patch

# Check GitHub workflow syntax
gh workflow view deploy.yml
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `.github/workflows/deploy.yml` | Main deployment workflow |
| `.github/workflows/testflight-deploy.yml` | Manual TestFlight trigger |
| `fastlane/Fastfile` | Fastlane lane definitions |
| `fastlane/Appfile` | Bundle ID configuration |
| `project.yml` | XcodeGen project spec |
| `scripts/setup.sh` | Local environment setup |
| `scripts/bump-version.sh` | Version management |
| `TESTFLIGHT_SETUP.md` | Setup documentation |

---

## Success Criteria

- [ ] GitHub Secrets configured
- [ ] App registered in App Store Connect
- [ ] First successful TestFlight build
- [ ] App installed on test device
- [ ] Bio-reactive features working
- [ ] Audio engine functional
- [ ] HealthKit integration verified

---

*Last Updated: 2026-01-24 | Phase 10000 ULTIMATE RALPH WIGGUM LOOP MODE*

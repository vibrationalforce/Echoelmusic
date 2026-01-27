# TestFlight Deployment Guide - Echoelmusic

> **Status:** Ready for TestFlight | **Version:** 1.2.0 | **Date:** 27.01.2026

## Quick Start (TL;DR)

```bash
# 1. Set environment variables
export APPLE_TEAM_ID="YOUR_10_CHAR_TEAM_ID"
export ASC_KEY_ID="your_api_key_id"
export ASC_ISSUER_ID="your_issuer_id"
export ASC_KEY_CONTENT="$(cat ~/path/to/AuthKey_XXXX.p8)"

# 2. Install dependencies
bundle install

# 3. Generate Xcode project
xcodegen generate

# 4. Deploy to TestFlight
fastlane ios beta
```

---

## Prerequisites Checklist

### Apple Developer Account
- [ ] Active Apple Developer Program membership ($99/year)
- [ ] Access to App Store Connect
- [ ] Team ID available (10-character alphanumeric)

### App Store Connect API Key
- [ ] API Key created at https://appstoreconnect.apple.com/access/api
- [ ] Key ID noted (e.g., `ABC123DEFG`)
- [ ] Issuer ID noted (e.g., `12345678-1234-1234-1234-123456789012`)
- [ ] `.p8` file downloaded and stored securely

### Local Development
- [ ] Xcode 15.4+ installed
- [ ] Ruby 3.0+ installed
- [ ] Bundler installed (`gem install bundler`)
- [ ] XcodeGen installed (`brew install xcodegen`)

---

## Step 1: Configure Secrets

### Option A: Environment Variables (Local Development)

```bash
# Add to ~/.zshrc or ~/.bash_profile
export APPLE_TEAM_ID="ABCD1234EF"
export ASC_KEY_ID="ABC123DEFG"
export ASC_ISSUER_ID="12345678-1234-1234-1234-123456789012"
export ASC_KEY_CONTENT="-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
-----END PRIVATE KEY-----"

# Reload shell
source ~/.zshrc
```

### Option B: GitHub Actions Secrets (CI/CD)

Go to: Repository Settings → Secrets and variables → Actions → New repository secret

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `APPLE_TEAM_ID` | 10-char Apple Developer Team ID | `ABCD1234EF` |
| `APP_STORE_CONNECT_KEY_ID` | API Key ID from .p8 filename | `ABC123DEFG` |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from API Keys page | `12345678-...` |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contents of .p8 file (full text) | `-----BEGIN...` |

---

## Step 2: Generate Xcode Project

```bash
cd /path/to/Echoelmusic

# Install XcodeGen if not present
brew install xcodegen

# Generate .xcodeproj from project.yml
xcodegen generate

# Verify generation
ls -la Echoelmusic.xcodeproj
```

---

## Step 3: Deploy to TestFlight

### iOS Only
```bash
bundle install
fastlane ios beta
```

### All Platforms (iOS, macOS, watchOS, tvOS, visionOS)
```bash
fastlane beta_all
```

### Individual Platforms
```bash
fastlane ios beta          # iOS with AUv3
fastlane ios beta_watchos  # watchOS
fastlane ios beta_tvos     # tvOS
fastlane ios beta_visionos # visionOS
fastlane mac beta          # macOS with AUv3
```

### Build Only (No Upload)
```bash
fastlane ios build_only    # iOS simulator build
fastlane mac build_only    # macOS local build
```

---

## Step 4: GitHub Actions Deployment

### Manual Trigger
1. Go to: Actions → "Deploy Apple Platforms"
2. Click "Run workflow"
3. Select platform: `all`, `ios`, `macos`, or `ios-macos`
4. Select environment: `testflight` or `production`
5. Click "Run workflow"

### Automatic Deployment (on tag)
```bash
git tag v1.2.0-beta.1
git push origin v1.2.0-beta.1
```

---

## Bundle IDs & Universal Purchase

All platforms use unified bundle IDs for Universal Purchase:

| Platform | Bundle ID | Notes |
|----------|-----------|-------|
| iOS | `com.echoelmusic.app` | Main app |
| macOS | `com.echoelmusic.app` | Same as iOS |
| tvOS | `com.echoelmusic.app` | Same as iOS |
| visionOS | `com.echoelmusic.app` | Same as iOS |
| watchOS | `com.echoelmusic.app.watchkitapp` | Child of iOS (required) |
| iOS AUv3 | `com.echoelmusic.app.auv3` | Extension |
| macOS AUv3 | `com.echoelmusic.app.auv3` | Extension |
| Widgets | `com.echoelmusic.app.widgets` | Extension |
| App Clip | `com.echoelmusic.app.Clip` | On-demand install |

---

## Deployment Targets

Synchronized across Package.swift and project.yml:

| Platform | Minimum Version | Notes |
|----------|-----------------|-------|
| iOS | 16.0 | iPhone & iPad |
| macOS | 13.0 | Ventura+ (Apple Silicon + Intel) |
| watchOS | 9.0 | Apple Watch |
| tvOS | 16.0 | Apple TV |
| visionOS | 1.0 | Apple Vision Pro |

---

## Troubleshooting

### "No signing certificate found"
```bash
# Clear derived data and retry
rm -rf ~/Library/Developer/Xcode/DerivedData
fastlane ios beta
```

### "Profile doesn't match bundle identifier"
```bash
# Force regenerate profiles
CLEAN_BUILD=true fastlane ios beta
```

### "API key not found"
```bash
# Verify environment variables
echo $ASC_KEY_ID
echo $ASC_ISSUER_ID
echo $APPLE_TEAM_ID
```

### "Build failed with signing errors"
1. Open Xcode: Echoelmusic.xcodeproj
2. Select target → Signing & Capabilities
3. Ensure "Automatically manage signing" is checked
4. Select your Team from dropdown

---

## App Review Notes

When submitting for App Review, include these notes:

```
DEMO MODE AVAILABLE:
The app includes a Demo Mode that simulates biometric data for testing.
To access: Settings → Developer → Enable Demo Mode

NO EXTERNAL HARDWARE REQUIRED:
All features can be tested without Apple Watch or external MIDI devices.
Demo mode provides simulated heart rate, HRV, and coherence data.

HEALTH DISCLAIMER:
This app is NOT a medical device. All wellness features are for
relaxation and creative purposes only. See in-app disclaimer.

FREE APP:
All features are free. No in-app purchases.
```

---

## Contact & Support

- **Website:** https://echoelmusic.com
- **Support:** https://support.echoelmusic.com
- **Privacy:** https://echoelmusic.com/privacy
- **Terms:** https://echoelmusic.com/terms

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.2.0 | 27.01.2026 | TestFlight deployment ready |
| 1.1.0 | 25.01.2026 | Feature complete (Phase 10000.4) |
| 1.0.0 | 01.01.2026 | Initial release |

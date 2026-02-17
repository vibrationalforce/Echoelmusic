# TestFlight Deployment Guide

## Quick Start

### 1. Deploy to TestFlight (Recommended)

1. Go to **Actions** tab in GitHub
2. Select **"TestFlight"** workflow
3. Click **"Run workflow"**
4. Choose platform: `ios`, `macos`, `watchos`, `tvos`, `visionos`, or `all`
5. Click **"Run workflow"**

Build will appear in App Store Connect within 5-10 minutes.

### 2. PR Build Validation

All PRs automatically trigger a build check (no signing required).
This validates the code compiles before merge.

## Required Secrets

Configure these in **Settings > Secrets and variables > Actions**:

| Secret | Description | Format |
|--------|-------------|--------|
| `APP_STORE_CONNECT_KEY_ID` | From App Store Connect API Keys | ~10 alphanumeric chars |
| `APP_STORE_CONNECT_ISSUER_ID` | From App Store Connect API Keys | UUID format |
| `APP_STORE_CONNECT_PRIVATE_KEY` | .p8 file content | PEM format with headers |
| `APPLE_TEAM_ID` | From developer.apple.com Membership | 10 alphanumeric chars |

### Private Key Format

The `APP_STORE_CONNECT_PRIVATE_KEY` must include the full PEM headers:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEA...
...base64 content...
-----END PRIVATE KEY-----
```

## Getting API Keys

1. Go to [App Store Connect](https://appstoreconnect.apple.com) > Users and Access > Keys
2. Click **"Generate API Key"**
3. Select **"App Manager"** role
4. Download the .p8 file (only available once!)
5. Copy Key ID and Issuer ID
6. Get Team ID from [developer.apple.com](https://developer.apple.com/account/#!/membership)

## Supported Platforms

| Platform | Bundle ID | Scheme |
|----------|-----------|--------|
| iOS | com.echoelmusic.app | Echoelmusic |
| iOS Widgets | com.echoelmusic.app.widgets | (embedded) |
| iOS App Clip | com.echoelmusic.app.clip | (embedded) |
| macOS | com.echoelmusic.app | Echoelmusic-macOS |
| macOS AUv3 | com.echoelmusic.app.auv3 | (embedded) |
| watchOS | com.echoelmusic.app.watchkitapp | Echoelmusic-watchOS |
| tvOS | com.echoelmusic.app | Echoelmusic-tvOS |
| visionOS | com.echoelmusic.app | Echoelmusic-visionOS |

## Version Info

- **Marketing Version**: 3.0.0
- **Build Number**: Auto-incremented from GitHub Actions run number
- **Bundle ID**: com.echoelmusic.app (Universal Purchase enabled)

## How Code Signing Works

This project uses **cloud-managed automatic signing**:

1. **No local certificates needed** - xcodebuild with App Store Connect API handles everything
2. **xcodebuild flags used**:
   - `-allowProvisioningUpdates` - allows automatic profile creation
   - `-allowProvisioningDeviceRegistration` - allows device registration
   - `-authenticationKeyPath` - provides API key for cloud signing
3. **Xcode automatically**:
   - Creates distribution certificates if needed
   - Creates/updates provisioning profiles for all bundle IDs
   - Signs the app and all extensions

## Troubleshooting

### "No provisioning profile found" Error

**Cause**: Xcode couldn't create/download a provisioning profile.

**Solutions**:
1. Verify the App ID exists in [App Store Connect](https://appstoreconnect.apple.com/apps)
2. Check that the Bundle ID matches exactly (case-sensitive)
3. Ensure the API Key has "App Manager" or higher permissions
4. Verify APPLE_TEAM_ID matches the team that owns the app

### "Certificate private key not in keychain" Error

**Cause**: A certificate exists but was created on a different machine.

**Solutions**:
1. This should be automatically handled with cloud signing
2. If it persists, an Apple admin may need to revoke old certificates at [developer.apple.com](https://developer.apple.com/account/resources/certificates/list)
3. The workflow will create new certificates automatically

### "Exit status 65" Error

**Cause**: General Xcode build failure.

**Solutions**:
1. Check the full build log for specific errors
2. Common causes:
   - Missing entitlements file
   - Swift compilation errors
   - Missing source files

### Build succeeds but app not in TestFlight

**Solutions**:
1. Wait 5-10 minutes for Apple's processing
2. Check [App Store Connect](https://appstoreconnect.apple.com) for processing status
3. Look for "Missing Compliance" or export compliance issues
4. Ensure app is registered in App Store Connect

### Preflight check fails

**Solutions**:
1. Check that all 4 secrets are configured
2. Verify secret formats:
   - Key ID: 8+ characters
   - Issuer ID: UUID format (36 characters with dashes)
   - Private Key: 200+ characters, includes `PRIVATE KEY` headers
   - Team ID: exactly 10 characters

## Local Development

```bash
# Install dependencies
brew install xcodegen
gem install fastlane

# Generate Xcode project
xcodegen generate

# Build for simulator (no signing)
fastlane ios build_only

# Run tests
fastlane ios test
```

## Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| **TestFlight** | Deploy to TestFlight (all platforms) | Manual |
| **ci.yml** | Post-merge CI (lint, test) | Push to main |
| **pr-check.yml** | PR validation (simulator build) | Pull Request |

## Architecture

```
GitHub Actions Runner (macOS-14)
    │
    ├── Create temporary keychain
    │
    ├── Setup API key file (~/.appstoreconnect/private_keys/)
    │
    ├── xcodegen generate (inject DEVELOPMENT_TEAM)
    │
    ├── xcodebuild with:
    │   ├── -allowProvisioningUpdates
    │   ├── -authenticationKeyPath
    │   └── CODE_SIGN_STYLE=Automatic
    │
    ├── Fastlane upload_to_testflight
    │
    └── Cleanup keychain + API key
```

---

*Phase 10000 ULTIMATE MODE - Cloud-Managed Signing*

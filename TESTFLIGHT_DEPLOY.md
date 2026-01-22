# TestFlight Deployment Guide

## Quick Start

### 1. Deploy to TestFlight (Recommended)

1. Go to **Actions** tab in GitHub
2. Select **"iOS TestFlight"** workflow
3. Click **"Run workflow"**
4. Choose `testflight` as build type
5. Click **"Run workflow"**

Build will appear in App Store Connect within 5-10 minutes.

### 2. PR Build Validation

All PRs automatically trigger a build check (no signing required).
This validates the code compiles before merge.

## Required Secrets

Configure these in **Settings > Secrets and variables > Actions**:

| Secret | Description |
|--------|-------------|
| `APP_STORE_CONNECT_KEY_ID` | From App Store Connect API Keys |
| `APP_STORE_CONNECT_ISSUER_ID` | From App Store Connect API Keys |
| `APP_STORE_CONNECT_PRIVATE_KEY` | .p8 file content (PEM format) |
| `APPLE_TEAM_ID` | From developer.apple.com Membership |

## Getting API Keys

1. Go to [App Store Connect](https://appstoreconnect.apple.com) > Users and Access > Keys
2. Click **"Generate API Key"**
3. Select **"App Manager"** role
4. Download the .p8 file (only available once!)
5. Copy Key ID and Issuer ID

## Version Info

- **Marketing Version**: 1.2.0
- **Build Number**: Auto-incremented from GitHub Actions run number
- **Bundle ID**: com.echoelmusic.app

## Troubleshooting

### Build fails with signing error
- Verify all 4 secrets are configured
- Check Team ID matches your App Store Connect account

### App not appearing in TestFlight
- Wait 5-10 minutes for processing
- Check App Store Connect for processing status
- Ensure app is registered in App Store Connect

### Certificate issues
- Fastlane automatically manages certificates
- Old certificates are cleaned up automatically

## Local Development

```bash
# Install dependencies
brew install xcodegen
gem install fastlane

# Generate Xcode project
xcodegen generate

# Build for simulator
fastlane ios build_only

# Run tests
fastlane ios test
```

## Workflows

| Workflow | Purpose | Trigger |
|----------|---------|---------|
| **iOS TestFlight** | PR checks + TestFlight deploy | PR + Manual |
| [LEGACY] TestFlight | Old workflow (deprecated) | Manual only |

---

*Phase 10000 ULTIMATE MODE - Production Ready*

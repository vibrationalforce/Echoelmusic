# Xcode Cloud Setup Guide for Echoelmusic

## Overview

This guide helps you set up Xcode Cloud for automated iOS/macOS builds and TestFlight distribution **without needing a physical Mac**.

## Prerequisites

1. **Apple Developer Account** ($99/year) - [developer.apple.com](https://developer.apple.com)
2. **App Store Connect Access** - Included with Developer Account
3. **GitHub Repository** - Already configured ✅

## Step 1: Create App in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS, macOS (select all you want)
   - **Name**: Echoelmusic
   - **Primary Language**: English (or German)
   - **Bundle ID**: Create new → `com.yourname.echoelmusic`
   - **SKU**: `echoelmusic-001`
   - **User Access**: Full Access

## Step 2: Connect GitHub to Xcode Cloud

1. In App Store Connect, go to your app
2. Click **Xcode Cloud** tab
3. Click **Get Started**
4. Select **Connect to a Git provider**
5. Choose **GitHub**
6. Authorize Apple to access your repository
7. Select the `Echoelmusic` repository

## Step 3: Create Your First Workflow

### Basic TestFlight Workflow

1. In Xcode Cloud, click **Create Workflow**
2. Configure:

```
Workflow Name: TestFlight Build

Start Conditions:
├── Branch Changes
│   └── Branch: main (or your default branch)
│   └── Auto-cancel builds: Yes

Environment:
├── Xcode Version: Latest Release
├── macOS Version: Latest
└── Clean: Yes

Build Actions:
├── Archive
│   ├── Platform: iOS
│   ├── Scheme: Echoelmusic
│   └── Configuration: Release

Post-Actions:
├── TestFlight Internal Testing
│   └── Group: Internal Testers
```

3. Click **Save**

## Step 4: Configure Signing

Xcode Cloud handles code signing automatically:

1. Go to **Certificates, Identifiers & Profiles** in Apple Developer Portal
2. Xcode Cloud will create **Cloud Managed** certificates
3. Ensure your Bundle ID matches

### Required Capabilities (enable in App Store Connect):

- HealthKit
- Background Modes (Audio, Background fetch)
- Push Notifications (optional)

## Step 5: Add Testers

1. In App Store Connect → **Users and Access**
2. Click **Testers** → **Internal Testers**
3. Add email addresses of testers
4. They'll receive TestFlight invite automatically

## CI Scripts (Already Created)

The following scripts in `ci_scripts/` are automatically detected:

| Script | Purpose |
|--------|---------|
| `ci_post_clone.sh` | Runs after repo clone, sets up dependencies |
| `ci_pre_xcodebuild.sh` | Runs before build |
| `ci_post_xcodebuild.sh` | Runs after successful build |

## Environment Variables

Available in CI scripts:

| Variable | Description |
|----------|-------------|
| `CI_WORKSPACE` | Path to cloned repository |
| `CI_BRANCH` | Branch being built |
| `CI_BUILD_NUMBER` | Auto-incrementing build number |
| `CI_COMMIT` | Git commit SHA |
| `CI_XCODE_SCHEME` | Scheme being built |
| `CI_ARCHIVE_PATH` | Path to built archive |

## Free Tier Limits

- **25 compute hours/month** included with Apple Developer Program
- Typical iOS build: 5-15 minutes
- ~100-300 builds per month possible

## Workflow Triggers

### Option A: Automatic (Recommended)
Builds trigger on every push to `main`

### Option B: Manual
1. Go to Xcode Cloud in App Store Connect
2. Click **Start Build**
3. Select branch

### Option C: Tag-based Releases
```
Start Conditions:
├── Tag Changes
│   └── Pattern: v*.*.*
```

## Troubleshooting

### Build Fails: "No scheme found"
- Ensure `Package.swift` has proper targets
- Add `.xcworkspace` file if needed

### Build Fails: "Signing error"
- Let Xcode Cloud manage certificates (automatic)
- Check Bundle ID matches in all files

### Build Fails: "HealthKit not available"
- Our code has `#if canImport(HealthKit)` guards ✅
- Should work on simulator builds

## TestFlight Distribution

After successful build:
1. Build appears in App Store Connect → TestFlight
2. Internal testers notified automatically
3. External testing requires **Beta App Review** (usually 24-48 hours)

## Next Steps After Setup

1. ✅ First build runs automatically
2. Download TestFlight app on your iPhone
3. Accept invite email
4. Install and test Echoelmusic!

---

## Quick Reference: Build Status

Check build status:
- App Store Connect → Xcode Cloud → Builds
- Email notifications (configure in settings)

## Support

- [Xcode Cloud Documentation](https://developer.apple.com/documentation/xcode/xcode-cloud)
- [TestFlight Documentation](https://developer.apple.com/testflight/)

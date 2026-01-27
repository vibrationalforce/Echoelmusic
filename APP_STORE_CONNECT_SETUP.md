# App Store Connect Setup Guide - Echoelmusic

## Complete Configuration for TestFlight Deployment

This document describes all required configurations in **App Store Connect** and **Apple Developer Portal** for successful TestFlight deployment of Echoelmusic across all platforms.

---

## 1. Bundle IDs to Register

Register the following Bundle IDs in [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list):

| Bundle ID | Platform | Type | Description |
|-----------|----------|------|-------------|
| `com.echoelmusic.app` | iOS/macOS/tvOS/visionOS | App | Main application (Universal Purchase) |
| `com.echoelmusic.app.watchkitapp` | watchOS | App | Apple Watch companion app |
| `com.echoelmusic.app.auv3` | iOS/macOS | App Extension | Audio Unit v3 plugin |
| `com.echoelmusic.app.widgets` | iOS | App Extension | Widget extension |
| `com.echoelmusic.app.Clip` | iOS | App Clip | Quick session App Clip |

---

## 2. Capabilities per Bundle ID

### 2.1 Main App (com.echoelmusic.app)

**In Apple Developer Portal > Identifiers > com.echoelmusic.app > Capabilities:**

| Capability | Status | Notes |
|------------|--------|-------|
| **App Groups** | Enable | Group: `group.com.echoelmusic.shared` |
| **Associated Domains** | Enable | For Universal Links & Handoff |
| **HealthKit** | Enable | For biometric data (HRV, HR) |
| **HomeKit** | Enable | Smart lighting integration |
| **iCloud** | Enable | CloudKit & CloudDocuments |
| **Inter-App Audio** | Enable | Audio routing between apps |
| **Keychain Sharing** | Enable | Shared credentials |
| **Multicast Networking** | Enable | Art-Net/DMX control |
| **Push Notifications** | Enable | Live Activities & alerts |
| **SiriKit** | Enable | Shortcuts integration |

**iCloud Container:** `iCloud.com.echoelmusic.app`

### 2.2 watchOS App (com.echoelmusic.app.watchkitapp)

| Capability | Status | Notes |
|------------|--------|-------|
| **App Groups** | Enable | Group: `group.com.echoelmusic.shared` |
| **HealthKit** | Enable | Including health-records & background delivery |
| **Keychain Sharing** | Enable | Shared credentials |

### 2.3 AUv3 Extension (com.echoelmusic.app.auv3)

| Capability | Status | Notes |
|------------|--------|-------|
| **App Groups** | Enable | Group: `group.com.echoelmusic.shared` |
| **Inter-App Audio** | Enable | Required for Audio Units |
| **Keychain Sharing** | Enable | Shared credentials |

### 2.4 Widgets Extension (com.echoelmusic.app.widgets)

| Capability | Status | Notes |
|------------|--------|-------|
| **App Groups** | Enable | Group: `group.com.echoelmusic.shared` |
| **Keychain Sharing** | Enable | Shared credentials |

### 2.5 App Clip (com.echoelmusic.app.Clip)

| Capability | Status | Notes |
|------------|--------|-------|
| **App Groups** | Enable | Group: `group.com.echoelmusic.shared` |
| **Associated Domains** | Enable | For App Clip invocation |
| **Parent Application Identifiers** | Enable | Link: `com.echoelmusic.app` |
| **On Demand Resources** | Enable | Keep App Clip under 15MB |

---

## 3. App Services to Configure

### 3.1 Push Notifications (APNs)

**In Apple Developer Portal > Keys > Create a New Key:**

1. Name: `Echoelmusic Push Key`
2. Enable: `Apple Push Notifications service (APNs)`
3. Download the `.p8` file (save securely - only downloadable once!)
4. Note the Key ID

**For Live Activities:**
- Push Notifications are required for Live Activity updates
- The app uses `aps-environment: development` for TestFlight
- Change to `production` for App Store release

### 3.2 iCloud Container

**In Apple Developer Portal > Identifiers > iCloud Containers:**

1. Create: `iCloud.com.echoelmusic.app`
2. Description: `Echoelmusic Cloud Storage`

**Services enabled:**
- CloudKit (for sync)
- CloudDocuments (for file storage)

### 3.3 App Group

**In Apple Developer Portal > Identifiers > App Groups:**

1. Create: `group.com.echoelmusic.shared`
2. Description: `Shared data between app, widgets, watch, and extensions`

### 3.4 Associated Domains

**Configure your server with AASA file:**

Host this file at: `https://echoelmusic.com/.well-known/apple-app-site-association`

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appIDs": [
          "TEAM_ID.com.echoelmusic.app"
        ],
        "paths": ["*"],
        "components": [
          { "/": "/*" }
        ]
      }
    ]
  },
  "activitycontinuation": {
    "apps": [
      "TEAM_ID.com.echoelmusic.app"
    ]
  },
  "appclips": {
    "apps": [
      "TEAM_ID.com.echoelmusic.app.Clip"
    ]
  }
}
```

Replace `TEAM_ID` with your Apple Developer Team ID.

---

## 4. App Store Connect Configuration

### 4.1 Create App Record

**In App Store Connect > My Apps > + > New App:**

| Field | Value |
|-------|-------|
| Platforms | iOS, macOS, tvOS, visionOS, watchOS |
| Name | Echoelmusic |
| Primary Language | German |
| Bundle ID | com.echoelmusic.app |
| SKU | echoelmusic-2026 |
| User Access | Full Access |

### 4.2 App Information

**Category:** Music
**Secondary Category:** Health & Fitness

**Content Rights:**
- Does your app contain, display, or access third-party content? No
- Does this app use third-party content that you have the rights to? Yes (own content)

### 4.3 Pricing & Availability

**Pricing:**
- Base price or Free with In-App Purchases

**Availability:**
- All territories (or select specific ones)

### 4.4 App Privacy

**Data Collection Types (based on your features):**

| Data Type | Collection | Linked to User | Tracking |
|-----------|------------|----------------|----------|
| Health & Fitness (Heart Rate, HRV) | Yes | No | No |
| User Content (Audio recordings) | Yes | No | No |
| Identifiers (Device ID) | Yes | No | No |
| Usage Data (App interactions) | Yes | No | No |

**Privacy URL:** `https://echoelmusic.com/privacy`

### 4.5 App Clip Configuration

**In App Store Connect > App Clips:**

1. **Default App Clip Experience:**
   - URL: `https://echoelmusic.app/clip`
   - Image: Upload promotional image (3000x2000px)
   - Title: "Quick Meditation"
   - Subtitle: "Start a breathing session instantly"

2. **Advanced App Clip Experiences:**
   - `/clip/breathwork` - Breathing exercises
   - `/clip/meditation` - Quick meditation
   - `/clip/coherence` - Coherence check
   - `/clip/soundbath` - Sound bath
   - `/clip/energize` - Energy boost

---

## 5. Provisioning Profiles

### 5.1 Development Profiles

Create in Apple Developer Portal > Profiles:

| Profile Name | Type | Bundle ID |
|--------------|------|-----------|
| Echoelmusic iOS Dev | iOS Development | com.echoelmusic.app |
| Echoelmusic Watch Dev | watchOS Development | com.echoelmusic.app.watchkitapp |
| Echoelmusic AUv3 iOS Dev | iOS Development | com.echoelmusic.app.auv3 |
| Echoelmusic Widgets Dev | iOS Development | com.echoelmusic.app.widgets |
| Echoelmusic Clip Dev | iOS Development | com.echoelmusic.app.Clip |
| Echoelmusic macOS Dev | macOS Development | com.echoelmusic.app |
| Echoelmusic AUv3 macOS Dev | macOS Development | com.echoelmusic.app.auv3 |
| Echoelmusic tvOS Dev | tvOS Development | com.echoelmusic.app |
| Echoelmusic visionOS Dev | visionOS Development | com.echoelmusic.app |

### 5.2 Distribution Profiles (TestFlight/App Store)

| Profile Name | Type | Bundle ID |
|--------------|------|-----------|
| Echoelmusic iOS Dist | App Store | com.echoelmusic.app |
| Echoelmusic Watch Dist | App Store | com.echoelmusic.app.watchkitapp |
| Echoelmusic AUv3 iOS Dist | App Store | com.echoelmusic.app.auv3 |
| Echoelmusic Widgets Dist | App Store | com.echoelmusic.app.widgets |
| Echoelmusic Clip Dist | App Store | com.echoelmusic.app.Clip |
| Echoelmusic macOS Dist | App Store | com.echoelmusic.app |
| Echoelmusic AUv3 macOS Dist | App Store | com.echoelmusic.app.auv3 |
| Echoelmusic tvOS Dist | App Store | com.echoelmusic.app |
| Echoelmusic visionOS Dist | App Store | com.echoelmusic.app |

---

## 6. Required Certificates

### 6.1 Development Certificates

| Certificate | Purpose |
|-------------|---------|
| Apple Development | Code signing for development builds |
| Apple Development (Mac) | macOS development builds |

### 6.2 Distribution Certificates

| Certificate | Purpose |
|-------------|---------|
| Apple Distribution | iOS, watchOS, tvOS, visionOS App Store/TestFlight |
| Apple Distribution (Mac) | macOS App Store/TestFlight |
| Developer ID Application | macOS distribution outside App Store (optional) |

---

## 7. Environment Variables for CI/CD

Set these in your CI environment (GitHub Actions Secrets):

```bash
# App Store Connect API
ASC_KEY_ID=XXXXXXXXXX              # Key ID from App Store Connect
ASC_ISSUER_ID=XXXXXXXX-XXXX-XXXX   # Issuer ID from App Store Connect
ASC_KEY_CONTENT=-----BEGIN...      # Full content of .p8 file

# Apple Developer
APPLE_TEAM_ID=XXXXXXXXXX           # Your team ID

# Code Signing
KEYCHAIN_PASSWORD=xxxxx            # Keychain password for CI
```

---

## 8. TestFlight Deployment Commands

```bash
# iOS (includes AUv3, Widgets, App Clip)
fastlane ios beta

# watchOS
fastlane ios beta_watchos

# tvOS
fastlane ios beta_tvos

# visionOS
fastlane ios beta_visionos

# macOS (includes AUv3)
fastlane mac beta

# ALL PLATFORMS
fastlane beta_all
```

---

## 9. TestFlight Tester Groups

### 9.1 Internal Testers
- Add your development team members
- Automatic access to all builds
- No TestFlight review required

### 9.2 External Testers
- Create groups: "Beta Testers", "VIP Testers"
- Requires TestFlight review for first build
- Add testers via email or public link

---

## 10. Pre-Submission Checklist

### Before First TestFlight Upload:

- [ ] All Bundle IDs registered
- [ ] All Capabilities enabled per bundle
- [ ] App Group created and assigned
- [ ] iCloud Container created and assigned
- [ ] Associated Domains configured (AASA file hosted)
- [ ] Push Notifications key created
- [ ] All provisioning profiles created
- [ ] App record created in App Store Connect
- [ ] App Clip experiences configured
- [ ] Privacy policy URL added
- [ ] Environment variables set in CI

### After Each Upload:

- [ ] Verify build processing in App Store Connect
- [ ] Check for any capability warnings
- [ ] Submit to TestFlight review (external testers)
- [ ] Notify testers

---

## 11. Common Issues & Solutions

### Issue: "No matching provisioning profile"
**Solution:** Regenerate profiles in Apple Developer Portal or run `fastlane match` with `force: true`

### Issue: "Capability not enabled"
**Solution:** Enable the capability in both Apple Developer Portal AND Xcode project settings

### Issue: "iCloud container not configured"
**Solution:** Create the container in Developer Portal and add to your app's iCloud capability

### Issue: "App Clip too large (>15MB)"
**Solution:** Enable On Demand Resources, strip unused code, optimize assets

### Issue: "Associated Domains not working"
**Solution:** Verify AASA file is hosted correctly with proper `Content-Type: application/json`

---

## 12. Support Resources

- [App Store Connect Help](https://developer.apple.com/help/app-store-connect/)
- [Capabilities Documentation](https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app)
- [App Clip Documentation](https://developer.apple.com/documentation/app_clips)
- [TestFlight Documentation](https://developer.apple.com/testflight/)

---

*Last Updated: 2026-01-27*
*Echoelmusic Phase 10000.4 - Feature Complete*

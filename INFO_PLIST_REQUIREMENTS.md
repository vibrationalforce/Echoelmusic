# Info.plist Requirements for AppStore Submission

**CRITICAL:** These entries are REQUIRED in Info.plist for AppStore approval

---

## 🔐 Privacy Permissions (REQUIRED)

### Microphone Access
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Echoelmusic needs microphone access to record audio and create music.</string>
```

### Camera Access (For HRV Detection)
```xml
<key>NSCameraUsageDescription</key>
<string>Echoelmusic uses the camera to detect heart rate variability for bio-reactive music creation.</string>
```

### Health Data (Biometric Integration)
```xml
<key>NSHealthShareUsageDescription</key>
<string>Echoelmusic reads your heart rate and movement data to create bio-reactive music that responds to your body.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Echoelmusic may save workout data when creating music.</string>
```

### Bluetooth (For Wireless Sensors)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Echoelmusic connects to Bluetooth heart rate monitors and MIDI controllers for bio-reactive music.</string>
```

### Photo Library (For Video Export)
```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Echoelmusic saves exported videos to your photo library.</string>
```

---

## 🎵 Background Modes (REQUIRED for Audio)

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>bluetooth-central</string>
</array>
```

**Why:** Allows audio playback when screen is locked and Bluetooth connectivity

---

## 🔒 App Transport Security

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

**Why:** Ensures HTTPS/TLS 1.3 for all network connections (AppStore requirement)

---

## 📱 Supported Interface Orientations

### iPhone
```xml
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

### iPad
```xml
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

---

## 🎹 Audio Session Configuration

```xml
<key>UIRequiresPersistentWiFi</key>
<false/>

<key>UIFileSharingEnabled</key>
<true/>

<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

**Why:**
- WiFi not required (works offline)
- File sharing for audio export
- Document-based app support

---

## 🌍 Localization

```xml
<key>CFBundleDevelopmentRegion</key>
<string>en</string>

<key>CFBundleLocalizations</key>
<array>
    <string>en</string>
    <string>de</string>
    <string>fr</string>
    <string>es</string>
    <string>ja</string>
    <string>zh-Hans</string>
</array>
```

---

## 📋 App Metadata

```xml
<key>CFBundleName</key>
<string>Echoelmusic</string>

<key>CFBundleDisplayName</key>
<string>Echoelmusic</string>

<key>CFBundleShortVersionString</key>
<string>1.0</string>

<key>CFBundleVersion</key>
<string>1</string>

<key>CFBundleIdentifier</key>
<string>com.vibrationalforce.echoelmusic</string>
```

---

## 📄 Document Types (Audio Files)

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Audio File</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>public.audio</string>
            <string>public.mp3</string>
            <string>com.apple.m4a-audio</string>
            <string>public.aiff-audio</string>
        </array>
    </dict>
</array>

<key>UTExportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeIdentifier</key>
        <string>com.vibrationalforce.echoelmusic.project</string>
        <key>UTTypeDescription</key>
        <string>Echoelmusic Project</string>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
        </array>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>echoel</string>
            </array>
        </dict>
    </dict>
</array>
```

---

## 🎨 App Icons & Launch Screen

```xml
<key>UILaunchScreen</key>
<dict>
    <key>UIImageName</key>
    <string>LaunchLogo</string>
    <key>UIColorName</key>
    <string>LaunchBackground</string>
</dict>
```

---

## ♿ Accessibility

```xml
<key>UIAccessibilityContrast</key>
<string>high</string>

<key>UISupportsDynamicType</key>
<true/>
```

---

## 🚀 COMPLETE Info.plist Template

**Copy this entire section into your Info.plist:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- App Metadata -->
    <key>CFBundleName</key>
    <string>Echoelmusic</string>

    <key>CFBundleDisplayName</key>
    <string>Echoelmusic</string>

    <key>CFBundleShortVersionString</key>
    <string>1.0</string>

    <key>CFBundleVersion</key>
    <string>1</string>

    <key>CFBundleIdentifier</key>
    <string>com.vibrationalforce.echoelmusic</string>

    <!-- Privacy Permissions -->
    <key>NSMicrophoneUsageDescription</key>
    <string>Echoelmusic needs microphone access to record audio and create music.</string>

    <key>NSCameraUsageDescription</key>
    <string>Echoelmusic uses the camera to detect heart rate variability for bio-reactive music creation.</string>

    <key>NSHealthShareUsageDescription</key>
    <string>Echoelmusic reads your heart rate and movement data to create bio-reactive music that responds to your body.</string>

    <key>NSHealthUpdateUsageDescription</key>
    <string>Echoelmusic may save workout data when creating music.</string>

    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>Echoelmusic connects to Bluetooth heart rate monitors and MIDI controllers for bio-reactive music.</string>

    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>Echoelmusic saves exported videos to your photo library.</string>

    <!-- Background Modes -->
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
        <string>bluetooth-central</string>
    </array>

    <!-- App Transport Security -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>

    <!-- Interface Orientations -->
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>

    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>

    <!-- Audio & Files -->
    <key>UIFileSharingEnabled</key>
    <true/>

    <key>LSSupportsOpeningDocumentsInPlace</key>
    <true/>

    <!-- Accessibility -->
    <key>UISupportsDynamicType</key>
    <true/>
</dict>
</plist>
```

---

## ✅ Verification Checklist

Before submitting to AppStore, verify:

- [ ] All privacy descriptions are clear and specific
- [ ] Background audio mode is enabled
- [ ] HTTPS/TLS is enforced (no arbitrary loads)
- [ ] All required permissions are requested with descriptions
- [ ] App icon is provided (all sizes)
- [ ] Launch screen is configured
- [ ] Bundle identifier matches App Store Connect
- [ ] Version numbers are correct

---

## 🚨 Common Rejection Reasons

### ❌ Missing Privacy Descriptions
**Fix:** Add all NSxxxUsageDescription keys

### ❌ Background Audio Not Working
**Fix:** Add "audio" to UIBackgroundModes

### ❌ Insecure Network Connections
**Fix:** Set NSAllowsArbitraryLoads to false

### ❌ Missing Accessibility Support
**Fix:** Add Dynamic Type support

---

**Save this file and use it to configure your Info.plist before AppStore submission!**

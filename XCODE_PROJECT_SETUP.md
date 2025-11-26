# 🛠️ XCODE PROJECT SETUP GUIDE

**Status:** Configuration files ready, Xcode project needs creation on macOS
**Priority:** P0 - Critical Blocker
**Time:** 1-2 hours
**Last Updated:** 2025-11-19

---

## ✅ COMPLETED

The following configuration files have been created and are ready:

- ✅ `Info.plist` - Updated for Echoelmusic with all permissions
- ✅ `Echoelmusic.entitlements` - iOS app capabilities
- ✅ `EchoelmusicAUv3.entitlements` - AUv3 extension capabilities
- ✅ `EchoelmusicAUv3-Info.plist` - AUv3 extension configuration
- ✅ `Package.swift` - Swift Package Manager configuration

---

## 📋 XCODE PROJECT CREATION (MANUAL STEPS ON macOS)

### **Step 1: Open in Xcode**

```bash
# On macOS with Xcode installed:
cd /path/to/Echoelmusic
open Package.swift
```

Xcode will automatically create a temporary project from Package.swift.

---

### **Step 2: Create Xcode Project**

1. **File → New → Project**
2. **iOS → App**
3. **Settings:**
   - Product Name: `Echoelmusic`
   - Team: (Your Apple Developer Team)
   - Organization Identifier: `com.echoelmusic`
   - Bundle Identifier: `com.echoelmusic.Echoelmusic`
   - Interface: SwiftUI
   - Language: Swift
   - Use Core Data: NO
   - Include Tests: YES

4. **Save in:** `/path/to/Echoelmusic` (same directory as this README)

---

### **Step 3: Configure Main App Target**

#### **3.1 General Tab:**

```
Display Name: Echoelmusic
Bundle Identifier: com.echoelmusic.Echoelmusic
Version: 0.8.0
Build: 1

Deployment Info:
  iOS: 15.0
  iPhone and iPad

Frameworks, Libraries:
  - HealthKit.framework
  - AVFoundation.framework
  - CoreAudio.framework
  - Accelerate.framework (for SIMD)
  - Vision.framework (for face tracking)
  - ARKit.framework (for face tracking)
  - Metal.framework (for GPU shaders)
  - MetalKit.framework
```

#### **3.2 Signing & Capabilities:**

Add the following capabilities:

```
☑ HealthKit
☑ Background Modes
  ☑ Audio, AirPlay, and Picture in Picture
  ☑ Background fetch
  ☑ Background processing
☑ App Groups
  - group.com.echoelmusic.shared
☑ Push Notifications
☑ iCloud
  ☑ CloudKit
  ☑ CloudKit Documents
☑ Keychain Sharing
☑ Inter-App Audio
```

**Entitlements File:** Select `Echoelmusic.entitlements`

#### **3.3 Build Settings:**

Search for and set the following:

```
Product Name: Echoelmusic
Product Bundle Identifier: com.echoelmusic.Echoelmusic

Deployment:
  iOS Deployment Target: 15.0

Architectures:
  Build Active Architecture Only (Debug): Yes
  Build Active Architecture Only (Release): No
  Valid Architectures: arm64

Swift Compiler:
  Optimization Level (Debug): -Onone
  Optimization Level (Release): -O
  Swift Language Version: 5

Apple Clang:
  Enable Modules: Yes

Build Options:
  Enable Bitcode: No (required for Swift packages)

Header Search Paths:
  $(SRCROOT)/Sources (recursive)

Library Search Paths:
  $(SRCROOT)/Build (recursive)
```

#### **3.4 Info.plist:**

In **Target → Info**, select `Info.plist` as the custom iOS target properties file.

---

### **Step 4: Create AUv3 Extension Target**

1. **File → New → Target**
2. **iOS → App Extension → Audio Unit Extension**
3. **Settings:**
   - Product Name: `EchoelmusicAUv3`
   - Bundle Identifier: `com.echoelmusic.Echoelmusic.AUv3`
   - Embed in Application: `Echoelmusic`

4. **Configure AUv3 Target:**

#### **4.1 General:**

```
Display Name: Echoelmusic AUv3
Bundle Identifier: com.echoelmusic.Echoelmusic.AUv3
Version: 0.8.0
Build: 1
iOS Deployment Target: 15.0
```

#### **4.2 Signing & Capabilities:**

```
☑ App Groups
  - group.com.echoelmusic.shared
☑ Keychain Sharing
```

**Entitlements File:** Select `EchoelmusicAUv3.entitlements`

#### **4.3 Info.plist:**

Select `EchoelmusicAUv3-Info.plist`

#### **4.4 Build Settings:**

```
Product Bundle Identifier: com.echoelmusic.Echoelmusic.AUv3
iOS Deployment Target: 15.0
Swift Language Version: 5
Enable Bitcode: No
```

---

### **Step 5: Link Swift Package Sources**

1. **Select Echoelmusic (main target)**
2. **Build Phases → Compile Sources**
3. **Add files from `Sources/Echoelmusic/`:**

```
+ EchoelmusicApp.swift
+ ContentView.swift
+ All subdirectories:
  - AI/
  - Audio/
  - Biofeedback/
  - DSP/
  - Export/
  - Stream/
  - Unified/
  - Visual/
  - etc.
```

**Important:** Ensure "Target Membership" is set correctly:
- Main app files → `Echoelmusic` target
- AUv3 files → `EchoelmusicAUv3` target

---

### **Step 6: Configure CMake Integration (for C++ DSP)**

The project uses CMake for C++ audio processing code. To integrate:

1. **Build C++ Libraries:**

```bash
cd /path/to/Echoelmusic
mkdir -p Build
cd Build
cmake .. -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0
cmake --build . --config Release
```

This creates:
- `libEchoelmusicDSP.a` - C++ DSP library
- `libJUCE.a` - JUCE framework

2. **Link Libraries in Xcode:**

**Echoelmusic target → General → Frameworks, Libraries:**

```
+ Add Other → Add Files
  - Build/libEchoelmusicDSP.a
  - Build/libJUCE.a
```

**Echoelmusic target → Build Settings → Library Search Paths:**

```
$(SRCROOT)/Build
```

**Echoelmusic target → Build Settings → Header Search Paths:**

```
$(SRCROOT)/Sources/Plugin
$(SRCROOT)/Sources/Audio
$(SRCROOT)/Sources/DSP
$(SRCROOT)/JUCE/modules (recursive)
```

---

### **Step 7: Configure Objective-C++ Bridging**

For Swift ↔ C++ communication (required for biofeedback):

1. **Create Bridging Header:**

**File → New → Header File:**
- Name: `Echoelmusic-Bridging-Header.h`

Content:
```objc
#ifndef Echoelmusic_Bridging_Header_h
#define Echoelmusic_Bridging_Header_h

// C++ Audio Engine Bridge
#import "EchoelmusicAudioEngineBridge.h"

#endif
```

2. **Configure in Build Settings:**

**Echoelmusic target → Build Settings:**

```
Objective-C Bridging Header:
  $(SRCROOT)/Echoelmusic-Bridging-Header.h

Objective-C++ Interop:
  Enable C++ Interop: Yes
```

---

### **Step 8: Configure Schemes**

#### **Echoelmusic Scheme:**

**Edit Scheme → Run:**

```
Build Configuration: Debug
Executable: Echoelmusic.app

Options:
  ☑ Debug Executable

Diagnostics:
  ☑ Address Sanitizer (optional, for memory debugging)
  ☑ Thread Sanitizer (CRITICAL - for audio thread safety testing)
  ☑ Main Thread Checker
```

#### **EchoelmusicAUv3 Scheme:**

**Edit Scheme → Run:**

```
Build Configuration: Debug
Executable: Ask on Launch

Info:
  Run EchoelmusicAUv3 in a host app (e.g., GarageBand, AUM)
```

---

### **Step 9: Add Resources**

1. **Create Asset Catalog:**

**File → New → Asset Catalog:**
- Name: `Assets.xcassets`

Add:
- App Icon (1024×1024)
- Launch Image
- HealthKit icon
- Biofeedback icons

2. **Link Resources:**

**Echoelmusic target → Build Phases → Copy Bundle Resources:**

```
+ Assets.xcassets
+ Resources/ (if exists)
```

---

### **Step 10: Test Build**

```bash
# Clean build folder
⌘ + Shift + K

# Build
⌘ + B

# Expected output:
# ✅ Build Succeeded (Echoelmusic)
# ✅ Build Succeeded (EchoelmusicAUv3)
```

**If build fails:**
- Check that all Swift files have correct target membership
- Verify C++ libraries are linked
- Ensure Info.plist and entitlements are selected
- Check that iOS Deployment Target is 15.0 everywhere

---

## 🧪 TESTING CHECKLIST

### **Main App:**

```
[ ] Launch on iPhone Simulator
[ ] Request HealthKit permissions
[ ] Request Microphone permissions
[ ] Request Camera permissions
[ ] Test audio playback
[ ] Test biofeedback data collection (if Apple Watch paired)
```

### **AUv3 Extension:**

```
[ ] Install on device
[ ] Open GarageBand
[ ] Tap + to add track
[ ] Audio Recorder → Plug-ins & EQ
[ ] Look for "Echoelmusic: Bio-Reactive Synthesizer"
[ ] Load plugin
[ ] Test audio output
```

---

## 🚨 CRITICAL NEXT STEPS

After Xcode project is created, immediately proceed to:

### **Sprint 1: Audio Thread Safety Fixes** (P0)

See: `AUDIO_THREAD_SAFETY_FIXES.md`

7 locations with mutex locks in audio thread:
- `Sources/Plugin/PluginProcessor.cpp:276,396`
- `Sources/DSP/SpectralSculptor.cpp:90,314,320,618`
- `Sources/DSP/DynamicEQ.cpp:429`
- `Sources/DSP/HarmonicForge.cpp:222`
- `Sources/Audio/SpatialForge.cpp`

**Fix:** Replace mutex locks with `juce::AbstractFifo` (lock-free)

---

## 📊 BUNDLE IDENTIFIERS

```
Main App:        com.echoelmusic.Echoelmusic
AUv3 Extension:  com.echoelmusic.Echoelmusic.AUv3
App Group:       group.com.echoelmusic.shared
iCloud:          iCloud.com.echoelmusic
```

---

## 🔑 APPLE DEVELOPER REQUIREMENTS

To build and test:

```
✅ Apple Developer Account (required)
✅ iOS Development Certificate
✅ Provisioning Profiles:
   - Echoelmusic (App ID with HealthKit, Inter-App Audio)
   - EchoelmusicAUv3 (Extension App ID)
✅ Devices:
   - iPhone (iOS 15+) for testing
   - Apple Watch Series 6+ for HRV biofeedback
```

---

## 📝 NOTES

1. **C++ Integration:** This project uses both Swift (UI) and C++ (DSP). The CMake build must run BEFORE Xcode build.

2. **Thread Sanitizer:** ALWAYS enable Thread Sanitizer during development to catch audio thread violations.

3. **AUv3 Testing:** AUv3 plugins MUST be tested in real DAW apps (GarageBand, Cubasis, AUM). Simulator is NOT sufficient.

4. **HealthKit:** HealthKit does NOT work in Simulator. Test on real device with paired Apple Watch.

5. **Code Signing:** Each target needs its own provisioning profile. Wildcard profiles do NOT work with HealthKit.

---

## 🎯 DEFINITION OF DONE

Sprint 0 is complete when:

```
[ ] Xcode project created successfully
[ ] Main app target builds without errors
[ ] AUv3 extension target builds without errors
[ ] C++ libraries linked correctly
[ ] All entitlements configured
[ ] App launches on simulator
[ ] App launches on device
[ ] HealthKit permissions requested
[ ] Audio playback works
[ ] AUv3 appears in GarageBand
```

---

**Created:** 2025-11-19
**Sprint:** 0 (Project Setup)
**Next:** Sprint 1 (Audio Thread Safety)
**Owner:** iOS Team

---

**🛠️ READY TO BUILD ON macOS! 🛠️**

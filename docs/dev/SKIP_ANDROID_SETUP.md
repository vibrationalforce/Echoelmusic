# Skip Framework Setup for Android

## Overview

[Skip](https://skip.tools) enables building **native Android apps from Swift/SwiftUI code**. This means your existing Echoelmusic Swift codebase can run on Android without a complete rewrite.

## How Skip Works

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Swift/SwiftUI  │────▶│  Skip Transpiler │────▶│  Kotlin/Compose │
│  (iOS Source)   │     │  (Build Time)    │     │  (Android)      │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

Skip transpiles Swift to Kotlin and SwiftUI to Jetpack Compose at **build time**, resulting in truly native Android code.

## Requirements

### For Development (Cloud Mac)
- macOS 14+ (Sonoma)
- Xcode 16+
- Android Studio 2024+
- Skip CLI (`brew install skiptools/skip/skip`)

### Using MacinCloud
1. Rent a Mac at [MacinCloud](https://www.macincloud.com) (~$25/month)
2. Install Xcode + Android Studio
3. Install Skip: `brew install skiptools/skip/skip`

## Project Structure After Skip Setup

```
Echoelmusic/
├── Package.swift                 # Swift Package (iOS)
├── skip.yml                      # Skip configuration ✅ (created)
├── Sources/
│   └── Echoelmusic/             # Swift source (shared)
├── android/                      # Android project (Skip-generated)
│   ├── app/
│   │   └── src/main/
│   │       ├── kotlin/          # Transpiled Kotlin
│   │       └── AndroidManifest.xml
│   ├── build.gradle.kts
│   └── settings.gradle.kts
└── ci_scripts/                   # Xcode Cloud scripts ✅
```

## Platform-Specific Code Handling

### iOS-Only → Android Alternatives

| iOS Framework | Android Alternative | Status |
|---------------|---------------------|--------|
| HealthKit | Health Connect | Need Android impl |
| ARKit | ARCore | Need Android impl |
| CoreMotion | SensorManager | Partial support |
| CoreML | TensorFlow Lite | Need conversion |
| Metal Shaders | Vulkan/OpenGL ES | Need porting |
| WatchKit | Wear OS SDK | Separate app |

### Conditional Code Pattern

```swift
// In your Swift code:
#if os(iOS)
import HealthKit
#elseif os(Android) // Skip defines this
import HealthConnect  // Skip-provided wrapper
#endif
```

## Step-by-Step Setup

### Step 1: Install Skip (on Cloud Mac)

```bash
# Install Homebrew if needed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Skip
brew install skiptools/skip/skip

# Verify installation
skip version
```

### Step 2: Initialize Skip in Project

```bash
cd Echoelmusic

# Initialize Skip (creates Android project structure)
skip init

# This creates:
# - android/ directory
# - Updates Package.swift
# - Generates initial Kotlin code
```

### Step 3: Configure Android Project

```bash
# Open in Android Studio
open -a "Android Studio" android/

# Or from command line:
cd android
./gradlew assembleDebug
```

### Step 4: Build for Android

```bash
# From project root
skip build

# Or build specific variant
skip build --configuration release
```

### Step 5: Test on Android Emulator

```bash
# Start emulator
emulator -avd Pixel_7_API_34

# Install and run
skip run --device emulator
```

## Health Connect Integration (Android HealthKit Alternative)

Create this file for Android health data:

```kotlin
// android/app/src/main/kotlin/com/echoelmusic/health/HealthConnectManager.kt

package com.echoelmusic.health

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import kotlinx.coroutines.flow.Flow

class HealthConnectManager(private val context: Context) {

    private val healthConnectClient by lazy {
        HealthConnectClient.getOrCreate(context)
    }

    suspend fun readHeartRate(): List<HeartRateRecord> {
        // Implementation
    }

    suspend fun readHRV(): List<HeartRateVariabilityRmssdRecord> {
        // Implementation
    }

    fun streamHeartRate(): Flow<Double> {
        // Real-time streaming
    }
}
```

## Building APK for Testing

### Debug Build
```bash
skip build --configuration debug
# Output: android/app/build/outputs/apk/debug/app-debug.apk
```

### Release Build (Signed)
```bash
# First, create keystore
keytool -genkey -v -keystore echoelmusic.keystore \
  -alias echoelmusic -keyalg RSA -keysize 2048 -validity 10000

# Build signed APK
skip build --configuration release --sign
# Output: android/app/build/outputs/apk/release/app-release.apk
```

## Google Play Store Submission

1. **Create Google Play Console Account** ($25 one-time)
2. **Create App** in Play Console
3. **Upload AAB** (Android App Bundle):
   ```bash
   skip build --configuration release --bundle
   # Creates: app-release.aab
   ```
4. **Submit for Review**

## CI/CD with GitHub Actions

See `.github/workflows/android-skip.yml` (will be created)

## Limitations & Workarounds

### What Works Automatically
- SwiftUI views → Jetpack Compose
- Swift data types → Kotlin data classes
- Combine → Kotlin Flow
- Async/await → Kotlin coroutines
- Foundation → Kotlin stdlib

### What Needs Manual Work
- Metal shaders → Convert to GLSL/Vulkan
- HealthKit → Health Connect wrapper
- ARKit → ARCore wrapper
- CoreML models → TensorFlow Lite conversion

## Cost Summary

| Item | Cost |
|------|------|
| Skip Framework | Free (Open Source) |
| MacinCloud (for builds) | ~$25/month |
| Google Play Developer | $25 (one-time) |
| **Total Year 1** | ~$325 |
| **Ongoing** | ~$300/year |

## Troubleshooting

### "Skip not found"
```bash
export PATH="$PATH:/opt/homebrew/bin"
```

### "Android SDK not found"
```bash
export ANDROID_HOME=~/Library/Android/sdk
```

### "Kotlin compilation error"
- Check Skip version matches Kotlin version
- Run `skip clean && skip build`

## Resources

- [Skip Documentation](https://skip.tools/docs)
- [Skip GitHub](https://github.com/skiptools/skip)
- [Skip Discord](https://discord.gg/skip)
- [Health Connect Guide](https://developer.android.com/health-and-fitness/guides/health-connect)

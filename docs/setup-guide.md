# Echoelmusic Setup Guide

Complete step-by-step setup guide for both iOS and Desktop components.

---

## Prerequisites

### For iOS Development

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **iOS Device**: iPhone/iPad with iOS 16.0+ (required for HealthKit)
- **Apple Developer Account**: Free tier sufficient for development

### For Desktop Development

- **JUCE Framework**: 7.0 or later
  - Download from: https://juce.com/get-juce/download
- **IDE**:
  - macOS: Xcode 15+
  - Windows: Visual Studio 2022
  - Linux: GCC 9+ or Clang 10+
- **Audio Interface**: Recommended for low-latency audio

### Network

- **WiFi Network**: iOS device and Desktop on same network
- **Firewall**: Allow UDP traffic on ports 8000-8001

---

## Part 1: iOS App Setup

### Step 1: Clone Repository

```bash
git clone https://github.com/vibrationalforce/Echoelmusic.git
cd Echoelmusic/ios-app
```

### Step 2: Install Dependencies

The project uses Swift Package Manager (SPM). Dependencies will be resolved automatically when you open the project.

If using `xcodegen`:

```bash
# Install xcodegen (optional)
brew install xcodegen

# Generate Xcode project
xcodegen generate
```

### Step 3: Open in Xcode

```bash
# If using Package.swift (recommended)
open Package.swift

# Or if you generated .xcodeproj
open Echoelmusic.xcodeproj
```

### Step 4: Configure Signing

1. Select project in Project Navigator
2. Select "Echoelmusic" target
3. Go to "Signing & Capabilities" tab
4. Select your Team (Apple Developer Account)
5. Xcode will automatically generate a Bundle ID

**Note**: If you see "Failed to register bundle identifier" error:
- Change the Bundle ID to something unique (e.g., add your name)
- Format: `com.yourname.echoelmusic`

### Step 5: Configure Capabilities

Ensure these capabilities are enabled:

1. **HealthKit**:
   - Click "+ Capability"
   - Add "HealthKit"
   - Check "Background Delivery"

2. **Background Modes** (if not already added):
   - Audio, AirPlay, and Picture in Picture
   - Background fetch

### Step 6: Update Info.plist

Verify/add these privacy descriptions in `Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>Echoelmusic uses your heart rate and respiratory data to create personalized audio experiences.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Echoelmusic needs to access your health data for real-time biofeedback.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Echoelmusic uses your microphone for voice pitch detection and audio input.</string>

<key>NSCameraUsageDescription</key>
<string>Echoelmusic uses the camera for face tracking in spatial audio.</string>

<key>NSMotionUsageDescription</key>
<string>Echoelmusic uses motion sensors for gesture control.</string>
```

### Step 7: Build and Run

1. Connect your iOS device via USB
2. Select your device in Xcode's device dropdown
3. Click "Build and Run" (⌘R)
4. **First launch**: App will request HealthKit permissions
   - Tap "Allow" for Heart Rate, HRV, Respiratory Rate

### Troubleshooting iOS

**Problem**: "Echoelmusic.app could not be installed"
- **Solution**: Trust your Developer Certificate
  - Settings → General → VPN & Device Management
  - Tap your developer profile → Trust

**Problem**: HealthKit not available
- **Solution**: HealthKit requires a physical device (not Simulator)

**Problem**: Build errors in Swift files
- **Solution**: Clean build folder (⇧⌘K) and rebuild

---

## Part 2: Desktop Engine Setup

### Step 1: Install JUCE

```bash
# Download JUCE from https://juce.com/get-juce/download
# Extract to ~/JUCE (or preferred location)

# Or via git
git clone https://github.com/juce-framework/JUCE.git ~/JUCE
cd ~/JUCE
git checkout 7.0.9  # Or latest stable
```

### Step 2: Open Projucer

```bash
cd ~/JUCE
open Projucer.app  # macOS
# or
./Projucer         # Linux
```

### Step 3: Create New JUCE Project

Since the Desktop Engine is still in development, you'll create the initial project:

1. **In Projucer**: File → New Project
2. **Type**: Audio Plugin / Standalone Application
3. **Name**: Echoelmusic
4. **Location**: `Echoelmusic/desktop-engine/`
5. **Modules**: Add these JUCE modules:
   - `juce_audio_basics`
   - `juce_audio_devices`
   - `juce_audio_processors`
   - `juce_audio_utils`
   - `juce_core`
   - `juce_data_structures`
   - `juce_events`
   - `juce_graphics`
   - `juce_gui_basics`
   - `juce_osc` (Important!)

### Step 4: Configure Project Settings

In Projucer project settings:

**Audio Plugin Formats** (if building plugin):
- VST3: ✓
- AU: ✓ (macOS)
- Standalone: ✓

**macOS Deployment Target**: 11.0
**Windows Target Platform**: Windows 10
**C++ Language Standard**: C++17

### Step 5: Add OSC Module

1. In Projucer, select "Modules" tab
2. Click "Add Module"
3. Find `juce_osc` in the list
4. Click "Add" (it's part of JUCE core modules)

### Step 6: Create Source Files

Create these files in `desktop-engine/Source/`:

**OSC/OSCManager.h**:
```cpp
#pragma once
#include <JuceHeader.h>

class OSCManager : public juce::OSCReceiver,
                   private juce::OSCReceiver::Listener<juce::OSCReceiver::MessageLoopCallback>
{
public:
    OSCManager();
    ~OSCManager() override;

    bool initialize(int port = 8000);
    void shutdown();

    // Callbacks
    std::function<void(float)> onHeartRateReceived;
    std::function<void(float)> onHRVReceived;
    std::function<void(float, float)> onPitchReceived;

private:
    void oscMessageReceived(const juce::OSCMessage& message) override;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(OSCManager)
};
```

**OSC/OSCManager.cpp**:
```cpp
#include "OSCManager.h"

OSCManager::OSCManager() {}

OSCManager::~OSCManager() {
    shutdown();
}

bool OSCManager::initialize(int port) {
    if (!connect(port)) {
        DBG("Failed to bind OSC receiver on port " + juce::String(port));
        return false;
    }

    addListener(this);
    DBG("OSC Server listening on port " + juce::String(port));
    return true;
}

void OSCManager::shutdown() {
    disconnect();
}

void OSCManager::oscMessageReceived(const juce::OSCMessage& message) {
    auto address = message.getAddressPattern().toString();

    if (address == "/echoel/bio/heartrate" && message.size() == 1) {
        if (auto* arg = message[0].getFloat32()) {
            DBG("Heart Rate: " + juce::String(*arg));
            if (onHeartRateReceived) onHeartRateReceived(*arg);
        }
    }
    else if (address == "/echoel/bio/hrv" && message.size() == 1) {
        if (auto* arg = message[0].getFloat32()) {
            DBG("HRV: " + juce::String(*arg));
            if (onHRVReceived) onHRVReceived(*arg);
        }
    }
    else if (address == "/echoel/audio/pitch" && message.size() == 2) {
        if (auto* freq = message[0].getFloat32()) {
            if (auto* conf = message[1].getFloat32()) {
                DBG("Pitch: " + juce::String(*freq) + " Hz (conf: " + juce::String(*conf) + ")");
                if (onPitchReceived) onPitchReceived(*freq, *conf);
            }
        }
    }
}
```

### Step 7: Save and Generate IDE Project

1. In Projucer: File → Save Project
2. Click "Save and Open in IDE" button
3. Projucer will generate Xcode/VS project in `desktop-engine/Builds/`

### Step 8: Build

**macOS (Xcode)**:
```bash
cd desktop-engine/Builds/MacOSX
open Echoelmusic.xcodeproj
# In Xcode: Select "Echoelmusic - Standalone" scheme
# Build and Run (⌘R)
```

**Windows (Visual Studio)**:
```bash
cd desktop-engine\Builds\VisualStudio2022
start Echoelmusic.sln
# In VS: Build → Build Solution (Ctrl+Shift+B)
# Debug → Start Without Debugging (Ctrl+F5)
```

**Linux**:
```bash
cd desktop-engine/Builds/LinuxMakefile
make CONFIG=Release
./build/Echoelmusic
```

### Step 9: Configure Audio Settings

When the app launches:

1. **macOS**: It may ask for Microphone permission → Allow
2. Go to Audio Settings
3. Select your **Audio Device** (built-in or interface)
4. Set **Sample Rate**: 48000 Hz
5. Set **Buffer Size**: 256 samples (balance latency vs. CPU)

### Troubleshooting Desktop

**Problem**: "juce_osc module not found"
- **Solution**: Ensure JUCE 7.0+ (juce_osc added in v7)
  - Update JUCE: `cd ~/JUCE && git pull`

**Problem**: High CPU usage
- **Solution**: Increase buffer size (512 or 1024 samples)

**Problem**: Audio crackling
- **Solution**: Close other audio applications, increase buffer size

---

## Part 3: Network Configuration

### Step 1: Find Desktop IP Address

**macOS**:
```bash
ipconfig getifaddr en0  # WiFi
# or
ifconfig | grep "inet "
```

**Windows**:
```bash
ipconfig
# Look for "IPv4 Address" under your WiFi adapter
```

**Linux**:
```bash
ip addr show | grep inet
```

**Example Output**: `192.168.1.100`

### Step 2: Configure Firewall

**macOS**:
```bash
# Allow incoming UDP on port 8000
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/Echoelmusic
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /path/to/Echoelmusic
```

**Windows**:
1. Windows Defender Firewall → Advanced Settings
2. Inbound Rules → New Rule
3. Port → UDP → 8000 → Allow

**Linux**:
```bash
sudo ufw allow 8000/udp
```

### Step 3: Test Connection

**On Desktop**, install `oscdump` for testing:
```bash
# macOS
brew install liblo
oscdump 8000

# Linux
sudo apt-get install liblo-tools
oscdump 8000
```

**On iOS**, open Echoelmusic app:
1. Go to Settings
2. Enter Desktop IP (e.g., `192.168.1.100`)
3. Tap "Connect"
4. Status should show "Connected ✓"

**Verify on Desktop**: You should see OSC messages in `oscdump` or Desktop app console.

---

## Part 4: Running the System

### Full System Test

1. **Start Desktop Engine**:
   ```bash
   cd desktop-engine/Builds/MacOSX/build/Release
   ./Echoelmusic
   ```

2. **Start iOS App** on device

3. **Connect**:
   - In iOS app: Settings → Enter Desktop IP → Connect
   - Check connection status

4. **Enable Biofeedback**:
   - In iOS app: Toggle "Heart Rate Monitor" ON
   - Desktop console should show: "Heart Rate: 72.5"

5. **Test Voice Input**:
   - Speak or sing into iPhone microphone
   - Desktop console should show: "Pitch: 220.0 Hz"

6. **Watch Visualization**:
   - iOS app should show Cymatics responding to Desktop audio

### Latency Check

In iOS app, go to "Debug" view:
- **Latency** should be < 10ms
- **Packet Loss** should be < 1%

If latency is high:
- Ensure both devices on same WiFi network
- Reduce Desktop buffer size (256 samples)
- Disable WiFi power saving on iOS: Settings → WiFi → (i) → Low Data Mode OFF

---

## Part 5: Development Workflow

### iOS Development

```bash
cd ios-app
open Package.swift
# Make changes in Xcode
# Build and run on device (⌘R)
```

**Hot Reload**: SwiftUI supports live previews
- Use `#Preview` macros for UI components
- Changes reflect instantly in Xcode Canvas

### Desktop Development

```bash
cd desktop-engine
open Echoelmusic.jucer
# Edit in Projucer
# Save → "Save and Open in IDE"
# Build in Xcode/VS
```

**Live Coding**: Use JUCE's built-in features
- Add `JUCE_ENABLE_LIVE_BUILD_FEATURES=1` to preprocessor

### Testing OSC Messages

**Send test messages to Desktop**:
```bash
# Install oscsend
brew install liblo

# Send test heart rate
oscsend localhost 8000 /echoel/bio/heartrate f 75.0

# Send test pitch
oscsend localhost 8000 /echoel/audio/pitch f 220.0 f 0.85
```

---

## Part 6: Troubleshooting Common Issues

### Connection Issues

**Symptom**: iOS shows "Disconnected"

**Solutions**:
1. Check Desktop IP is correct
2. Ensure Desktop app is running
3. Ping test: `ping <desktop_ip>` from iOS (use network utility app)
4. Firewall: Temporarily disable to test
5. Try different WiFi network (avoid public/corporate networks with AP isolation)

### HealthKit Issues

**Symptom**: No heart rate data

**Solutions**:
1. Check permissions: iOS Settings → Privacy → Health → Echoelmusic
2. Ensure Apple Watch is paired and worn
3. Start a workout on Watch to activate sensors
4. Check HealthKitManager logs in Xcode console

### Audio Issues

**Symptom**: Crackling/dropouts

**Solutions**:
1. Increase buffer size (512 or 1024)
2. Close other audio apps (DAWs, browsers with audio)
3. Disable WiFi power saving
4. Check CPU usage (should be < 50%)

### Build Issues

**iOS**:
```bash
# Clean build
rm -rf ~/Library/Developer/Xcode/DerivedData
cd ios-app
xcodebuild clean
```

**Desktop**:
```bash
cd desktop-engine/Builds/MacOSX
make clean
make CONFIG=Release
```

---

## Part 7: Performance Optimization

### iOS

1. **Reduce OSC send rate**:
   ```swift
   // In OSCManager
   let throttleInterval = 0.016 // 60 Hz max
   ```

2. **Optimize Metal shaders**:
   - Use Metal Debugger (Xcode → Product → Profile → Metal)
   - Target 60 FPS

3. **Background modes**:
   - Ensure app continues in background when needed

### Desktop

1. **Audio buffer size**:
   - Start with 256 samples
   - Increase if CPU high

2. **CPU profiling**:
   - Use Instruments (macOS)
   - Use Visual Studio Profiler (Windows)

3. **Optimize DSP**:
   - Use SIMD intrinsics
   - Table lookups for oscillators

---

## Part 8: Next Steps

### For iOS

- [ ] Implement OSCManager using template from `docs/osc-protocol.md`
- [ ] Add connection UI (IP input, status indicator)
- [ ] Integrate with existing HealthKitManager
- [ ] Add latency display in debug view

### For Desktop

- [ ] Implement audio synthesis engine
- [ ] Add parameter mapping (biofeedback → audio)
- [ ] Implement analysis (FFT, RMS) and send back to iOS
- [ ] Add UI for monitoring biofeedback

### Testing

- [ ] Unit tests for OSC encoding/decoding
- [ ] Integration test: iOS → Desktop → iOS roundtrip
- [ ] Latency measurement
- [ ] Stress test (many messages)

---

## Support

**Issues**: https://github.com/vibrationalforce/Echoelmusic/issues
**Documentation**: See `docs/` folder
**Contact**: via GitHub Issues

---

**Last Updated**: November 2025
**Version**: 1.0.0-alpha

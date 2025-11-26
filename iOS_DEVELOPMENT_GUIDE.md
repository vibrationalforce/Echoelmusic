# EOEL iOS/iPad App - Development Guide 📱

**Target:** iPad as primary platform (iPhone secondary)
**Goal:** MVP in 2-3 months
**Revenue:** €49.99 one-time purchase

---

## 🎯 MVP Feature Scope

### Core Features (MUST HAVE)
```yaml
Audio Engine:
  ✅ 8-track audio recording/playback
  ✅ Real-time monitoring (< 10ms latency)
  ✅ 44.1/48 kHz support
  ✅ 16/24-bit recording
  ✅ Core Audio integration

Plugin Hosting (CRITICAL!):
  ✅ AUv3 (Audio Unit v3) hosting
  ✅ User's existing plugins work!
  ✅ Plugin state save/restore
  ✅ Preset management
  ✅ Automation recording

MIDI:
  ✅ MIDI input (USB, Bluetooth)
  ✅ Virtual MIDI (connect with other apps)
  ✅ MIDI recording/editing
  ✅ Piano roll editor (touch-optimized)

Sync:
  ✅ Ableton Link (sync with FL Mobile, Beatmaker, etc.)
  ✅ MIDI Clock out
  ✅ Inter-App Audio (legacy iOS apps)

Built-in DSP:
  ✅ Parametric EQ (8-band)
  ✅ Compressor
  ✅ Reverb (algorithmic)
  ✅ Delay (tempo-sync)

Export:
  ✅ WAV (16/24-bit)
  ✅ MP3 (320 kbps)
  ✅ AAC (256 kbps, Apple Music standard)
  ✅ Share to Files, iCloud, Dropbox

UI:
  ✅ Touch-optimized (multi-touch, gestures)
  ✅ Vaporwave/retrofuturistic aesthetic
  ✅ Dark mode (OLED-optimized)
  ✅ Landscape + Portrait support
```

### Deferred (v2.0+)
```yaml
Later:
  ⏳ Cloud rendering (EOELCloud™)
  ⏳ Remote processing (iPad → server)
  ⏳ Video integration
  ⏳ Spatial audio
  ⏳ EOELWisdom AI assistant
  ⏳ Collaboration features
```

---

## 🛠️ Technical Stack

### Framework: JUCE 7.x
```yaml
Why JUCE?
  ✅ Cross-platform (iOS, macOS, Windows, Linux)
  ✅ Excellent audio engine (low-latency)
  ✅ Plugin hosting built-in (VST3, AU, AUv3)
  ✅ MIDI support (comprehensive)
  ✅ Active community + documentation

iOS Support:
  ✅ Native iOS support
  ✅ Touch gesture handling
  ✅ AUv3 hosting (AudioUnit v3)
  ✅ Inter-App Audio
  ✅ CoreAudio backend
  ✅ Metal rendering (GPU-accelerated UI)
```

### Build System
```cmake
# CMake for iOS
cmake_minimum_required(VERSION 3.22)
project(EOEL_iOS VERSION 1.0.0 LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_OSX_DEPLOYMENT_TARGET 15.0)  # iOS 15+

# JUCE
add_subdirectory(JUCE)

juce_add_gui_app(EOEL_iOS
    PRODUCT_NAME "EOEL"
    BUNDLE_ID "com.echoel.echoelmusic"
    COMPANY_NAME "EOEL"
    COMPANY_WEBSITE "https://echoelmusic.com"

    # iOS specific
    IPHONE_SCREEN_ORIENTATIONS UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight
    IPAD_SCREEN_ORIENTATIONS UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight

    # Capabilities
    MICROPHONE_PERMISSION_ENABLED TRUE
    MICROPHONE_PERMISSION_TEXT "EOEL needs microphone access for audio recording"

    BLUETOOTH_PERMISSION_ENABLED TRUE
    BLUETOOTH_PERMISSION_TEXT "Connect MIDI controllers via Bluetooth"
)

# AUv3 Support
target_compile_definitions(EOEL_iOS PRIVATE
    JUCE_PLUGINHOST_AUv3=1
    JUCE_PLUGINHOST_AU=1
)

# ARM NEON optimizations (iPad)
target_compile_options(EOEL_iOS PRIVATE
    -march=armv8-a+simd
    -ffast-math
)

# Frameworks
target_link_libraries(EOEL_iOS PRIVATE
    "-framework CoreAudio"
    "-framework AVFoundation"
    "-framework CoreMIDI"
    "-framework AudioToolbox"
    "-framework CoreAudioKit"  # AUv3 hosting UI
)
```

---

## 📦 Project Structure

```
EOEL/
├── Sources/
│   ├── iOS/                        # iOS-specific code
│   │   ├── EOELApp.h/.mm   # Main iOS app
│   │   ├── MainViewController.h/.mm # Root view controller
│   │   ├── AudioEngine_iOS.h/.cpp  # iOS audio backend
│   │   └── Gestures.h/.mm          # Touch gesture handling
│   │
│   ├── Audio/                      # Cross-platform audio
│   │   ├── AudioEngine.h/.cpp      # Core audio engine
│   │   ├── Track.h/.cpp            # Audio/MIDI tracks
│   │   └── MixBus.h/.cpp           # Routing + mixing
│   │
│   ├── Plugin/                     # AUv3 hosting
│   │   ├── PluginManager.h/.cpp    # Scan, load, manage plugins
│   │   ├── AUv3Host.h/.mm          # AUv3 specific hosting
│   │   └── PluginWindow.h/.cpp     # Plugin UI hosting
│   │
│   ├── DSP/                        # Built-in effects
│   │   ├── ParametricEQ.h/.cpp
│   │   ├── Compressor.h/.cpp
│   │   ├── Reverb.h/.cpp
│   │   └── Delay.h/.cpp
│   │
│   ├── MIDI/                       # MIDI engine
│   │   ├── MIDIEngine.h/.cpp
│   │   ├── PianoRoll.h/.cpp        # Touch-optimized editor
│   │   └── MIDIRouter.h/.cpp
│   │
│   ├── Sync/
│   │   ├── EOELSync.h/.cpp       # Already created!
│   │   └── AbletonLink.cpp         # Ableton Link SDK
│   │
│   ├── UI/                         # User interface
│   │   ├── MainWindow.h/.cpp       # App window
│   │   ├── TrackView.h/.cpp        # Track list
│   │   ├── MixerView.h/.cpp        # Mixer interface
│   │   ├── PianoRollView.h/.cpp    # MIDI editor
│   │   └── Theme.h/.cpp            # Vaporwave aesthetic
│   │
│   └── Project/                    # Project management
│       ├── ProjectManager.h/.cpp
│       ├── FileIO.h/.cpp
│       └── CloudSync.h/.cpp        # iCloud/Dropbox sync
│
├── Resources/
│   ├── Images/                     # UI graphics
│   ├── Fonts/                      # VT323, IBM Plex Mono
│   └── Presets/                    # Default DSP presets
│
└── CMakeLists.txt
```

---

## 🎨 UI/UX Design Principles

### Vaporwave/Retrofuturistic Aesthetic
```yaml
Color Palette:
  Primary: Cyan (#00E5FF)
  Secondary: Magenta (#FF00FF)
  Accent: Purple (#651FFF)
  Background: Dark (#1A1A2E)
  Surface: Darker (#16213E)

Typography:
  Headers: VT323 (retro terminal)
  Body: IBM Plex Mono (readable)
  Accents: Press Start 2P (sparingly)

Visual Effects:
  - Subtle CRT scanlines
  - Phosphor glow on text
  - Neon gradient borders
  - Smooth animations (60 FPS)
  - Metal shader effects (GPU)

Touch Interactions:
  - Large touch targets (44pt minimum)
  - Gestures: pinch-zoom, two-finger pan
  - Haptic feedback (UIImpactFeedbackGenerator)
  - Smooth scrolling (UIScrollView)
```

### Layout (iPad Landscape)
```
┌────────────────────────────────────────────────────────┐
│ ⚙️ EOEL | 🎵 Project Name  | ▶️ [BPM: 128]  ☁️ 📱│
├─────┬──────────────────────────────────────────────────┤
│     │                                                  │
│  T  │          Waveform / Piano Roll View            │
│  r  │                                                  │
│  a  │  ╔══════════════════════════════════════════╗  │
│  c  │  ║  🎵🎵🎵🎵 ▂▃▅▇▅▃▂ 🎵🎵🎵                 ║  │
│  k  │  ╚══════════════════════════════════════════╝  │
│     │                                                  │
│  L  │  [Track 1: Kick     ] [Vol] [Pan] [FX] [AUv3]  │
│  i  │  [Track 2: Snare    ] [Vol] [Pan] [FX] [AUv3]  │
│  s  │  [Track 3: Bass     ] [Vol] [Pan] [FX] [AUv3]  │
│  t  │  [Track 4: Melody   ] [Vol] [Pan] [FX] [AUv3]  │
│     │                                                  │
├─────┴──────────────────────────────────────────────────┤
│ ⏮️ ⏯️ ⏭️ ⏹️  |  [00:00:00]  |  🔊 ▂▄▆█▆▄▂  |  💾 📤  │
└────────────────────────────────────────────────────────┘
```

---

## 🔌 AUv3 Plugin Hosting (CRITICAL!)

### Why AUv3?
```yaml
✅ User's existing plugins work!
   - All iOS audio apps use AUv3
   - FL Studio Mobile plugins
   - Audiobus effects
   - Hundreds of synths/effects

✅ System-integrated:
   - iOS handles plugin discovery
   - Automatic updates (App Store)
   - Sandboxed (secure)
   - Preset management (cloud sync)

✅ Modern API:
   - Sample-accurate MIDI
   - Parameter automation
   - State save/restore
   - UI embedding (SwiftUI/UIKit)
```

### Implementation (JUCE)
```cpp
// Sources/Plugin/AUv3Host.mm
#include <CoreAudioKit/CoreAudioKit.h>
#include <AudioToolbox/AudioToolbox.h>

class AUv3Host
{
public:
    AUv3Host()
    {
        // Initialize Audio Component Manager
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Effect;  // or kAudioUnitType_MusicDevice
        desc.componentSubType = 0;
        desc.componentManufacturer = 0;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;

        // Find all AUv3 plugins
        scanForPlugins(desc);
    }

    void scanForPlugins(const AudioComponentDescription& desc)
    {
        AudioComponent comp = nullptr;
        while ((comp = AudioComponentFindNext(comp, &desc)) != nullptr)
        {
            CFStringRef name = nullptr;
            AudioComponentCopyName(comp, &name);

            PluginInfo plugin;
            plugin.component = comp;
            plugin.name = juce::String::fromCFString(name);

            availablePlugins.add(plugin);
            CFRelease(name);
        }
    }

    AudioUnit* loadPlugin(const PluginInfo& plugin)
    {
        AudioUnit* audioUnit = nullptr;
        OSStatus result = AudioComponentInstanceNew(plugin.component, &audioUnit);

        if (result == noErr)
        {
            // Initialize audio unit
            AudioUnitInitialize(audioUnit);
            return audioUnit;
        }

        return nullptr;
    }

    // UI hosting (SwiftUI)
    UIViewController* getPluginViewController(AudioUnit* audioUnit)
    {
        // Request view controller from AUv3
        __block AUAudioUnitViewConfiguration* config = nullptr;

        [audioUnit requestViewControllerWithCompletionHandler:^(AUViewController* viewController) {
            // Present plugin UI
            if (viewController != nullptr)
            {
                // Embed in our UI
                [parentViewController addChildViewController:viewController];
                [parentViewController.view addSubview:viewController.view];
            }
        }];
    }

private:
    juce::Array<PluginInfo> availablePlugins;
};
```

### Plugin UI Integration
```swift
// Swift wrapper for plugin UI
import SwiftUI
import CoreAudioKit

struct PluginView: UIViewControllerRepresentable {
    let audioUnit: AUAudioUnit

    func makeUIViewController(context: Context) -> AUViewController {
        var viewController: AUViewController?

        audioUnit.requestViewController { controller in
            viewController = controller
        }

        return viewController ?? UIViewController()
    }

    func updateUIViewController(_ uiViewController: AUViewController, context: Context) {
        // Update if needed
    }
}
```

---

## 🎵 Ableton Link Integration

### SDK Integration
```cpp
// Already have EOELSync.h!
// But for iOS-specific implementation:

#include <ableton/Link.hpp>

class AbletonLinkBridge
{
public:
    AbletonLinkBridge()
        : link(120.0)  // Default 120 BPM
    {
        link.enable(true);
        link.enableStartStopSync(true);
    }

    void setTempo(double bpm)
    {
        auto sessionState = link.captureAppSessionState();
        sessionState.setTempo(bpm, link.clock().micros());
        link.commitAppSessionState(sessionState);
    }

    double getTempo() const
    {
        auto sessionState = link.captureAppSessionState();
        return sessionState.tempo();
    }

    void play()
    {
        auto sessionState = link.captureAppSessionState();
        sessionState.setIsPlaying(true, link.clock().micros());
        link.commitAppSessionState(sessionState);
    }

    int getNumPeers() const
    {
        return link.numPeers();
    }

private:
    ableton::Link link;
};
```

### Usage
```cpp
// In AudioEngine:
abletonLink.setTempo(128.0);
abletonLink.play();

// In audio callback (sample-accurate):
auto sessionState = abletonLink.captureAudioSessionState();
double beat = sessionState.beatAtTime(hostTimeAtBufferBegin, quantum);
```

---

## 🔧 Build & Development Setup

### Requirements
```yaml
Hardware:
  - Mac (Apple Silicon or Intel)
  - iPad (for testing, iOS 15+)
  - iPhone (optional, secondary target)

Software:
  - Xcode 15+
  - CMake 3.22+
  - JUCE 7.x
  - Ableton Link SDK (optional, for sync)
```

### Setup Steps

#### 1. Clone & Configure
```bash
git clone https://github.com/vibrationalforce/EOEL.git
cd EOEL

# Create iOS build directory
mkdir build-ios && cd build-ios

# Configure for iOS
cmake .. \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_OSX_ARCHITECTURES=arm64
```

#### 2. Open in Xcode
```bash
open EOEL.xcodeproj
```

#### 3. Configure Signing
- Select EOEL target
- Signing & Capabilities
- Team: Your Apple Developer account
- Bundle ID: com.echoel.echoelmusic

#### 4. Add Capabilities
- ✅ Audio, AirPlay, and Picture in Picture
- ✅ Background Modes → Audio
- ✅ Inter-App Audio

#### 5. Build & Run
- Select iPad simulator or connected device
- Cmd+R to build and run

---

## 📱 App Store Submission

### Required Assets
```yaml
App Icon:
  - 1024x1024 (App Store)
  - Various sizes (iPad, iPhone)
  - No alpha channel
  - Vaporwave aesthetic (neon cyan/magenta)

Screenshots:
  - iPad Pro 12.9" (2732x2048)
  - iPad Pro 11" (2388x1668)
  - iPhone 15 Pro Max (optional)
  - Show main features:
    1. Track view with waveforms
    2. AUv3 plugin loaded
    3. Piano roll editor
    4. Mixer view
    5. Export options

Preview Video (optional):
  - 15-30 seconds
  - Show creating a beat
  - Loading AUv3 plugin
  - Ableton Link sync with FL Mobile
```

### App Store Description
```
EOEL - Mobile-First Music Production

CREATE MUSIC ANYWHERE
• 8-track audio + MIDI recording
• Ultra-low latency (< 10ms)
• Beautiful vaporwave UI

YOUR PLUGINS WORK!
• AUv3 plugin hosting
• Use FL Studio Mobile plugins
• All your favorite synths & effects

SYNC EVERYTHING
• Ableton Link (FL Mobile, Beatmaker, etc.)
• MIDI Clock output
• Inter-App Audio

BUILT-IN EFFECTS
• Parametric EQ (8-band)
• Compressor
• Reverb + Delay

EXPORT & SHARE
• WAV, MP3, AAC
• iCloud, Dropbox
• Streaming-ready (-14 LUFS)

ONE-TIME PURCHASE
€49.99 - Yours forever!
No subscriptions. No in-app purchases.

Created by EOEL, an artist who codes.
```

### Pricing
```yaml
Tier: €49.99 (or local equivalent)

Free Version (Future):
  - 4 tracks
  - 5 AUv3 plugins max
  - Watermark on export
  → Upgrade to Pro: €49.99 IAP
```

---

## 🎯 Development Timeline

### Month 1: Foundation
```yaml
Week 1-2: Setup & Core Audio
  - ✅ JUCE iOS project
  - ✅ Basic audio playback
  - ✅ CoreAudio backend
  - ✅ 8-track engine

Week 3-4: AUv3 Hosting
  - ✅ Plugin scanning
  - ✅ Plugin loading
  - ✅ UI integration
  - ✅ State save/restore
```

### Month 2: Features
```yaml
Week 5-6: MIDI & Recording
  - ✅ MIDI input (USB, Bluetooth)
  - ✅ MIDI recording
  - ✅ Piano roll editor (touch UI)
  - ✅ Audio recording

Week 7-8: Sync & DSP
  - ✅ Ableton Link integration
  - ✅ Built-in EQ, Compressor
  - ✅ Reverb, Delay
  - ✅ Export (WAV, MP3, AAC)
```

### Month 3: Polish & Launch
```yaml
Week 9-10: UI/UX Polish
  - ✅ Vaporwave aesthetic
  - ✅ Touch gestures
  - ✅ Animations
  - ✅ Dark mode

Week 11-12: Testing & Launch
  - ✅ TestFlight beta (100 users)
  - ✅ Bug fixes
  - ✅ App Store submission
  - ✅ Marketing materials
```

---

## 🚀 Next Steps (Immediate)

1. **Setup iOS Build** (Today)
   ```bash
   cd EOEL
   mkdir build-ios
   cd build-ios
   cmake .. -G Xcode -DCMAKE_SYSTEM_NAME=iOS
   ```

2. **Create iOS-Specific Files** (This Week)
   - Sources/iOS/EOELApp.mm
   - Sources/iOS/AudioEngine_iOS.cpp
   - Sources/Plugin/AUv3Host.mm

3. **Test Basic Audio** (This Week)
   - Playback test tone
   - Verify < 10ms latency
   - Test on real iPad

4. **AUv3 Plugin Scan** (Next Week)
   - Scan for available plugins
   - Display list in UI
   - Load & test one plugin

---

**Created by EOEL™**
**Mobile-First Music Production**
**November 2025** 📱

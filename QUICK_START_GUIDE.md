# 🚀 Echoelmusic Quick Start Guide

Complete setup guide to get iOS + Desktop running in 15 minutes.

---

## 📋 Prerequisites

### iOS Development
- macOS 13.0+
- Xcode 15.0+
- iOS device or simulator (iOS 16.0+)
- Apple Developer account (for device testing)

### Desktop Development
- **macOS**: Xcode 15.0+
- **Windows**: Visual Studio 2022
- **Linux**: gcc/clang, ALSA/JACK
- JUCE Framework 7.0+ ([download](https://juce.com/get-juce))

### Network
- iOS and Desktop on **same WiFi network**
- Firewall allows UDP ports 8000, 8001

---

## 🎯 Step 1: Clone Repository

```bash
git clone https://github.com/vibrationalforce/Echoelmusic.git
cd Echoelmusic
```

---

## 📱 Step 2: Build iOS App

### 2.1 Open in Xcode

```bash
open ios-app/Echoelmusic.xcodeproj
```

### 2.2 Configure Signing

1. Select **Echoelmusic** target
2. Go to **Signing & Capabilities**
3. Select your **Team**
4. Change **Bundle Identifier**: `com.yourname.echoelmusic`

### 2.3 Enable HealthKit

Already configured! Just verify:
- ✅ HealthKit capability enabled
- ✅ Privacy descriptions in Info.plist

### 2.4 Build & Run

1. Select your device/simulator
2. Press **⌘R** to build and run
3. Allow HealthKit permissions when prompted

### 2.5 Verify iOS App

You should see:
- 5 scene buttons (Meditation, Workout, Creative, Relaxation, Sleep)
- Biofeedback data (if HealthKit available)
- Audio controls

---

## 🖥️ Step 3: Build Desktop Engine

### 3.1 Install JUCE

Download and install JUCE Projucer:
https://juce.com/get-juce

### 3.2 Open in Projucer

```bash
# Launch Projucer
# Then: File → Open... → desktop-engine/Echoelmusic.jucer
```

### 3.3 Configure Project

In Projucer, verify these settings:

**Modules Tab:**
- ✅ juce_audio_basics
- ✅ juce_audio_devices
- ✅ juce_audio_utils
- ✅ juce_core
- ✅ juce_data_structures
- ✅ juce_dsp **← CRITICAL**
- ✅ juce_events
- ✅ juce_graphics
- ✅ juce_gui_basics
- ✅ juce_gui_extra
- ✅ juce_osc **← CRITICAL**

**Source Files:**

Add all files from `desktop-engine/Source/`:

```
Source/
├── Main.cpp
├── Audio/
│   ├── BasicSynthesizer.h/cpp
│   ├── EnhancedSynthesizer.h/cpp
│   ├── ReverbEffect.h/cpp
│   ├── DelayEffect.h/cpp
│   └── FilterEffect.h/cpp
├── DSP/
│   └── FFTAnalyzer.h/cpp
├── OSC/
│   └── OSCManager.h/cpp
└── UI/
    └── MainComponent.h/cpp
```

### 3.4 Save & Export

1. **Save Project** (⌘S)
2. Click your platform icon:
   - **macOS**: Xcode icon
   - **Windows**: Visual Studio icon
   - **Linux**: Code::Blocks or Makefile icon

### 3.5 Build in IDE

**macOS (Xcode):**
```bash
cd desktop-engine/Builds/MacOSX
open Echoelmusic.xcodeproj
# Press ⌘R to build and run
```

**Windows (Visual Studio):**
```bash
cd desktop-engine\Builds\VisualStudio2022
Echoelmusic.sln
# Press F5 to build and run
```

**Linux (Makefile):**
```bash
cd desktop-engine/Builds/LinuxMakefile
make CONFIG=Release
./build/Echoelmusic
```

### 3.6 Verify Desktop App

You should see:
- ✅ OSC Server: Listening on port 8000
- Window with biofeedback displays
- Audio output active

---

## 🔗 Step 4: Connect iOS ↔ Desktop

### 4.1 Find Desktop IP Address

**macOS/Linux:**
```bash
ifconfig | grep "inet "
# Look for 192.168.x.x address
```

**Windows:**
```bash
ipconfig
# Look for IPv4 Address: 192.168.x.x
```

Example: `192.168.1.100`

### 4.2 Configure iOS App

1. Open iOS app
2. Tap **Settings** (if you have a settings screen)
3. **OR** Add OSC connection in your main view:

```swift
// In your ContentView or main view
@StateObject var oscManager = OSCManager()
@StateObject var oscReceiver = OSCReceiver()

var body: some View {
    VStack {
        Button("Connect to Desktop") {
            oscManager.connect(to: "192.168.1.100")  // Your Desktop IP
            oscReceiver.startListening()
        }
    }
}
```

### 4.3 Configure Desktop App

In `MainComponent.cpp`, uncomment and set iOS IP:

```cpp
void MainComponent::setupOSC() {
    // ... existing code ...

    // Set iOS client address
    oscManager->setClientAddress("192.168.1.50", 8001);  // Your iOS device IP
}
```

Rebuild Desktop app after changing IP.

### 4.4 Test Connection

**On iOS:**
1. Connect to Desktop
2. Check connection indicator (green = connected)

**On Desktop:**
1. You should see console output when iOS sends data:
   ```
   OSC: Heart Rate: 72.5 bpm
   OSC: HRV: 45.2 ms
   ```

**On iOS (receiving feedback):**
1. Check spectrum visualizer
2. Should see bars moving in real-time
3. RMS/Peak meters updating

---

## 🎵 Step 5: Test Audio Reactivity

### 5.1 Send Biofeedback Data

**If you have HealthKit data:**
- iOS automatically sends Heart Rate and HRV
- Desktop frequency should change with HR

**Manual testing (in code):**

```swift
// Add test button in iOS
Button("Test OSC") {
    oscManager.sendHeartRate(80.0)      // Should hear higher pitch
    oscManager.sendHRV(60.0)            // Should hear more reverb
    oscManager.sendBreathRate(10.0)     // Should hear mellow filter
}
```

### 5.2 Verify Audio Changes

When sending different values:

| Parameter | Low Value | High Value | Expected Audio Change |
|-----------|-----------|------------|----------------------|
| Heart Rate | 60 BPM | 120 BPM | Lower → Higher pitch |
| HRV | 20 ms | 80 ms | Subtle → Spacious reverb |
| Breath Rate | 8/min | 25/min | Mellow → Bright filter |

### 5.3 Check Desktop Feedback

On iOS spectrum visualizer:
- Should see 8 bars moving
- RMS meter shows average level
- Peak meter shows maximum level
- Connection indicator: **green**

---

## 🐛 Troubleshooting

### iOS Build Errors

**"Signing for Echoelmusic requires a development team"**
- Select your Team in Signing & Capabilities
- Change Bundle Identifier to unique name

**"HealthKit not available in simulator"**
- Use real device for HealthKit testing
- OR disable HealthKit in code for simulator testing

### Desktop Build Errors

**"juce_osc module not found"**
- Open Projucer
- Add `juce_osc` in Modules tab
- Save and re-export

**"EnhancedSynthesizer.h not found"**
- Verify all Source files added in Projucer
- Check file paths are correct
- Re-save project

### Connection Issues

**"OSC: Not connected"**
- Verify both devices on same WiFi
- Check firewall allows UDP 8000, 8001
- Verify IP addresses are correct

**"No data received on Desktop"**
- Check iOS connection indicator (should be green)
- Verify Desktop shows "Listening on port 8000"
- Try restarting both apps

**"No spectrum on iOS"**
- Verify Desktop has iOS IP configured
- Check iOS receiver is listening (port 8001)
- Try manual test: Desktop should send ~3 messages/second

---

## 📊 Expected Performance

| Metric | Expected Value |
|--------|----------------|
| **Connection latency** | <10ms |
| **Audio latency** | 5-15ms |
| **Desktop CPU** | 10-20% |
| **iOS CPU** | 5-10% |
| **OSC message rate** | 30-60 Hz (iOS→Desktop), 3 Hz (Desktop→iOS) |

---

## 🎨 UI Integration Example

Complete integration example for iOS:

```swift
import SwiftUI

struct ContentView: View {
    @StateObject var oscManager = OSCManager()
    @StateObject var oscReceiver = OSCReceiver()
    @StateObject var oscBridge = OSCBiofeedbackBridge()

    var body: some View {
        VStack(spacing: 20) {
            // Connection
            HStack {
                Button(oscManager.isConnected ? "Disconnect" : "Connect") {
                    if oscManager.isConnected {
                        oscManager.disconnect()
                        oscReceiver.stopListening()
                    } else {
                        oscManager.connect(to: "192.168.1.100")
                        oscReceiver.startListening()
                        oscBridge.setup(oscManager: oscManager)
                    }
                }

                Text(oscManager.isConnected ? "Connected" : "Disconnected")
                    .foregroundColor(oscManager.isConnected ? .green : .red)
            }

            // Spectrum Visualizer
            SpectrumVisualizerView()

            // Scene Buttons
            // ... your existing UI ...
        }
    }
}
```

---

## 📚 Next Steps

### Week 3 Enhancements (Coming Soon)
- [ ] Multi-voice polyphony (4 voices)
- [ ] Chord generation from pitch
- [ ] Advanced waveform synthesis
- [ ] Parameter presets
- [ ] iOS spectrum animation effects

### Advanced Features
- [ ] Recording and playback
- [ ] MIDI output
- [ ] Ableton Link sync
- [ ] Cloud session sharing

---

## 🔗 Useful Documentation

- **Architecture**: `docs/architecture.md`
- **OSC Protocol**: `docs/osc-protocol.md`
- **Setup Guide**: `docs/setup-guide.md`
- **Desktop Week 2**: `desktop-engine/WEEK_2_ENHANCEMENTS.md`
- **iOS Integration**: `ios-app/Echoelmusic/OSC/INTEGRATION_GUIDE.md`

---

## 💡 Tips

1. **Network Discovery**: Consider adding auto-discovery using Bonjour/mDNS
2. **IP Configuration**: Add settings screen for easy IP entry
3. **Testing**: Use OSC debugging tools (OSCulator, TouchOSC)
4. **Performance**: Increase audio buffer size if CPU is high
5. **Latency**: Use wired network for lowest latency (<5ms)

---

## ✅ Success Checklist

- [ ] iOS app builds and runs
- [ ] Desktop app builds and runs
- [ ] Both apps on same WiFi
- [ ] OSC connection established (green indicator)
- [ ] Desktop receives biofeedback from iOS
- [ ] Desktop audio changes with biofeedback
- [ ] iOS receives spectrum from Desktop
- [ ] Spectrum visualizer shows moving bars
- [ ] No audio glitches or dropouts
- [ ] Latency feels responsive (<20ms)

---

## 🎉 You're Ready!

If all checkboxes are ✅, you have a fully functional bio-reactive music system!

**Enjoy creating music with your body! 🎵✨**

---

**Support**: Open an issue on GitHub if you encounter problems
**Documentation**: See `/docs/` folder for detailed specifications
**Examples**: See Week 2 documentation for advanced features

🎛️ **Happy Music Making!** 🎶

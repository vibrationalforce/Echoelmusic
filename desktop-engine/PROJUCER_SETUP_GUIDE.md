
# Projucer Setup Guide - Echoelmusic Desktop Engine

Complete step-by-step guide to create the JUCE project in Projucer.

---

## Prerequisites

1. **JUCE Framework** (7.0 or later)
   ```bash
   # Download from https://juce.com/get-juce/download
   # Or via git:
   git clone https://github.com/juce-framework/JUCE.git ~/JUCE
   cd ~/JUCE
   git checkout 7.0.9  # Or latest stable
   ```

2. **Projucer**
   ```bash
   cd ~/JUCE
   # macOS
   open Projucer.app

   # Linux
   ./Projucer

   # Windows
   Projucer.exe
   ```

---

## Step 1: Create New Project

1. **Open Projucer**

2. **File → New Project**

3. **Project Settings**:
   - **Type**: Application → Standalone Application
   - **Name**: `Echoelmusic`
   - **Location**: `/path/to/Echoelmusic/desktop-engine/`
   - **Create folder for project**: ✅ Check
   - **Create .h file with main() function**: ❌ Uncheck (we have Main.cpp)

4. **Click "Create Project"**

---

## Step 2: Project Configuration

### Project Settings Tab

```
Project Name: Echoelmusic
Version: 1.0.0
Company Name: Tropical Drones
Company Website: https://tropicaldrones.de

Project Type: Application (Standalone)
Bundle Identifier: de.tropicaldrones.echoelmusic

C++ Language Standard: C++17
```

### Build Settings

**macOS**:
- Deployment Target: 11.0
- Architecture: Universal (Apple Silicon + Intel)

**Windows**:
- Platform Toolset: Latest
- Target Platform: Windows 10

**Linux**:
- Packages: (leave default)

---

## Step 3: Add JUCE Modules

Click "Modules" tab, then "Add Module":

**Required Modules**:
- ✅ `juce_core`
- ✅ `juce_events`
- ✅ `juce_audio_basics`
- ✅ `juce_audio_devices`
- ✅ `juce_audio_formats`
- ✅ `juce_audio_processors`
- ✅ `juce_audio_utils`
- ✅ `juce_gui_basics`
- ✅ `juce_gui_extra`
- ✅ `juce_osc` ← **CRITICAL for OSC communication**

**Module Paths**:
- Global Modules Path: `~/JUCE/modules`
- Or specify manually: `/path/to/JUCE/modules`

---

## Step 4: Add Source Files

In Projucer, **File Explorer** tab:

### 1. Remove default Main.cpp

- Right-click `Main.cpp` (generated)
- Select "Remove file from project"

### 2. Add our source files

**Main.cpp**:
- Right-click on "Source" group
- "Add Existing Files..."
- Select `desktop-engine/Source/Main.cpp`

**OSC** folder:
- Right-click "Source"
- "Add Existing Files..."
- Select `desktop-engine/Source/OSC/` folder
  - `OSCManager.h`
  - `OSCManager.cpp`

**Audio** folder:
- Right-click "Source"
- "Add Existing Files..."
- Select `desktop-engine/Source/Audio/` folder
  - `BasicSynthesizer.h`
  - `BasicSynthesizer.cpp`

**UI** folder:
- Right-click "Source"
- "Add Existing Files..."
- Select `desktop-engine/Source/UI/` folder
  - `MainComponent.h`
  - `MainComponent.cpp`

**Final Structure**:
```
Echoelmusic
├── Source
│   ├── Main.cpp
│   ├── Audio
│   │   ├── BasicSynthesizer.h
│   │   └── BasicSynthesizer.cpp
│   ├── OSC
│   │   ├── OSCManager.h
│   │   └── OSCManager.cpp
│   └── UI
│       ├── MainComponent.h
│       └── MainComponent.cpp
```

---

## Step 5: Audio Settings

**In Project Settings → Audio**:

```
Audio Plugin Formats: (none for standalone)

Standalone Plugin Characteristics:
✅ Standalone Plugin Input
✅ Standalone Plugin Output
```

---

## Step 6: Save and Generate

1. **File → Save Project** (⌘S / Ctrl+S)

2. **"Save and Open in IDE"** button
   - macOS: Opens Xcode project
   - Windows: Opens Visual Studio solution
   - Linux: Generates Makefile

---

## Step 7: Build the Project

### macOS (Xcode)

```bash
cd desktop-engine/Builds/MacOSX
open Echoelmusic.xcodeproj

# In Xcode:
# - Select "Echoelmusic - App" scheme
# - Product → Build (⌘B)
# - Product → Run (⌘R)
```

Or command line:
```bash
cd desktop-engine/Builds/MacOSX
xcodebuild -configuration Release
./build/Release/Echoelmusic.app/Contents/MacOS/Echoelmusic
```

### Windows (Visual Studio)

```bash
cd desktop-engine\Builds\VisualStudio2022
start Echoelmusic.sln

# In Visual Studio:
# - Build → Build Solution (Ctrl+Shift+B)
# - Debug → Start Without Debugging (Ctrl+F5)
```

Or command line:
```bash
cd desktop-engine\Builds\VisualStudio2022
msbuild Echoelmusic.sln /p:Configuration=Release
.\build\Release\Echoelmusic.exe
```

### Linux (Makefile)

```bash
cd desktop-engine/Builds/LinuxMakefile
make CONFIG=Release

./build/Echoelmusic
```

---

## Step 8: Configure Audio Device

When the app launches:

1. **Audio Settings** (usually auto-opens on first launch)
2. **Select Audio Device**:
   - macOS: "Built-in Output" or your audio interface
   - Windows: ASIO driver (if available) or DirectSound
   - Linux: JACK or ALSA
3. **Sample Rate**: 48000 Hz
4. **Buffer Size**: 256 samples (balance latency vs. CPU)

---

## Step 9: Test OSC Connection

### Without iOS App (using oscdump)

```bash
# macOS/Linux
brew install liblo
oscsend localhost 8000 /echoel/bio/heartrate f 75.0

# You should see in Desktop app console:
# ♥️ Heart Rate: 75.0 bpm → Freq: 262.5 Hz
```

### With iOS App

1. **Start Desktop Engine**
   - OSC Server listens on port 8000
   - Audio output starts

2. **On iOS**:
   - Go to OSC Settings
   - Enter Desktop IP (e.g., `192.168.1.100`)
   - Tap "Connect"
   - Enable "Send Biofeedback Data"

3. **Verify**:
   - Desktop UI should show Heart Rate, HRV
   - Audio pitch should change with heart rate
   - iOS should show "Connected" status

---

## Troubleshooting

### "juce_osc module not found"

✅ JUCE version must be 7.0+
✅ Module path is correct (`~/JUCE/modules`)
✅ Update JUCE: `cd ~/JUCE && git pull`

### "Cannot open include file: JuceHeader.h"

✅ Regenerate project in Projucer (save again)
✅ Clean build folder
✅ Check Module Paths in Projucer

### "OSC Server failed to start"

✅ Port 8000 not in use: `lsof -i :8000` (macOS/Linux) or `netstat -an | findstr 8000` (Windows)
✅ Firewall allows UDP port 8000
✅ Try different port (change in OSCManager initialization)

### Build errors in OSCManager.cpp

✅ Ensure `juce_osc` module is added
✅ Check C++ standard is C++17 or later
✅ Re-save project in Projucer

### Audio crackling/dropouts

✅ Increase buffer size (512 or 1024 samples)
✅ Close other audio applications
✅ Use dedicated audio interface (not built-in)

---

## Testing Checklist

After building, verify:

- [ ] App launches without crash
- [ ] Main window appears (600x400)
- [ ] Title shows "🎵 Echoelmusic Desktop Engine"
- [ ] Status shows "✅ OSC Server: Listening on port 8000"
- [ ] Audio outputs sine wave (default 220 Hz)
- [ ] Can send test OSC message with `oscsend`
- [ ] Desktop shows received heart rate
- [ ] Audio pitch changes with heart rate
- [ ] No audio crackling

---

## Performance

**Expected Performance**:
- CPU: 5-15% (with basic synth)
- Latency: <5ms (at 256 buffer size)
- Memory: <100 MB

**If CPU > 50%**:
- Increase buffer size
- Disable visual updates (reduce timer frequency)
- Optimize synthesis (use table lookups)

---

## Next Steps

### Week 2: Enhance Audio Engine

1. **Add Effects**:
   - Reverb (juce::dsp::Reverb)
   - Delay (tap delay)
   - Filter (LP, HP, BP)

2. **Multi-Voice Synthesis**:
   - Polyphony (4 voices)
   - Chord generation from pitch

3. **Advanced Parameter Mapping**:
   - HRV → Reverb wetness
   - Breath → Filter cutoff
   - Coherence → Waveform blend

### Week 3: Analysis & Feedback

1. **FFT Spectrum**:
   - 8-band spectrum
   - Send to iOS via OSC

2. **Metering**:
   - RMS/Peak levels
   - CPU monitoring

---

## Source Files Summary

| File | Lines | Purpose |
|------|-------|---------|
| `Main.cpp` | ~80 | Application entry point |
| `UI/MainComponent.h` | ~50 | Main UI header |
| `UI/MainComponent.cpp` | ~150 | UI implementation & integration |
| `Audio/BasicSynthesizer.h` | ~60 | Synth header |
| `Audio/BasicSynthesizer.cpp` | ~150 | Synth implementation |
| `OSC/OSCManager.h` | ~80 | OSC server header |
| `OSC/OSCManager.cpp` | ~200 | OSC server implementation |

**Total**: ~770 lines of C++ code ✅

---

## Support

**Docs**:
- OSC Protocol: `/docs/osc-protocol.md`
- Architecture: `/docs/architecture.md`
- Desktop README: `/desktop-engine/README.md`

**JUCE Docs**: https://docs.juce.com

**Issues**: https://github.com/vibrationalforce/Echoelmusic/issues

---

**Status**: ✅ **Ready to Build**
**Estimated Setup Time**: 30-60 minutes
**Next**: Test with iOS App (Week 1 complete!)

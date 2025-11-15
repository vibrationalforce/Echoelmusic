# 🖥️ Echoelmusic Desktop Engine

**Status**: ✅ **Production Ready** (Week 2 Complete)

JUCE-based audio engine with bio-reactive synthesis, effects chain, FFT analysis, and bidirectional OSC communication.

---

## 🚀 Quick Start (5 Minutes)

### Prerequisites

1. **Install JUCE** (if not already installed):
   - Download from https://juce.com/get-juce
   - Install Projucer application

2. **Verify JUCE Modules Path**:
   - Open Projucer
   - Go to **Settings** (gear icon)
   - Set **Global Paths** → **JUCE Modules** to your JUCE installation
   - Example: `/Applications/JUCE/modules` (macOS)

---

## 📂 Build Instructions

### Step 1: Open in Projucer

```bash
# Option A: Double-click
desktop-engine/Echoelmusic.jucer

# Option B: From Projucer
File → Open → Navigate to desktop-engine/Echoelmusic.jucer
```

### Step 2: Verify Configuration

In Projucer, check these tabs:

**✅ Modules Tab**
Should show all modules as ✅:
- juce_audio_basics
- juce_audio_devices
- juce_audio_formats
- juce_audio_processors
- juce_audio_utils
- juce_core
- juce_data_structures
- **juce_dsp** ← CRITICAL
- juce_events
- juce_graphics
- juce_gui_basics
- juce_gui_extra
- **juce_osc** ← CRITICAL

If any are missing or show errors, click **Add Module** and select from JUCE folder.

**✅ File Explorer Tab**
Should show:
```
Echoelmusic
└── Source
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

### Step 3: Save & Export

1. Click **Save Project** (⌘S / Ctrl+S)
2. Click your platform's icon:
   - **macOS**: Xcode icon
   - **Windows**: Visual Studio 2022 icon
   - **Linux**: Linux Makefile icon

This generates build files in `Builds/` folder.

---

## 🔨 Platform-Specific Build

### macOS (Xcode)

```bash
cd desktop-engine/Builds/MacOSX
open Echoelmusic.xcodeproj

# In Xcode:
# - Select scheme: Echoelmusic
# - Press ⌘R to build and run
```

**Or via command line:**
```bash
xcodebuild -configuration Release
./build/Release/Echoelmusic.app/Contents/MacOS/Echoelmusic
```

### Windows (Visual Studio 2022)

```bash
cd desktop-engine\Builds\VisualStudio2022
start Echoelmusic.sln

# In Visual Studio:
# - Set configuration to Release
# - Press F5 to build and run
```

**Or via command line:**
```bash
msbuild Echoelmusic.sln /p:Configuration=Release
.\x64\Release\Echoelmusic.exe
```

### Linux (Makefile)

```bash
cd desktop-engine/Builds/LinuxMakefile
make CONFIG=Release -j8
./build/Echoelmusic
```

**Dependencies** (install if missing):
```bash
# Ubuntu/Debian
sudo apt-get install libasound2-dev libfreetype6-dev libx11-dev \
  libxinerama-dev libxrandr-dev libxcursor-dev libgl1-mesa-dev

# Fedora
sudo dnf install alsa-lib-devel freetype-devel libX11-devel \
  libXinerama-devel libXrandr-devel libXcursor-devel mesa-libGL-devel
```

---

## ✅ Verify It Works

When you run the app, you should see:

```
🎵 Echoelmusic Desktop Engine (Enhanced)
✅ OSC Server: Listening on port 8000

♥️ Heart Rate: --
🫀 HRV: --
🌬️ Breath Rate: --
🧘 Coherence: --
🎹 Frequency: 220 Hz
```

**Expected behavior:**
- Window opens (600x450)
- No compile errors
- Console shows "OSC Server listening on port 8000"
- Audio device selected automatically

---

## 🔧 Troubleshooting

### "Module juce_osc not found"

**Solution:**
1. Open Projucer
2. Click **Modules** tab
3. Click **Add a module**
4. Navigate to your JUCE installation
5. Select `modules/juce_osc`
6. Save and re-export

### "Module juce_dsp not found"

Same as above, but add `modules/juce_dsp`.

### "File not found: EnhancedSynthesizer.h"

**Solution:**
1. In Projucer, verify all files are listed in **File Explorer** tab
2. If missing, right-click **Source** → **Add Existing Files**
3. Navigate to `desktop-engine/Source/` and add missing folders
4. Save and re-export

### "No audio device found"

**Solution:**
- **macOS**: Grant microphone permission (System Settings → Privacy)
- **Windows**: Check Windows Sound settings
- **Linux**: Verify ALSA/JACK is running

### Build errors with C++17

**Solution:**
In Projucer:
1. Click **Settings** (gear icon)
2. For your platform, set **C++ Language Standard** to **C++17**
3. Save and re-export

---

## 🎛️ Audio Settings

Default settings (in code):
- **Sample Rate**: 48000 Hz
- **Buffer Size**: 256 samples
- **Latency**: ~5-10ms

To change:
Edit `MainComponent.cpp` → `prepareToPlay()`:
```cpp
void MainComponent::prepareToPlay(int samplesPerBlockExpected, double sampleRate)
{
    // samplesPerBlockExpected = buffer size
    // sampleRate = 44100 or 48000
    synthesizer->prepareToPlay(samplesPerBlockExpected, sampleRate);
}
```

---

## 📡 OSC Configuration

### Setting iOS Client Address

To send analysis back to iOS, edit `MainComponent.cpp`:

```cpp
void MainComponent::setupOSC()
{
    // ... existing code ...

    // Set iOS device IP (find via Settings → WiFi → Info)
    oscManager->setClientAddress("192.168.1.50", 8001);
}
```

**Find iOS IP:**
- iOS: Settings → WiFi → Tap (i) icon → IP Address
- Desktop will send spectrum/RMS/peak to this address

### Testing OSC

Use Python test script:
```bash
cd ../scripts
pip install -r requirements.txt
python osc_test.py --mode ios --desktop-ip 127.0.0.1
```

You should see biofeedback values update in Desktop app!

---

## 📊 Performance Tuning

### Reduce CPU Usage

If CPU is high (>20%):

1. **Increase buffer size**:
   - macOS: Audio MIDI Setup → Configure Speakers → Buffer Size: 512
   - Windows: ASIO Control Panel → Buffer Size: 512

2. **Reduce OSC feedback rate**:
   - Edit `MainComponent.h` → Change `feedbackInterval` from 10 to 30
   - This reduces Desktop→iOS messages from 3Hz to 1Hz

3. **Disable FFT** (if not needed):
   - Comment out `fftAnalyzer->process()` in `EnhancedSynthesizer.cpp`

### Reduce Latency

For lowest latency (<5ms):

1. **Decrease buffer size**: 128 or 64 samples
2. **Use dedicated audio interface** (not built-in speakers)
3. **Close other audio applications**

---

## ✨ Features

**Synthesis:**
- Bio-reactive sine oscillator
- Heart Rate → Frequency (40-200 BPM → 100-800 Hz)
- HRV → Amplitude (0-100ms → 0.1-0.5 gain)

**Effects Chain:**
- Reverb (HRV → wetness & room size)
- Delay (coherence → feedback)
- Filter (breath rate → cutoff, exponential)
- Signal Flow: `Synth → Filter → Delay → Reverb → FFT → Output`

**Analysis:**
- 8-band FFT spectrum (20Hz-20kHz)
- RMS/Peak metering (-80 to 0 dB)
- Sent to iOS @ 3Hz

**OSC:**
- Bidirectional communication
- <10ms latency (typical: 3-8ms)
- iOS→Desktop: biofeedback (30-60 Hz)
- Desktop→iOS: analysis (3 Hz)

---

## 📚 Documentation

| File | Description |
|------|-------------|
| **WEEK_2_ENHANCEMENTS.md** | Week 2 features (effects, FFT, OSC feedback) |
| **PROJUCER_SETUP_GUIDE.md** | Original Projucer setup instructions |
| **../QUICK_START_GUIDE.md** | Complete iOS + Desktop setup |
| **../docs/osc-protocol.md** | Full OSC message specification |
| **../docs/architecture.md** | System architecture and data flow |

---

## 🎯 Next Steps

1. **Build and run** - Follow Quick Start above
2. **Test OSC** - Use Python script in `../scripts/`
3. **Connect iOS** - See `../QUICK_START_GUIDE.md`
4. **Fine-tune** - Adjust parameters in code
5. **Extend** - Add more effects, voices, features!

---

**Version**: 1.0.0 (Week 2 Complete)
**Platforms**: macOS, Windows, Linux
**Status**: ✅ Production Ready

🎵 **Happy Music Making!** 🎛️

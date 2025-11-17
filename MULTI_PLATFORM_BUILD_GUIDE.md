# 🌍 ECHOELMUSIC MULTI-PLATFORM BUILD GUIDE

**Complete guide for building Echoelmusic on Windows, macOS, and Linux**

---

## 📋 **QUICK START**

### **Linux (Ubuntu/Debian)**
```bash
./verify_build.sh
```

### **macOS**
```bash
./build-macos.sh
```

### **Windows**
```cmd
build-windows.bat
```

---

## 🐧 **LINUX BUILD** (Ubuntu 20.04+, Debian 11+, Arch, Fedora)

### Prerequisites

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    libasound2-dev \
    libfreetype6-dev \
    libx11-dev \
    libxext-dev \
    libxrandr-dev \
    libxinerama-dev \
    libxcursor-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev
```

**Arch Linux:**
```bash
sudo pacman -S \
    base-devel \
    cmake \
    ninja \
    git \
    alsa-lib \
    freetype2 \
    libx11 \
    libxext \
    libxrandr \
    libxinerama \
    libxcursor \
    mesa
```

**Fedora/RHEL:**
```bash
sudo dnf install -y \
    gcc-c++ \
    cmake \
    ninja-build \
    git \
    alsa-lib-devel \
    freetype-devel \
    libX11-devel \
    libXext-devel \
    libXrandr-devel \
    libXinerama-devel \
    libXcursor-devel \
    mesa-libGL-devel
```

### Build Steps

1. **Clone repository:**
```bash
git clone https://github.com/vibrationalforce/Echoelmusic.git
cd Echoelmusic
```

2. **Install JUCE (automatic):**
```bash
if [ ! -d "ThirdParty/JUCE/modules" ]; then
    git clone --depth 1 --branch 7.0.12 \
        https://github.com/juce-framework/JUCE.git ThirdParty/JUCE
fi
```

3. **Configure and build:**
```bash
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_VST3=ON \
    -DBUILD_STANDALONE=ON

cmake --build build --parallel $(nproc)
```

4. **Install:**
```bash
# VST3
cp -r build/Echoelmusic_artefacts/Release/VST3/Echoelmusic.vst3 ~/.vst3/

# Standalone
sudo cp build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic /usr/local/bin/
```

### Output

- **VST3:** `build/Echoelmusic_artefacts/Release/VST3/Echoelmusic.vst3`
- **Standalone:** `build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic`
- **Size:** ~4-5 MB (optimized)

---

## 🍎 **MACOS BUILD** (macOS 10.13+, Universal Binary)

### Prerequisites

1. **Xcode Command Line Tools:**
```bash
xcode-select --install
```

2. **Homebrew packages:**
```bash
brew install cmake ninja git
```

### Build Steps

1. **Clone repository:**
```bash
git clone https://github.com/vibrationalforce/Echoelmusic.git
cd Echoelmusic
```

2. **Run build script:**
```bash
chmod +x build-macos.sh
./build-macos.sh Release
```

**Or manually:**
```bash
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.13 \
    -DBUILD_VST3=ON \
    -DBUILD_AU=ON \
    -DBUILD_STANDALONE=ON

cmake --build build --parallel $(sysctl -n hw.ncpu)
```

3. **Install:**
```bash
# VST3
cp -r build/Echoelmusic_artefacts/Release/VST3/Echoelmusic.vst3 \
    ~/Library/Audio/Plug-Ins/VST3/

# Audio Units
cp -r build/Echoelmusic_artefacts/Release/AU/Echoelmusic.component \
    ~/Library/Audio/Plug-Ins/Components/

# Standalone App
cp -r build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic.app \
    /Applications/
```

4. **Verify Universal Binary:**
```bash
lipo -info build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic.app/Contents/MacOS/Echoelmusic
# Output should show: arm64 x86_64
```

### Output

- **VST3:** `build/Echoelmusic_artefacts/Release/VST3/Echoelmusic.vst3`
- **AU:** `build/Echoelmusic_artefacts/Release/AU/Echoelmusic.component`
- **App:** `build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic.app`
- **Architectures:** arm64 (Apple Silicon) + x86_64 (Intel)
- **Size:** ~5-6 MB per architecture (Universal ~10-12 MB)

### Code Signing (for distribution)

```bash
# Sign the app
codesign --deep --force --verify --verbose \
    --sign "Developer ID Application: Your Name (TEAMID)" \
    Echoelmusic.app

# Verify signature
codesign --verify --verbose=4 Echoelmusic.app

# Create DMG
hdiutil create -volname "Echoelmusic" -srcfolder Echoelmusic.app \
    -ov -format UDZO Echoelmusic.dmg

# Notarize (requires Apple Developer account)
xcrun notarytool submit Echoelmusic.dmg \
    --keychain-profile "AC_PASSWORD" \
    --wait

# Staple notarization ticket
xcrun stapler staple Echoelmusic.dmg
```

---

## 🪟 **WINDOWS BUILD** (Windows 10+, Visual Studio 2019/2022)

### Prerequisites

1. **Visual Studio 2019 or 2022** (Community Edition is free)
   - Download: https://visualstudio.microsoft.com/downloads/
   - Install "Desktop development with C++" workload

2. **CMake** (3.22+)
   - Download: https://cmake.org/download/
   - Or via Chocolatey: `choco install cmake`

3. **Git**
   - Download: https://git-scm.com/download/win
   - Or via Chocolatey: `choco install git`

### Build Steps

1. **Open "Developer Command Prompt for VS 2022"** (important!)

2. **Clone repository:**
```cmd
git clone https://github.com/vibrationalforce/Echoelmusic.git
cd Echoelmusic
```

3. **Run build script:**
```cmd
build-windows.bat Release
```

**Or manually:**
```cmd
REM Configure
cmake -B build -G "Visual Studio 17 2022" -A x64 ^
    -DCMAKE_BUILD_TYPE=Release ^
    -DBUILD_VST3=ON ^
    -DBUILD_STANDALONE=ON

REM Build
cmake --build build --config Release --parallel
```

4. **Install:**
```cmd
REM VST3 (requires admin)
xcopy /E /I /Y build\Echoelmusic_artefacts\Release\VST3\Echoelmusic.vst3 ^
    "%COMMONPROGRAMFILES%\VST3\Echoelmusic.vst3"

REM Standalone
xcopy /E /I /Y build\Echoelmusic_artefacts\Release\Standalone ^
    "%PROGRAMFILES%\Echoelmusic"
```

### Output

- **VST3:** `build\Echoelmusic_artefacts\Release\VST3\Echoelmusic.vst3`
- **EXE:** `build\Echoelmusic_artefacts\Release\Standalone\Echoelmusic.exe`
- **Size:** ~5-6 MB (optimized)

### Creating Installer (Optional)

**Using NSIS:**
```cmd
REM Install NSIS: choco install nsis
cd build
cpack -G NSIS
REM Output: Echoelmusic-1.0.0-win64.exe
```

**Using WiX (MSI):**
```cmd
REM Install WiX: choco install wixtoolset
cd build
cpack -G WIX
REM Output: Echoelmusic-1.0.0-win64.msi
```

---

## ⚙️ **BUILD CONFIGURATION OPTIONS**

### Plugin Formats

```cmake
-DBUILD_VST3=ON           # VST3 (all platforms)
-DBUILD_AU=ON             # Audio Units (macOS only)
-DBUILD_AAX=OFF           # Pro Tools AAX (requires AAX SDK)
-DBUILD_LV2=OFF           # LV2 (Linux, not recommended - use VST3)
-DBUILD_CLAP=ON           # CLAP (modern format)
-DBUILD_STANDALONE=ON     # Standalone application
```

### Audio Backends

**Windows:**
```cmake
-DENABLE_WASAPI=ON        # Windows Audio Session API (recommended)
-DENABLE_ASIO=ON          # ASIO (low latency)
-DENABLE_DIRECTSOUND=ON   # DirectSound (legacy)
```

**Linux:**
```cmake
-DENABLE_ALSA=ON          # ALSA (recommended)
-DENABLE_JACK=OFF         # JACK (professional audio)
-DENABLE_PULSEAUDIO=OFF   # PulseAudio
```

### Optimizations

```cmake
-DCMAKE_BUILD_TYPE=Release      # Release optimizations (-O3)
-DCMAKE_BUILD_TYPE=Debug        # Debug symbols (-g)
-DCMAKE_BUILD_TYPE=RelWithDebInfo  # Release + debug symbols
```

---

## 🧪 **TESTING**

### Quick Test

```bash
# Linux/macOS
./build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic

# Windows
build\Echoelmusic_artefacts\Release\Standalone\Echoelmusic.exe
```

### DAW Testing

**Supported DAWs:**
- **Ableton Live** (VST3)
- **Logic Pro** (AU, macOS only)
- **Pro Tools** (AAX, if built)
- **Reaper** (VST3, AU, all platforms)
- **Bitwig Studio** (VST3, CLAP)
- **FL Studio** (VST3, Windows/macOS)
- **Cubase/Nuendo** (VST3)
- **Studio One** (VST3)
- **Ardour** (VST3, Linux)

**Test Checklist:**
- [ ] Plugin loads without errors
- [ ] All 46 DSP effects accessible
- [ ] Audio input/output works
- [ ] Automation works
- [ ] Presets save/load correctly
- [ ] CPU usage < 20% (idle)
- [ ] Latency < 10ms
- [ ] No audio glitches

---

## 📊 **BUILD STATISTICS**

### Compilation Time

| Platform | CPU | Time | Parallel Jobs |
|----------|-----|------|---------------|
| Linux (Ryzen 9 5900X) | 12 cores | ~3 min | 12 |
| macOS (M1 Max) | 10 cores | ~4 min | 10 |
| Windows (i7-11700K) | 8 cores | ~5 min | 8 |

### Binary Sizes (Release, stripped)

| Platform | VST3 | Standalone | Total |
|----------|------|------------|-------|
| Linux x86_64 | 3.8 MB | 4.4 MB | 8.2 MB |
| macOS Universal | 8.0 MB | 10.5 MB | 18.5 MB |
| Windows x64 | 4.2 MB | 5.1 MB | 9.3 MB |

### Features Included

- ✅ 46 professional DSP effects
- ✅ 5 MIDI composition tools
- ✅ Biofeedback integration
- ✅ SIMD optimizations (AVX2/NEON/SSE)
- ✅ Ultra-low latency capable (<1ms)
- ✅ Multi-threaded audio processing
- ✅ OpenGL-accelerated UI
- ✅ Session management
- ✅ Preset system

---

## 🐛 **TROUBLESHOOTING**

### Common Issues

**"JUCE not found"**
```bash
# Solution: Clone JUCE manually
git clone --depth 1 --branch 7.0.12 https://github.com/juce-framework/JUCE.git ThirdParty/JUCE
```

**Linux: "X11 headers not found"**
```bash
# Solution: Install X11 development packages
sudo apt-get install libx11-dev libxext-dev libxrandr-dev
```

**macOS: "Command line tools not found"**
```bash
# Solution: Install Xcode command line tools
xcode-select --install
```

**Windows: "MSVC not found"**
```
Solution: Run from "Developer Command Prompt for VS 2022"
Not regular cmd.exe!
```

**"Linking errors with JUCE modules"**
```bash
# Solution: Clean and rebuild
rm -rf build
cmake -B build ...
```

---

## 🚀 **CI/CD AUTOMATED BUILDS**

GitHub Actions automatically builds for all platforms on every push:

- **Linux** (Ubuntu latest)
- **Windows** (Visual Studio 2022)
- **macOS** (Universal Binary)

**Artifacts available:** https://github.com/vibrationalforce/Echoelmusic/actions

**Tagged releases:** https://github.com/vibrationalforce/Echoelmusic/releases

---

## 📚 **ADDITIONAL RESOURCES**

- **JUCE Documentation:** https://docs.juce.com/
- **CMake Documentation:** https://cmake.org/documentation/
- **VST3 SDK:** https://steinbergmedia.github.io/vst3_doc/
- **Audio Units:** https://developer.apple.com/documentation/audiounit

---

## 💬 **SUPPORT**

**Issues:** https://github.com/vibrationalforce/Echoelmusic/issues
**Discussions:** https://github.com/vibrationalforce/Echoelmusic/discussions
**Website:** https://echoelmusic.com (coming soon)

---

**Build Guide Version:** 1.0.0
**Last Updated:** November 2025
**Platforms:** Linux, macOS, Windows

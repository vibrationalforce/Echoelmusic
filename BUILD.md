# BUILD & SETUP GUIDE - Echoelmusic 🎵

Complete guide to building Echoelmusic from source on all platforms.

---

## 📋 PREREQUISITES

### All Platforms

- **CMake** 3.22 or later
- **C++17** compatible compiler
- **Git** (for cloning and submodules)

### Platform-Specific

#### macOS / iOS
- **Xcode** 26 or later
- **macOS** 15.0 (Sequoia) or later
- **iOS SDK** 26 or later (for iOS builds)
- **Developer Tools**: `xcode-select --install`

#### Windows
- **Visual Studio** 2019 or 2022
- **Windows 10 SDK** (minimum version 10.0.19041.0)
- **Visual C++ Build Tools**
- Optional: **ASIO SDK** for low-latency audio

#### Linux
- **GCC** 9+ or **Clang** 10+
- **Dependencies**:
  ```bash
  # Ubuntu/Debian
  sudo apt install build-essential cmake git \
    libasound2-dev libjack-jackd2-dev \
    libpulse-dev libfreetype6-dev \
    libx11-dev libxext-dev libxrandr-dev \
    libxinerama-dev libxcursor-dev \
    libgl1-mesa-dev libglu1-mesa-dev

  # Fedora/RHEL
  sudo dnf install cmake gcc-c++ git \
    alsa-lib-devel jack-audio-connection-kit-devel \
    pulseaudio-libs-devel freetype-devel \
    libX11-devel libXext-devel mesa-libGL-devel

  # Arch
  sudo pacman -S base-devel cmake git \
    alsa-lib jack2 pulseaudio \
    freetype2 libx11 libxext mesa
  ```

#### Android
- **Android Studio** 2021.1 or later
- **Android SDK** Level 24 (Android 7.0) minimum
- **Android NDK** r23 or later

---

## 🔧 STEP 1: CLONE REPOSITORY

```bash
git clone https://github.com/vibrationalforce/Echoelmusic.git
cd Echoelmusic
```

---

## 🎼 STEP 2: INSTALL JUCE FRAMEWORK

Echoelmusic requires JUCE 7.0.9 or later.

### Option A: Git Submodule (Recommended)

```bash
git submodule add https://github.com/juce-framework/JUCE.git ThirdParty/JUCE
git submodule update --init --recursive
```

### Option B: Download Manually

```bash
# Linux/macOS
cd ThirdParty
wget https://github.com/juce-framework/JUCE/releases/download/7.0.9/juce-7.0.9-linux.zip
unzip juce-7.0.9-linux.zip -d JUCE
cd ..

# Windows
# Download from https://github.com/juce-framework/JUCE/releases/download/7.0.9/juce-7.0.9-windows.zip
# Extract to ThirdParty/JUCE
```

---

## 🏗️ STEP 3: BUILD

### macOS / iOS

#### Build for macOS (Universal Binary: Intel + Apple Silicon)

```bash
mkdir build
cd build

# Configure
cmake .. \
  -G "Xcode" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_VST3=ON \
  -DBUILD_AU=ON \
  -DBUILD_AAX=OFF \
  -DBUILD_STANDALONE=ON

# Build
cmake --build . --config Release

# Install plugins
cmake --install . --config Release
```

**Output Locations:**
- VST3: `~/Library/Audio/Plug-Ins/VST3/Echoelmusic.vst3`
- AU: `~/Library/Audio/Plug-Ins/Components/Echoelmusic.component`
- Standalone: `build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic.app`

#### Build for iOS (AUv3)

```bash
mkdir build-ios
cd build-ios

cmake .. \
  -G "Xcode" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DBUILD_AUv3=ON \
  -DBUILD_VST3=OFF \
  -DBUILD_AU=OFF \
  -DBUILD_STANDALONE=ON

cmake --build . --config Release
```

---

### Windows

#### Using Visual Studio

```bash
mkdir build
cd build

# Configure
cmake .. ^
  -G "Visual Studio 17 2022" ^
  -A x64 ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DBUILD_VST3=ON ^
  -DBUILD_AAX=OFF ^
  -DBUILD_STANDALONE=ON ^
  -DENABLE_ASIO=ON ^
  -DENABLE_WASAPI=ON

# Build
cmake --build . --config Release

# Install
cmake --install . --config Release
```

**Output Locations:**
- VST3: `C:\Program Files\Common Files\VST3\Echoelmusic.vst3`
- Standalone: `build\Echoelmusic_artefacts\Release\Standalone\Echoelmusic.exe`

#### With ASIO Support

1. Download ASIO SDK from Steinberg
2. Extract to `ThirdParty/asiosdk`
3. Add `-DENABLE_ASIO=ON` to cmake command

---

### Linux

```bash
mkdir build
cd build

# Configure
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_VST3=ON \
  -DBUILD_STANDALONE=ON \
  -DENABLE_ALSA=ON \
  -DENABLE_JACK=ON \
  -DENABLE_PULSEAUDIO=ON

# Build (use all CPU cores)
cmake --build . --config Release -j$(nproc)

# Install
sudo cmake --install . --config Release
```

**Output Locations:**
- VST3: `~/.vst3/Echoelmusic.vst3`
- Standalone: `build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic`

---

### Android

```bash
mkdir build-android
cd build-android

cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-24 \
  -DBUILD_ANDROID_APP=ON \
  -DENABLE_ANDROID_OBOE=ON

cmake --build . --config Release
```

Import `build-android` into Android Studio for app packaging.

---

## 🧪 STEP 4: TESTING

### Run Standalone Application

#### macOS
```bash
./build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic.app/Contents/MacOS/Echoelmusic
```

#### Windows
```bash
.\build\Echoelmusic_artefacts\Release\Standalone\Echoelmusic.exe
```

#### Linux
```bash
./build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic
```

### Test Plugin in DAW

1. Open your DAW (Ableton, Logic, FL Studio, Reaper, etc.)
2. Rescan plugins
3. Look for "Echoelmusic" in effects/instruments
4. Load plugin and test audio routing

### Verify Installation

```bash
# macOS - Check VST3
ls -la ~/Library/Audio/Plug-Ins/VST3/Echoelmusic.vst3

# macOS - Check AU
ls -la ~/Library/Audio/Plug-Ins/Components/Echoelmusic.component

# Windows - Check VST3
dir "C:\Program Files\Common Files\VST3\Echoelmusic.vst3"

# Linux - Check VST3
ls -la ~/.vst3/Echoelmusic.vst3
```

---

## 🚀 ADVANCED BUILD OPTIONS

### Debug Build

```bash
cmake .. -DCMAKE_BUILD_TYPE=Debug
cmake --build . --config Debug
```

### Build Specific Formats Only

```bash
# VST3 only
cmake .. -DBUILD_VST3=ON -DBUILD_AU=OFF -DBUILD_STANDALONE=OFF

# Standalone only
cmake .. -DBUILD_VST3=OFF -DBUILD_AU=OFF -DBUILD_STANDALONE=ON
```

### Build with AAX (Pro Tools)

1. Download AAX SDK from Avid Developer
2. Extract to `ThirdParty/AAX_SDK`
3. Configure with `-DBUILD_AAX=ON`

### Build with CLAP Support

```bash
git clone https://github.com/free-audio/clap.git ThirdParty/clap
cmake .. -DBUILD_CLAP=ON
```

### Performance Optimization

```bash
# Enable LTO (Link-Time Optimization)
cmake .. -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON

# Native CPU optimization
cmake .. -DCMAKE_CXX_FLAGS="-march=native -O3"
```

---

## 🐛 TROUBLESHOOTING

### CMake Can't Find JUCE

**Solution:**
```bash
# Ensure JUCE is in the correct location
ls ThirdParty/JUCE/CMakeLists.txt

# If missing, clone JUCE
git submodule update --init --recursive
```

### "undefined reference to JUCE symbols"

**Solution:**
- Ensure all JUCE modules are linked in CMakeLists.txt
- Clean build directory: `rm -rf build && mkdir build`

### macOS: "cannot be opened because the developer cannot be verified"

**Solution:**
```bash
# Remove quarantine flag
xattr -cr ~/Library/Audio/Plug-Ins/VST3/Echoelmusic.vst3
xattr -cr ~/Library/Audio/Plug-Ins/Components/Echoelmusic.component

# Or allow in System Preferences > Security & Privacy
```

### Windows: Missing VCRUNTIME140.dll

**Solution:**
- Install Visual C++ Redistributable
- Download from Microsoft: https://aka.ms/vs/17/release/vc_redist.x64.exe

### Linux: "cannot open shared object file"

**Solution:**
```bash
# Install missing dependencies
sudo apt install libfreetype6 libx11-6 libxext6 libasound2

# Update library cache
sudo ldconfig
```

### ASIO Not Working (Windows)

**Solution:**
- Ensure ASIO drivers are installed (ASIO4ALL or hardware drivers)
- Run Echoelmusic as Administrator (first time only)
- Check Windows audio settings

### Plugin Not Showing in DAW

**Solution:**
1. **Rescan plugins** in DAW preferences
2. **Check plugin paths** in DAW settings
3. **Verify installation**:
   - macOS: `pluginval --validate ~/Library/Audio/Plug-Ins/VST3/Echoelmusic.vst3`
   - Windows: `pluginval.exe --validate "C:\Program Files\Common Files\VST3\Echoelmusic.vst3"`

---

## 📦 PACKAGING FOR DISTRIBUTION

### macOS - Create DMG Installer

```bash
# Create DMG
hdiutil create -volname "Echoelmusic" \
  -srcfolder build/Echoelmusic_artefacts/Release \
  -ov -format UDZO Echoelmusic-1.0.0-macOS.dmg

# Sign DMG (requires Developer ID)
codesign --force --sign "Developer ID Application: Your Name" \
  Echoelmusic-1.0.0-macOS.dmg
```

### Windows - Create Installer

Use **Inno Setup** or **NSIS**:

```iss
; Inno Setup Script
[Setup]
AppName=Echoelmusic
AppVersion=1.0.0
DefaultDirName={commonpf}\VST3\Echoelmusic
OutputBaseFilename=Echoelmusic-1.0.0-Windows

[Files]
Source: "build\Echoelmusic_artefacts\Release\VST3\Echoelmusic.vst3"; DestDir: "{app}"
Source: "build\Echoelmusic_artefacts\Release\Standalone\Echoelmusic.exe"; DestDir: "{app}"
```

### Linux - Create DEB Package

```bash
# Create package structure
mkdir -p echoelmusic_1.0.0/usr/lib/vst3
mkdir -p echoelmusic_1.0.0/usr/bin
mkdir -p echoelmusic_1.0.0/DEBIAN

# Copy files
cp -r build/Echoelmusic_artefacts/Release/VST3/Echoelmusic.vst3 \
  echoelmusic_1.0.0/usr/lib/vst3/
cp build/Echoelmusic_artefacts/Release/Standalone/Echoelmusic \
  echoelmusic_1.0.0/usr/bin/

# Create control file
cat > echoelmusic_1.0.0/DEBIAN/control <<EOF
Package: echoelmusic
Version: 1.0.0
Architecture: amd64
Maintainer: Echoelmusic <michaelterbuyken@gmail.com>
Description: Bio-Reactive Audio Processing Platform
EOF

# Build package
dpkg-deb --build echoelmusic_1.0.0
```

---

## 🔐 CODE SIGNING

### macOS

```bash
# Sign all components
codesign --force --sign "Developer ID Application: Your Name" \
  --options runtime \
  --entitlements Resources/Entitlements.plist \
  ~/Library/Audio/Plug-Ins/VST3/Echoelmusic.vst3

# Notarize
xcrun notarytool submit Echoelmusic-1.0.0-macOS.dmg \
  --apple-id your@email.com \
  --team-id TEAMID \
  --password APP_SPECIFIC_PASSWORD
```

### Windows

```bash
# Sign with signtool
signtool sign /tr http://timestamp.digicert.com /td sha256 /fd sha256 \
  /a Echoelmusic.vst3
```

---

## 📊 BUILD STATISTICS

**Expected Build Times (Release, -j8):**

| Platform | Configuration | Time |
|----------|--------------|------|
| macOS M1 | Universal Binary | ~8 min |
| macOS Intel | x86_64 | ~12 min |
| Windows | x64 | ~10 min |
| Linux | x86_64 | ~7 min |
| iOS | arm64 | ~10 min |
| Android | arm64-v8a | ~15 min |

**Binary Sizes:**

| Format | Size (Release) |
|--------|---------------|
| VST3 | ~35 MB |
| AU | ~32 MB |
| AUv3 | ~28 MB |
| Standalone | ~40 MB |
| AAX | ~38 MB |

---

## 🆘 SUPPORT

**Documentation:**
- [MASTER_STRATEGY.md](MASTER_STRATEGY.md) - Implementation roadmap
- [COMPLETE_FEATURE_LIST.md](COMPLETE_FEATURE_LIST.md) - All features
- [HARDWARE_INTEGRATION_GUIDE.md](HARDWARE_INTEGRATION_GUIDE.md) - Hardware setup
- [CREATOR_AGENCY_GUIDE.md](CREATOR_AGENCY_GUIDE.md) - Business features
- [GLOBAL_REACH_STRATEGY.md](GLOBAL_REACH_STRATEGY.md) - Accessibility & i18n

**Community:**
- GitHub Issues: https://github.com/vibrationalforce/Echoelmusic/issues
- Discord: https://discord.gg/echoelmusic
- Forum: https://forum.echoelmusic.com

**Contact:**
- Email: michaelterbuyken@gmail.com
- Website: https://echoelmusic.com

---

## 📝 LICENSE

See [LICENSE](LICENSE) file for details.

---

**Last Updated:** 2025-11-12
**Version:** 1.0.0
**Build System:** CMake 3.22+, JUCE 7.0.9+

---

**Ready to build the future of music creation! 🚀🎵**

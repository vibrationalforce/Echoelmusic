# Echoelmusic Release Guide

## Automated Builds

Every push to `main` triggers automatic builds for all platforms via GitHub Actions.

### Creating a Release

1. **Tag the version:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

2. **GitHub Actions automatically:**
   - Builds Windows (VST3, CLAP, Standalone, Installer)
   - Builds macOS (VST3, AU, CLAP, Standalone, DMG)
   - Builds Linux (VST3, CLAP, Standalone, AppImage, Deb)
   - Builds Android (APK)
   - Creates GitHub Release with all downloads

3. **Download links appear at:**
   ```
   https://github.com/YOUR_USERNAME/Echoelmusic/releases/latest
   ```

---

## Manual Local Builds

### Windows

```powershell
# Prerequisites
choco install cmake git visualstudio2022-workload-nativedesktop

# Build
cd Sources/Desktop
mkdir build && cd build
cmake -G "Visual Studio 17 2022" -A x64 ..
cmake --build . --config Release

# Create installer
choco install nsis
cd ../../../installers/windows
makensis installer.nsi
```

### macOS

```bash
# Prerequisites
xcode-select --install
brew install cmake

# Build
cd Sources/Desktop
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build .

# Create DMG
cd ../../../installers/macos
chmod +x create-dmg.sh
./create-dmg.sh
```

### Linux

```bash
# Prerequisites (Ubuntu/Debian)
sudo apt-get install build-essential cmake git \
    libasound2-dev libjack-jackd2-dev libfreetype6-dev \
    libx11-dev libxcomposite-dev libxcursor-dev \
    libxext-dev libxinerama-dev libxrandr-dev \
    libxrender-dev libglu1-mesa-dev

# Build
cd Sources/Desktop
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build .

# Create packages
cd ../../../installers/linux
chmod +x create-appimage.sh
./create-appimage.sh
```

### Android

```bash
cd android
./gradlew assembleRelease

# APK location:
# android/app/build/outputs/apk/release/app-release.apk
```

---

## Download Links (After Release)

| Platform | Format | Download |
|----------|--------|----------|
| **Windows** | Installer | `Echoelmusic-Windows-Setup.exe` |
| **Windows** | VST3 | `Echoelmusic.vst3` |
| **Windows** | CLAP | `Echoelmusic.clap` |
| **macOS** | DMG | `Echoelmusic-macOS-1.0.0.dmg` |
| **Linux** | AppImage | `Echoelmusic-1.0.0-x86_64.AppImage` |
| **Linux** | Deb | `echoelmusic_1.0.0_amd64.deb` |
| **Android** | APK | `Echoelmusic-1.0.0.apk` |

---

## Plugin Installation Paths

### Windows
- VST3: `C:\Program Files\Common Files\VST3\`
- CLAP: `C:\Program Files\Common Files\CLAP\`

### macOS
- VST3: `/Library/Audio/Plug-Ins/VST3/`
- AU: `/Library/Audio/Plug-Ins/Components/`
- CLAP: `/Library/Audio/Plug-Ins/CLAP/`

### Linux
- VST3: `~/.vst3/` or `/usr/lib/vst3/`
- CLAP: `~/.clap/` or `/usr/lib/clap/`

---

## Version History

### v1.0.0 (Initial Release)
- 16-voice polyphonic synthesizer
- TR-808 Bass with pitch glide
- AI Stem Separation
- Bio-reactive features
- Quantum AI composition
- Full MIDI 2.0 / MPE support
- Cross-platform: Windows, macOS, Linux, Android, iOS

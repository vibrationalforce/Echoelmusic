# ECHOEL Platform Support

Comprehensive cross-platform architecture for iOS, Android, macOS, Windows, Linux, Web, VR/AR.

## Platform Status

| Platform | Status | Implementation | Notes |
|----------|--------|----------------|-------|
| **iOS** | ✅ Production | Native Swift + Metal | Full featured |
| **iPadOS** | ✅ Production | Native Swift + Metal | Optimized for tablets |
| **macOS** | 🟡 Ready | Native Swift + Metal | Desktop app structure ready |
| **visionOS** | 🟡 Ready | Native Swift + RealityKit | Spatial computing |
| **Android** | 🔵 Planned | Kotlin + Vulkan | Core engine ready |
| **Windows** | 🔵 Planned | C# .NET MAUI / C++ | DirectX 12 |
| **Linux** | 🔵 Planned | C++ / Rust | Vulkan + PipeWire |
| **Web** | 🔵 Planned | TypeScript + WASM | WebGPU/WebGL |
| **Meta Quest** | 🔵 Planned | Unity/Unreal plugin | Native VR |
| **SteamVR** | 🔵 Planned | OpenVR SDK | PC VR |
| **PSVR2** | 🔵 Planned | PS5 SDK | Console VR |

## Architecture

### Core Engine (Platform-Agnostic)

```
Sources/Echoel/
├── Platform/
│   ├── HardwareAbstractionLayer.swift   ✅ IMPLEMENTED
│   └── GraphicsAPIAbstraction.swift     ✅ IMPLEMENTED
├── Audio/
│   ├── AudioEngine.swift                ✅ IMPLEMENTED
│   └── Effects/
│       └── AudioEffectsManager.swift    ✅ IMPLEMENTED
├── Visual/
│   ├── VisualizationMode.swift          ✅ IMPLEMENTED
│   ├── MIDIToVisualMapper.swift         ✅ IMPLEMENTED
│   └── CymaticsRenderer.swift           ✅ IMPLEMENTED
├── Export/
│   └── VideoExportManager.swift         ✅ IMPLEMENTED
├── Integration/
│   ├── OSCManager.swift                 ✅ IMPLEMENTED
│   └── WebRTCManager.swift              ✅ IMPLEMENTED
└── Tracking/
    └── GazeTracker.swift                ✅ IMPLEMENTED
```

### Platform-Specific Implementations

```
Platforms/
├── iOS/              ✅ Current implementation
├── Android/          🔵 See Android/README.md
├── macOS/            🔵 See macOS/README.md
├── Windows/          🔵 See Windows/README.md
├── Linux/            🔵 See Linux/README.md
├── Web/              🔵 See Web/README.md
└── VR/               🔵 See VR/README.md
```

## Platform-Specific Features

### iOS / iPadOS
- ✅ Metal GPU acceleration
- ✅ ARKit face/hand tracking
- ✅ HealthKit integration
- ✅ Spatial Audio
- ✅ MIDI 2.0 / MPE
- ✅ CoreML on-device AI
- ✅ Background audio

### Android
- 🔵 Vulkan rendering
- 🔵 ARCore tracking
- 🔵 Health Connect API
- 🔵 Oboe low-latency audio
- 🔵 MIDI over USB/BLE
- 🔵 TensorFlow Lite

### macOS
- 🔵 Metal GPU acceleration
- 🔵 Desktop window management
- 🔵 Multi-display support
- 🔵 Pro audio (JACK, CoreAudio)
- 🔵 MIDI 2.0
- 🔵 Export to Final Cut Pro

### Windows
- 🔵 DirectX 12 / Vulkan
- 🔵 Windows Hello
- 🔵 WASAPI audio
- 🔵 ASIO low-latency
- 🔵 Touch Bar support
- 🔵 Xbox controller integration

### Linux
- 🔵 Vulkan rendering
- 🔵 PipeWire audio
- 🔵 JACK audio
- 🔵 GTK/Qt UI
- 🔵 X11/Wayland
- 🔵 ALSA MIDI

### Web
- 🔵 WebGPU rendering
- 🔵 WebGL 2.0 fallback
- 🔵 WebAssembly core
- 🔵 Web Audio API
- 🔵 WebMIDI
- 🔵 WebRTC multiplayer
- 🔵 WebXR (VR in browser)

### VR/AR
- 🔵 Meta Quest (Android-based)
- 🔵 SteamVR (PC)
- 🔵 PSVR2 (PS5)
- 🔵 Apple Vision Pro (visionOS)
- 🔵 Hand tracking
- 🔵 6DOF controllers
- 🔵 Spatial audio
- 🔵 Passthrough AR

## Getting Started

### For Each Platform:

1. **Read platform-specific README** in `Platforms/{platform}/README.md`
2. **Install platform SDK** (Xcode, Android Studio, etc.)
3. **Run platform setup script** if available
4. **Build and test** using platform tools

## Hardware Requirements

### Minimum Specs (Per Platform)

**iOS:**
- iPhone XS / iPad Pro 2018 or newer
- iOS 15.0+
- 3 GB RAM

**Android:**
- Snapdragon 845 / Exynos 9810 equivalent
- Android 10+
- Vulkan 1.1 support
- 4 GB RAM

**Desktop (macOS/Windows/Linux):**
- 8 GB RAM
- GPU with Vulkan 1.2 / DirectX 12 / Metal 2
- 4-core CPU (2.5 GHz+)

**Web:**
- Modern browser (Chrome 94+, Firefox 93+, Safari 15+)
- WebGPU support (or WebGL 2.0)
- 4 GB RAM

**VR:**
- Meta Quest 2/3/Pro
- PC: GTX 1070 / RTX 2060 or better
- 8 GB RAM (16 GB recommended)

## Development Workflow

### Cross-Platform Development Process:

1. **Core Logic** → Implement in platform-agnostic Swift/Kotlin/C++
2. **HAL Integration** → Use `HardwareAbstractionLayer.swift`
3. **Graphics** → Use `GraphicsAPIAbstraction.swift`
4. **Platform Specifics** → Implement in platform folders
5. **Testing** → Test on all target platforms
6. **CI/CD** → Automated builds for each platform

## API Consistency

All platforms expose the same high-level API:

```swift
// Same API across all platforms
let blab = EchoelEngine()
blab.start()

blab.setVisualizationMode(.cymatics)
blab.setSpatialAudioMode(.afa)

blab.onBioUpdate { hrv, hr, coherence in
    // React to biofeedback
}

blab.export(to: url, format: .hevc)
```

## Feature Parity Matrix

| Feature | iOS | Android | macOS | Windows | Linux | Web |
|---------|-----|---------|-------|---------|-------|-----|
| Audio Engine | ✅ | 🔵 | 🔵 | 🔵 | 🔵 | 🔵 |
| Visual Engine | ✅ | 🔵 | 🔵 | 🔵 | 🔵 | 🔵 |
| Biofeedback | ✅ | 🔵 | 🔵 | ❌ | ❌ | ❌ |
| Face Tracking | ✅ | 🔵 | ❌ | ❌ | ❌ | 🔵 |
| Gaze Tracking | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| MIDI 2.0 | ✅ | 🔵 | 🔵 | 🔵 | 🔵 | 🔵 |
| Spatial Audio | ✅ | 🔵 | 🔵 | 🔵 | 🔵 | 🔵 |
| Video Export | ✅ | 🔵 | 🔵 | 🔵 | 🔵 | 🔵 |
| OSC | ✅ | 🔵 | 🔵 | 🔵 | 🔵 | 🔵 |
| WebRTC | ✅ | 🔵 | 🔵 | 🔵 | 🔵 | 🔵 |
| NDI | 🔵 | 🔵 | 🔵 | 🔵 | 🔵 | ❌ |

✅ = Implemented
🔵 = Planned
❌ = Not applicable

## Build Instructions

### iOS
```bash
cd Platforms/iOS
xcodebuild -scheme Echoel
```

### Android
```bash
cd Platforms/Android
./gradlew assembleDebug
```

### macOS
```bash
cd Platforms/macOS
xcodebuild -scheme Echoel-macOS
```

### Web
```bash
cd Platforms/Web
npm install
npm run build
```

## Testing

### Unit Tests
```bash
swift test                    # iOS/macOS
./gradlew test               # Android
npm test                     # Web
```

### Integration Tests
Each platform has integration tests in `Platforms/{platform}/Tests/`

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on:
- Adding new platforms
- Implementing platform-specific features
- Maintaining cross-platform compatibility
- Testing across platforms

## License

See [LICENSE](../LICENSE)

## Support

- Documentation: https://blab.audio/docs
- Issues: https://github.com/vibrationalforce/echoel-ios-app/issues
- Discord: https://discord.gg/blab

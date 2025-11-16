# CLAUDE.md — Echoelmusic Platform

## 🎯 Project Overview
Echoelmusic ist eine biofeedback-gesteuerte Creative Platform mit Audio DAW (JUCE C++), iOS App (Swift), und Streaming-Engine. Früher "BLAB", jetzt vollständig zu "Echoelmusic" rebranded.

**Stack**: Swift (iOS), C++ (JUCE), Metal (GPU), HealthKit (Biometrics)

## 🏗️ Architecture

```
Echoelmusic/
├── Sources/
│   ├── Echoelmusic/           # Swift iOS App (SwiftUI + Combine)
│   │   ├── Audio/            # AVAudioEngine, binaural beats
│   │   ├── Spatial/          # 3D/4D spatial audio, Ambisonics
│   │   ├── Visual/           # Metal shaders, particle engine
│   │   ├── Biofeedback/      # HealthKit HRV, coherence
│   │   ├── MIDI/             # MIDI 2.0, MPE zones
│   │   ├── LED/              # Push3 RGB, DMX/Art-Net
│   │   ├── Stream/           # RTMP, chat aggregation
│   │   ├── Recording/        # Multi-track sessions
│   │   ├── Video/            # Chromakey, export
│   │   └── Unified/          # 60Hz control hub
│   ├── Audio/                # C++ Audio Engine (JUCE)
│   ├── DSP/                  # 50+ DSP effects (C++)
│   ├── MIDI/                 # ChordGenius, MelodyForge
│   ├── Synthesis/            # EchoSynth, WaveForge
│   ├── Video/                # VideoWeaver
│   ├── Wellness/             # Audio-visual entrainment
│   └── Plugin/               # JUCE plugin entry point
├── Tests/EchoelmusicTests/   # XCTest unit tests
├── ThirdParty/JUCE/          # JUCE audio framework
├── Resources/                # Assets, PrivacyInfo.xcprivacy
└── .github/workflows/        # CI/CD (4 workflows)
```

## 🛠️ Essential Commands

```bash
# Swift Package Manager (iOS/macOS)
swift build                   # Build iOS framework
swift test                    # Run unit tests
swift package resolve         # Resolve dependencies

# Xcode (iOS App)
open Package.swift            # Open in Xcode
xcodebuild -scheme Echoelmusic -destination 'platform=iOS Simulator,name=iPhone 15 Pro' test

# CMake (C++ JUCE Plugin)
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
./build/Echoelmusic_Standalone  # Run standalone app

# Testing
./test.sh                     # Run all tests
./test-ios15.sh               # iOS 15 compatibility tests
./debug.sh                    # Debug build

# Scripts
./setup_juce.sh               # Setup JUCE framework
./build.sh                    # Production build
./deploy.sh                   # Deployment
```

## 📝 Code Conventions

### Swift (iOS)

- **SwiftUI + Combine** for reactive UI
- **@MainActor** for all UI classes
- **NO force unwraps (!)** — use optional binding
- Biometric data: HealthKit local-only, NEVER sync
- 60 FPS target, 120 FPS on ProMotion
- Compiler warnings = 0

### C++ (JUCE)

- **Audio callback: NO allocations, NO locks**
- Use `juce::AudioProcessorValueTreeState` for parameters
- Target latency: **<3ms** roundtrip
- RAII, smart pointers only
- SIMD optimizations (AVX2, ARM NEON)

### Metal Shaders

- 60 FPS minimum for particle engine
- 100k particles target on M1+
- Avoid synchronous GPU waits

## 🔒 Security Requirements

### P0 (Critical)

- ✅ **Biometric data**: AES-256 encryption (PrivacyManager.swift:211-231)
- ✅ **HealthKit**: Local-only, NOT linked to identity (PrivacyInfo.xcprivacy)
- ⚠️ **RTMP streaming**: NO encryption key in code (RTMPClient.swift:9 stores in plaintext)
- ⚠️ **CloudKit**: Uses plaintext sync (CloudSyncManager.swift:54-65)
- ❌ **Encryption keys**: Stored in UserDefaults, NOT Keychain (PrivacyManager.swift:199-207)

### P1 (High)

- Validate all audio input buffers
- Rate limiting on cloud sync
- HIPAA compliance for health data
- No third-party trackers (NSPrivacyTracking: false)

## 🧪 Testing Standards

- **Unit tests**: 40% coverage (target: >80%)
- **Audio tests**: Latency, pitch detection, binaural beats
- **Biofeedback tests**: HRV coherence algorithm
- **UI tests**: Particle engine, face tracking
- **Performance**: <3ms audio, 60fps UI, <200MB memory

Current test files:
- `Tests/EchoelmusicTests/BinauralBeatTests.swift` (8.5 KB)
- `Tests/EchoelmusicTests/ComprehensiveTestSuite.swift` (19.9 KB)
- `Tests/EchoelmusicTests/HealthKitManagerTests.swift` (5.5 KB)
- `Tests/EchoelmusicTests/PitchDetectorTests.swift` (13.9 KB)
- `Tests/EchoelmusicTests/UnifiedControlHubTests.swift` (4.8 KB)
- `Tests/EchoelmusicTests/FaceToAudioMapperTests.swift` (8.4 KB)

## 🚀 Git Workflow

```bash
# Always use claude/* branches
git checkout -b claude/feature-name-{sessionId}

# Commit format (follow existing pattern)
git commit -m "feat: Add biometric encryption 🔒"
git commit -m "fix: Resolve audio latency issue 🎵"
git commit -m "perf: Optimize particle engine 💨"
git commit -m "docs: Update API documentation 📚"

# Push to designated branch
git push -u origin claude/echoelmusic-security-audit-015t2hvDhJanpsp4vRQ2t4pa

# Never push to main directly
```

## ⚡ Performance Targets

| Component | Target | Current |
|-----------|--------|---------|
| Audio latency | <3ms | ~5ms (needs optimization) |
| UI rendering | 60 FPS | 60 FPS ✅ |
| Particle count | 100k @ 60fps | 500 max (ParticleView.swift:39) |
| Control loop | 60 Hz | 60 Hz ✅ |
| Memory usage | <200 MB | ~150 MB ✅ |
| HRV coherence calc | <10ms | Unknown (needs benchmark) |

## 🐛 Known Issues & Gotchas

1. **Sample rate mismatch**: iOS defaults to 48kHz, ensure audio session configured (AudioConfiguration.swift)
2. **HealthKit authorization**: Async, may fail silently on simulator
3. **Metal shader compilation**: First run slow, cache after
4. **RTMP handshake**: Incomplete implementation (RTMPClient.swift:79-83 TODO)
5. **CloudKit encryption**: Uses plaintext, needs E2E encryption
6. **Keychain storage**: Encryption keys in UserDefaults, NOT Keychain (security risk)

## 🔥 Critical Paths (DO NOT BREAK)

1. **`Sources/Echoelmusic/Biofeedback/HealthKitManager.swift`** — HRV monitoring, coherence algorithm
2. **`Sources/Echoelmusic/Audio/AudioEngine.swift`** — Main audio hub
3. **`Sources/Echoelmusic/Unified/UnifiedControlHub.swift`** — 60Hz control loop
4. **`Sources/Echoelmusic/ParticleView.swift`** — Real-time particle physics
5. **`Sources/Echoelmusic/Privacy/PrivacyManager.swift`** — Privacy compliance
6. **`Sources/DSP/BioReactiveDSP.cpp`** — C++ audio processing
7. **`Resources/PrivacyInfo.xcprivacy`** — App Store privacy nutrition label

## 📊 Monitoring & Logs

```bash
# iOS Debugging
log stream --predicate 'subsystem == "com.blab.studio"' --level debug

# Audio Performance
# Enable in AudioConfiguration.swift:
# AudioConfiguration.setAudioThreadPriority()

# Memory Profiling
# Instruments > Allocations
# Instruments > Leaks

# FPS/GPU
# Xcode > Debug > View Debugging > Rendering
```

## 🚨 Emergency Procedures

### Audio Glitch
1. Check buffer size (AudioConfiguration.swift)
2. Verify sample rate (48kHz)
3. Profile with Instruments > Audio

### Memory Leak
1. Run Instruments > Leaks
2. Check particle cleanup (ParticleView.swift:83-85)
3. Verify HealthKit query stop (HealthKitManager.swift:423-425)

### High Latency
1. Verify audio thread priority (AudioConfiguration.swift:83)
2. Check CPU usage (should be <30%)
3. Reduce particle count

### HealthKit Authorization Fail
1. Check Info.plist permissions
2. Reset simulator: `xcrun simctl privacy booted reset health`
3. Test on real device with Apple Watch

### Streaming Drop
1. Verify RTMP URL and stream key
2. Check network bandwidth
3. Review RTMPClient.swift error logs

## 📚 Documentation

- **Main README**: `/README.md` (444 lines)
- **Architecture**: `/ARCHITECTURE_SCIENTIFIC.md`
- **Build Guide**: `/BUILD.md`
- **Xcode Setup**: `/XCODE_HANDOFF.md` (MUST READ before dev)
- **iOS Dev Guide**: `/iOS_DEVELOPMENT_GUIDE.md`
- **Deployment**: `/DEPLOYMENT.md`
- **Status Report**: `/ECHOELMUSIC_STATUS_REPORT.md`
- **Feature List**: `/COMPLETE_FEATURE_LIST.md` (29 KB, comprehensive)

## 🔐 Privacy & Compliance

### GDPR/CCPA

- ✅ Data minimization: Collect only essential biometric data
- ✅ User control: Privacy modes (Maximum/Balanced/Convenience)
- ✅ Right to access: `PrivacyManager.exportAllUserData()` (line 243)
- ✅ Right to delete: `PrivacyManager.deleteAllUserData()` (line 304)
- ✅ No tracking: NSPrivacyTracking = false

### HIPAA Compliance

- ⚠️ **CRITICAL**: Biometric data transmitted unencrypted via WebSocket (needs fix)
- ✅ Local storage: HealthKit data never leaves device
- ⚠️ Cloud sync: Needs E2E encryption (currently plaintext)
- ✅ Access control: HealthKit authorization required

## 🎯 Development Priorities

### Phase 4 (Current - 80% Complete)
- Recording & session management
- Multi-track audio export
- Cloud sync with encryption

### Phase 5 (Planned - 0% Complete)
- AI composition layer
- ML-powered mixing
- Generative music

### Technical Debt
1. **P0**: Fix biometric WebSocket encryption
2. **P0**: Move encryption keys to Keychain
3. **P0**: Implement RTMP handshake
4. **P1**: Increase test coverage to >80%
5. **P1**: Optimize particle engine to 100k particles
6. **P2**: CloudKit E2E encryption

## 🛠️ Tools & Dependencies

### Required
- **Xcode 15.2+**
- **Swift 5.9+**
- **CMake 3.22+** (for JUCE)
- **iOS 15+** (deployment target)

### Optional
- SwiftLint (code quality)
- swift-format (formatting)
- Instruments (profiling)
- JUCE Framework (included in ThirdParty/)

### External SDKs (not in repo)
- AAX SDK (Pro Tools plugin)
- ASIO SDK (Windows low-latency)
- Oboe (Android audio)

## 🚀 Quick Start for Claude Code

```bash
# 1. Clone and setup
git clone https://github.com/vibrationalforce/Echoelmusic.git
cd Echoelmusic

# 2. Open in Xcode
open Package.swift

# 3. Build iOS app
xcodebuild -scheme Echoelmusic -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# 4. Run tests
swift test

# 5. Build JUCE plugin
cmake -B build && cmake --build build
```

## 📞 Contact & Support

- **Repository**: https://github.com/vibrationalforce/Echoelmusic
- **Issues**: Use GitHub Issues for bug reports
- **Security**: Report security issues via GitHub Security Advisory

---

**Last Updated**: 2025-11-16
**Version**: Phase 4 (MVP 75% Complete)
**Maintainer**: Claude Code Compatible ✅

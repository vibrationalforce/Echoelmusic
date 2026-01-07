# Integration Tests Documentation

## Overview

The `IntegrationTests.swift` file contains comprehensive end-to-end integration tests for the Echoelmusic platform. These tests verify that multiple components work correctly together in real-world workflows.

**Location:** `/home/user/Echoelmusic/Tests/EchoelmusicTests/IntegrationTests.swift`

**Total Test Methods:** 50+

**Lines of Code:** 1,695

## Test Categories

### 1. BioAudioIntegrationTests (10 tests)

Tests the complete biofeedback pipeline from HealthKit to audio output.

| Test Method | Description |
|-------------|-------------|
| `testHealthKitToAudioEngineFlow()` | Full pipeline: HealthKit → UnifiedControlHub → AudioEngine |
| `testCoherenceAffectsSpatialAudioGeometry()` | Coherence changes affecting spatial audio field geometry |
| `testHRVModulatesFilterParameters()` | HRV modulating filter cutoff via BioModulator |
| `testBreathSyncWithAudioTempo()` | Breathing rate synchronized with audio tempo |
| `testCoherenceAffectsReverbMix()` | Coherence affecting reverb wet/dry mix |
| `testHeartRateDrivesInstrumentEnvelope()` | Heart rate driving ADSR envelope parameters |
| `testGSRModulatesDistortion()` | Skin conductance modulating distortion amount |
| `testBreathPhaseModulatesFilterEnvelope()` | Breath phase modulating filter envelope |
| `testMultipleBioSourcesMappedSimultaneously()` | Multiple bio sources mapped to different targets |
| `testBioModulationSmoothing()` | Smoothing prevents sudden parameter jumps |

**Key Workflows:**
- HealthKit → BioModulator → Audio Parameters
- Coherence → Spatial Audio Geometry
- Breath → Tempo/Filter Modulation

### 2. VisualAudioIntegrationTests (8 tests)

Tests audio-visual synchronization and mapping.

| Test Method | Description |
|-------------|-------------|
| `testAudioBeatDetectionToVisualSync()` | Beat detection drives visual pulse/animation |
| `testFrequencyAnalysisToColorMapping()` | Spectrum analysis → color mapping (bass=red, mid=green, high=blue) |
| `testQuantumVisualizationRespondsToAudio()` | Quantum light emulator responding to audio |
| `testAudioAmplitudeModulatesVisualIntensity()` | Audio amplitude → visual brightness |
| `testAudioWaveformDrivesParticleEmission()` | Waveform analysis → particle emission rate |
| `testStereoFieldAffectsVisualSpatialDistribution()` | Stereo width → visual spatial spread |
| `testSpectralCentroidDrivesVisualBrightness()` | Spectral centroid → brightness (dark vs bright sounds) |
| `testOnsetDetectionTriggersVisualEvents()` | Onset detection → visual flash events |

**Key Workflows:**
- Audio Beat → Visual Pulse
- Frequency Spectrum → Color Mapping
- Onsets → Visual Events

### 3. HardwareIntegrationTests (8 tests)

Tests integration with external MIDI, DMX, and hardware controllers.

| Test Method | Description |
|-------------|-------------|
| `testMIDIInputToAudioParameterChanges()` | MIDI CC messages → audio parameter changes |
| `testDMXOutputSynchronizedWithAudio()` | DMX lighting synchronized with audio beat |
| `testPush3LEDFeedbackFromCoherence()` | Ableton Push 3 LED feedback from coherence |
| `testMIDIClockSyncWithAudioEngine()` | MIDI clock synchronization at 120 BPM |
| `testArtNetLightControlFromSpatialAudioPosition()` | Spatial audio position → Art-Net DMX control |
| `testMPEPerNoteControl()` | MIDI Polyphonic Expression per-voice control |
| `testAbletonLinkSyncAcrossDevices()` | Ableton Link tempo sync across devices |
| `testOSCIntegration()` | Open Sound Control (OSC) message handling |

**Key Workflows:**
- MIDI → Audio Parameters
- Audio → DMX Lighting
- Coherence → Push 3 LEDs
- MPE Per-Note Expression

### 4. StreamingIntegrationTests (6 tests)

Tests live streaming workflows with bio data overlays.

| Test Method | Description |
|-------------|-------------|
| `testBioDataToStreamingOverlay()` | Bio data rendered as stream overlay |
| `testMultiDestinationStreamingSetup()` | Simultaneous streaming to YouTube, Twitch, Facebook |
| `testQualityAdaptationBasedOnNetwork()` | Adaptive quality based on network bandwidth |
| `testRTMPHandshakeAndConnection()` | RTMP connection and handshake |
| `testStreamHealthMonitoring()` | Stream health metrics (dropped frames, bitrate) |
| `testStreamingWithVisualEffectsOverlay()` | Visual effects composited into stream |

**Key Workflows:**
- Bio Data → Stream Overlay
- Multi-Destination Streaming
- Adaptive Quality

### 5. CollaborationIntegrationTests (6 tests)

Tests worldwide collaboration and multi-user sessions.

| Test Method | Description |
|-------------|-------------|
| `testSessionCreationAndJoining()` | Create and join collaboration sessions |
| `testBioSyncBetweenParticipants()` | Bio data sync across participants |
| `testStateSynchronization()` | Shared state sync (BPM, key, scale) |
| `testRealTimeParameterSync()` | Real-time parameter updates across participants |
| `testLatencyMeasurementAndCompensation()` | Round-trip latency measurement and compensation |
| `testChatAndReactionsSystem()` | Chat messages and reactions |

**Key Workflows:**
- Session Creation/Joining
- Bio Coherence Sync
- Real-Time Parameter Sync

### 6. PluginIntegrationTests (6 tests)

Tests the developer plugin SDK and plugin system.

| Test Method | Description |
|-------------|-------------|
| `testPluginLoadingAndActivation()` | Plugin loading from bundle |
| `testPluginBioDataAccess()` | Plugin access to shared bio data |
| `testInterPluginCommunication()` | Message passing between plugins |
| `testPluginRESTAPIAccess()` | Plugin REST API client |
| `testPluginPerformanceMonitoring()` | CPU, memory, latency monitoring |
| `testPluginErrorHandlingAndRecovery()` | Plugin crash recovery |

**Key Workflows:**
- Plugin Lifecycle
- Shared Bio Data Access
- Inter-Plugin Communication

### 7. FullSessionIntegrationTests (6 tests)

Tests complete end-to-end session workflows.

| Test Method | Description |
|-------------|-------------|
| `testCompleteSessionWorkflow()` | Full session: start → bio → audio → visual → end |
| `testPresetApplicationAcrossAllSystems()` | Preset applied to all engines simultaneously |
| `testRecordingAndPlayback()` | Session recording and playback |
| `testSessionAnalyticsAndMetrics()` | Session analytics (duration, avg coherence, etc.) |
| `testExportToMultipleFormats()` | Export to WAV, JSON, PDF |
| `testCrossPlatformSessionMigration()` | Session migration between iOS, macOS, Android |

**Key Workflows:**
- Complete Session Lifecycle
- Preset Application
- Recording/Playback
- Cross-Platform Migration

## Running Integration Tests

### Method 1: Using the Test Script

```bash
./run_integration_tests.sh
```

### Method 2: Using Swift Test Directly

```bash
# Run all integration tests
swift test --filter IntegrationTests

# Run specific test category
swift test --filter IntegrationTests.testBioAudio

# Run with verbose output
swift test --filter IntegrationTests --verbose
```

### Method 3: Using the Main Test Script

```bash
./test.sh --verbose
```

### Method 4: In Xcode

1. Open `Package.swift` in Xcode
2. Navigate to Test Navigator (⌘5)
3. Find `IntegrationTests` test class
4. Click the diamond icon next to the class or individual test methods

## Test Requirements

### Runtime Requirements

- **Platform:** iOS 15+, macOS 12+, or Linux
- **Dependencies:** All Echoelmusic components installed
- **Hardware (Optional):**
  - Ableton Push 3 (for Push 3 tests)
  - DMX interface (for lighting tests)
  - MIDI controller (for MIDI tests)

**Note:** Tests will use mocks/stubs when real hardware is unavailable.

### Mock Components

The integration tests include comprehensive mock/stub classes:

- `AudioToVisualMapper` - Audio-visual mapping
- `AudioToQuantumMapper` - Audio-quantum mapping
- `BioToLEDMapper` - Bio-LED mapping
- `PluginManager` - Plugin system
- `SessionManager` - Session management
- `StreamHealthMonitor` - Stream monitoring
- And many more...

These mocks allow tests to run without real hardware or network connections.

## Test Assertions

Each test includes multiple assertions:

- **State Verification:** Component state is correct
- **Data Flow:** Data flows correctly between components
- **Timing:** Events occur in correct order
- **Error Handling:** Errors are handled gracefully
- **Performance:** Operations complete within expected time

## Common Test Patterns

### Async Testing

```swift
func testAsyncOperation() async throws {
    // Start async operation
    await component.start()

    // Wait for completion
    try await Task.sleep(for: .milliseconds(100))

    // Verify results
    XCTAssertTrue(component.isRunning)
}
```

### Component Setup/Teardown

```swift
override func setUp() async throws {
    try await super.setUp()
    cancellables = Set<AnyCancellable>()
}

override func tearDown() async throws {
    cancellables = nil
    try await super.tearDown()
}
```

### Multi-Component Integration

```swift
// Setup all components
let healthKit = HealthKitManager()
let audioEngine = AudioEngine(microphoneManager: micManager)
let hub = UnifiedControlHub(audioEngine: audioEngine)

// Enable integrations
hub.enableBioFeedback(healthKitManager: healthKit)

// Test interaction
hub.start()
healthKit.hrvCoherence = 0.85
// Verify effect propagates...
```

## Expected Output

```
========================================
  Echoelmusic Integration Test Suite
========================================

Running Integration Tests...

Test Suite 'IntegrationTests' started
  ✓ testHealthKitToAudioEngineFlow (0.25s)
  ✓ testCoherenceAffectsSpatialAudioGeometry (0.18s)
  ✓ testHRVModulatesFilterParameters (0.03s)
  ✓ testBreathSyncWithAudioTempo (0.02s)
  ... (46 more tests)

Test Suite 'IntegrationTests' passed
  - 50 tests passed
  - 0 tests failed
  - Total duration: 12.5s

✓ All integration tests passed!
```

## Continuous Integration

Integration tests are run automatically in CI/CD:

- **GitHub Actions:** `.github/workflows/phase8000-ci.yml`
- **Run Frequency:** On every push and PR
- **Timeout:** 10 minutes
- **Platforms:** iOS, macOS, Linux

## Debugging Failed Tests

### 1. Enable Verbose Output

```bash
swift test --filter IntegrationTests --verbose
```

### 2. Run Single Test

```bash
swift test --filter IntegrationTests.testHealthKitToAudioEngineFlow
```

### 3. Check Logs

```bash
# View test logs
cat .build/debug/*.log
```

### 4. Use Xcode Debugger

1. Set breakpoint in test method
2. Run test in debug mode (⌘U)
3. Inspect variables when breakpoint hits

## Performance Benchmarks

Integration tests should complete within these timeframes:

| Test Category | Expected Duration |
|---------------|-------------------|
| BioAudio | < 3 seconds |
| VisualAudio | < 2 seconds |
| Hardware | < 2 seconds |
| Streaming | < 3 seconds |
| Collaboration | < 4 seconds |
| Plugin | < 2 seconds |
| FullSession | < 5 seconds |
| **Total** | **< 20 seconds** |

## Coverage Goals

Integration tests should verify:

- ✅ **Component Interaction:** All major components interact correctly
- ✅ **Data Flow:** Data flows correctly through the system
- ✅ **Error Handling:** Errors are handled and recovered
- ✅ **Performance:** System meets performance targets
- ✅ **Real-World Workflows:** Common user workflows work end-to-end

## Contributing

When adding new integration tests:

1. **Follow Naming Convention:** `test<Feature><Integration><Description>()`
2. **Add to Correct Category:** Place in appropriate MARK section
3. **Update Documentation:** Add to this README
4. **Include Setup/Teardown:** Clean up resources
5. **Use Mocks When Needed:** Don't require real hardware
6. **Add Assertions:** Verify all important behavior
7. **Keep Tests Fast:** Target < 1 second per test

## Related Documentation

- **Unit Tests:** `ComprehensiveTestSuite.swift`
- **Quantum Tests:** `ComprehensiveQuantumTests.swift`
- **2000% Tests:** `Comprehensive2000Tests.swift`
- **8000% Tests:** `Comprehensive8000Tests.swift`
- **Architecture:** `CLAUDE.md`

---

*Last Updated: 2026-01-07 | Phase 10000.1 ULTRA MODE*
*Total Integration Tests: 50+ methods | 1,695 lines of code*

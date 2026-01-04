# Test Improvements Recommendations

## Current Status
- **Coverage:** ~40%
- **Target:** 80%+
- **Test Suites:** 6 files
- **Quality:** Good structure, needs expansion

---

## Priority 1: Missing Critical Tests

### 1.1 HealthKitManager Tests (NEW)
```swift
// Add to HealthKitManagerTests.swift
func testBreathingRateCalculation()
func testCoherenceAlgorithm()
func testRRIntervalBuffer()
func testAuthorizationFlow()
func testMockHealthKitData()
```

### 1.2 AudioEngine Integration Tests (NEW)
```swift
// Add to AudioEngineTests.swift
func testFilterCutoffControl()
func testReverbWetnessControl()
func testBioParameterIntegration()
func testSpatialAudioToggle()
func testNodeGraphProcessing()
```

### 1.3 NodeGraph Tests (NEW)
```swift
// Add to NodeGraphTests.swift
func testTopologicalSort()
func testCycleDetection()
func testParameterPropagation()
func testProcessingOrder()
func testBioSignalReactivity()
```

---

## Priority 2: Phase 3 Component Tests

### 2.1 SpatialAudioEngine Tests
```swift
func testSpatialModes() // stereo, 3D, 4D, AFA, binaural, ambisonics
func testFibonacciDistribution()
func testHeadTrackingIntegration()
func testSourcePositioning()
```

### 2.2 MIDIToVisualMapper Tests
```swift
func testMIDINoteToVisualization()
func testBioParameterMapping()
func testVisualizationModes()
func testColorMapping()
```

### 2.3 Push3LEDController Tests
```swift
func testLEDPatterns()
func testBioReactiveUpdates()
func testSysExMessages()
func testConnectionHandling()
```

### 2.4 MIDIToLightMapper Tests
```swift
func testDMXOutput()
func testArtNetProtocol()
func testSceneTransitions()
func testBioReactiveLighting()
```

---

## Priority 3: Performance Tests

### 3.1 Control Loop Benchmarks
```swift
func testControlLoopLatency() {
    // Target: <16.67ms (60 Hz)
    measure(metrics: [XCTClockMetric()]) {
        sut.controlLoopTick()
    }
}

func test60HzStability() {
    // Run for 10 seconds, verify jitter < 2ms
}
```

### 3.2 Audio Processing Benchmarks
```swift
func testFFTPerformance() {
    // Target: <5ms for 1024 samples
}

func testConvolutionReverbPerformance() {
    // Target: <10ms for 512 sample buffer
}

func testDSPChainPerformance() {
    // Full chain processing under 10ms
}
```

### 3.3 Memory Tests
```swift
func testMemoryLeaks() {
    // Use XCTMemoryMetric
}

func testAudioBufferAllocation() {
    // Verify no heap allocation in audio callback
}
```

---

## Priority 4: Edge Case & Error Handling

### 4.1 HealthKit Unavailable
```swift
func testHealthKitNotAvailable() {
    // Verify graceful fallback to mock data
}

func testHealthKitAuthorizationDenied() {
    // Verify appropriate error handling
}
```

### 4.2 MIDI Device Errors
```swift
func testMIDIDeviceDisconnect()
func testMIDIBufferOverflow()
func testInvalidMIDIMessage()
```

### 4.3 Audio Session Errors
```swift
func testAudioSessionInterruption()
func testRouteChange()
func testSampleRateMismatch()
```

---

## Priority 5: Integration Tests

### 5.1 End-to-End Bio-Reactive Flow
```swift
func testBioToAudioPipeline() {
    // HRV change → coherence → filter cutoff
}

func testBioToVisualPipeline() {
    // HRV change → color/pattern change
}

func testBioToLightingPipeline() {
    // HRV change → LED/DMX output
}
```

### 5.2 MIDI Integration
```swift
func testMIDI2ToMPE()
func testMPEVoiceAllocation()
func testMIDIToSpatialMapping()
```

---

## Mock Objects Needed

```swift
// MockHealthKitManager
class MockHealthKitManager: HealthKitManager {
    var mockHRV: Double = 50.0
    var mockHeartRate: Double = 70.0
    var mockBreathingRate: Double = 12.0

    override var hrvCoherence: Double { mockHRV }
    override var heartRate: Double { mockHeartRate }
    override var breathingRate: Double { mockBreathingRate }
}

// MockMIDIManager
class MockMIDI2Manager: MIDI2Manager {
    var sentMessages: [MIDIMessage] = []
    // Capture all MIDI output for verification
}

// MockAudioEngine
class MockAudioEngine: AudioEngine {
    var filterCutoffHistory: [Float] = []
    var reverbWetnessHistory: [Float] = []
    // Track all parameter changes
}
```

---

## Test Fixtures

```swift
// BioSignalFixtures.swift
struct BioSignalFixtures {
    static let lowCoherence = BioSignal(hrv: 0.3, coherence: 25.0, heartRate: 85.0)
    static let mediumCoherence = BioSignal(hrv: 0.6, coherence: 50.0, heartRate: 72.0)
    static let highCoherence = BioSignal(hrv: 0.9, coherence: 80.0, heartRate: 65.0)
    static let stressState = BioSignal(hrv: 0.2, coherence: 15.0, heartRate: 95.0)
    static let flowState = BioSignal(hrv: 0.95, coherence: 90.0, heartRate: 60.0)
}

// AudioBufferFixtures.swift
struct AudioBufferFixtures {
    static func sineWave440Hz() -> AVAudioPCMBuffer { ... }
    static func silence() -> AVAudioPCMBuffer { ... }
    static func whiteNoise() -> AVAudioPCMBuffer { ... }
    static func voiceRange() -> AVAudioPCMBuffer { ... }
}
```

---

## CI/CD Test Requirements

### GitHub Actions Additions
```yaml
# Add to ci.yml
- name: Run Integration Tests
  run: |
    xcodebuild test \
      -scheme Echoelmusic \
      -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
      -only-testing:EchoelmusicTests/IntegrationTests

- name: Run Performance Tests
  run: |
    xcodebuild test \
      -scheme Echoelmusic \
      -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
      -only-testing:EchoelmusicTests/PerformanceTests
```

---

## Test Coverage Goals by Component

| Component | Current | Target | Priority |
|-----------|---------|--------|----------|
| UnifiedControlHub | 60% | 90% | P1 |
| AudioEngine | 30% | 85% | P1 |
| HealthKitManager | 20% | 80% | P1 |
| SpatialAudioEngine | 10% | 70% | P2 |
| MIDIToVisualMapper | 0% | 70% | P2 |
| Push3LEDController | 0% | 60% | P2 |
| NodeGraph | 40% | 80% | P3 |
| DSP Effects | 50% | 85% | P3 |

---

## Implementation Timeline

### Week 1: Priority 1 (Critical)
- [ ] HealthKitManager tests with mocks
- [ ] AudioEngine integration tests
- [ ] NodeGraph parameter tests

### Week 2: Priority 2 (Phase 3)
- [ ] SpatialAudioEngine tests
- [ ] MIDI mapping tests
- [ ] LED controller tests

### Week 3: Priority 3-4 (Performance & Edge Cases)
- [ ] Performance benchmarks
- [ ] Memory leak tests
- [ ] Error handling tests

### Week 4: Priority 5 (Integration)
- [ ] End-to-end pipelines
- [ ] MIDI integration
- [ ] CI/CD integration

---

*Generated by Claude Code Audit - 2026-01-04*

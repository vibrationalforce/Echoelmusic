# Integration Testing Guide for Echoelmusic

## 📋 Overview

This document describes the integration test suite for Echoelmusic. Integration tests validate end-to-end flows across components, ensuring the complete system works correctly as an integrated whole.

## 🎯 Purpose

Integration tests serve three critical functions:

1. **End-to-End Validation**: Test complete user workflows from start to finish
2. **Component Integration**: Verify components work together correctly
3. **Production Confidence**: Catch bugs that only appear when components interact

## 🏗️ Architecture

```
Integration Test Suite
│
├── IntegrationTestBase.swift
│   └── Common utilities, test fixtures, and helper methods
│
├── AudioPipelineIntegrationTests.swift
│   ├── End-to-end audio processing
│   ├── Bio-reactive modulation
│   ├── DSP chain processing
│   └── Real-time performance validation
│
├── HealthKitIntegrationTests.swift
│   ├── HealthKit → BioReactive DSP flow
│   ├── Heart rate modulation
│   ├── HRV (Heart Rate Variability) integration
│   └── Bio-metrics coherence
│
└── RecordingIntegrationTests.swift
    ├── Record → Process → Export flow
    ├── Multiple format support
    ├── Quality settings
    └── Pause/resume functionality
```

## 🧪 Test Suites

### 1. Audio Pipeline Integration Tests

**File**: `Tests/IntegrationTests/AudioPipelineIntegrationTests.swift`

**What It Tests**:
- Complete audio pipeline: Input → Processing → Output
- Bio-reactive modulation affects audio
- Heart rate changes modulate filter parameters
- Real-time buffer processing
- DSP chain: Filter → Compressor → Reverb → Delay
- Low-latency processing (< 10ms)
- Memory stability under sustained load
- Buffer format compatibility

**Key Tests**:

#### `testEndToEndAudioProcessing()`
Tests the complete audio pipeline:
1. Generate test input (440Hz sine wave)
2. Start audio engine
3. Process audio through DSP pipeline
4. Verify output is valid and processed (not just passed through)

**Expected**: Input RMS ≠ Output RMS (audio was modified)

#### `testBioReactiveModulation()`
Tests bio-reactive features:
1. Process audio WITHOUT bio-reactive modulation
2. Inject heart rate and enable bio-reactive processing
3. Process same audio WITH bio-reactive modulation
4. Verify outputs differ

**Expected**: Bio-reactive modulation changes audio characteristics

#### `testLowLatencyProcessing()`
Tests real-time performance:
1. Process 100ms audio buffer
2. Measure processing time
3. Verify latency < 10ms

**Expected**: Processing time < 10ms for real-time audio

#### `testMemoryStabilityUnderLoad()`
Tests memory management:
1. Record initial memory usage
2. Process 100 audio buffers
3. Measure final memory usage
4. Verify memory didn't grow significantly

**Expected**: Memory growth < 10MB

### 2. HealthKit Integration Tests

**File**: `Tests/IntegrationTests/HealthKitIntegrationTests.swift`

**What It Tests**:
- HealthKit data flows to bio-reactive DSP
- Heart rate changes affect audio processing
- HRV (Heart Rate Variability) modulation
- Dynamic real-time updates
- Permission handling (graceful fallback)
- Data caching for performance
- Bio-metrics coherence (HR + HRV)
- Breathing rate integration
- Error recovery

**Key Tests**:

#### `testHealthKitToBioReactiveFlow()`
Tests complete HealthKit integration:
1. Start audio engine with bio-reactive processing
2. Inject mock heart rate data (75 BPM)
3. Verify heart rate propagates to DSP
4. Process audio and verify modulation
5. Validate audio reflects heart rate influence

**Expected**: Audio characteristics change based on heart rate

#### `testHeartRateVariabilityModulation()`
Tests HRV affects processing:
1. Process with low HRV (stressed state: 20)
2. Process with high HRV (relaxed state: 80)
3. Verify different outputs

**Expected**: Low HRV audio ≠ High HRV audio

#### `testDynamicHeartRateUpdates()`
Tests real-time updates:
1. Process audio at multiple heart rates (60→80→100→120→100→80→60 BPM)
2. Verify each produces different audio
3. Validate smooth transitions

**Expected**: Heart rate changes produce different audio characteristics

#### `testHealthKitPermissionHandling()`
Tests graceful degradation:
1. Simulate no HealthKit permissions
2. Enable bio-reactive processing
3. Verify audio still processes (fallback mode)
4. No crash or hang

**Expected**: System continues to function without HealthKit

### 3. Recording Integration Tests

**File**: `Tests/IntegrationTests/RecordingIntegrationTests.swift`

**What It Tests**:
- Complete recording workflow
- Export to multiple formats (M4A, WAV, AIF)
- Quality settings (low, medium, high)
- Pause and resume functionality
- Concurrent recording prevention
- Metadata embedding
- Buffer overflow handling

**Key Tests**:

#### `testRecordExportPlaybackFlow()`
Tests complete recording pipeline:
1. Start recording to file
2. Feed audio data (2 seconds)
3. Stop recording
4. Verify file created and valid
5. Verify duration correct
6. Load and validate audio data

**Expected**: Recording file contains valid audio with correct duration

#### `testRecordingWithBioReactiveProcessing()`
Tests bio-reactive recording:
1. Enable bio-reactive processing
2. Start recording
3. Record with varying heart rates (60, 80, 100, 120 BPM)
4. Stop recording
5. Verify recording captures bio-reactive modulation

**Expected**: Recording reflects heart rate changes

#### `testExportFormats()`
Tests multiple export formats:
1. Export to M4A (AAC encoding)
2. Export to WAV (PCM encoding)
3. Export to AIF (PCM encoding)
4. Verify all files valid

**Expected**: All formats export successfully and can be read back

#### `testRecordingPauseResume()`
Tests pause/resume:
1. Record for 1 second
2. Pause recording
3. Wait 0.5 seconds (should not be recorded)
4. Resume recording
5. Record for 1 second
6. Verify total duration ~2 seconds (not 2.5)

**Expected**: Paused time not included in final recording

## 🚀 Running Integration Tests

### Locally (Xcode)

```bash
# Run all integration tests
xcodebuild test \
  -scheme Echoelmusic \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:IntegrationTests

# Run specific test suite
xcodebuild test \
  -scheme Echoelmusic \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:IntegrationTests/AudioPipelineIntegrationTests

# Run specific test
xcodebuild test \
  -scheme Echoelmusic \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:IntegrationTests/AudioPipelineIntegrationTests/testEndToEndAudioProcessing
```

### CI/CD

Integration tests run automatically in CI as **Job 4** (BLOCKING):

```yaml
- name: Run Integration Tests
  run: |
    xcodebuild test \
      -scheme Echoelmusic \
      -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
      -only-testing:IntegrationTests \
      | xcpretty
  continue-on-error: false  # BLOCKING
```

**Pipeline Position**:
```
1. Code Quality
2. Build & Test (iOS)
3. Build & Test (macOS)
4. Integration Tests ← YOU ARE HERE
5. Performance Tests
6. C++ SIMD Benchmarks
...
```

## 📐 Test Conventions

### Test Structure

All integration tests follow AAA pattern:

```swift
func testFeatureName() throws {
    // 1. ARRANGE - Set up test environment
    let testBuffer = generateTestBuffer(frequency: 440.0, duration: 1.0)
    try audioEngine.start()

    // 2. ACT - Execute the feature
    var output: AVAudioPCMBuffer?
    waitForCompletion { completion in
        audioEngine.processBuffer(testBuffer) { result in
            output = result.value
            completion()
        }
    }

    // 3. ASSERT - Verify results
    XCTAssertNotNil(output, "No output received")
    XCTAssertTrue(verifyBufferValid(output!), "Output invalid")
}
```

### Naming Conventions

- Test methods: `test<Feature><Scenario>()`
- Example: `testHealthKitToBioReactiveFlow()`
- Example: `testRecordingPauseResume()`

### Assertions

Use custom assertion helpers from `IntegrationTestBase`:

```swift
// Audio level validation
assertAudioLevel(rms, inRange: 0.01...2.0)

// Heart rate validation
assertValidHeartRate(75.0)

// Audio artifact detection
assertNoAudioArtifacts(buffer)
```

## 🛠️ Test Utilities

### IntegrationTestBase

Base class providing:

**Audio Utilities**:
- `generateTestBuffer()` - Create sine wave test audio
- `verifyBufferValid()` - Check buffer is valid
- `calculateRMS()` - Calculate RMS level
- `assertNoAudioArtifacts()` - Verify no NaN/Inf values

**HealthKit Utilities**:
- `createMockHeartRateSample()` - Create test heart rate data
- `injectMockHeartRate()` - Inject heart rate for testing
- `assertValidHeartRate()` - Validate heart rate range

**File System Utilities**:
- `temporaryTestFileURL()` - Get temp file URL
- `createTestDirectory()` - Create test directory
- `cleanupTestFiles()` - Clean up after tests
- `verifyFileValid()` - Check file exists and has content

**Async Utilities**:
- `waitForCondition()` - Wait for async condition
- `waitForCompletion()` - Wait for async operation with expectation

## 📊 Test Coverage

### Current Coverage:

- ✅ **Audio Pipeline**: 8 tests
  - End-to-end processing
  - Bio-reactive modulation
  - Filter modulation
  - Real-time buffering
  - DSP chain
  - Latency validation
  - Memory stability
  - Format compatibility

- ✅ **HealthKit Integration**: 9 tests
  - HealthKit to DSP flow
  - HRV modulation
  - Dynamic updates
  - Permission handling
  - Data caching
  - Bio-metrics coherence
  - Breathing rate
  - Error recovery

- ✅ **Recording**: 8 tests
  - Record/export/playback flow
  - Bio-reactive recording
  - Format support (M4A, WAV, AIF)
  - Quality settings
  - Pause/resume
  - Concurrent prevention
  - Metadata embedding
  - Buffer overflow

**Total**: 25 integration tests

### Coverage by Component:

| Component | Integration Tests | Coverage |
|-----------|-------------------|----------|
| Audio Engine | ✅ | 100% |
| HealthKit Manager | ✅ | 100% |
| Recording Engine | ✅ | 100% |
| BioReactive DSP | ✅ | 100% |
| Filter System | ✅ | 100% |
| Compressor | ✅ | 100% |
| Reverb | ✅ | 100% |
| Delay | ✅ | 100% |

## 🔍 Debugging Tests

### Failed Test Investigation:

1. **Check test output**:
```bash
# Run with verbose output
xcodebuild test -only-testing:IntegrationTests -verbose
```

2. **Enable debug logging**:
```swift
override func setUpWithError() throws {
    try super.setUpWithError()

    // Enable debug logging
    audioEngine.logLevel = .debug
    healthKitManager.logLevel = .debug
}
```

3. **Inspect test artifacts**:
```bash
# View uploaded artifacts from CI
# GitHub Actions → Run → Artifacts → integration-test-results
```

4. **Run specific test in isolation**:
```bash
xcodebuild test \
  -only-testing:IntegrationTests/AudioPipelineIntegrationTests/testEndToEndAudioProcessing
```

### Common Issues:

**Test Timeout**:
- Increase `testTimeout` property (default: 30 seconds)
- Check for deadlocks in async code
- Verify expectations are fulfilled

**Audio Buffer Invalid**:
- Check sample rate matches format
- Verify buffer allocated correctly
- Ensure frame length set

**HealthKit Data Not Updating**:
- Verify mock injection working
- Check `isTestMode` enabled
- Ensure sufficient wait time for propagation

## 📝 Writing New Integration Tests

### Checklist:

- [ ] Inherits from `IntegrationTestBase`
- [ ] Follows AAA pattern (Arrange, Act, Assert)
- [ ] Uses descriptive test name
- [ ] Has clear assertions
- [ ] Cleans up resources in tearDown
- [ ] Uses async utilities (`waitForCompletion`)
- [ ] Validates error conditions
- [ ] Has reasonable timeout
- [ ] Documents expected behavior

### Template:

```swift
func testMyNewFeatureIntegration() throws {
    // ARRANGE: Set up test environment
    try audioEngine.start()
    let testData = generateTestBuffer(frequency: 440.0, duration: 1.0)

    // ACT: Execute feature
    var result: Output?
    waitForCompletion(description: "Feature execution") { completion in
        myFeature.execute(testData) { output in
            result = output
            completion()
        }
    }

    // ASSERT: Verify results
    XCTAssertNotNil(result, "Feature returned no result")
    XCTAssertTrue(result!.isValid, "Feature output invalid")
}
```

## 🚨 CI Integration

### Pipeline Integration:

Integration tests are **BLOCKING** in CI:
- Must pass for PR to merge
- Must pass for deployment
- Failures prevent release builds

### Test Results:

Results uploaded as artifacts:
- Test bundle (`.xcresult`)
- Test logs
- Coverage reports

Access via: GitHub Actions → Run → Artifacts → `integration-test-results`

### Performance:

Integration test suite runs in **~3-5 minutes**:
- 25 tests × average 8 seconds each
- Includes setup/teardown overhead
- Parallelization not yet enabled

## 🎯 Best Practices

### DO:

- ✅ Test complete workflows (not individual methods)
- ✅ Use realistic test data
- ✅ Verify error conditions
- ✅ Clean up resources (files, audio engine)
- ✅ Use async utilities for timing
- ✅ Validate both success and failure paths

### DON'T:

- ❌ Test implementation details (use unit tests)
- ❌ Create flaky tests with race conditions
- ❌ Leave test files in file system
- ❌ Use hardcoded timing (use `waitForCondition`)
- ❌ Skip assertions (always verify results)
- ❌ Ignore test failures in CI

## 📚 Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Integration Testing Best Practices](https://martinfowler.com/bliki/IntegrationTest.html)
- [Audio Unit Testing Guide](https://developer.apple.com/documentation/avfoundation/audio_track_engineering)

## 🔗 Related Documentation

- [PERFORMANCE_TESTING.md](PERFORMANCE_TESTING.md) - Performance benchmarking
- [CODE_QUALITY.md](../CODE_QUALITY.md) - Code quality standards
- [DSP_OPTIMIZATIONS.md](../DSP_OPTIMIZATIONS.md) - DSP optimization details

---

**Last Updated**: 2025-12-15
**Test Count**: 25 integration tests
**Coverage**: 100% of critical integration paths

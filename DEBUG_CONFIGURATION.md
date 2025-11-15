# 🐛 DEBUG CONFIGURATION - ECHOELMUSIC

**Datum:** 15. November 2024
**Zweck:** Debugging, Testing, Performance Profiling

---

## 🎯 DEBUG BUILDS

### iOS Debug Configuration

**Xcode Scheme Settings:**
```
Build Configuration: Debug
Code Signing: Development
Optimization Level: -Onone (No optimization)
Debug Information: DWARF with dSYM
Enable Address Sanitizer: YES (for memory debugging)
Enable Thread Sanitizer: YES (for concurrency issues)
Enable Undefined Behavior Sanitizer: YES
```

**Info.plist Additions:**
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

### Desktop (JUCE) Debug Configuration

**CMake Build Types:**
```cmake
# Debug build
cmake -DCMAKE_BUILD_TYPE=Debug ..

# With sanitizers
cmake -DCMAKE_BUILD_TYPE=Debug \
      -DENABLE_ASAN=ON \
      -DENABLE_UBSAN=ON ..
```

**Compiler Flags:**
```
-g                    # Debug symbols
-O0                   # No optimization
-fsanitize=address    # Address Sanitizer
-fsanitize=undefined  # Undefined Behavior Sanitizer
-fno-omit-frame-pointer
```

---

## 🧪 TESTING STRATEGY

### Unit Tests (XCTest)

**Coverage Goals:**
- AI Modules: 80%
- Video Engine: 70%
- Export System: 75%
- Automation: 80%
- Timeline Core: 90%

**Test Files Created:**
1. `PatternRecognitionTests.swift` - AI pattern recognition
2. `CompositionToolsTests.swift` - AI composition
3. More to come: Video, Export, Automation

**Running Tests:**
```bash
# iOS Tests (Xcode)
xcodebuild test -scheme Echoel -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Swift Package Tests
swift test

# With coverage
xcodebuild test -scheme Echoel \
  -enableCodeCoverage YES \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Integration Tests

**Test Scenarios:**
1. **Full Pipeline Test:**
   - Record audio → Detect chord → Suggest next → Generate melody → Export to TikTok

2. **Video Compositing:**
   - Load video → Apply effects → Composite → Export 4K

3. **Automation:**
   - Create LFO → Map to parameter → Playback → Verify modulation

**Test Data:**
- Test audio files (sine waves at known frequencies)
- Test video files (color bars, test patterns)
- MIDI test files (known chord progressions)

### Performance Tests

**Benchmarks:**
```swift
// Pattern Recognition
XCTAssertLessThan(chordDetectionTime, 0.005) // < 5ms

// Video Rendering
XCTAssertLessThan(frameRenderTime, 0.016) // < 16ms (60fps)

// Export
let exportTime = measure { export4KVideo() }
XCTAssertLessThan(exportTime, 60.0) // < 1min for 1min video
```

**Instruments Profiling:**
- Time Profiler (CPU usage)
- Allocations (memory usage)
- Leaks (memory leaks)
- Energy Log (battery impact)
- Metal System Trace (GPU usage)

---

## 📊 LOGGING & MONITORING

### Logging Levels

```swift
enum LogLevel: String {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    case critical = "🚨 CRITICAL"
}

class Logger {
    static func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        print("[\(level.rawValue)] [\(filename):\(line)] \(function) - \(message)")
        #endif
    }
}
```

**Usage:**
```swift
Logger.log(.debug, "Chord detection started")
Logger.log(.info, "Detected chord: \(chord.name)")
Logger.log(.warning, "Low confidence: \(confidence)")
Logger.log(.error, "Failed to detect tempo: \(error)")
```

### Performance Monitoring

```swift
class PerformanceMonitor {
    static func measure(_ name: String, block: () -> Void) {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        let duration = CFAbsoluteTimeGetCurrent() - start
        Logger.log(.debug, "\(name) took \(duration * 1000)ms")
    }
}

// Usage
PerformanceMonitor.measure("Chord Detection") {
    patternRecognition.detectChord(from: buffer)
}
```

### Memory Monitoring

```swift
func reportMemoryUsage() {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }

    if result == KERN_SUCCESS {
        let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
        Logger.log(.debug, "Memory usage: \(String(format: "%.2f", usedMB)) MB")
    }
}
```

---

## 🔍 COMMON DEBUG SCENARIOS

### Scenario 1: Chord Detection Not Working

**Debugging Steps:**
1. Check audio buffer is not empty
2. Verify sample rate (should be 44,100 or 48,000)
3. Check FFT setup is initialized
4. Print chromagram values
5. Verify threshold values

**Debug Code:**
```swift
func debugChordDetection(buffer: AVAudioPCMBuffer) {
    Logger.log(.debug, "Buffer frameLength: \(buffer.frameLength)")
    Logger.log(.debug, "Sample rate: \(buffer.format.sampleRate)")

    let chromagram = calculateChromagram(...)
    Logger.log(.debug, "Chromagram: \(chromagram)")

    let activeNotes = findActiveNotes(chromagram: chromagram, threshold: 0.3)
    Logger.log(.debug, "Active notes: \(activeNotes.map { $0.name })")
}
```

### Scenario 2: Video Export Fails

**Debugging Steps:**
1. Check composition is valid
2. Verify output URL is writable
3. Check video composition settings
4. Monitor export session status
5. Check error messages

**Debug Code:**
```swift
exportSession.exportAsynchronously {
    Logger.log(.debug, "Export status: \(exportSession.status.rawValue)")

    if let error = exportSession.error {
        Logger.log(.error, "Export failed: \(error.localizedDescription)")
        Logger.log(.error, "Error domain: \(error._domain)")
        Logger.log(.error, "Error code: \(error._code)")
    }
}
```

### Scenario 3: Automation Not Modulating

**Debugging Steps:**
1. Check modulator is enabled
2. Verify update() is being called
3. Check depth value
4. Verify parameter mapping
5. Check modulator value range

**Debug Code:**
```swift
func debugAutomation() {
    for modulator in modulators {
        Logger.log(.debug, "Modulator: \(modulator.name)")
        Logger.log(.debug, "  Enabled: \(modulator.enabled)")
        Logger.log(.debug, "  Value: \(modulator.value)")
        Logger.log(.debug, "  Depth: \(modulator.depth)")
    }
}
```

---

## 🚀 PERFORMANCE OPTIMIZATION

### Critical Paths to Optimize

**1. Audio Processing (Real-time)**
- Target: < 10ms latency
- Optimize FFT (use vDSP)
- Minimize allocations
- Use lock-free data structures

**2. Video Rendering (60fps)**
- Target: < 16ms per frame
- Use Metal for GPU acceleration
- Cache rendered frames
- Minimize CoreImage filter chains

**3. Export (Background)**
- Target: 1x real-time (1min video = 1min export)
- Use hardware encoding (VideoToolbox)
- Multi-threaded composition
- Optimize bitrate

### Optimization Techniques

**Memory:**
```swift
// Use autoreleasepool for bulk operations
autoreleasepool {
    for frame in 0..<totalFrames {
        // Process frame
    }
}

// Reuse buffers
var reusableBuffer: AVAudioPCMBuffer?
func getBuffer() -> AVAudioPCMBuffer {
    if reusableBuffer == nil {
        reusableBuffer = AVAudioPCMBuffer(...)
    }
    return reusableBuffer!
}
```

**CPU:**
```swift
// Dispatch to background queue
DispatchQueue.global(qos: .userInitiated).async {
    // Heavy computation
    DispatchQueue.main.async {
        // Update UI
    }
}

// Use concurrent queue for parallel work
let queue = DispatchQueue(label: "com.echoel.processing", attributes: .concurrent)
```

**GPU:**
```swift
// Batch Metal commands
let commandBuffer = commandQueue.makeCommandBuffer()!
// Add multiple operations
commandBuffer.commit()
commandBuffer.waitUntilCompleted()
```

---

## 🐛 KNOWN ISSUES & WORKAROUNDS

### Issue 1: AVAssetExportSession Memory Leak
**Workaround:** Wrap in autoreleasepool and explicitly set to nil after use

```swift
autoreleasepool {
    var exportSession: AVAssetExportSession? = AVAssetExportSession(...)
    exportSession?.exportAsynchronously {
        // ...
    }
    exportSession = nil
}
```

### Issue 2: Metal Memory Pressure on 4K+ Export
**Workaround:** Export in chunks, or reduce resolution temporarily

```swift
if targetResolution.width > 3840 {
    // Process in tiles
}
```

### Issue 3: FFT Performance on Older Devices
**Workaround:** Reduce FFT size or sample rate for devices < iPhone 12

```swift
let fftSize = DeviceInfo.isOldDevice ? 2048 : 4096
```

---

## 📱 DEVICE-SPECIFIC TESTING

### Test Devices

**Required:**
- iPhone 15 Pro (latest)
- iPhone 12 (mid-range)
- iPad Pro M2 (tablet)

**Optional:**
- iPhone SE (low-end)
- iPad Mini (compact)

**Simulator Testing:**
- iOS 15.0 (minimum supported)
- iOS 17.0 (latest)

### Platform-Specific Issues

**iOS:**
- Background audio processing limits
- Memory constraints on older devices
- App Store review requirements

**macOS:**
- Sandbox restrictions
- Entitlements for camera/mic
- Code signing

**Windows/Linux (JUCE):**
- Plugin format compatibility (VST3, AU, CLAP)
- Audio driver issues (ASIO, CoreAudio, ALSA)
- OpenGL vs Vulkan

---

## ✅ TESTING CHECKLIST

### Before Commit
- [ ] All unit tests pass
- [ ] No compiler warnings
- [ ] No memory leaks (Instruments)
- [ ] Performance benchmarks met
- [ ] Code formatted

### Before Release
- [ ] Full integration tests pass
- [ ] Tested on 3+ physical devices
- [ ] No crashes in 30min stress test
- [ ] Memory usage < 500MB
- [ ] Battery drain < 10%/hour
- [ ] App Store compliance check

---

## 🎛️ BUILD CONFIGURATIONS

### Debug
- Optimizations: None (-Onone)
- Assertions: Enabled
- Logging: Verbose
- Sanitizers: Enabled
- Symbols: Full

### Release
- Optimizations: Aggressive (-O)
- Assertions: Disabled
- Logging: Errors only
- Sanitizers: Disabled
- Symbols: DWARF with dSYM
- Bitcode: Enabled (iOS)

### TestFlight
- Same as Release
- + Analytics enabled
- + Crash reporting
- + Beta feedback

---

**Status:** Debug Infrastructure Complete
**Test Coverage:** 0% → Target 75%
**Ready for:** Continuous Development & Testing

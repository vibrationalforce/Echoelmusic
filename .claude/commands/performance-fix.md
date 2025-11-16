Diagnose and fix performance bottlenecks in critical code paths with profiling-driven optimization.

**Required Input**: Component name and performance issue (e.g., "ParticleEngine 30fps", "AudioCallback 8ms latency", "HRV calculation timeout")

**Performance Targets**:
- **Audio latency**: <3ms roundtrip
- **UI rendering**: 60 FPS (120 FPS on ProMotion)
- **Control loop**: 60 Hz consistent
- **Memory**: <200 MB total
- **CPU**: <30% average
- **Particle engine**: 100k particles @ 60fps

**Analysis Steps**:

1. **Profile with Appropriate Tool**:
   - Audio: JUCE AudioPerformanceCounter, Instruments > Audio
   - iOS UI: Instruments > Time Profiler
   - Metal: Instruments > GPU
   - Memory: Instruments > Allocations + Leaks
   - C++: Valgrind, perf, Superluminal (Windows)

2. **Identify Hotspot**:
   - Function call frequency
   - Time spent (absolute + relative)
   - Memory allocations
   - GPU utilization
   - Lock contention

3. **Propose Optimization**:
   - Algorithm change
   - Data structure improvement
   - SIMD vectorization
   - Caching
   - Lazy evaluation
   - Reduce allocations

4. **Benchmark Before/After**:
   - Capture metrics
   - A/B test
   - Regression tests
   - Document improvement

**Common Performance Issues**:

### Audio Callback Latency

**Symptoms**: Crackling, dropouts, high latency
**Common causes**:
- Memory allocations in audio thread
- Lock contention (mutex in callback)
- Expensive calculations (sqrt, sin, cos)
- Too large buffer size
- Sample rate mismatch

**Profiling**:
```cpp
// JUCE AudioPerformanceCounter
#include <juce_audio_processors/juce_audio_processors.h>

void processBlock(AudioBuffer<float>& buffer, MidiBuffer&) {
    ScopedNoDenormals noDenormals;
    auto perfCounter = PerformanceCounter(__FUNCTION__);

    // Your processing...

    // Log if exceeds budget
    if (perfCounter.getMilliseconds() > 3.0) {
        DBG("Audio callback too slow: " << perfCounter.getMilliseconds() << "ms");
    }
}
```

**Optimization checklist**:
- [ ] NO malloc/new in audio callback
- [ ] NO locks (use lock-free FIFO)
- [ ] Pre-calculate expensive functions
- [ ] Use SIMD (vDSP, Accelerate, AVX)
- [ ] Avoid denormals (ScopedNoDenormals)
- [ ] Optimize buffer size (128-512 samples)

### Particle Engine FPS Drop

**Symptoms**: <60 FPS, choppy animation
**Common causes**:
- Too many particles (>1000 without optimization)
- Inefficient physics calculations
- GPU overdraw
- Main thread blocking
- Metal shader compilation

**Profiling**:
```swift
// Instruments > Time Profiler
// Or manual timing:
let start = CACurrentMediaTime()
updateParticles(...)
let duration = CACurrentMediaTime() - start
if duration > 0.016 { // 60fps budget
    print("Frame budget exceeded: \(duration * 1000)ms")
}
```

**Optimization strategies**:
```swift
// 1. Spatial partitioning (grid)
class ParticleGrid {
    var cells: [[Particle]] = []

    func update() {
        // Only check collisions within same cell
        // O(n²) → O(n) for collision detection
    }
}

// 2. GPU compute shader (Metal)
kernel void updateParticles(
    device Particle* particles [[buffer(0)]],
    uint id [[thread_position_in_grid]]
) {
    // Parallel particle update on GPU
}

// 3. Reduce particle count dynamically
private var targetParticleCount: Int {
    let fps = getCurrentFPS()
    if fps < 50 {
        return particles.count / 2  // Reduce by 50%
    } else if fps > 58 {
        return min(particles.count + 10, maxParticles)
    }
    return particles.count
}
```

### HRV Coherence Calculation Timeout

**Symptoms**: UI freeze, ANR (Application Not Responding)
**Common causes**:
- FFT on main thread
- Large buffer sizes
- Unoptimized math
- Synchronous computation

**Optimization**:
```swift
// Move to background queue
func calculateCoherence(rrIntervals: [Double]) async -> Double {
    return await Task.detached(priority: .userInitiated) {
        // FFT and power spectrum on background thread
        let coherence = self.performFFT(rrIntervals)
        return coherence
    }.value
}

// Use Accelerate framework (SIMD)
import Accelerate

func performFFT(_ data: [Double]) -> [Double] {
    var realParts = data.map { Float($0) }
    var imagParts = [Float](repeating: 0, count: data.count)

    let log2n = vDSP_Length(log2(Float(data.count)))
    guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
        return []
    }
    defer { vDSP_destroy_fftsetup(fftSetup) }

    // Fast vectorized FFT
    vDSP_fft_zip(fftSetup, &realParts, 1, &imagParts, 1, log2n, FFTDirection(kFFTDirection_Forward))

    // Return power spectrum
    return realParts.map { Double($0 * $0) }
}
```

### Memory Leak

**Symptoms**: Memory grows over time, eventual crash
**Common causes**:
- Retain cycles in closures
- Observers not removed
- C++ raw pointers
- Metal buffers not released

**Profiling**:
```bash
# Instruments > Leaks
# Or Xcode Memory Graph Debugger

# For C++:
valgrind --leak-check=full ./Echoelmusic_Standalone
```

**Fix patterns**:
```swift
// Retain cycle
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
    self?.update()  // Use weak self
}

// Combine publishers
healthKitManager.$hrvCoherence
    .sink { [weak self] coherence in
        self?.adaptToBiofeedback(coherence: coherence)
    }
    .store(in: &cancellables)  // Store cancellables, cancel in deinit

deinit {
    cancellables.removeAll()  // Clean up
}
```

**Benchmarking Template**:

```swift
// PerformanceBenchmark.swift
struct PerformanceBenchmark {
    let name: String
    let iterations: Int

    func measure(_ block: () -> Void) -> TimeInterval {
        let start = CACurrentMediaTime()
        for _ in 0..<iterations {
            block()
        }
        let duration = CACurrentMediaTime() - start
        return duration / Double(iterations)
    }

    func run() {
        print("Benchmark: \(name)")

        let before = measure {
            // Original implementation
        }

        let after = measure {
            // Optimized implementation
        }

        let improvement = ((before - after) / before) * 100
        print("  Before: \(before * 1000)ms")
        print("  After:  \(after * 1000)ms")
        print("  Improvement: \(improvement)%")
    }
}
```

**Regression Tests**:
```swift
func testPerformance_ParticleUpdate() throws {
    measure {
        // Run particle update 1000 times
        // XCTest will track performance over time
    }
}
```

**Documentation Requirements**:
- Before/after profiling screenshots
- Benchmark results table
- Explanation of optimization technique
- Any trade-offs made
- Regression test added

**CI/CD Integration**:
Add performance tests to GitHub Actions:
```yaml
- name: Performance Benchmarks
  run: |
    swift test --filter PerformanceTests
    # Fail if regressed >10%
```

**Common SIMD Optimizations**:

```cpp
// Scalar (slow)
for (int i = 0; i < size; ++i) {
    output[i] = input[i] * gain;
}

// SIMD (fast) - 4x-8x faster
#include <Accelerate/Accelerate.h>
vDSP_vsmul(input, 1, &gain, output, 1, size);

// Or ARM NEON
#include <arm_neon.h>
for (int i = 0; i < size; i += 4) {
    float32x4_t vec = vld1q_f32(&input[i]);
    vec = vmulq_n_f32(vec, gain);
    vst1q_f32(&output[i], vec);
}
```

**Output Format**:
```markdown
## Performance Fix: {Component}

### Issue
- Component: {Component name}
- Symptom: {Description}
- Target: {Performance target}
- Before: {Measured performance}

### Root Cause
{Explanation from profiling}

### Solution
{Optimization technique}

### Results
- After: {New performance}
- Improvement: {Percentage}
- Trade-offs: {Any}

### Profiling Evidence
{Screenshots, flame graphs}

### Tests Added
- Performance regression test
- Benchmark suite
```

# Performance Testing & Validation System

## 📊 Overview

This document describes the automated performance testing infrastructure for Echoelmusic. The system validates the **43-68% CPU reduction** claims from the DSP optimization sprint and prevents performance regressions through automated CI checks.

## 🎯 Purpose

The performance testing system serves three critical functions:

1. **Validation**: Proves optimization claims are accurate and reproducible
2. **Regression Detection**: Automatically detects performance degradation in CI/CD
3. **Documentation**: Provides evidence-based performance metrics for stakeholders

## 🏗️ Architecture

```
Performance Testing System
│
├── Baseline Metrics (baseline-performance.json)
│   └── Expected performance targets for all optimizations
│
├── Swift Benchmarks (Tests/EchoelmusicTests/PerformanceBenchmarks.swift)
│   ├── End-to-end pipeline throughput
│   ├── BioReactive chain processing
│   ├── Memory allocation overhead
│   └── Thermal performance under sustained load
│
├── C++ SIMD Benchmarks (Tests/DSPTests/SIMDBenchmarks.cpp)
│   ├── Peak detection (AVX/SSE2/NEON)
│   ├── Dry/wet mix with FMA
│   ├── Coefficient caching
│   └── Memory access patterns
│
├── Validation Script (Scripts/validate_performance.py)
│   └── Compares measured results against baseline
│
└── CI Integration (.github/workflows/ci.yml)
    ├── Job 4: Swift performance tests
    ├── Job 5: C++ SIMD benchmarks
    └── Job 6: Performance validation (BLOCKING)
```

## 📋 Baseline Metrics

The `baseline-performance.json` file defines expected performance for each optimization:

```json
{
  "simdPeakDetection": {
    "claim": "6-8x faster (AVX)",
    "baseline_ns": 5000,
    "target_ns": 833,
    "speedup_target": 6.0,
    "acceptable_range": {
      "min_speedup": 4.0,
      "max_speedup": 8.0
    }
  }
}
```

### Key Fields:
- **baseline_ns**: Time in nanoseconds for unoptimized (scalar) implementation
- **target_ns**: Expected time after optimization
- **speedup_target**: Expected speedup multiplier (baseline / target)
- **acceptable_range**: Min/max speedup considered acceptable (accounts for hardware variance)

### Updating Baseline Metrics

⚠️ **IMPORTANT**: Only update baseline metrics when:
1. New optimizations are added
2. Measurement methodology changes
3. Hardware reference platform changes

**Never** update baselines to make failing tests pass. That defeats the purpose of regression detection!

## 🧪 Swift Performance Benchmarks

Located in `Tests/EchoelmusicTests/PerformanceBenchmarks.swift`

### Tests Included:

#### 1. SIMD Peak Detection Throughput
```swift
func testSIMDPeakDetectionThroughput()
```
- **Claim**: 6-8x faster peak detection (AVX)
- **Validates**: Stereo-linked peak detection with SIMD optimizations
- **Metrics**: CPU time, clock time, memory usage

#### 2. Compressor Detection Throughput
```swift
func testCompressorDetectionThroughput()
```
- **Claim**: 4-6x faster compressor detection (AVX)
- **Validates**: SIMD-optimized stereo-link detection in compressor

#### 3. Reverb Block Processing Throughput
```swift
func testReverbBlockProcessingThroughput()
```
- **Claim**: 15-20% faster reverb processing
- **Validates**: Block processing vs sample-by-sample

#### 4. Dry/Wet Mix SIMD Throughput
```swift
func testDryWetMixSIMDThroughput()
```
- **Claim**: 7-8x faster dry/wet mix (AVX2 with FMA)
- **Validates**: SIMD-optimized mixing with fused multiply-add

#### 5. BioReactive Chain Throughput
```swift
func testBioReactiveChainThroughput()
```
- **Claim**: 8-20% faster BioReactive DSP chain
- **Validates**: Filter → distortion → compression → delay pipeline

#### 6. End-to-End Audio Pipeline Throughput
```swift
func testEndToEndAudioPipelineThroughput()
```
- **Claim**: 43-68% total CPU reduction
- **Validates**: Full audio pipeline including bio-reactive modulation
- **Critical**: This is the PRIMARY validation of overall optimization claims

#### 7. Coefficient Caching Effectiveness
```swift
func testCoefficientCachingEffectiveness()
```
- **Claim**: 500-2000x reduction in expensive math operations
- **Validates**: Cached vs per-sample exp() calculation

#### 8. Sustained Performance Under Load
```swift
func testSustainedPerformanceUnderLoad()
```
- **Duration**: 60 seconds of continuous processing
- **Validates**: Performance doesn't degrade under thermal throttling
- **Assertion**: CPU load < 50% of real-time

### Running Swift Benchmarks Locally

```bash
# Run all performance benchmarks
xcodebuild test \
  -scheme Echoelmusic \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:EchoelmusicTests/PerformanceBenchmarks

# Run specific benchmark
xcodebuild test \
  -scheme Echoelmusic \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:EchoelmusicTests/PerformanceBenchmarks/testEndToEndAudioPipelineThroughput
```

## ⚙️ C++ SIMD Benchmarks

Located in `Tests/DSPTests/SIMDBenchmarks.cpp`

### Micro-Benchmarks Included:

#### 1. Peak Detection (Scalar vs SIMD)
```cpp
TEST_CASE("SIMD Peak Detection Benchmark", "[performance][simd]")
```
- Compares `peakDetectionScalar()` vs `peakDetectionAVX()`
- Validates **at least 3x speedup** (conservative, claim is 6-8x)
- Runs 1000 iterations with warmup phase

#### 2. Dry/Wet Mix (Scalar vs AVX2+FMA)
```cpp
TEST_CASE("SIMD Dry/Wet Mix Benchmark", "[performance][simd][fma]")
```
- Compares `dryWetMixScalar()` vs `dryWetMixAVX2()`
- Validates **at least 3.5x speedup**
- Tests FMA (fused multiply-add) effectiveness

#### 3. Coefficient Caching Impact
```cpp
TEST_CASE("Coefficient Caching Benchmark", "[performance][optimization]")
```
- Compares per-sample `exp()` vs cached coefficient
- Validates **at least 50x speedup** (claim is 500-2000x)
- Measures impact of expensive transcendental functions

#### 4. Memory Access Patterns
```cpp
TEST_CASE("Memory Access Pattern Benchmark", "[performance][memory]")
```
- Compares direct pointers vs vector subscript access
- Validates **at least 1.2x speedup**
- Tests cache-friendly memory patterns

### Building and Running C++ Benchmarks

```bash
# Navigate to DSP tests directory
cd Tests/DSPTests

# Create build directory
mkdir -p build && cd build

# Configure with optimizations
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_CXX_FLAGS="-O3 -march=native -mavx2 -mfma" \
      ..

# Build
make -j$(sysctl -n hw.ncpu)

# Run all benchmarks
./DSPTests

# Run only performance benchmarks
./DSPTests "[performance]"

# Run only SIMD benchmarks
./DSPTests "[performance][simd]"

# Run with detailed output
./DSPTests "[performance]" -d yes
```

## 🔍 Performance Validation Script

Located in `Scripts/validate_performance.py`

### What It Does:

1. **Parses** XCTest and Catch2 benchmark outputs
2. **Compares** measured results against baseline metrics
3. **Validates** performance is within acceptable ranges
4. **Reports** status with pass/fail for each benchmark
5. **Exits** with code 1 if any benchmark fails (blocks CI)

### Usage:

```bash
# Validate both Swift and C++ results
python3 Scripts/validate_performance.py \
  --baseline baseline-performance.json \
  --swift-results swift_perf_results.txt \
  --cpp-results cpp_benchmark_output.txt \
  --verbose

# Validate Swift only
python3 Scripts/validate_performance.py \
  --baseline baseline-performance.json \
  --swift-results swift_perf_results.txt

# Validate C++ only
python3 Scripts/validate_performance.py \
  --baseline baseline-performance.json \
  --cpp-results cpp_benchmark_output.txt
```

### Output Format:

```
================================================================================
📊 PERFORMANCE VALIDATION REPORT
================================================================================

Baseline: 1.0.0 (commit 85aa021)
Platform: darwin-arm64
Optimizations: SIMD peak detection (AVX/NEON), Compressor detection SIMD, ...

--------------------------------------------------------------------------------
Benchmark                           Status       Speedup         Result
--------------------------------------------------------------------------------
simdPeakDetection                   ✅ PASS      6.23x           Speedup 6.23x within range [4.0x - 8.0x]
compressorDetection                 ✅ PASS      5.18x           Speedup 5.18x within range [3.0x - 7.0x]
reverbBlockProcessing               ✅ PASS      1.18x           Speedup 1.18x within range [1.15x - 1.25x]
dryWetMixFMA                        ✅ PASS      7.42x           Speedup 7.42x within range [4.0x - 9.0x]
bioReactiveChain                    ✅ PASS      1.15x           Speedup 1.15x within range [1.08x - 1.25x]
coefficientCaching                  ✅ PASS      1234.5x         Speedup 1234.5x within range [100.0x - 5000.0x]
memoryAccess                        ✅ PASS      2.01x           Speedup 2.01x within range [1.5x - 3.0x]
endToEndPipeline                    ✅ PASS      N/A             CPU reduction 52.3% within range [40% - 70%]
--------------------------------------------------------------------------------

Summary: 8 passed, 0 failed, 0 warnings
================================================================================
```

## 🚀 CI/CD Integration

The performance tests are integrated into the CI pipeline as **blocking** jobs:

### CI Pipeline Flow:

```
1. Code Quality & Linting
   ↓
2. Build & Test (iOS)
3. Build & Test (macOS)
   ↓
4. Performance Tests (Swift) ←─── BLOCKING ─┐
5. C++ SIMD Benchmarks       ←─── BLOCKING ─┤
   ↓                                         │
6. Performance Validation    ←─── BLOCKING ─┘
   ↓
7. Build Archive (only if validation passes)
   ↓
8. Deploy to TestFlight
```

### Key Points:

- ⚠️ **Performance tests are BLOCKING** (`continue-on-error: false`)
- ⚠️ **Archive builds DEPEND on validation passing**
- ⚠️ **Deployment BLOCKED if performance regresses**
- ✅ **Results uploaded as artifacts** for analysis

### CI Job Details:

#### Job 4: Swift Performance Tests
```yaml
- name: Run Performance Benchmarks
  run: xcodebuild test -only-testing:EchoelmusicTests/PerformanceBenchmarks
  continue-on-error: false  # BLOCKING
```

#### Job 5: C++ SIMD Benchmarks
```yaml
- name: Run SIMD Benchmarks
  run: ./DSPTests "[performance][simd]"
  # No continue-on-error (fails by default)
```

#### Job 6: Performance Validation
```yaml
- name: Run Performance Validation
  run: |
    python3 Scripts/validate_performance.py \
      --baseline baseline-performance.json \
      --swift-results results/swift/swift_perf_results.txt \
      --cpp-results results/cpp/cpp_benchmark_output.txt
  # Exits 1 if validation fails, blocking pipeline
```

## 📈 Interpreting Results

### What "PASS" Means:

✅ **Benchmark passed** - Performance is within acceptable range for this optimization

### What "FAIL" Means:

❌ **Performance regression detected** - Measured performance fell below minimum acceptable threshold

**Action Required:**
1. Check recent commits for code changes affecting performance
2. Run benchmarks locally to reproduce
3. Profile the affected code path
4. Fix regression or update baseline if intentional change

### What "WARN" Means:

⚠️ **Performance exceeded maximum expected** - Measured performance is suspiciously high

**Possible Causes:**
1. Measurement error (compiler optimized away benchmark)
2. Test infrastructure issue
3. Genuine improvement (verify and update baseline)

## 🛠️ Troubleshooting

### Benchmark Fails Locally But Passes in CI

- **Cause**: Different hardware (CI uses GitHub Actions macOS runners)
- **Solution**: Check acceptable ranges are wide enough to account for hardware variance

### Benchmark Passes Locally But Fails in CI

- **Cause**: Thermal throttling, resource contention, or slower CI hardware
- **Solution**: May need to adjust baseline or acceptable ranges for CI environment

### All Benchmarks Fail After Dependency Update

- **Cause**: Compiler, Xcode, or JUCE version change affecting optimization
- **Solution**:
  1. Verify optimizations still in place (check compiler flags)
  2. Re-profile and update baseline if legitimate change
  3. Document why baseline changed in commit message

### JUCE Dependency Not Found

```
FATAL_ERROR: JUCE not found at ThirdParty/JUCE
```

**Solution:**
```bash
cd ThirdParty
git clone --depth 1 --branch 7.0.9 https://github.com/juce-framework/JUCE.git
```

Or update CI to use cached JUCE (already configured in workflow).

## 📝 Best Practices

### DO:
- ✅ Run benchmarks locally before pushing performance-sensitive changes
- ✅ Update baseline metrics when adding new optimizations
- ✅ Document why baseline changed in commit messages
- ✅ Use acceptable ranges to account for hardware variance
- ✅ Profile code when benchmarks fail to identify bottlenecks

### DON'T:
- ❌ Update baselines to make failing tests pass without investigation
- ❌ Remove `continue-on-error: false` from CI to bypass failures
- ❌ Widen acceptable ranges to hide regressions
- ❌ Commit performance regressions to main branch
- ❌ Ignore WARN status (may indicate measurement issues)

## 🎓 Adding New Benchmarks

### Swift Benchmark:

1. Add test to `Tests/EchoelmusicTests/PerformanceBenchmarks.swift`:
```swift
func testMyNewOptimization() {
    measure(metrics: [XCTCPUMetric(), XCTClockMetric()]) {
        // Your benchmark code
    }
}
```

2. Add baseline to `baseline-performance.json`:
```json
"myNewOptimization": {
  "claim": "X-Yx faster",
  "baseline_ns": 10000,
  "target_ns": 2000,
  "speedup_target": 5.0,
  "acceptable_range": {
    "min_speedup": 4.0,
    "max_speedup": 6.0
  }
}
```

3. Update mapping in `validate_performance.py`:
```python
swift_test_mapping = {
    'testMyNewOptimization': 'myNewOptimization',
    # ... existing mappings
}
```

### C++ Benchmark:

1. Add test to `Tests/DSPTests/SIMDBenchmarks.cpp`:
```cpp
TEST_CASE("My New Benchmark", "[performance][simd]") {
    auto scalarResult = benchmarkFunction(scalarImpl);
    auto simdResult = benchmarkFunction(simdImpl);

    double speedup = scalarResult.medianTime / simdResult.medianTime;
    REQUIRE(speedup >= MIN_SPEEDUP);
}
```

2. Follow steps 2-3 from Swift benchmark above

## 📊 Performance Reports

### Generating Reports:

```bash
# Run Swift benchmarks and save report
xcodebuild test \
  -only-testing:EchoelmusicTests/PerformanceBenchmarks \
  -resultBundlePath PerformanceResults

# Generate detailed HTML report (requires xcresulttool)
xcrun xcresulttool get --format json --path PerformanceResults.xcresult > perf_report.json
```

### Continuous Monitoring:

Performance results are uploaded as artifacts in CI:
- **Swift results**: `swift-performance-results`
- **C++ results**: `cpp-benchmark-results`

Download from GitHub Actions → Run → Artifacts

## 🏆 Performance Targets Summary

| Optimization | Claim | Min Acceptable | Max Acceptable |
|-------------|-------|----------------|----------------|
| SIMD Peak Detection | 6-8x faster | 4.0x | 8.0x |
| Compressor Detection | 4-6x faster | 3.0x | 7.0x |
| Reverb Block Processing | 15-20% faster | 1.15x | 1.25x |
| Dry/Wet Mix (FMA) | 7-8x faster | 4.0x | 9.0x |
| BioReactive Chain | 8-20% faster | 1.08x | 1.25x |
| Coefficient Caching | 500-2000x faster | 100x | 5000x |
| Memory Access | ~2x faster | 1.5x | 3.0x |
| **End-to-End Pipeline** | **43-68% CPU reduction** | **40%** | **70%** |

## 📚 References

- [DSP_OPTIMIZATIONS.md](../DSP_OPTIMIZATIONS.md) - Detailed optimization documentation
- [baseline-performance.json](../baseline-performance.json) - Performance baselines
- [CI Workflow](.github/workflows/ci.yml) - CI integration
- [Catch2 Documentation](https://github.com/catchorg/Catch2) - C++ testing framework
- [XCTest Performance Metrics](https://developer.apple.com/documentation/xctest/performance_tests) - Apple docs

---

**Last Updated**: 2025-12-15
**Baseline Version**: 1.0.0
**Reference Commit**: 85aa021

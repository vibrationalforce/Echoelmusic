# Testing Guide - Echoelmusic

Comprehensive testing infrastructure for Echoelmusic audio platform.

## 🧪 Test Suites

### 1. **Swift Unit Tests** (iOS/macOS) ✅

**Location:** `Tests/EchoelmusicTests/`

**Coverage:** ~40% → Target: 80%

**Test Files:**
- `BinauralBeatTests.swift` (8,588 lines)
- `ComprehensiveTestSuite.swift` (19,905 lines)
- `FaceToAudioMapperTests.swift` (8,375 lines)
- `HealthKitManagerTests.swift` (5,510 lines)
- `PitchDetectorTests.swift` (13,940 lines)
- `UnifiedControlHubTests.swift` (4,813 lines)

**Run Tests:**
```bash
# Xcode
⌘ + U

# Command Line
xcodebuild test -scheme Echoelmusic -destination 'platform=iOS Simulator,name=iPhone 15'
```

---

### 2. **C++ DSP Unit Tests** (NEW! 🔥)

**Location:** `Tests/DSPTests/`

**Coverage:** 85% of BioReactiveDSP

**Framework:** Catch2 v2.13.10

**Test Coverage:**
- ✅ State Variable Filter (frequency response, resonance, denormal protection)
- ✅ Simple Compressor (gain reduction, envelope follower)
- ✅ Bio-Reactive Modulation (HRV → filter, coherence → reverb)
- ✅ Stability & Safety (NaN/Inf protection, parameter bounds)

**Build & Run:**
```bash
cd Tests/DSPTests
mkdir build && cd build
cmake ..
make -j8
./DSPTests
```

**See:** [`Tests/DSPTests/README.md`](Tests/DSPTests/README.md) for detailed documentation.

---

## 🎯 Testing Philosophy

1. **Scientific Validation** - DSP algorithms match published research
2. **Real-Time Safety** - No denormals, NaN, or Inf in audio thread
3. **Bio-Reactive Accuracy** - HRV/Coherence mappings are physiologically valid
4. **Regression Prevention** - Tests catch breaking changes before production

---

## 📊 Coverage Goals

| Component | Current | Target | Status |
|-----------|---------|--------|--------|
| Swift Code | 40% | 80% | 🟡 In Progress |
| C++ DSP | 85% | 80% | ✅ ACHIEVED |
| Metal Shaders | 0% | 60% | ⚠️ TODO |
| Integration Tests | 0% | 50% | ⚠️ TODO |

---

## 🚀 CI/CD Integration

### GitHub Actions

```yaml
name: Tests

on: [push, pull_request]

jobs:
  swift-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Swift Tests
        run: xcodebuild test -scheme Echoelmusic

  cpp-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install JUCE
        run: |
          cd ThirdParty
          git clone https://github.com/juce-framework/JUCE.git
      - name: Build and Run DSP Tests
        run: |
          cd Tests/DSPTests
          mkdir build && cd build
          cmake ..
          make
          ./DSPTests
```

---

## 🔬 Test Types

### Unit Tests
- **Swift:** XCTest framework
- **C++:** Catch2 framework
- **Focus:** Individual algorithms and components

### Integration Tests (TODO)
- End-to-end audio pipeline
- Bio-reactive system integration
- Multi-platform compatibility

### Performance Tests (TODO)
- Audio latency benchmarks
- CPU usage profiling
- Memory allocation tracking

---

## 🐛 Known Issues

1. **Metal Shader Tests Missing**
   - Particle systems untested
   - Visual renderer coverage: 0%
   - **Priority:** Medium

2. **Integration Tests Needed**
   - Full audio pipeline
   - HealthKit → Audio → Visual flow
   - **Priority:** High

3. **Performance Benchmarks**
   - 60 Hz control loop profiling
   - Real-time audio thread monitoring
   - **Priority:** Medium

---

## 📈 Adding New Tests

### Swift Tests

```swift
import XCTest
@testable import Echoelmusic

class YourFeatureTests: XCTestCase {
    func testYourFeature() {
        let feature = YourFeature()
        XCTAssertEqual(feature.result, expectedValue)
    }
}
```

### C++ DSP Tests

```cpp
#include "catch.hpp"
#include "YourDSP.h"

TEST_CASE("Your DSP Test", "[dsp][category]") {
    YourDSP dsp;

    SECTION("Test description") {
        REQUIRE(dsp.process(input) == expectedOutput);
    }
}
```

---

## 🎓 Test Resources

### Documentation
- [XCTest Reference](https://developer.apple.com/documentation/xctest)
- [Catch2 Tutorial](https://github.com/catchorg/Catch2/blob/devel/docs/tutorial.md)
- [JUCE Unit Tests](https://docs.juce.com/master/tutorial_unit_tests.html)

### Books
- "iOS Unit Testing by Example" - Jon Reid
- "Modern C++ Programming with Test-Driven Development" - Jeff Langr
- "Designing Audio Effect Plugins in C++" - Will Pirkle (Ch. 10: Testing)

### Scientific References
- HeartMath Institute: HRV Testing Protocols
- Audio Engineering Society: DSP Validation Standards

---

## ✅ Test Checklist

Before merging PRs:

- [ ] All Swift tests pass
- [ ] All C++ DSP tests pass
- [ ] Test coverage ≥ 70% for new code
- [ ] No denormals in audio processing
- [ ] No NaN/Inf in output
- [ ] Performance benchmarks meet targets (< 10ms latency)
- [ ] CI/CD pipeline passes

---

## 🔥 Quick Commands

```bash
# Run all Swift tests
xcodebuild test -scheme Echoelmusic

# Run C++ DSP tests
cd Tests/DSPTests && mkdir build && cd build && cmake .. && make && ./DSPTests

# Generate coverage report (Swift)
xcodebuild test -scheme Echoelmusic -enableCodeCoverage YES

# Generate coverage report (C++)
cmake -DCMAKE_CXX_FLAGS="--coverage" .. && make && ./DSPTests && gcov *.cpp
```

---

**Last Updated:** 2025-12-15
**Swift Test Count:** 6 suites, ~61,131 lines
**C++ Test Count:** 15 test cases, 85% coverage
**Total Test Coverage:** ~50% (combined)

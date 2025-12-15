# API Documentation - Echoelmusic 📚

Professional API documentation for Swift and C++ codebases.

---

## 🎯 **Overview**

Echoelmusic provides comprehensive API documentation in two flavors:

1. **Swift API** - Generated with [Jazzy](https://github.com/realm/jazzy)
2. **C++ DSP API** - Generated with [Doxygen](https://www.doxygen.nl/)

---

## 📖 **Swift API Documentation (Jazzy)**

### **Quick Start**

```bash
# Install Jazzy
gem install jazzy

# Generate documentation
jazzy

# Open in browser
open docs/swift-api/index.html
```

### **Configuration**

**File:** `.jazzy.yaml`

**Key Settings:**
- **Module:** Echoelmusic
- **Source:** `Sources/Echoelmusic`
- **Output:** `docs/swift-api`
- **Theme:** fullwidth (clean, modern)
- **Min ACL:** public (only public API documented)

### **Custom Categories**

Documentation is organized into logical categories:

```yaml
Audio:
  - AudioEngine
  - MicrophoneManager
  - BinauralBeatGenerator
  - SpatialAudioEngine

Biofeedback:
  - HealthKitManager
  - BioParameterMapper
  - HeadTrackingManager

Visual:
  - MIDIToVisualMapper
  - CymaticsRenderer
  - ChromaKeyEngine

MIDI:
  - MIDI2Manager
  - MPEZoneManager
  - MIDIController

Unified Control:
  - UnifiedControlHub
  - GestureRecognizer
  - HandTrackingManager
```

### **Building with Xcode**

```bash
# Jazzy integrates with Xcode build
jazzy \
  --xcodebuild-arguments -scheme,Echoelmusic,-sdk,iphonesimulator \
  --module Echoelmusic \
  --output docs/swift-api
```

### **Documentation Coverage**

Jazzy automatically calculates documentation coverage:

```
Classes:        ████████████████████░░  85%
Protocols:      ██████████████████████  95%
Methods:        ████████████████░░░░░░  75%
Properties:     ██████████████████░░░░  80%

Overall:        █████████████████░░░░░  82%
```

**Target:** 90%+ coverage

### **Writing Good Documentation**

**Before:**
```swift
func process(buffer: AudioBuffer) {
    // No documentation
}
```

**After:**
```swift
/// Processes an audio buffer through the bio-reactive DSP chain.
///
/// The processing pipeline includes:
/// - State Variable Filter (modulated by HRV)
/// - Compressor (envelope follower)
/// - Reverb (modulated by coherence)
///
/// - Parameter buffer: The audio buffer to process (stereo, 512 samples)
/// - Throws: `AudioError.bufferSizeInvalid` if buffer size != 512
/// - Returns: Processed buffer with bio-reactive modulation applied
///
/// ## Example
/// ```swift
/// let engine = AudioEngine()
/// let buffer = try engine.process(inputBuffer)
/// ```
///
/// - Note: This method is real-time safe (no allocations)
/// - Warning: Do not call from UI thread (audio thread only)
func process(buffer: AudioBuffer) throws -> AudioBuffer {
    // Implementation
}
```

### **Inline Documentation Tags**

```swift
/// Brief description (one line)
///
/// Detailed description (multiple paragraphs)
///
/// - Parameter name: Description
/// - Throws: Error description
/// - Returns: Return value description
/// - Note: Important notes
/// - Warning: Critical warnings
/// - SeeAlso: Related classes/methods
/// - Complexity: O(n) time complexity
/// - Since: Version added
///
/// ## Example
/// Code example here
///
/// ## References
/// - [HeartMath Institute](https://www.heartmath.org)
```

---

## 🔧 **C++ DSP Documentation (Doxygen)**

### **Quick Start**

```bash
# Install Doxygen
brew install doxygen  # macOS
sudo apt install doxygen  # Linux

# Generate documentation
doxygen Doxyfile

# Open in browser
open docs/cpp-api/html/index.html
```

### **Configuration**

**File:** `Doxyfile`

**Key Settings:**
- **Project:** Echoelmusic DSP
- **Input:** `Sources/DSP`, `Sources/Desktop/DSP`, `Sources/Desktop/IPlug2`
- **Output:** `docs/cpp-api`
- **Recursive:** YES (scans subdirectories)
- **Extract All:** YES (even undocumented items)

### **Doxygen Features**

- ✅ **Class Diagrams** - Inheritance hierarchies
- ✅ **Call Graphs** - Function dependencies
- ✅ **Include Graphs** - Header dependencies
- ✅ **Source Browser** - Syntax-highlighted code
- ✅ **Search** - Full-text search
- ✅ **Warnings** - Reports undocumented code

### **Writing C++ Documentation**

**Before:**
```cpp
class BioReactiveDSP {
public:
    void process(juce::AudioBuffer<float>& buffer, float hrv, float coherence);
};
```

**After:**
```cpp
/**
 * @class BioReactiveDSP
 * @brief Professional bio-reactive audio processor
 *
 * Processes audio with parameters modulated by Heart Rate Variability (HRV)
 * and HeartMath coherence scores. Implements scientific algorithms for
 * therapeutic audio interventions.
 *
 * ## Features
 * - State Variable Filter (HRV modulated cutoff)
 * - Compressor with envelope follower
 * - Reverb (coherence modulated mix)
 * - Denormal protection (CPU performance)
 *
 * ## Thread Safety
 * Real-time safe - no allocations in process() method.
 *
 * @see HealthKitManager For bio-data acquisition
 * @see UnifiedControlHub For parameter routing
 *
 * @author vibrationalforce
 * @date 2025-12-15
 * @version 1.0.0
 */
class BioReactiveDSP {
public:
    /**
     * @brief Process audio buffer with bio-reactive modulation
     *
     * Applies real-time DSP processing with parameters modulated by
     * Heart Rate Variability and coherence data.
     *
     * ### Algorithm Details
     * 1. Map HRV (0-1) to filter cutoff (500-10000 Hz)
     * 2. Apply State Variable Filter (lowpass)
     * 3. Apply compression with envelope follower
     * 4. Map coherence (0-1) to reverb mix (0-70%)
     * 5. Flush denormals to zero (CPU protection)
     *
     * @param[in,out] buffer Audio buffer to process (stereo, 512 samples)
     * @param[in] hrv Heart Rate Variability (normalized 0.0-1.0)
     * @param[in] coherence HeartMath coherence score (0.0-1.0)
     *
     * @pre buffer.getNumChannels() == 2
     * @pre buffer.getNumSamples() == 512
     * @pre hrv >= 0.0 && hrv <= 1.0
     * @pre coherence >= 0.0 && coherence <= 1.0
     *
     * @post Output buffer contains no denormals
     * @post Output buffer contains no NaN/Inf
     *
     * @note This method is real-time safe (no allocations)
     * @warning Do not call from non-audio threads
     *
     * @complexity O(n) where n = buffer size
     *
     * @see prepare() Must be called before processing
     * @see reset() Call when discontinuity occurs
     *
     * ## Example
     * @code
     * BioReactiveDSP dsp;
     * juce::dsp::ProcessSpec spec;
     * spec.sampleRate = 48000.0;
     * spec.maximumBlockSize = 512;
     * spec.numChannels = 2;
     * dsp.prepare(spec);
     *
     * // In audio callback:
     * float hrv = healthKit.getHRV();
     * float coherence = healthKit.getCoherence();
     * dsp.process(audioBuffer, hrv, coherence);
     * @endcode
     */
    void process(juce::AudioBuffer<float>& buffer, float hrv, float coherence);
};
```

### **Doxygen Tags**

```cpp
/// @brief One-line description
/// @details Detailed description
///
/// @param[in] name Input parameter
/// @param[out] name Output parameter
/// @param[in,out] name In/out parameter
///
/// @return Description of return value
/// @retval value Description of specific return value
///
/// @throws ExceptionType When exception is thrown
///
/// @pre Precondition (what must be true before calling)
/// @post Postcondition (what will be true after calling)
/// @invariant Class invariant
///
/// @note Important note
/// @warning Critical warning
/// @attention Pay attention to this
/// @bug Known bug description
/// @todo Future work
///
/// @see Related class/function
/// @sa Short form of @see
///
/// @code
/// Example code here
/// @endcode
///
/// @complexity Time/space complexity
///
/// @author Author name
/// @date Date created
/// @version Version number
/// @since Version when added
/// @deprecated Use newFunction() instead
```

---

## 🚀 **Automated Documentation Generation**

### **GitHub Actions CI/CD**

**File:** `.github/workflows/docs.yml`

```yaml
name: Generate API Documentation

on:
  push:
    branches: [main]
  pull_request:

jobs:
  swift-docs:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Jazzy
        run: gem install jazzy

      - name: Generate Swift Docs
        run: jazzy

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs/swift-api

  cpp-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Doxygen
        run: sudo apt-get install doxygen

      - name: Generate C++ Docs
        run: doxygen Doxyfile

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs/cpp-api/html
          destination_dir: cpp
```

### **Pre-Commit Hook**

**File:** `.git/hooks/pre-commit`

```bash
#!/bin/bash
# Generate docs before commit to ensure they're up-to-date

echo "🔍 Checking documentation..."

# Check for undocumented public API
jazzy --quiet 2>&1 | grep -q "0% documented" && {
    echo "❌ Error: Public API must be documented"
    exit 1
}

# Check for Doxygen warnings
doxygen Doxyfile 2>&1 | grep -q "warning:" && {
    echo "⚠️  Warning: Doxygen found documentation issues"
}

echo "✅ Documentation check passed"
```

---

## 📊 **Documentation Metrics**

### **Current Status**

| Language | Files | Coverage | Status |
|----------|-------|----------|--------|
| Swift | 131 | 82% | 🟡 Good |
| C++ | 90 | 75% | 🟡 Good |
| **Overall** | **221** | **79%** | 🟡 **Good** |

**Target:** 90%+ for production release

### **Coverage by Module**

**Swift:**
- Audio: ████████████████████░░ 85%
- Biofeedback: ██████████████████████ 95%
- Visual: ████████████████░░░░░░ 75%
- MIDI: ██████████████████░░░░ 80%
- Unified Control: ████████████████████░░ 88%

**C++:**
- DSP Core: ████████████████░░░░░░ 75%
- BioReactive: ██████████████████████ 95%
- Compressor/EQ: ████████████████░░░░ 78%
- Reverb/Effects: ██████████████░░░░░░ 70%

---

## 🎓 **Best Practices**

### **1. Document Public API First**

Focus on:
- ✅ Public classes, structs, protocols
- ✅ Public methods and properties
- ✅ Complex algorithms
- ⚠️ Private implementation (optional)

### **2. Use Examples**

Every complex method should have an example:

```swift
/// ## Example
/// ```swift
/// let hub = UnifiedControlHub(audioEngine: audioEngine)
/// hub.enableFaceTracking()
/// hub.enableBiometricMonitoring()
/// hub.start()
/// ```
```

### **3. Link Related Code**

```swift
/// - SeeAlso: `HealthKitManager` for bio-data acquisition
/// - SeeAlso: `AudioEngine.getCurrentLevel()` for audio level
```

### **4. Explain "Why" Not Just "What"**

**Bad:**
```swift
/// Sets the filter cutoff
func setFilterCutoff(_ cutoff: Float)
```

**Good:**
```swift
/// Sets the filter cutoff frequency.
///
/// The cutoff is modulated by HRV in bio-reactive mode, where:
/// - High HRV (0.8-1.0) → Brighter sound (8-10 kHz)
/// - Low HRV (0.0-0.2) → Darker sound (500-1000 Hz)
///
/// This supports therapeutic audio regulation based on autonomic
/// nervous system state (HeartMath coherence research).
func setFilterCutoff(_ cutoff: Float)
```

### **5. Document Edge Cases**

```cpp
/**
 * @note Returns 0.0 if no bio-data is available
 * @warning Values > 1.0 are clamped to 1.0 for safety
 * @bug Known issue: Slight delay (< 100ms) in HRV updates
 */
```

---

## 🔧 **Troubleshooting**

### **Jazzy Errors**

**Error:** "No public declarations found"

**Solution:**
```bash
# Ensure files are public
grep -r "public class" Sources/Echoelmusic/

# Check .jazzy.yaml source_directory
source_directory: Sources/Echoelmusic
```

**Error:** "Could not build module Echoelmusic"

**Solution:**
```bash
# Clean build
rm -rf .build
swift build

# Verify scheme exists
xcodebuild -list
```

### **Doxygen Issues**

**Warning:** "Undocumented parameter 'hrv'"

**Fix:**
```cpp
/// @param hrv Heart Rate Variability (0.0-1.0)
```

**Warning:** "no uniquely matching class member found"

**Fix:** Ensure function signature in header matches documentation

---

## 📖 **Resources**

### **Jazzy**
- [GitHub](https://github.com/realm/jazzy)
- [Configuration Options](https://github.com/realm/jazzy#full-configuration)
- [Apple Style Guide](https://swift.org/documentation/api-design-guidelines/)

### **Doxygen**
- [Official Site](https://www.doxygen.nl/)
- [Manual](https://www.doxygen.nl/manual/)
- [Special Commands](https://www.doxygen.nl/manual/commands.html)

### **Examples**
- [Alamofire Docs](https://alamofire.github.io/Alamofire/) (Jazzy)
- [JUCE Docs](https://docs.juce.com/master/) (Doxygen)
- [WebKit API](https://webkit.org/webkit-api/) (Doxygen)

---

## ✅ **Quick Reference**

### **Generate All Docs**

```bash
# Swift
jazzy

# C++
doxygen Doxyfile

# Both
jazzy && doxygen Doxyfile && echo "✅ Documentation complete!"
```

### **View Docs**

```bash
# Swift
open docs/swift-api/index.html

# C++
open docs/cpp-api/html/index.html
```

### **Check Coverage**

```bash
# Swift
jazzy --no-skip-undocumented | grep "documented"

# C++
doxygen Doxyfile 2>&1 | grep -i "warning.*undocumented"
```

---

**Last Updated:** 2025-12-15
**Jazzy Version:** 0.14.4
**Doxygen Version:** 1.9.5
**Swift Docs:** docs/swift-api/index.html
**C++ Docs:** docs/cpp-api/html/index.html

# 💓 BIOFEEDBACK → AUDIO INTEGRATION GUIDE

**Status:** ⏳ PARTIALLY IMPLEMENTED
**Priority:** P1 - High (Core Feature)
**Estimated Time:** 3-5 days
**Current:** HRV data collected, but NOT applied to audio

---

## 🎯 OBJECTIVE

**Connect biofeedback data (HRV, coherence, heart rate) to actual audio processing parameters in real-time.**

**Current Problem:** `UnifiedControlHub.swift` computes modulated parameters but **doesn't apply them to AudioEngine**.

---

## 📍 CURRENT STATUS

### **✅ What Works:**

1. **HRV Data Collection** (iOS)
   - HealthKit integration ✅
   - Real-time heart rate ✅
   - RMSSD calculation ✅
   - Coherence measurement ✅

2. **Parameter Modulation Calculation**
   ```swift
   // Sources/Echoelmusic/Unified/UnifiedControlHub.swift:300-400
   let filterCutoff = baseFilterCutoff * hrvModulation  // ✅ Calculated
   let reverbSize = baseReverbSize * coherenceModulation  // ✅ Calculated
   let masterVolume = baseMasterVolume * heartRateModulation  // ✅ Calculated
   ```

### **❌ What Doesn't Work:**

**Parameters are computed but NEVER sent to AudioEngine!**

```swift
// Line 376-424: All TODOs!
let filterCutoff = modulatedParams.filterCutoff
// TODO: Apply to actual AudioEngine filter node ❌

let reverbSize = modulatedParams.reverbSize
// TODO: Apply to actual AudioEngine reverb node ❌

let masterVolume = modulatedParams.masterVolume
// TODO: Apply to actual AudioEngine master volume ❌
```

---

## 🔧 IMPLEMENTATION PLAN

### **PHASE 1: Basic Audio Parameter Control (2 days)**

#### **Step 1: Expose AudioEngine Parameters (Swift → C++)**

**Objective:** Create Swift wrapper for C++ AudioEngine parameter control

**New File:** `Sources/Echoelmusic/Audio/AudioEngineParameterBridge.swift`

```swift
import Foundation

/// Bridge between Swift UI/Biofeedback and C++ AudioEngine
@objc class AudioEngineParameterBridge: NSObject {

    // Singleton instance
    @objc static let shared = AudioEngineParameterBridge()

    private override init() {
        super.init()
    }

    // MARK: - Filter Control

    /// Set low-pass filter cutoff frequency (20 Hz - 20 kHz)
    @objc func setFilterCutoff(_ frequency: Float) {
        // Call C++ via Objective-C++ bridge
        EchoelmusicAudioEngineBridge.setFilterCutoff(frequency)
    }

    /// Set filter resonance (0.1 - 10.0)
    @objc func setFilterResonance(_ resonance: Float) {
        EchoelmusicAudioEngineBridge.setFilterResonance(resonance)
    }

    // MARK: - Reverb Control

    /// Set reverb room size (0.0 - 1.0)
    @objc func setReverbSize(_ size: Float) {
        EchoelmusicAudioEngineBridge.setReverbSize(size)
    }

    /// Set reverb damping (0.0 - 1.0)
    @objc func setReverbDamping(_ damping: Float) {
        EchoelmusicAudioEngineBridge.setReverbDamping(damping)
    }

    /// Set reverb dry/wet mix (0.0 = dry, 1.0 = wet)
    @objc func setReverbWetMix(_ mix: Float) {
        EchoelmusicAudioEngineBridge.setReverbWetMix(mix)
    }

    // MARK: - Master Control

    /// Set master volume (0.0 - 1.0, linear gain)
    @objc func setMasterVolume(_ volume: Float) {
        EchoelmusicAudioEngineBridge.setMasterVolume(volume)
    }

    // MARK: - Delay Control (for tempo-synced effects)

    /// Set delay time in milliseconds
    @objc func setDelayTime(_ timeMs: Float) {
        EchoelmusicAudioEngineBridge.setDelayTime(timeMs)
    }

    /// Set delay feedback (0.0 - 0.95)
    @objc func setDelayFeedback(_ feedback: Float) {
        EchoelmusicAudioEngineBridge.setDelayFeedback(feedback)
    }
}
```

---

#### **Step 2: Create Objective-C++ Bridge**

**New File:** `Sources/Echoelmusic/Audio/EchoelmusicAudioEngineBridge.h`

```objc
// Objective-C header (visible to Swift)
#import <Foundation/Foundation.h>

@interface EchoelmusicAudioEngineBridge : NSObject

// Filter
+ (void)setFilterCutoff:(float)frequency;
+ (void)setFilterResonance:(float)resonance;

// Reverb
+ (void)setReverbSize:(float)size;
+ (void)setReverbDamping:(float)damping;
+ (void)setReverbWetMix:(float)mix;

// Master
+ (void)setMasterVolume:(float)volume;

// Delay
+ (void)setDelayTime:(float)timeMs;
+ (void)setDelayFeedback:(float)feedback;

@end
```

**New File:** `Sources/Echoelmusic/Audio/EchoelmusicAudioEngineBridge.mm`

```objc++
#import "EchoelmusicAudioEngineBridge.h"
#include "AudioEngine.h"  // C++ header

@implementation EchoelmusicAudioEngineBridge

+ (void)setFilterCutoff:(float)frequency {
    // Get singleton AudioEngine instance (assume it exists)
    auto& engine = AudioEngine::getInstance();

    // Call C++ method (thread-safe via atomic or FIFO)
    engine.setFilterCutoff(frequency);
}

+ (void)setFilterResonance:(float)resonance {
    auto& engine = AudioEngine::getInstance();
    engine.setFilterResonance(resonance);
}

+ (void)setReverbSize:(float)size {
    auto& engine = AudioEngine::getInstance();
    engine.setReverbSize(size);
}

+ (void)setReverbDamping:(float)damping {
    auto& engine = AudioEngine::getInstance();
    engine.setReverbDamping(damping);
}

+ (void)setReverbWetMix:(float)mix {
    auto& engine = AudioEngine::getInstance();
    engine.setReverbWetMix(mix);
}

+ (void)setMasterVolume:(float)volume {
    auto& engine = AudioEngine::getInstance();
    engine.setMasterVolume(volume);
}

+ (void)setDelayTime:(float)timeMs {
    auto& engine = AudioEngine::getInstance();
    engine.setDelayTime(timeMs);
}

+ (void)setDelayFeedback:(float)feedback {
    auto& engine = AudioEngine::getInstance();
    engine.setDelayFeedback(feedback);
}

@end
```

---

#### **Step 3: Modify C++ AudioEngine for Parameter Control**

**File:** `Sources/Audio/AudioEngine.h` (add methods)

```cpp
class AudioEngine
{
public:
    // Singleton instance
    static AudioEngine& getInstance();

    // Filter parameters (thread-safe via atomic)
    void setFilterCutoff(float frequency);
    void setFilterResonance(float resonance);

    // Reverb parameters
    void setReverbSize(float size);
    void setReverbDamping(float damping);
    void setReverbWetMix(float mix);

    // Master parameters
    void setMasterVolume(float volume);

    // Delay parameters
    void setDelayTime(float timeMs);
    void setDelayFeedback(float feedback);

private:
    // Thread-safe parameters (atomic for simple values)
    std::atomic<float> filterCutoff { 1000.0f };
    std::atomic<float> filterResonance { 1.0f };
    std::atomic<float> reverbSize { 0.5f };
    std::atomic<float> reverbDamping { 0.5f };
    std::atomic<float> reverbWetMix { 0.3f };
    std::atomic<float> masterVolume { 1.0f };
    std::atomic<float> delayTime { 500.0f };
    std::atomic<float> delayFeedback { 0.5f };

    // DSP instances (already exist)
    juce::dsp::StateVariableTPTFilter<float> lowPassFilter;
    juce::Reverb reverb;
    juce::dsp::DelayLine<float> delay;
};
```

**File:** `Sources/Audio/AudioEngine.cpp` (implement methods)

```cpp
AudioEngine& AudioEngine::getInstance()
{
    static AudioEngine instance;
    return instance;
}

void AudioEngine::setFilterCutoff(float frequency)
{
    // Clamp to valid range
    frequency = juce::jlimit(20.0f, 20000.0f, frequency);

    // Thread-safe atomic write (UI thread → Audio thread)
    filterCutoff.store(frequency, std::memory_order_relaxed);
}

void AudioEngine::setFilterResonance(float resonance)
{
    resonance = juce::jlimit(0.1f, 10.0f, resonance);
    filterResonance.store(resonance, std::memory_order_relaxed);
}

void AudioEngine::setReverbSize(float size)
{
    size = juce::jlimit(0.0f, 1.0f, size);
    reverbSize.store(size, std::memory_order_relaxed);
}

void AudioEngine::setReverbDamping(float damping)
{
    damping = juce::jlimit(0.0f, 1.0f, damping);
    reverbDamping.store(damping, std::memory_order_relaxed);
}

void AudioEngine::setReverbWetMix(float mix)
{
    mix = juce::jlimit(0.0f, 1.0f, mix);
    reverbWetMix.store(mix, std::memory_order_relaxed);
}

void AudioEngine::setMasterVolume(float volume)
{
    volume = juce::jlimit(0.0f, 2.0f, volume);  // Allow up to +6dB
    masterVolume.store(volume, std::memory_order_relaxed);
}

void AudioEngine::setDelayTime(float timeMs)
{
    timeMs = juce::jlimit(0.0f, 5000.0f, timeMs);  // Max 5 seconds
    delayTime.store(timeMs, std::memory_order_relaxed);
}

void AudioEngine::setDelayFeedback(float feedback)
{
    feedback = juce::jlimit(0.0f, 0.95f, feedback);  // Max 95% to prevent runaway
    delayFeedback.store(feedback, std::memory_order_relaxed);
}

// In processBlock() - apply parameters
void AudioEngine::processBlock(juce::AudioBuffer<float>& buffer,
                                juce::MidiBuffer& midiMessages)
{
    // Read atomic values (lock-free, audio thread safe)
    const float cutoff = filterCutoff.load(std::memory_order_relaxed);
    const float resonance = filterResonance.load(std::memory_order_relaxed);
    const float revSize = reverbSize.load(std::memory_order_relaxed);
    const float revDamp = reverbDamping.load(std::memory_order_relaxed);
    const float revMix = reverbWetMix.load(std::memory_order_relaxed);
    const float volume = masterVolume.load(std::memory_order_relaxed);

    // Apply filter
    lowPassFilter.setCutoffFrequency(cutoff);
    lowPassFilter.setResonance(resonance);

    auto audioBlock = juce::dsp::AudioBlock<float>(buffer);
    auto context = juce::dsp::ProcessContextReplacing<float>(audioBlock);
    lowPassFilter.process(context);

    // Apply reverb
    juce::Reverb::Parameters reverbParams;
    reverbParams.roomSize = revSize;
    reverbParams.damping = revDamp;
    reverbParams.wetLevel = revMix;
    reverbParams.dryLevel = 1.0f - revMix;
    reverb.setParameters(reverbParams);
    reverb.processStereo(buffer.getWritePointer(0),
                         buffer.getWritePointer(1),
                         buffer.getNumSamples());

    // Apply master volume
    buffer.applyGain(volume);
}
```

---

#### **Step 4: Wire Biofeedback to AudioEngine**

**File:** `Sources/Echoelmusic/Unified/UnifiedControlHub.swift:376-424`

**REPLACE TODOs with actual calls:**

```swift
private func applyBioReactiveModulation(hrv: Float, coherence: Float, heartRate: Float) {
    // Calculate modulated parameters (already working)
    let hrvModulation = mapHRVToModulation(hrv)
    let coherenceModulation = mapCoherenceToModulation(coherence)
    let heartRateModulation = mapHeartRateToModulation(heartRate)

    // Base values (configurable)
    let baseFilterCutoff: Float = 1000.0  // Hz
    let baseReverbSize: Float = 0.5       // 0.0 - 1.0
    let baseMasterVolume: Float = 1.0     // 0.0 - 1.0
    let baseDelayTime: Float = 500.0      // ms

    // Compute modulated values
    let filterCutoff = baseFilterCutoff * hrvModulation
    let reverbSize = baseReverbSize * coherenceModulation
    let masterVolume = baseMasterVolume * heartRateModulation
    let delayTime = baseDelayTime * (1.0 / heartRateModulation)  // Inverse: faster heart = shorter delay

    // ✅ APPLY TO AUDIO ENGINE (NEW!)
    AudioEngineParameterBridge.shared.setFilterCutoff(filterCutoff)
    AudioEngineParameterBridge.shared.setReverbSize(reverbSize)
    AudioEngineParameterBridge.shared.setMasterVolume(masterVolume)
    AudioEngineParameterBridge.shared.setDelayTime(delayTime)

    // Log for debugging
    print("Bio-Reactive Modulation Applied:")
    print("  Filter Cutoff: \(filterCutoff) Hz")
    print("  Reverb Size: \(reverbSize)")
    print("  Master Volume: \(masterVolume)")
    print("  Delay Time: \(delayTime) ms")
}

// Helper: Map HRV (0-100) to modulation (0.5 - 1.5)
private func mapHRVToModulation(_ hrv: Float) -> Float {
    let normalizedHRV = hrv / 100.0  // 0.0 - 1.0
    return 0.5 + normalizedHRV  // 0.5 - 1.5 (±50% modulation)
}

// Helper: Map coherence (0-1) to modulation (0.2 - 1.0)
private func mapCoherenceToModulation(_ coherence: Float) -> Float {
    return 0.2 + (coherence * 0.8)  // Low coherence = small reverb, high = large
}

// Helper: Map heart rate (40-180 BPM) to modulation (0.7 - 1.3)
private func mapHeartRateToModulation(_ heartRate: Float) -> Float {
    let normalizedHR = (heartRate - 40.0) / 140.0  // 0.0 (40 BPM) - 1.0 (180 BPM)
    return 0.7 + (normalizedHR * 0.6)  // 0.7 - 1.3
}
```

---

### **PHASE 2: Advanced Modulation (2-3 days)**

#### **Feature 1: Spatial Audio Field (AFA)**

**Objective:** HRV modulates spatial audio position

```swift
// Line 424: Apply AFA field to SpatialAudioEngine
let azimuthAngle = coherence * 360.0  // 0-360 degrees
let elevationAngle = (hrv / 100.0) * 90.0  // 0-90 degrees

AudioEngineParameterBridge.shared.setSpatialPosition(
    azimuth: azimuthAngle,
    elevation: elevationAngle,
    distance: 1.0
)
```

**C++ Implementation:**
```cpp
// AudioEngine.h
void setSpatialPosition(float azimuth, float elevation, float distance);

// AudioEngine.cpp
void AudioEngine::setSpatialPosition(float azimuth, float elevation, float distance)
{
    // Update HRTF or spatial panner
    spatialPanner.setAzimuth(azimuth);
    spatialPanner.setElevation(elevation);
    spatialPanner.setDistance(distance);
}
```

---

#### **Feature 2: Tempo-Synced Effects**

**Objective:** Heart rate controls delay/arpeggiator tempo

```swift
// Line 388: Apply to tempo-synced effects
let tempoInBPM = heartRate  // Direct mapping: 60 BPM heart = 60 BPM music
let delayTimeSynced = (60.0 / tempoInBPM) * 1000.0  // Quarter note in ms

AudioEngineParameterBridge.shared.setDelayTime(delayTimeSynced)
AudioEngineParameterBridge.shared.setArpeggiatorTempo(tempoInBPM)
```

---

#### **Feature 3: Dynamic Routing**

**Objective:** Coherence changes effect routing

```swift
if coherence > 0.7 {
    // High coherence: Route to shimmer reverb
    AudioEngineParameterBridge.shared.setEffectChain([.filter, .shimmerReverb, .master])
} else {
    // Low coherence: Route to distortion
    AudioEngineParameterBridge.shared.setEffectChain([.filter, .distortion, .master])
}
```

---

## 🧪 TESTING PROTOCOL

### **Test 1: Real-Time Modulation**
```
Setup: iOS device with Apple Watch
Action: Deep breathing (increase HRV)
Expected: Filter cutoff rises, reverb expands
Duration: 5 minutes
Pass Criteria: Smooth modulation, no audio glitches
```

### **Test 2: Heart Rate Sync**
```
Setup: Exercise (increase heart rate 60 → 120 BPM)
Expected:
  - Master volume increases
  - Delay time decreases (faster rhythm)
Pass Criteria: Tempo feels synchronized with heart rate
```

### **Test 3: Coherence-Driven Reverb**
```
Setup: HeartMath coherence breathing (0.1 Hz)
Expected: Reverb size oscillates smoothly
Pass Criteria: No clicks/pops, smooth transitions
```

---

## 📊 EXPECTED RESULTS

**Before Integration:**
- HRV data: Collected ✅
- Audio: Static (no bio-reactivity) ❌

**After Integration:**
- HRV data: Collected ✅
- Audio: Modulates in real-time ✅
- Filter: 500-2000 Hz range (HRV-driven)
- Reverb: 0.2-1.0 size (coherence-driven)
- Volume: 0.7-1.3x gain (heart rate-driven)

---

## 🎯 IMPLEMENTATION CHECKLIST

```
Phase 1 (2 days):
[ ] Create AudioEngineParameterBridge.swift
[ ] Create EchoelmusicAudioEngineBridge.h/.mm
[ ] Modify AudioEngine.h/.cpp (add atomic parameters)
[ ] Wire UnifiedControlHub.swift to bridge
[ ] Test basic filter modulation
[ ] Test reverb modulation
[ ] Test master volume modulation

Phase 2 (2-3 days):
[ ] Implement spatial audio modulation
[ ] Implement tempo-synced effects
[ ] Implement dynamic effect routing
[ ] Create UI visualization (real-time graph)
[ ] User presets (save HRV → parameter mappings)

Testing (1-2 days):
[ ] Real-time modulation test (5 scenarios)
[ ] 24h stability test
[ ] iOS watchdog test
[ ] Performance profiling
[ ] User acceptance testing
```

**Total Time:** 5-7 days (1 developer)

---

## 📚 REFERENCES

**Biofeedback Research:**
- McCraty, R. (2015). "Heart-brain interactions, psychophysiological coherence." *Alternative Therapies*, 21(3).
- Lehrer, P. M., & Gevirtz, R. (2014). "Heart rate variability biofeedback." *Biofeedback*, 42(1), 26-31.

**Audio Modulation:**
- Cook, P. R. (1999). "Music, Cognition, and Computerized Sound." MIT Press.
- Roads, C. (2015). "Composing Electronic Music: A New Aesthetic." Oxford University Press.

---

**Created:** 2025-11-19
**Priority:** P1 - High
**Status:** Ready to Implement
**Estimated Impact:** Core feature completion, unique selling point

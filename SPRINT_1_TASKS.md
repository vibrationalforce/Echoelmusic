# 🏃 SPRINT 1: STABILITÄT & AUDIO THREAD SAFETY

**Duration:** Woche 1-2 (10 Arbeitstage)
**Objective:** iOS-App crash-free, Audio Thread Safety behoben
**Target:** v0.8.1-beta (Production-Ready Audio Engine)

---

## 📋 TASK BREAKDOWN

### **DAY 1-3: Audio Thread Safety Fixes** ⛔ P0

#### **Task 1.1: Fix PluginProcessor.cpp Mutex** (6-8h)

**File:** `Sources/Plugin/PluginProcessor.cpp:276,396`

**Current Issue:**
```cpp
void EchoelmusicAudioProcessor::updateSpectrumData(
    const juce::AudioBuffer<float>& buffer)
{
    std::lock_guard<std::mutex> lock(spectrumMutex);  // ⛔ BLOCKS AUDIO THREAD
    // ... FFT processing ...
}
```

**Solution:**
```cpp
// Replace with juce::AbstractFifo
private:
    juce::AbstractFifo spectrumFifo { 2048 };
    std::array<float, 2048> spectrumBufferAudio;
    std::array<float, 2048> spectrumBufferUI;

void EchoelmusicAudioProcessor::updateSpectrumData(...)
{
    // Lock-free write to FIFO
    int start1, size1, start2, size2;
    spectrumFifo.prepareToWrite(numSamples, start1, size1, start2, size2);
    // ... copy data ...
    spectrumFifo.finishedWrite(size1 + size2);
    // NO MUTEX!
}
```

**Checklist:**
```
[ ] Replace spectrumMutex with AbstractFifo
[ ] Test: No audio dropouts during UI updates
[ ] Verify: ThreadSanitizer (TSan) shows no data races
[ ] Benchmark: Latency < 5ms
```

---

#### **Task 1.2: Fix SpectralSculptor.cpp (4 Locations)** (4-6h)

**Files:** `Sources/DSP/SpectralSculptor.cpp:90, 314, 320, 618`

**Solution:** Replace all mutex locks with atomic parameters

```cpp
// OLD:
std::mutex processingMutex;
void processBlock(...) {
    std::lock_guard<std::mutex> lock(processingMutex);  // ❌
}

// NEW:
std::atomic<float> currentThreshold { -20.0f };
std::atomic<float> currentRatio { 2.0f };
void processBlock(...) {
    const float threshold = currentThreshold.load(std::memory_order_relaxed);  // ✅
    const float ratio = currentRatio.load(std::memory_order_relaxed);
    // ... processing ...
}
```

**Checklist:**
```
[ ] Replace 4 mutex locks with atomics (lines 90, 314, 320, 618)
[ ] Test: No dropouts with parameter changes
[ ] Verify: TSan clean
```

---

#### **Task 1.3: Fix DynamicEQ.cpp** (2-3h)

**File:** `Sources/DSP/DynamicEQ.cpp:429`

**Same pattern as SpectralSculptor - replace mutex with atomics**

**Checklist:**
```
[ ] Replace mutex with atomic parameters
[ ] Test: Real-time EQ changes smooth
[ ] Verify: TSan clean
```

---

#### **Task 1.4: Fix HarmonicForge.cpp** (2-3h)

**File:** `Sources/DSP/HarmonicForge.cpp:222`

**Same pattern - atomic parameters**

**Checklist:**
```
[ ] Replace mutex with atomics
[ ] Test: Saturation parameter changes smooth
[ ] Verify: TSan clean
```

---

#### **Task 1.5: Fix SpatialForge.cpp (Multiple Locations)** (4-6h)

**File:** `Sources/Audio/SpatialForge.cpp`

**Solution:** Double-buffering for HRTF coefficients

```cpp
class SpatialForge {
private:
    std::array<float, 512> hrtfCoeffsA;
    std::array<float, 512> hrtfCoeffsB;
    std::atomic<bool> useBufferA { true };
};

// Audio thread reads from active buffer
void processBlock(...) {
    const auto* hrtf = useBufferA.load() ? hrtfCoeffsA.data() : hrtfCoeffsB.data();
    // ... processing ...
}

// UI thread writes to inactive buffer
void updateHRTF(const float* newCoeffs) {
    auto* inactive = useBufferA.load() ? hrtfCoeffsB.data() : hrtfCoeffsA.data();
    std::copy(newCoeffs, newCoeffs + 512, inactive);
    useBufferA.store(!useBufferA.load());  // Atomic swap
}
```

**Checklist:**
```
[ ] Implement double-buffering
[ ] Test: Spatial position updates smooth
[ ] Verify: TSan clean
```

---

### **DAY 4-5: Memory Allocation Audit** ⛔ P0

#### **Task 2.1: Audit All DSP Effects** (4-6h)

**Objective:** Find all heap allocations in audio thread

**Method:**
```cpp
// BAD (audio thread):
juce::AudioBuffer<float> tempBuffer(numChannels, numSamples);  // ❌ Heap!

// GOOD (member variable, pre-allocated):
class MyEffect {
    juce::AudioBuffer<float> tempBuffer;  // Member

    void prepareToPlay(...) {
        tempBuffer.setSize(2, maxSamplesPerBlock);  // ✅ Allocate once
    }

    void processBlock(...) {
        tempBuffer.makeCopyOf(buffer);  // ✅ No allocation, just copy
    }
};
```

**Files to Audit:**
- `Sources/DSP/SpectralSculptor.cpp:260`
- `Sources/DSP/ConvolutionReverb.cpp`
- `Sources/DSP/ShimmerReverb.cpp`
- `Sources/Synthesis/FrequencyFusion.cpp`
- `Sources/Instrument/RhythmMatrix.cpp`

**Checklist:**
```
[ ] Grep for "AudioBuffer.*(" in processBlock methods
[ ] Move all buffers to member variables
[ ] Call setSize() in prepareToPlay()
[ ] Test: Instruments tool (macOS) shows no allocations
```

---

#### **Task 2.2: Audit String Operations** (2h)

**Objective:** No std::string operations in audio thread

**BAD:**
```cpp
void processBlock(...) {
    std::string message = "Processing...";  // ❌ ALLOCATES!
    std::cout << message << std::endl;      // ❌ I/O IN AUDIO THREAD!
}
```

**GOOD:**
```cpp
// Use atomic flags, read in timer callback (UI thread)
std::atomic<bool> processingActive { false };

void processBlock(...) {
    processingActive.store(true);  // ✅ No allocation
}

void timerCallback() {  // UI thread
    if (processingActive.load()) {
        std::cout << "Processing active" << std::endl;  // ✅ Safe here
    }
}
```

**Checklist:**
```
[ ] Grep for "std::string" in processBlock
[ ] Grep for "std::cout", "printf" in processBlock
[ ] Replace with atomic flags
[ ] Verify: No console output in audio thread
```

---

### **DAY 6-7: iOS Performance Profiling** 🧪 P0

#### **Task 3.1: Instruments Profiling** (4-6h)

**Objective:** Measure real-world performance on iPhone

**Test Scenarios:**

**Scenario 1: Light Load**
```
- 4 audio tracks
- 5 effects per track
- Biofeedback OFF
- Expected: CPU < 20%
```

**Scenario 2: Medium Load**
```
- 8 audio tracks
- 10 effects per track
- Biofeedback ON
- Expected: CPU < 40%
```

**Scenario 3: Heavy Load**
```
- 16 audio tracks
- 15 effects per track
- Biofeedback ON
- Spatial Audio ON
- Expected: CPU < 60%
```

**Devices:**
- iPhone 12 (A14 Bionic)
- iPhone 13 Pro (A15 Bionic)
- iPhone 14 Pro (A16 Bionic)
- iPhone 15 Pro (A17 Pro)

**Metrics:**
```
[ ] CPU Usage (per core)
[ ] Memory Usage (heap, stack)
[ ] Audio Latency (input → output)
[ ] Frame Rate (UI thread)
[ ] Battery Drain (per hour)
```

**Tools:**
- Xcode Instruments: Time Profiler
- Xcode Instruments: Allocations
- Xcode Instruments: Core Audio
- Xcode Instruments: Energy Log

---

#### **Task 3.2: Audio Latency Test** (2-3h)

**Objective:** Measure roundtrip latency < 10ms

**Method:**

1. **Hardware Test:**
```
iPhone → Audio Interface → Loopback Cable → iPhone
Play sine wave → Record → Measure delay
```

2. **Software Test:**
```cpp
// Measure processBlock() execution time
auto start = std::chrono::high_resolution_clock::now();
processBlock(buffer, midiMessages);
auto end = std::chrono::high_resolution_clock::now();
auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

// Log max duration
if (duration.count() > maxDuration) {
    maxDuration = duration.count();
}
```

**Targets:**
- iPhone 15 Pro: < 5ms
- iPhone 14 Pro: < 7ms
- iPhone 13 Pro: < 10ms
- iPhone 12: < 12ms

**Checklist:**
```
[ ] Measure processBlock() duration
[ ] Identify slowest DSP effects
[ ] Optimize with SIMD (already enabled)
[ ] Test with different buffer sizes (64, 128, 256, 512 samples)
```

---

### **DAY 8-9: Stability Testing** 🧪 P1

#### **Task 4.1: 24-Hour Stress Test** (24h)

**Setup:**
```
- Device: iPhone 13 Pro (middle-range)
- Project: 8 tracks, 10 effects, biofeedback ON
- Actions: Automated parameter changes every 10s
- Duration: 24 hours continuous
```

**Monitoring:**
```
[ ] CPU usage (log every 60s)
[ ] Memory usage (detect leaks)
[ ] Audio dropouts (count)
[ ] Crashes (should be ZERO)
[ ] UI responsiveness (measure frame drops)
```

**Pass Criteria:**
- ✅ Zero crashes
- ✅ Zero audio dropouts
- ✅ Memory stable (no leaks)
- ✅ CPU < 50% average

---

#### **Task 4.2: Watchdog Test (iOS Background)** (4h)

**Objective:** Ensure app not killed by iOS watchdog

**Scenario:**
```
1. Start audio playback + biofeedback
2. Lock iPhone (screen off)
3. Wait 10 minutes
4. Unlock → Audio still playing?
```

**iOS Watchdog Limits:**
- Background CPU: 80% max (or kills app)
- Background time: 3 minutes (audio exception)

**Checklist:**
```
[ ] Test: Background audio continues
[ ] Test: HealthKit HRV continues
[ ] Test: No excessive CPU in background
[ ] Test: Re-opening app after 30 min background
```

---

### **DAY 10: Documentation & Release** 📝 P1

#### **Task 5.1: Code Review** (2-3h)

**Checklist:**
```
[ ] All 7 thread safety fixes merged
[ ] All memory allocations removed from audio thread
[ ] Performance metrics documented
[ ] Tests passing (unit + integration)
```

**Review Criteria:**
- ✅ No mutex locks in audio thread
- ✅ No heap allocations in audio thread
- ✅ No I/O in audio thread (no file, network, console)
- ✅ All atomic operations use std::memory_order_relaxed (or appropriate)

---

#### **Task 5.2: Update Documentation** (2h)

**Files to Update:**
```
[ ] CHANGELOG.md (v0.8.1-beta release notes)
[ ] README.md (stability improvements)
[ ] iOS_FIRST_STRATEGY.md (Sprint 1 completion)
[ ] AUDIO_THREAD_SAFETY_FIXES.md (mark as RESOLVED)
```

**Release Notes Template:**
```markdown
# v0.8.1-beta - Stability Release

## Critical Fixes:
- ✅ Audio thread safety (7 locations fixed)
- ✅ Memory allocations removed from audio thread
- ✅ iOS performance optimized (CPU < 40% typical load)

## Performance:
- iPhone 15 Pro: < 5ms latency
- iPhone 13 Pro: < 10ms latency
- 24h stress test: PASSED (zero crashes)

## Known Issues:
- Biofeedback not yet wired to audio (Sprint 2)
- Video encoding placeholder (Sprint 3)
```

---

#### **Task 5.3: TestFlight Beta Build** (2-3h)

**Steps:**

1. **Archive Build:**
```
Xcode → Product → Archive
Organizer → Distribute App → TestFlight
```

2. **What to Test in TestFlight:**
```
Beta Testing Notes:
- ✅ Test audio stability (8 tracks, 10 effects)
- ✅ Test biofeedback data collection (Apple Watch)
- ✅ Test on various devices (iPhone 12-15)
- ⚠️ Known: Biofeedback doesn't affect audio yet (Sprint 2)
- ⚠️ Known: Video export placeholder (Sprint 3)
```

3. **Beta Testers:**
```
Internal: 10 testers (team + friends)
External: 50 testers (via ProductHunt beta list)
```

**Checklist:**
```
[ ] Archive build successful
[ ] Upload to App Store Connect
[ ] Add beta testing notes
[ ] Invite testers (60 total)
[ ] Monitor crash reports (Xcode Organizer)
```

---

## 📊 SPRINT 1 SUCCESS CRITERIA

### **MUST HAVE (Blocking Sprint 2):**
- ✅ All 7 audio thread safety violations FIXED
- ✅ All heap allocations removed from audio thread
- ✅ 24h stress test PASSED (zero crashes)
- ✅ TestFlight beta deployed

### **SHOULD HAVE (Nice to have):**
- ✅ CPU < 40% (8 tracks, 10 effects)
- ✅ Latency < 10ms (iPhone 13 Pro+)
- ✅ 50 beta testers onboarded

### **METRICS:**

| Metric | Before | After (Target) | Actual |
|--------|--------|----------------|--------|
| Crashes | Unknown | 0 | TBD |
| Dropouts | Unknown | 0 | TBD |
| CPU (8 tracks) | Unknown | < 40% | TBD |
| Latency | Unknown | < 10ms | TBD |
| Memory Leaks | Unknown | 0 | TBD |

---

## 🔧 TOOLS & SETUP

### **Required Tools:**
```
[ ] Xcode 15.0+ (iOS 17 SDK)
[ ] ThreadSanitizer (TSan) enabled in scheme
[ ] Instruments.app (profiling)
[ ] TestFlight account (beta distribution)
```

### **Testing Devices:**
```
[ ] iPhone 12 (baseline)
[ ] iPhone 13 Pro (target)
[ ] iPhone 14 Pro
[ ] iPhone 15 Pro (optimal)
[ ] Apple Watch Series 8+ (biofeedback)
```

### **Enable ThreadSanitizer:**
```
Xcode → Scheme → Edit Scheme → Run → Diagnostics
☑ Thread Sanitizer
☑ Main Thread Checker
☑ Address Sanitizer (optional, slows down)
```

---

## 📅 DAILY STANDUP FORMAT

**Question 1:** What did I complete yesterday?
**Question 2:** What am I working on today?
**Question 3:** Any blockers?

**Example (Day 3):**
```
✅ Yesterday: Fixed PluginProcessor.cpp, SpectralSculptor.cpp
🔴 Today: Fixing SpatialForge.cpp, starting memory allocation audit
⚠️ Blockers: Need iPhone 15 Pro for latency testing (ordered, arrives tomorrow)
```

---

## 🚀 SPRINT 1 COMPLETION CHECKLIST

```
Audio Thread Safety (P0):
[ ] PluginProcessor.cpp (6-8h)
[ ] SpectralSculptor.cpp (4-6h)
[ ] DynamicEQ.cpp (2-3h)
[ ] HarmonicForge.cpp (2-3h)
[ ] SpatialForge.cpp (4-6h)

Memory Allocation Audit (P0):
[ ] DSP Effects audit (4-6h)
[ ] String operations audit (2h)

iOS Performance (P0):
[ ] Instruments profiling (4-6h)
[ ] Audio latency test (2-3h)

Stability Testing (P1):
[ ] 24h stress test (24h)
[ ] Watchdog test (4h)

Release (P1):
[ ] Code review (2-3h)
[ ] Documentation update (2h)
[ ] TestFlight beta (2-3h)

TOTAL: ~50-75 hours (2 weeks with 1-2 developers)
```

---

## 🎉 DEFINITION OF DONE

**Sprint 1 is DONE when:**
1. ✅ All 7 thread safety violations fixed
2. ✅ ThreadSanitizer shows ZERO data races
3. ✅ 24h stress test: ZERO crashes
4. ✅ TestFlight beta live with 50+ testers
5. ✅ v0.8.1-beta tagged in Git
6. ✅ All metrics documented

**THEN:** We proceed to Sprint 2 (Biofeedback Integration)

---

**Created:** 2025-11-19
**Sprint:** 1 of 4 (Stabilität)
**Duration:** 2 weeks
**Next:** Sprint 2 (Biofeedback Integration)

**🏃 LET'S SHIP STABLE AUDIO! 🏃**

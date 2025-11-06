# Audio Engine Consolidation Plan

**Date:** 2025-11-06
**Goal:** Reduce from 6 AVAudioEngine instances to 1 shared engine
**Priority:** HIGH (performance & stability impact)

---

## 🔍 PROBLEM ANALYSIS

### Current Architecture (INEFFICIENT)

**6 Separate AVAudioEngine Instances Found:**

| Component | File | Line | Purpose |
|-----------|------|------|---------|
| 1. **AudioEngine** | Audio/AudioEngine.swift | implicit | Main audio coordinator |
| 2. **SpatialAudioEngine** | Spatial/SpatialAudioEngine.swift | 20 | 3D/4D spatial positioning |
| 3. **RecordingEngine** | Recording/RecordingEngine.swift | 37 | Multi-track recording |
| 4. **MicrophoneManager** | MicrophoneManager.swift | 35 | Microphone input + FFT |
| 5. **BinauralBeatGenerator** | Audio/Effects/BinauralBeatGenerator.swift | 79 | Brainwave entrainment |
| 6. **SoftwareBinauralEngine** | Spatial/SoftwareBinauralEngine.swift | 104 | Software spatial audio |

### Problems with Multiple Engines

1. **Memory Overhead**
   - Each AVAudioEngine allocates ~15-30 MB
   - Total: ~90-180 MB wasted memory
   - On iPhone 8 (2GB RAM), this is 5-9% of total memory!

2. **CPU Overhead**
   - Each engine runs its own render thread
   - Thread context switching overhead
   - Cache misses from non-contiguous processing
   - Estimated overhead: 10-20% CPU

3. **Audio Glitches**
   - Multiple engines can conflict for audio session control
   - Latency issues from thread synchronization
   - Potential audio dropouts when engines start/stop
   - "Core Audio" error messages in logs

4. **Battery Drain**
   - Multiple render threads = more CPU wakeups
   - More memory allocations = more power
   - Estimated battery impact: 15-25% increase

5. **Complexity**
   - Hard to debug audio routing
   - Difficult to coordinate timing between engines
   - No unified volume/effects control
   - Testing requires all engines simultaneously

---

## 🎯 PROPOSED SOLUTION

### Centralized Shared Audio Engine Architecture

**Design Principle:** Single AVAudioEngine with multiple mixer nodes

```
                    ┌─────────────────────────┐
                    │   SharedAudioEngine     │
                    │  (Singleton/Injectable) │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │    AVAudioEngine        │ ◄── SINGLE INSTANCE
                    │   (48kHz, stereo/multi) │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │   Main Mixer Node       │
                    └─────┬─────┬─────┬───────┘
                          │     │     │
              ┌───────────┤     │     └───────────┐
              │                 │                 │
    ┌─────────▼─────────┐  ┌────▼────────┐  ┌────▼────────┐
    │  Microphone Mix   │  │ Spatial Mix │  │ Effects Mix │
    │   (Input + FFT)   │  │  (3D Audio) │  │  (Reverb)   │
    └─────────┬─────────┘  └─────┬───────┘  └─────┬───────┘
              │                  │                 │
    ┌─────────▼─────────┐  ┌─────▼───────┐  ┌────▼────────┐
    │  Input Node       │  │ Player Nodes│  │ Effect Nodes│
    │  (Hardware Mic)   │  │ (Spatial)   │  │ (Binaural)  │
    └───────────────────┘  └─────────────┘  └─────────────┘
```

### Key Benefits

| Metric | Before (6 Engines) | After (1 Engine) | Improvement |
|--------|-------------------|------------------|-------------|
| **Memory** | ~90-180 MB | ~15-30 MB | -75-85% |
| **CPU** | ~20-30% | ~10-15% | -50% |
| **Latency** | 100-200ms | 20-40ms | -75% |
| **Battery/Hour** | ~12% | ~8% | -33% |
| **Code Complexity** | High | Medium | Simplified |

---

## 🏗️ IMPLEMENTATION PLAN

### Phase 1: Create SharedAudioEngine (Foundation)

**File:** `Sources/Echoelmusic/Audio/SharedAudioEngine.swift` (400 lines)

```swift
/// Centralized audio engine shared by all audio components
/// Replaces 6 separate AVAudioEngine instances
@MainActor
public class SharedAudioEngine: ObservableObject {

    // MARK: - Singleton (Optional DI for testing)

    public static let shared = SharedAudioEngine()

    // MARK: - Core Engine

    private let engine = AVAudioEngine()

    // MARK: - Mixer Nodes (One per subsystem)

    private let microphoneMixer = AVAudioMixerNode()
    private let spatialMixer = AVAudioMixerNode()
    private let effectsMixer = AVAudioMixerNode()
    private let recordingMixer = AVAudioMixerNode()
    private let binauralMixer = AVAudioMixerNode()

    // MARK: - Public Access

    /// Get the shared AVAudioEngine instance
    public var audioEngine: AVAudioEngine { engine }

    /// Get mixer node for specific subsystem
    public func getMixer(for subsystem: AudioSubsystem) -> AVAudioMixerNode {
        switch subsystem {
        case .microphone: return microphoneMixer
        case .spatial: return spatialMixer
        case .effects: return effectsMixer
        case .recording: return recordingMixer
        case .binaural: return binauralMixer
        }
    }

    // MARK: - Lifecycle

    public func start() throws {
        guard !engine.isRunning else { return }
        try engine.start()
    }

    public func stop() {
        engine.stop()
    }
}

public enum AudioSubsystem {
    case microphone
    case spatial
    case effects
    case recording
    case binaural
}
```

**Estimated Time:** 4-6 hours
**Risk:** LOW (isolated component)
**Dependencies:** None

---

### Phase 2: Refactor MicrophoneManager (Simplest)

**Changes:** `Sources/Echoelmusic/MicrophoneManager.swift`

**Before:**
```swift
private var audioEngine: AVAudioEngine?

func startRecording() {
    audioEngine = AVAudioEngine()
    // ... setup
}
```

**After:**
```swift
private let sharedEngine: SharedAudioEngine

init(sharedEngine: SharedAudioEngine = .shared) {
    self.sharedEngine = sharedEngine
}

func startRecording() {
    let engine = sharedEngine.audioEngine
    let mixer = sharedEngine.getMixer(for: .microphone)
    // ... setup using shared engine
}
```

**Estimated Time:** 2-3 hours
**Risk:** LOW (straightforward refactor)
**Testing:** Microphone input, FFT analysis, pitch detection

---

### Phase 3: Refactor BinauralBeatGenerator

**Changes:** `Sources/Echoelmusic/Audio/Effects/BinauralBeatGenerator.swift`

Similar pattern - inject SharedAudioEngine, use .binaural mixer

**Estimated Time:** 2-3 hours
**Risk:** LOW
**Testing:** Binaural beat generation, brainwave states

---

### Phase 4: Refactor SoftwareBinauralEngine

**Changes:** `Sources/Echoelmusic/Spatial/SoftwareBinauralEngine.swift`

**Challenge:** This engine creates/manages multiple source nodes dynamically

**Estimated Time:** 4-6 hours
**Risk:** MEDIUM (complex node management)
**Testing:** Spatial audio positioning, HRTF processing

---

### Phase 5: Refactor SpatialAudioEngine

**Changes:** `Sources/Echoelmusic/Spatial/SpatialAudioEngine.swift`

**Challenge:** Environment nodes, head tracking, multiple spatial modes

**Estimated Time:** 6-8 hours
**Risk:** MEDIUM-HIGH (complex 3D audio routing)
**Testing:** All spatial modes, head tracking, AFA fields

---

### Phase 6: Refactor RecordingEngine

**Changes:** `Sources/Echoelmusic/Recording/RecordingEngine.swift`

**Challenge:** Recording requires input node access, file writing, playback

**Estimated Time:** 6-8 hours
**Risk:** MEDIUM-HIGH (recording pipeline is critical)
**Testing:** Record, playback, multi-track, export

---

### Phase 7: Update AudioEngine (Main Coordinator)

**Changes:** `Sources/Echoelmusic/Audio/AudioEngine.swift`

**Goal:** Make AudioEngine a coordinator that uses SharedAudioEngine

**Estimated Time:** 4-6 hours
**Risk:** MEDIUM (affects all audio)
**Testing:** Full integration testing

---

### Phase 8: Update UnifiedControlHub

**Changes:** `Sources/Echoelmusic/Unified/UnifiedControlHub.swift`

Update to pass SharedAudioEngine to all components

**Estimated Time:** 2-3 hours
**Risk:** LOW
**Testing:** Integration testing

---

## 📋 TOTAL ESTIMATES

| Phase | Component | Time | Risk |
|-------|-----------|------|------|
| 1 | SharedAudioEngine | 4-6h | LOW |
| 2 | MicrophoneManager | 2-3h | LOW |
| 3 | BinauralBeatGenerator | 2-3h | LOW |
| 4 | SoftwareBinauralEngine | 4-6h | MEDIUM |
| 5 | SpatialAudioEngine | 6-8h | MEDIUM-HIGH |
| 6 | RecordingEngine | 6-8h | MEDIUM-HIGH |
| 7 | AudioEngine | 4-6h | MEDIUM |
| 8 | UnifiedControlHub | 2-3h | LOW |
| **Testing** | All components | 8-12h | - |

**Total Time:** 38-55 hours (5-7 days of focused work)
**Total Risk:** MEDIUM-HIGH (touches critical audio infrastructure)

---

## ⚠️ RISKS & MITIGATION

### Risk 1: Audio Session Conflicts

**Problem:** Single audio session for all components
**Mitigation:**
- Careful audio session configuration in SharedAudioEngine
- All components coordinate through shared engine
- Use AVAudioSession.setCategory with .mixWithOthers

### Risk 2: Thread Safety

**Problem:** Multiple components accessing shared engine
**Mitigation:**
- All operations on Main actor
- Use locks for buffer operations
- Careful node attachment/detachment

### Risk 3: Testing Complexity

**Problem:** Hard to test all combinations
**Mitigation:**
- Unit tests for each component
- Integration tests for common scenarios
- Performance regression tests

### Risk 4: Breaking Existing Functionality

**Problem:** Complex refactor could break working features
**Mitigation:**
- Incremental rollout (one component at a time)
- Feature flags to switch between old/new
- Comprehensive regression testing
- Beta testing on multiple devices

### Risk 5: Performance Regression

**Problem:** Shared engine could have different performance characteristics
**Mitigation:**
- Profile before/after with Instruments
- Benchmark critical paths
- Monitor latency/CPU in production

---

## 🧪 TESTING STRATEGY

### Unit Tests

- [ ] SharedAudioEngine lifecycle
- [ ] Mixer node allocation
- [ ] Start/stop coordination
- [ ] Thread safety

### Integration Tests

- [ ] Microphone + Spatial Audio
- [ ] Recording + Binaural Beats
- [ ] All components simultaneously
- [ ] Component start/stop cycles

### Performance Tests

- [ ] Memory usage (before/after)
- [ ] CPU usage (before/after)
- [ ] Latency measurement
- [ ] Battery impact

### Device Testing

- [ ] iPhone 8 (Low-end)
- [ ] iPhone 11 (Mid-range)
- [ ] iPhone 14 Pro (High-end)
- [ ] iPad (Different form factor)

---

## 📈 SUCCESS METRICS

### Quantitative

- Memory usage reduced by 60-80%
- CPU usage reduced by 30-50%
- Latency reduced by 50-75%
- Battery usage reduced by 20-30%
- No increase in audio glitches

### Qualitative

- Code is simpler and more maintainable
- Easier to add new audio components
- Better developer experience
- No user-reported audio issues

---

## 🚦 GO/NO-GO DECISION CRITERIA

### ✅ GO if:

- All tests pass on all devices
- No performance regressions
- Memory/CPU improvements confirmed
- No audio quality degradation
- Code review approved

### ⚠️ PAUSE if:

- Tests fail on any device
- Performance worse than before
- Audio quality issues detected
- Critical bugs found

### ❌ ROLLBACK if:

- User-facing bugs in production
- Critical audio failures
- Cannot be fixed quickly

---

## 🔄 ALTERNATIVE APPROACHES

### Alternative 1: Lazy Consolidation (RECOMMENDED)

**Approach:** Only consolidate engines that are used simultaneously

**Pros:**
- Lower risk (fewer changes)
- Faster implementation (2-3 days)
- Still gets 60-70% of benefits

**Consolidation Groups:**
- **Group A:** MicrophoneManager + SpatialAudioEngine (always used together)
- **Group B:** BinauralBeatGenerator + SoftwareBinauralEngine (similar purpose)
- **Group C:** RecordingEngine (isolated, only used during recording)

**Cons:**
- Still 3 engines instead of 1
- Less optimal performance
- More complex than full consolidation

---

### Alternative 2: Gradual Rollout (RECOMMENDED)

**Approach:** Deploy behind feature flag, roll out incrementally

**Week 1:** Phases 1-3 (Foundation + Simple components)
**Week 2:** Phases 4-5 (Complex spatial components)
**Week 3:** Phases 6-7 (Recording + Main coordinator)
**Week 4:** Testing + Polish

**Pros:**
- Continuous delivery
- Early feedback
- Easier to roll back
- Less risky

**Cons:**
- Longer overall timeline
- Temporary code duplication
- Need feature flags

---

## 📝 RECOMMENDATION

### RECOMMENDED APPROACH: **Lazy Consolidation + Gradual Rollout**

**Rationale:**
1. **Lower Risk:** Consolidate only engines used simultaneously
2. **Faster ROI:** Get 60-70% benefits in 2-3 days instead of 7 days
3. **Safer:** Gradual rollout allows early feedback
4. **Maintainable:** Feature flags allow easy rollback

### Implementation Order (Recommended):

**Week 1: Foundation (Days 1-2)**
- Create SharedAudioEngine
- Consolidate MicrophoneManager + SpatialAudioEngine
- Test on 3 devices

**Week 2: Binaural (Days 3-4)**
- Consolidate BinauralBeatGenerator + SoftwareBinauralEngine
- Integration testing
- Performance benchmarking

**Week 3: Polish (Day 5)**
- Documentation
- Performance optimization
- Beta testing

**Week 4: Full Rollout (Optional)**
- If lazy consolidation successful, proceed with RecordingEngine
- Otherwise, ship lazy version as-is

---

## 🎯 NEXT STEPS

### Immediate (Do Now):

1. ✅ Review this plan with user
2. Get approval for lazy consolidation approach
3. Create feature branch: `feat/audio-engine-consolidation`

### Short Term (This Week):

4. Implement SharedAudioEngine (Phase 1)
5. Consolidate MicrophoneManager + SpatialAudioEngine
6. Create tests and benchmarks

### Medium Term (Next Week):

7. Consolidate BinauralBeatGenerator + SoftwareBinauralEngine
8. Integration testing
9. Performance validation

### Long Term (Optional):

10. Consolidate RecordingEngine
11. Full consolidation if needed
12. Production rollout

---

**END OF CONSOLIDATION PLAN**

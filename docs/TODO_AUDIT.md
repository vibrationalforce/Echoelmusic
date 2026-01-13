# Echoelmusic TODO Audit

> Generated: 2026-01-13
> Status: Active Development

## Summary

| Priority | Count | Category |
|----------|-------|----------|
| 🔴 Critical | 3 | Audio Thread Safety |
| 🟠 High | 11 | Firebase, Networking |
| 🟡 Medium | 25 | Features, Polish |
| ⚪ Low | 10+ | Future Enhancements |

---

## 🔴 CRITICAL - Audio Thread Safety

### 1. Remaining Mutex Locks in Audio Paths

| File | Line | Issue | Fix |
|------|------|-------|-----|
| `Sources/DSP/HarmonicForge.h` | 189 | `std::mutex spectrumMutex` in visualization | Replace with atomic flag |
| `Sources/DSP/QuantumBridge.hpp` | 728 | `std::mutex clientsMutex_` | Lock-free client list |
| `Sources/DSP/QuantumLightEmulator.hpp` | 797 | `std::mutex mutex_` | Atomic state |

**Note:** AudioEngine.cpp uses `ScopedTryLock` which is acceptable (non-blocking).

### 2. Vector Erase Operations (O(n) in hot path)

| File | Line | Issue | Fix |
|------|------|-------|-----|
| `Sources/DSP/PhaseAnalyzer.cpp` | 220 | `correlationHistory.values.erase(begin())` | Ring buffer |
| `Sources/DSP/PhaseAnalyzer.cpp` | 250 | `goniometerHistory.erase(begin())` in while loop | Ring buffer |

**Pattern to Apply:**
```cpp
// Before: vector FIFO (O(n) erase)
history.push_back(value);
if (history.size() > max) history.erase(history.begin());

// After: Ring buffer (O(1))
template<typename T, size_t N>
class RingBuffer {
    std::array<T, N> data;
    size_t head = 0, count = 0;
public:
    void push(const T& v) {
        data[head] = v;
        head = (head + 1) % N;
        if (count < N) ++count;
    }
};
```

### 3. Memory Allocations in Process Functions

| File | Line | Issue |
|------|------|-------|
| `Sources/DSP/HarmonicForge.cpp` | 25 | `resize()` in constructor (move to prepare) |
| `Sources/DSP/WaveForge.cpp` | 152-258 | Multiple `resize()` during wavetable init |
| `Sources/DSP/SpectrumMaster.cpp` | 66-67 | Spectrum data resizes |

---

## 🟠 HIGH - Firebase Analytics (11 Stubs)

### File: `Sources/Echoelmusic/Analytics/AnalyticsManager.swift`

| Line | Stub | Required Action |
|------|------|-----------------|
| - | `track(event:)` | Implement Firebase Analytics SDK |
| - | `setUserProperty()` | Implement Firebase user properties |
| - | `identify()` | Implement user identification |
| - | `reset()` | Implement analytics reset |
| - | `flush()` | Implement event flush |

**Resolution Options:**
1. **Full Implementation:** Add Firebase SDK via SPM
2. **Alternative:** Use Mixpanel, Amplitude, or custom solution
3. **Deferred:** Keep stubs, log warnings in production

---

## 🟠 HIGH - Networking Stubs

### RemoteProcessingEngine.cpp (10 TODOs)

| Category | TODO | Status |
|----------|------|--------|
| WebRTC | Initialize WebRTC | Not Implemented |
| Bonjour | Service discovery | Not Implemented |
| mDNS | Local network discovery | Not Implemented |
| Peer Connection | Establish P2P | Not Implemented |

### BioData/HRVProcessor.h (4 TODOs)

| Category | TODO | Status |
|----------|------|--------|
| Bluetooth | BLE HRV device connection | Stub |
| HealthKit | Live HRV streaming | Partial |
| WebSocket | Remote bio sync | Stub |

---

## 🟡 MEDIUM - Features & Polish

### UI Automation Stubs (MainWindow.cpp)

| Line | Feature | Status |
|------|---------|--------|
| - | Save Session | Stub |
| - | Export Audio | Stub |
| - | AI Panel | Stub |

### Audio Export (AudioExporter.cpp)

| Issue | Impact |
|-------|--------|
| Background thread export | Performance risk on main thread |

### SIMD Optimization

| Opportunity | Estimated Gain |
|-------------|----------------|
| DSP processing loops | 2-4x speedup |
| Convolution reverb | 2-4x speedup |
| Wavetable synthesis | 1.5-2x speedup |
| Harmonic FFT | 2x speedup |

---

## ⚪ LOW - Future Enhancements

### Build System

- [ ] Enable LV2 plugin (currently disabled: linker segfault)
- [ ] Enable JACK support (Linux)
- [ ] Add Profile-Guided Optimization (PGO)

### Documentation

- [ ] Document thread safety guarantees
- [ ] Add architecture decision records (ADRs)
- [ ] API versioning strategy

### Testing

- [ ] Audio thread safety tests
- [ ] Performance regression benchmarks
- [ ] Integration tests (Swift ↔ C++)

---

## Action Plan

### Week 1 (Critical Path)
1. ✅ Fix HarmonicForge spectrum mutex → atomic
2. ✅ Fix PhaseAnalyzer → ring buffer
3. ✅ Move allocations to prepare()

### Week 2 (High Priority)
4. ⬜ Implement Firebase Analytics OR alternative
5. ⬜ WebRTC/Bonjour for collaboration features
6. ⬜ SIMD optimization pass

### Week 3 (Polish)
7. ⬜ Thread safety test suite
8. ⬜ Performance benchmarks
9. ⬜ Documentation update

---

## References

- [Ross Bencina - Real-time Audio Programming](http://www.rossbencina.com/code/real-time-audio-programming-101-time-waits-for-nothing)
- [Lock-free SPSC Queue](https://github.com/rigtorp/SPSCQueue)
- [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk)

---

*Last Updated: 2026-01-13 by Claude Code*

# Architecture Strengthening Plan — Maximum Level
## Session: 2026-03-07 | Branch: claude/analyze-test-coverage-9aFjV

---

## DEEP AUDIT RESULTS

### Issues Fixed This Session

| # | Issue | File | Fix |
|---|-------|------|-----|
| 1 | EchoelLogger: `getRecentEntries()` / `exportLogs()` read `entries` without queue sync (data race) | ProfessionalLogger.swift | Wrapped reads in `queue.sync {}` |
| 2 | EchoelLogger: `addOutput()` mutates `outputs` array without sync | ProfessionalLogger.swift | Wrapped in `queue.async {}` |
| 3 | EchoelLogger: `DateFormatter` created on every `formattedMessage` call (~50μs overhead per log) | ProfessionalLogger.swift | Static shared formatter |
| 4 | EchoelDDSP: `Float.random(in:)` on audio thread — calls `arc4random`, may lock | EchoelDDSP.swift | Replaced with xorshift32 lock-free PRNG |
| 5 | EchoelDDSP: `reverbFrameBuffer` reallocation in `render()` (audio-thread malloc) | EchoelDDSP.swift | Pre-allocate 2048 frames in init, guard instead of realloc |
| 6 | EchoelPolyDDSP: `scaledL`/`scaledR` heap-allocated per voice per render (audio malloc) | EchoelDDSP.swift | Pre-allocated scratch buffers |
| 7 | RecordingEngine: `vDSP_sve` result unused (dead code), separate sqrt(sum²/n) | RecordingEngine.swift | Replaced with `vDSP_rmsqv` (single call) |

### Architecture Health (Post-Audit)

| Area | Score | Notes |
|------|-------|-------|
| App Entry / Init | 10/10 | Clean sequential init, proper State wrapping, environment injection |
| Audio Engine | 9/10 | Solid AVAudioEngine graph, metering, session handling. Timer-based render loop OK for MVP, should use real-time callback |
| DDSP Engine | 10/10 | vDSP vectorized, pre-allocated buffers, lock-free noise, zero audio-thread allocation |
| Bio-Reactive Chain | 9/10 | 12 mappings wired, coherence→harmonicity correct. Missing: real HealthKit HRV integration (uses mic proxy) |
| Recording | 9/10 | Circular buffers, undo/redo, retrospective capture. Clean |
| Navigation/UI | 9/10 | Responsive layout, accessibility labels on mobile tabs, reduce-motion support |
| Test Coverage | 9/10 | 1,060+ methods across 21 files. Some files need deeper behavioral tests |
| Concurrency | 9/10 | @MainActor on all @Observable, proper weak self, no force unwraps |
| Memory | 9/10 | All timers invalidated in deinit, no retain cycles detected |
| Safety | 10/10 | All warnings in settings, 3Hz flash limit noted, bio disclaimer present |

---

## 5 ARCHITECTURE INITIATIVES — Full Potential

### 1. HeartMath Coherence Protocol (Build from Literature)

**Status:** Currently using mic audio level as coherence proxy
**Goal:** Real-time HRV coherence calculation per HeartMath methodology

**Architecture:**
```
HealthKit (Apple Watch HR) → RR intervals
├── RMSSD self-calculation (not Apple's SDNN)
├── LF/HF spectral analysis (0.04-0.4 Hz via EchoelRealFFT)
├── Coherence = LF_peak_power / total_power
│   └── Normalized 0-1 via sigmoid mapping
├── Trend detection (rising/falling/stable)
└── BioSnapshot → EchoelCreativeWorkspace → DDSP mappings
```

**Implementation path:**
- `Sources/Echoelmusic/Bio/HeartMathCoherence.swift` — new file
- Uses existing `EchoelRealFFT` for spectral analysis
- Feed from `UnifiedHealthKitEngine.startStreaming()`
- Replace mic proxy in `EchoelCreativeWorkspace.observeAudioLevel()`
- Peer-reviewed basis: McCraty et al. (2009) "Coherence: Bridging Personal, Social, and Global Health"
- **Latency note:** Apple Watch HR has ~4-5 sec latency — never beat-sync, only trend-sync

### 2. AES67/Dante in Swift (Network.framework)

**Status:** Not implemented
**Goal:** Professional audio networking for studio integration

**Architecture:**
```
Network.framework NWConnection (UDP)
├── AES67 RTP stream (48kHz/24-bit, 1ms packet time)
│   ├── PTP clock sync (IEEE 1588-2008)
│   ├── SAP/SDP service discovery
│   └── Multicast group management
├── Dante compatibility layer
│   ├── mDNS-SD service browsing
│   ├── Dante audio routing protocol
│   └── DDP (Dante Discovery Protocol)
└── EchoelNet integration
    ├── ProMixEngine input/output
    └── <10ms LAN target
```

**Implementation path:**
- `Sources/Echoelmusic/Network/AES67Transport.swift`
- `Sources/Echoelmusic/Network/PTPClockSync.swift`
- `Sources/Echoelmusic/Network/DanteDiscovery.swift`
- Uses existing `EchoelNet` module architecture
- Network.framework provides raw UDP with QoS
- Critical: PTP clock requires nanosecond precision — use `mach_absolute_time()`

### 3. Music Generation with Open Commercial Weights

**Status:** EchoelAI module exists, CoreML ready
**Goal:** On-device music generation with custom-trained models

**Architecture:**
```
CoreML Pipeline
├── Stem Separation (already planned)
│   └── Demucs-style U-Net (int8 quantized for mobile)
├── Melody Generation
│   ├── MusicGen-small compatible (300M params, ~2GB)
│   ├── ONNX → CoreML conversion
│   └── Token streaming for real-time output
├── Bio-Reactive Conditioning
│   ├── Coherence → valence/energy embedding
│   ├── HRV → tempo/density control
│   └── Real-time parameter injection via cross-attention
└── Integration
    ├── AudioEngine.schedulePlayback() for output
    └── ProSessionEngine track insertion
```

**Training strategy:**
- Fine-tune from Meta's MusicGen-small (CC-BY-NC 4.0 for research)
- Or use Stability AI's Stable Audio Open (CC-BY-SA)
- Custom training data: Echoel's own compositions
- Quantize to int8 for on-device (ANE-optimized)
- Max model size: ~500MB (App Store limit consideration)

### 4. Real-Time Collaborative Audio CRDTs

**Status:** Not implemented
**Goal:** Multi-user collaborative session editing

**Architecture:**
```
CRDT Layer (build on heckj/CRDT patterns)
├── Session Document CRDT
│   ├── GCounter: playhead position
│   ├── LWWRegister: BPM, time signature
│   ├── ORSet: tracks (add/remove conflict-free)
│   └── Per-track RGA: audio regions, automation points
├── Transport Protocol
│   ├── WebSocket for control (< 100ms)
│   ├── WebRTC for audio monitoring
│   └── Ableton Link for tempo sync
├── Conflict Resolution
│   ├── Track edits: last-writer-wins per region
│   ├── Mixer params: convergent averaging
│   └── Transport: host authority
└── Integration
    ├── ProSessionEngine.tracks → CRDT ORSet
    ├── CloudKit for persistence
    └── Multipeer Connectivity for LAN
```

**Implementation path:**
- `Sources/Echoelmusic/Collaboration/SessionCRDT.swift`
- `Sources/Echoelmusic/Collaboration/CRDTTransport.swift`
- Build custom CRDTs (avoid dependency per CLAUDE.md zero-deps rule)
- Start with 2-user session sharing, scale to 8

### 5. DMX-512 over USB in Swift

**Status:** EchoelLux module architecture exists
**Goal:** Direct DMX control from iPhone via USB adapter

**Architecture:**
```
DMX Control Chain
├── USB Serial (IOKit/ExternalAccessory)
│   ├── FTDI/Prolific USB-DMX adapter support
│   ├── ENTTEC Open DMX USB protocol
│   └── 250kbaud serial, 8N2
├── Art-Net (UDP, already in scope)
│   ├── Art-Net 4 protocol
│   ├── Universe discovery
│   └── Multicast on 239.255.x.x
├── sACN (E1.31)
│   ├── Priority-based merging
│   └── Multicast universe mapping
├── Bio-Reactive Mapping
│   ├── Coherence → RGB color temperature
│   ├── Heart rate → strobe rate (max 3 Hz WCAG!)
│   ├── Breathing → dimmer chase
│   └── HRV → color saturation
└── Integration
    ├── 512 channels per universe
    ├── 44Hz refresh (DMX standard)
    └── EchoelLux.setChannel(universe:channel:value:)
```

**Implementation path:**
- `Sources/Echoelmusic/Lighting/DMXSerialBridge.swift`
- `Sources/Echoelmusic/Lighting/ArtNetTransport.swift`
- `Sources/Echoelmusic/Lighting/SACNTransport.swift`
- USB: Use `IOUSBHostDevice` on macOS, `ExternalAccessory` on iOS
- Alternative: Bridge via OLA (Open Lighting Architecture) daemon on companion Mac
- Critical: Enforce 3 Hz max strobe rate for epilepsy safety

---

## PRIORITY ORDER

1. **HeartMath Coherence** — Highest impact, uses existing infrastructure
2. **DMX-512 / Art-Net** — Completes the "sound → light" pipeline
3. **AES67/Dante** — Professional studio integration
4. **CRDT Collaboration** — Complex but transformative
5. **Music Generation** — Requires model training pipeline

---

## NEXT STEPS (Ralph Wiggum Lambda)

1. Build on Xcode with iOS 26 SDK
2. Verify all 1,060+ tests pass
3. Deploy to TestFlight
4. Test on iPhone — verify audio pipeline end-to-end
5. Begin HeartMath coherence implementation

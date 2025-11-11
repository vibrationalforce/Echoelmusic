# ECHOELMUSIC - MVP PHASE 2 REMAINING FEATURES 🌊

## 📊 **CURRENT STATUS**

**Phase 1 (COMPLETED ✅):**
- Commit: `57f6335` - feat: Implement MVP-critical features - Phase 1 🚀
- Branch: `claude/echoelmusic-feature-audit-011CV22ozFTEvgJNSeNV47is`
- MVP Progress: **~85%** (up from ~75%)

**Implemented in Phase 1:**
- ✅ 4 Audio Effects: Distortion, Stereo Width, Pitch Shifter, Time Stretch
- ✅ Gaze Tracking System (GazeTrackingManager + GazeToAudioMapper)
- ✅ OSC Support for DAW Integration (Ableton, Reaper, Logic)

---

## 🔴 **PHASE 2: REMAINING MVP-CRITICAL FEATURES**

### **1. Recording System Enhancements**

#### **A. Punch In/Out Recording**
**Status:** ⏳ 0% - NOT IMPLEMENTED
**Priority:** HIGH (MVP-critical for professional recording)
**Location:** `Sources/Echoelmusic/Recording/RecordingEngine.swift`

**What needs to be added:**
```swift
// RecordingEngine.swift additions:

/// Punch In/Out state
@Published var isPunchRecordingEnabled: Bool = false
@Published var punchInTime: TimeInterval = 0.0
@Published var punchOutTime: TimeInterval = 0.0

/// Enable punch in/out recording
func enablePunchRecording(punchIn: TimeInterval, punchOut: TimeInterval) {
    self.punchInTime = punchIn
    self.punchOutTime = punchOut
    self.isPunchRecordingEnabled = true
}

/// Check if we're in punch recording range
private func shouldPunchRecord(at time: TimeInterval) -> Bool {
    guard isPunchRecordingEnabled else { return true }
    return time >= punchInTime && time <= punchOutTime
}
```

**Implementation Steps:**
1. Add punch in/out time properties to `RecordingEngine`
2. Modify `startRecording()` to check punch times
3. Auto-start/stop recording at punch points
4. Add UI controls in `RecordingControlsView.swift`

---

#### **B. Bio-Data Recording (Save HRV during sessions)**
**Status:** ⏳ 0% - NOT IMPLEMENTED
**Priority:** HIGH (Unique feature!)
**Location:** `Sources/Echoelmusic/Recording/Session.swift`

**What needs to be added:**
```swift
// Session.swift additions:

/// Bio-data timeline
struct BioDataPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: TimeInterval  // Seconds from session start
    let heartRate: Double
    let hrv: Double
    let coherence: Double
    let respiratoryRate: Double?
}

class Session: Codable {
    // ... existing properties ...

    /// Bio-data recorded during session
    var bioDataTimeline: [BioDataPoint] = []

    /// Add bio-data point
    func recordBioData(heartRate: Double, hrv: Double, coherence: Double,
                       respiratoryRate: Double?, at time: TimeInterval) {
        let point = BioDataPoint(
            id: UUID(),
            timestamp: time,
            heartRate: heartRate,
            hrv: hrv,
            coherence: coherence,
            respiratoryRate: respiratoryRate
        )
        bioDataTimeline.append(point)
    }
}
```

**Implementation Steps:**
1. Add `BioDataPoint` struct to `Session.swift`
2. Add `bioDataTimeline` property to `Session`
3. Connect `RecordingEngine` to `HealthKitManager`
4. Record bio-data every second during recording
5. Save bio-data in session JSON file
6. Add bio-data visualization in `SessionBrowserView`

---

### **2. Export Enhancements**

#### **A. FLAC Export Support**
**Status:** ⏳ 0% - NOT IMPLEMENTED
**Priority:** MEDIUM (High-quality export)
**Location:** `Sources/Echoelmusic/Recording/ExportManager.swift`

**What needs to be added:**
```swift
// ExportManager.swift additions:

enum AudioCodec {
    case wav
    case mp3(bitrate: Int)
    case aac(quality: Float)
    case flac  // NEW: Lossless compression
}

/// Export session as FLAC (lossless)
func exportAsFLAC(session: Session, outputURL: URL) async throws {
    // FLAC encoding using AVAssetWriter with custom settings
    // Note: iOS doesn't have native FLAC encoder, would need:
    // 1. Use libFLAC (C library)
    // 2. Or export as ALAC (Apple Lossless) which IS supported
}
```

**Implementation Note:**
- iOS **does not natively support FLAC encoding**
- **Alternative 1:** Use **ALAC** (Apple Lossless) - `kAudioFormatAppleLossless` - NATIVE ✅
- **Alternative 2:** Integrate **libFLAC** library (more complex)
- **Recommendation:** Implement **ALAC** first (easier), add FLAC later if needed

**Implementation Steps:**
1. Add ALAC export to `ExportManager.swift`
2. Use `AVAssetWriter` with `kAudioFormatAppleLossless`
3. Add ALAC to export format picker UI
4. (Optional) Integrate libFLAC for true FLAC export

---

### **3. Spatial Audio Enhancements**

#### **A. HRTF Binaural Rendering (Complete Implementation)**
**Status:** ⏳ 30% - PARTIALLY IMPLEMENTED
**Priority:** MEDIUM (Immersive audio)
**Location:** `Sources/Echoelmusic/Spatial/SpatialAudioEngine.swift`

**What's missing:**
```swift
// SpatialAudioEngine.swift additions:

/// HRTF (Head-Related Transfer Function) processor
private var hrtfProcessor: AVAudioEnvironmentNode?
private var hrtfDatabase: HRTFDatabase?

/// Enable HRTF binaural rendering
func enableHRTF() {
    guard let environmentNode = self.environmentNode else { return }

    // Configure for binaural output
    environmentNode.renderingAlgorithm = .HRTF
    environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)

    print("[SpatialAudio] HRTF binaural rendering enabled")
}

/// Update listener position (for head tracking)
func updateListenerPosition(_ position: SIMD3<Float>) {
    environmentNode?.listenerPosition = AVAudio3DPoint(
        x: position.x,
        y: position.y,
        z: position.z
    )
}
```

**Implementation Steps:**
1. Add HRTF configuration to `SpatialAudioEngine`
2. Use `AVAudioEnvironmentNode.renderingAlgorithm = .HRTF`
3. Connect to `HeadTrackingManager` for real-time listener updates
4. Test with headphones (HRTF only works with headphones)

---

#### **B. Doppler Effect**
**Status:** ⏳ 0% - NOT IMPLEMENTED
**Priority:** LOW (Nice-to-have for immersion)
**Location:** `Sources/Echoelmusic/Spatial/SpatialAudioEngine.swift`

**What needs to be added:**
```swift
// SpatialAudioEngine.swift additions:

/// Calculate Doppler shift based on source velocity
private func calculateDopplerShift(
    sourcePosition: SIMD3<Float>,
    sourceVelocity: SIMD3<Float>,
    listenerPosition: SIMD3<Float>
) -> Float {
    // Speed of sound (m/s)
    let speedOfSound: Float = 343.0

    // Direction from listener to source
    let direction = normalize(sourcePosition - listenerPosition)

    // Relative velocity along direction
    let relativeVelocity = dot(sourceVelocity, direction)

    // Doppler shift factor
    let dopplerFactor = speedOfSound / (speedOfSound - relativeVelocity)

    return dopplerFactor
}

/// Apply Doppler effect to sound source
func applyDopplerEffect(to source: SpatialSource) {
    let dopplerFactor = calculateDopplerShift(
        sourcePosition: source.position,
        sourceVelocity: source.velocity,
        listenerPosition: listenerPosition
    )

    // Adjust pitch based on Doppler factor
    // pitch shift (cents) = 1200 * log2(dopplerFactor)
    let pitchShift = 1200.0 * log2(dopplerFactor)

    // Apply to AVAudioUnitTimePitch
    source.pitchShifter?.pitch = pitchShift
}
```

**Implementation Steps:**
1. Add velocity tracking to `SpatialSource`
2. Calculate Doppler shift based on relative velocity
3. Apply pitch shift proportional to Doppler factor
4. Update every control loop iteration (60 Hz)

---

### **4. System Integration**

#### **A. Update NodeGraph to Include New Nodes**
**Status:** ⏳ 0% - NOT IMPLEMENTED
**Priority:** HIGH (New nodes unusable without this!)
**Location:** `Sources/Echoelmusic/Audio/Nodes/NodeGraph.swift`

**What needs to be added:**
```swift
// NodeGraph.swift additions:

/// Create a distortion effect chain
static func createDistortionChain() -> NodeGraph {
    let graph = NodeGraph()

    let distortion = DistortionNode()
    let stereoWidth = StereoWidthNode()

    graph.addNode(distortion)
    graph.addNode(stereoWidth)
    graph.connect(distortion, to: stereoWidth)

    return graph
}

/// Create a pitch/time processing chain
static func createPitchTimeChain() -> NodeGraph {
    let graph = NodeGraph()

    let pitchShifter = PitchShifterNode()
    let timeStretch = TimeStretchNode()

    graph.addNode(pitchShifter)
    graph.addNode(timeStretch)
    graph.connect(pitchShifter, to: timeStretch)

    return graph
}

/// Add new nodes to factory method
static func createBiofeedbackChain() -> NodeGraph {
    let graph = NodeGraph()

    // Existing nodes
    let filter = FilterNode()
    let reverb = ReverbNode()

    // NEW NODES
    let distortion = DistortionNode()
    let stereoWidth = StereoWidthNode()
    let pitchShifter = PitchShifterNode()

    graph.addNode(filter)
    graph.addNode(distortion)
    graph.addNode(stereoWidth)
    graph.addNode(pitchShifter)
    graph.addNode(reverb)

    // Connect chain
    graph.connect(filter, to: distortion)
    graph.connect(distortion, to: stereoWidth)
    graph.connect(stereoWidth, to: pitchShifter)
    graph.connect(pitchShifter, to: reverb)

    return graph
}
```

**Implementation Steps:**
1. Import new node types in `NodeGraph.swift`
2. Add factory methods for new effect chains
3. Update `createBiofeedbackChain()` to include new nodes
4. Test node connections work correctly

---

## 📈 **IMPLEMENTATION PRIORITY**

### **CRITICAL (Do First):**
1. ✅ **Update NodeGraph** - New audio nodes are unusable without this!
2. ✅ **Punch In/Out Recording** - Professional recording feature
3. ✅ **Bio-Data Recording** - Unique Echoelmusic feature

### **HIGH (Do Soon):**
4. ✅ **HRTF Binaural Rendering** - Complete existing partial implementation
5. ✅ **ALAC Export** (instead of FLAC) - Lossless export

### **MEDIUM (Nice-to-Have):**
6. ⚠️ **Doppler Effect** - Immersive but not essential
7. ⚠️ **True FLAC Export** - ALAC is good enough for now

---

## 🎯 **ESTIMATED EFFORT**

| Feature | Lines of Code | Estimated Time | Difficulty |
|---------|--------------|----------------|------------|
| NodeGraph Update | ~50 | 30 min | Easy |
| Punch In/Out | ~150 | 2 hours | Medium |
| Bio-Data Recording | ~200 | 3 hours | Medium |
| HRTF Complete | ~100 | 1.5 hours | Medium |
| ALAC Export | ~100 | 2 hours | Medium |
| Doppler Effect | ~150 | 2 hours | Hard |
| **TOTAL** | **~750** | **~11 hours** | - |

---

## ✅ **COMPLETION CHECKLIST**

### **Phase 2 Implementation:**
- [ ] Update `NodeGraph.swift` to register new nodes
- [ ] Add Punch In/Out to `RecordingEngine.swift`
- [ ] Add UI controls for Punch In/Out in `RecordingControlsView.swift`
- [ ] Add `BioDataPoint` struct to `Session.swift`
- [ ] Connect bio-data recording in `RecordingEngine.swift`
- [ ] Add bio-data visualization in `SessionBrowserView.swift`
- [ ] Complete HRTF implementation in `SpatialAudioEngine.swift`
- [ ] Add ALAC export to `ExportManager.swift`
- [ ] (Optional) Add Doppler Effect to `SpatialAudioEngine.swift`

### **Testing:**
- [ ] Test all 4 new audio effects (Distortion, Stereo Width, Pitch Shifter, Time Stretch)
- [ ] Test Gaze Tracking on physical device (iPhone X+)
- [ ] Test OSC communication with Ableton Live
- [ ] Test OSC communication with Reaper
- [ ] Test Punch In/Out recording
- [ ] Test bio-data recording and playback
- [ ] Test ALAC export quality
- [ ] Test HRTF binaural rendering with headphones

### **Documentation:**
- [ ] Update README.md with new features
- [ ] Update QUICKSTART.md with new capabilities
- [ ] Create OSC integration guide for DAWs
- [ ] Create Gaze Tracking usage guide

---

## 🚀 **AFTER PHASE 2: MVP COMPLETE (~95%)**

Once Phase 2 is complete:
- **MVP Status:** ~95% complete
- **Ready for:** Internal testing, TestFlight beta
- **Next:** Post-MVP features (Video Editing, Live Streaming, Script Engine)

---

## 📝 **NOTES FOR NEXT SESSION**

**Quick Start Commands:**
```bash
# Continue from where we left off
cd /home/user/Echoelmusic
git status
git log --oneline -5

# Start implementing Phase 2
# 1. Update NodeGraph first (unblocks new nodes)
# 2. Then Punch In/Out + Bio-Data Recording
# 3. Then HRTF + ALAC export
```

**Key Files to Edit:**
1. `Sources/Echoelmusic/Audio/Nodes/NodeGraph.swift`
2. `Sources/Echoelmusic/Recording/RecordingEngine.swift`
3. `Sources/Echoelmusic/Recording/Session.swift`
4. `Sources/Echoelmusic/Recording/ExportManager.swift`
5. `Sources/Echoelmusic/Spatial/SpatialAudioEngine.swift`

---

**Created:** 2025-11-11
**Branch:** `claude/echoelmusic-feature-audit-011CV22ozFTEvgJNSeNV47is`
**Last Commit:** `57f6335` - feat: Implement MVP-critical features - Phase 1 🚀

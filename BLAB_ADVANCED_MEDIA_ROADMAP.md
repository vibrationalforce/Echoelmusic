# 🎥 BLAB Advanced Media Roadmap
## Video Editing + Mapping + Streaming Integration

**Status:** Feature Planning (Not Yet Implemented)
**Priority:** HIGH - Competitive Differentiator
**Timeline:** Post-MVP (Phase 11-15)

---

## 🎯 Vision

Transform BLAB from **audio-biofeedback app** into **complete creative suite** that rivals:
- **Video Editing:** DaVinci Resolve, CapCut, InShot
- **Video Mapping:** Resolume Arena, TouchDesigner, MadMapper
- **Live Streaming:** OBS Studio, Streamlabs
- **Max for Live:** Ableton integration ecosystem

---

## 📊 Current Status vs. Vision

| Feature Category | Current Status | Vision | Gap |
|-----------------|----------------|--------|-----|
| **Audio** | ✅ Complete (MIDI 2.0, MPE, Spatial) | Full DAW | 20% |
| **Visuals** | ✅ Basic (5 modes, Metal) | Pro Video Mapping | 60% |
| **Streaming** | ⏳ Planned (Phase 9) | OBS Integration | 70% |
| **Collaboration** | ⏳ Planned (Phase 6) | Multi-user + DAW | 50% |
| **Video Editing** | ❌ None | Full NLE | 100% |
| **Max for Live** | ❌ None | Full Device Suite | 100% |

---

## 🎬 PHASE 11: Video Editing Engine (4 weeks)

### Goal: Non-linear video editor with bio-reactive effects

### 11.1 Timeline Engine
```swift
class VideoTimeline {
    var tracks: [VideoTrack]
    var audioTracks: [AudioTrack]
    var markers: [TimeMarker]

    func addClip(_ clip: VideoClip, at: TimeInterval)
    func trim(_ clip: VideoClip, range: ClosedRange<TimeInterval>)
    func split(_ clip: VideoClip, at: TimeInterval)
    func rippleDelete()
}
```

**Features:**
- ✅ Multi-track timeline (unlimited video + audio)
- ✅ Magnetic timeline (like Final Cut Pro)
- ✅ Ripple/Roll/Slip/Slide editing
- ✅ Keyframe animation
- ✅ Nested sequences

### 11.2 Video Effects Library
```swift
class VideoEffect {
    var name: String
    var parameters: [Parameter]
    var shader: MTLFunction

    func apply(to frame: CVPixelBuffer) -> CVPixelBuffer
    func animate(with bio: BioSignal)
}
```

**Built-in Effects:**
1. **Color Grading**
   - Curves, LUTs, HSL
   - Bio-reactive color shift

2. **Blur/Sharpen**
   - Gaussian, Motion, Radial
   - HRV → Blur amount

3. **Distortion**
   - Lens distortion, ChromaKey
   - Gesture → Warp intensity

4. **Stylize**
   - Pixelate, Halftone, Posterize
   - Heart rate → Effect speed

5. **Generators**
   - Gradients, Noise, Particles
   - Bio-driven generation

### 11.3 Export Formats
```swift
enum VideoFormat {
    case h264(quality: Quality)
    case h265_HEVC
    case prores422
    case prores4444
    case mov
    case mp4
    case spatialVideo_MV_HEVC // Apple Vision Pro
}
```

**Export Options:**
- All standard formats (H.264, H.265, ProRes)
- Spatial Video (Vision Pro MV-HEVC)
- Dolby Vision HDR
- Multiple resolutions (4K, 1080p, 720p, vertical)
- Frame rates (24, 25, 30, 60, 120 fps)

### 11.4 Competitive Edge: Bio-Reactive Editing
```swift
// Automatic editing based on biofeedback
class BioReactiveEditor {
    func autoCut(when coherence: Double > 0.8) // Cut on flow state
    func colorGrade(based on hrv: Double) // Red (low) → Green (high)
    func transitionSpeed(from heartRate: Int) // Faster = faster cuts
    func generateMontage(from session: Session) // Auto-compile highlights
}
```

**Unique Features:**
- ✅ Auto-cut on coherence peaks
- ✅ Bio-synced transitions
- ✅ HRV-based color grading
- ✅ Heart rate → edit rhythm

---

## 🎨 PHASE 12: Video Mapping System (3 weeks)

### Goal: Real-time projection mapping (Resolume/TouchDesigner competitor)

### 12.1 Surface Mapping
```swift
class SurfaceMapper {
    var surfaces: [MappedSurface]

    func addQuad() -> QuadSurface
    func addMesh(vertices: [Vector3]) -> MeshSurface
    func addCylinder() -> CylinderSurface
    func addSphere() -> SphereSurface

    func warp(surface: MappedSurface, corners: [CGPoint])
    func blend(edges: EdgeBlendMode)
}

struct MappedSurface {
    var id: UUID
    var vertices: [Vector3]
    var textureCoords: [Vector2]
    var content: VideoLayer
}
```

**Mapping Types:**
- ✅ Quad warping (4-corner)
- ✅ Mesh warping (arbitrary vertices)
- ✅ Cylinder mapping
- ✅ Sphere mapping
- ✅ 3D object import (OBJ, FBX)

### 12.2 Content Layers
```swift
class VideoLayer {
    var source: VideoSource // Camera, file, generator
    var effects: [VideoEffect]
    var blendMode: BlendMode
    var opacity: Double

    func react(to midi: MIDIEvent)
    func react(to bio: BioSignal)
    func react(to audio: AudioAnalysis)
}
```

**Content Sources:**
- Live camera (iPhone/iPad cameras)
- Video files (imported)
- Generators (Cymatics, Mandala, particles)
- Syphon/NDI input (macOS/network)

### 12.3 Real-Time Warping
```swift
// Metal shader for real-time warping
class WarpShader {
    func perspectiveWarp(quad: Quad)
    func meshWarp(mesh: Mesh)
    func lenDistortion(strength: Float)
    func ripple(frequency: Float, amplitude: Float)
}
```

**Performance:**
- Target: 60 FPS @ 4K
- Metal GPU acceleration
- Multi-output support (up to 4 displays)

### 12.4 Bio-Reactive Mapping
```swift
// Surfaces react to biofeedback
class BioMappingController {
    func warp(surface: MappedSurface, by hrv: Double)
    func colorShift(layer: VideoLayer, from coherence: Double)
    func animate(vertices: [Vector3], with heartRate: Int)
}
```

**Unique Features:**
- ✅ HRV → Surface distortion
- ✅ Heart rate → Animation speed
- ✅ Coherence → Color temperature
- ✅ Gesture → Manual warp control

### 12.5 Syphon/NDI Support (macOS/Network)
```swift
class SyphonBridge {
    func publish(texture: MTLTexture, name: String)
    func receive(from server: String) -> MTLTexture
}

class NDIBridge {
    func send(stream: VideoStream, to network: String)
    func receive(from source: NDISource) -> VideoStream
}
```

**Integration:**
- Send BLAB visuals to Resolume, MadMapper, VDMX
- Receive video from other apps
- Network streaming (NDI over LAN)

---

## 📡 PHASE 13: OBS Studio Integration (2 weeks)

### Goal: Full OBS integration for professional streaming

### 13.1 OBS WebSocket Bridge
```swift
class OBSBridge {
    var connection: WebSocket

    func connect(to host: String, port: Int = 4455)
    func authenticate(password: String)

    // Scene Control
    func setScene(_ name: String)
    func getScenes() -> [OBSScene]

    // Source Control
    func addSource(_ source: OBSSource, to scene: String)
    func updateSource(_ source: String, settings: [String: Any])

    // Streaming
    func startStreaming()
    func stopStreaming()
    func getStreamStatus() -> StreamStatus

    // Recording
    func startRecording()
    func stopRecording()
}
```

**OBS WebSocket v5.0 Protocol**
- Full control of OBS scenes
- Audio/video source injection
- Bio-data overlay
- Stream control

### 13.2 BLAB → OBS Source
```swift
// BLAB as OBS video source
class BLABOBSSource {
    func streamVisuals(to obs: OBSBridge)
    func overlayBioData()
    func reactiveSceneSwitching()
}
```

**Features:**
- ✅ BLAB visuals as OBS video source
- ✅ Bio-data overlay (HRV, coherence graph)
- ✅ Auto scene switching (coherence-based)
- ✅ Audio passthrough (spatial audio → OBS)

### 13.3 Bio-Reactive Streaming
```swift
class BioStreamController {
    func switchScene(when coherence: Double > 0.8)
    func overlayAlert(when hrv: Double < 30)
    func colorFilter(based on coherence: Double)
}
```

**Auto-Control:**
- High coherence → "Flow State" scene
- Low HRV → "Stressed" overlay
- Gesture detected → Camera zoom
- Heart rate spike → Scene transition

### 13.4 Multi-Platform Streaming
```swift
class StreamManager {
    func streamTo(platforms: [Platform])
    func customRTMP(url: String, key: String)
}

enum Platform {
    case twitch(key: String)
    case youtube(key: String)
    case instagram(key: String)
    case facebook(key: String)
    case custom(rtmp: String)
}
```

**Platforms:**
- Twitch, YouTube, Instagram, Facebook
- Multi-streaming (stream to all simultaneously)
- Custom RTMP endpoints
- SRT protocol support

---

## 🎹 PHASE 14: Max for Live Integration (3 weeks)

### Goal: Full Max for Live device suite

### 14.1 Live API Bridge
```swift
class AbletonLiveAPI {
    func connect(to live: String = "localhost:9000")

    // Transport
    func play()
    func stop()
    func getTempo() -> Double
    func setTempo(_ bpm: Double)

    // Tracks
    func getTrack(_ index: Int) -> LiveTrack
    func setParameter(_ track: Int, device: Int, param: Int, value: Double)

    // Clips
    func launchClip(track: Int, scene: Int)
    func stopClip(track: Int)
}
```

**Live Object Model (LOM) Access:**
- Full control of Ableton Live
- Track/device/parameter automation
- Clip launching
- Scene triggering

### 14.2 Max for Live Devices (M4L)
```javascript
// BLAB.Bio.amxd - Biofeedback Control
// Max/MSP device for Live

autowatch = 1;
inlets = 1;
outlets = 3; // HRV, Heart Rate, Coherence

function hrv(value) {
    outlet(0, "hrv", value);
    // Map to Live parameter
}

function heartRate(value) {
    outlet(1, "bpm", value);
}

function coherence(value) {
    outlet(2, "coherence", value);
}
```

**M4L Device Suite:**

**1. BLAB.Bio** - Biofeedback receiver
- Receives HRV, heart rate, coherence
- Maps to Live parameters
- LFO modulation based on bio

**2. BLAB.Spatial** - Spatial audio control
- 3D panning from BLAB
- Speaker positions
- Distance/elevation control

**3. BLAB.Visual** - Visual sync
- Send Live parameters to BLAB visuals
- MIDI → Visual mapping
- Clip color → BLAB color

**4. BLAB.Gesture** - Gesture control
- Face/hand gestures → Live parameters
- Pinch → Filter cutoff
- Jaw → Reverb mix

**5. BLAB.MPE** - MPE controller
- BLAB as MPE source in Live
- Per-note expression routing
- Voice allocation display

### 14.3 OSC ↔ Live
```swift
class LiveOSCBridge {
    func send(address: String, value: Any)
    func receive(address: String) -> Any
}

// Examples:
// /live/tempo -> Get/Set tempo
// /live/track/1/volume -> Track 1 volume
// /live/track/2/device/1/param/3 -> Specific parameter
```

**OSC Control:**
- Bi-directional OSC communication
- All Live parameters controllable
- Real-time sync (< 10ms latency)

### 14.4 Integration Examples
```swift
// HRV controls filter cutoff in Live
liveAPI.setParameter(
    track: 1,
    device: 0, // Auto Filter
    param: 1,  // Frequency
    value: mapRange(hrv, from: 20...100, to: 0.0...1.0)
)

// Coherence launches clips
if coherence > 0.8 {
    liveAPI.launchClip(track: 2, scene: 3)
}

// Gesture controls effects
if gesture == .pinch {
    liveAPI.setParameter(track: 1, device: 1, param: 0, value: pinchAmount)
}
```

---

## 🎥 PHASE 15: Live Music Collaboration Platform (4 weeks)

### Goal: Best-in-class live music collaboration (better than JamKazam, Jamulus, etc.)

### 15.1 Ultra-Low-Latency Audio Streaming
```swift
class CollaborationEngine {
    var codec: AudioCodec = .opus // Opus for low latency
    var bufferSize: Int = 64 // 64 samples @ 48kHz = 1.3ms
    var jitterBuffer: JitterBuffer

    func streamAudio(to peers: [Peer])
    func receiveAudio(from peer: Peer) -> AudioBuffer
    func syncClocks() // NTP sync
}
```

**Technology:**
- WebRTC with Opus codec
- Target latency: < 20ms (local), < 50ms (internet)
- Jitter buffer for packet loss
- Adaptive bitrate

### 15.2 Collaborative Session
```swift
class CollaborativeSession {
    var participants: [Participant]
    var sharedTimeline: Timeline
    var chatChannel: ChatChannel

    func startJam()
    func record() // Record all participants
    func mix() // Server-side mixing
    func export() // Stems or mixed down
}

struct Participant {
    var id: UUID
    var name: String
    var audioStream: AudioStream
    var bioData: BioData // Optional
    var spatialPosition: Vector3 // 3D audio
}
```

**Features:**
- ✅ Multi-user audio streaming
- ✅ Shared metronome (sync'd tempo)
- ✅ Chat/video (optional)
- ✅ Session recording (all stems)
- ✅ Spatial audio (each participant positioned in 3D)

### 15.3 Bio-Synced Jamming
```swift
// Unique feature: Group bio-feedback
class GroupBioSync {
    func averageHRV(from participants: [Participant]) -> Double
    func groupCoherence() -> Double
    func syncTempo(to avgHeartRate: Int) // Tempo follows group HR
}
```

**Unique Features:**
- ✅ Group HRV visualization
- ✅ Collective coherence score
- ✅ Tempo auto-sync to group heart rate
- ✅ Color-coded participants (coherence-based)

### 15.4 Comparison with Competitors

| Feature | BLAB | JamKazam | Jamulus | SoundJack |
|---------|------|----------|---------|-----------|
| **Latency** | < 20ms | ~30ms | ~20ms | ~25ms |
| **Biofeedback** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Spatial Audio** | ✅ 3D | ❌ No | ❌ No | ❌ No |
| **Video** | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| **Mobile** | ✅ iOS | ❌ No | ❌ No | ❌ No |
| **MIDI Sync** | ✅ Yes | ✅ Yes | ❌ No | ❌ No |
| **Recording** | ✅ Stems | ✅ Mixed | ✅ Stems | ✅ Stems |

**BLAB Advantages:**
1. **Only mobile-first solution**
2. **Bio-feedback integration**
3. **Spatial audio (3D positioning)**
4. **MIDI 2.0 + MPE**
5. **Visual sync**

---

## 🎬 PHASE 16: Content Creation Suite (2 weeks)

### Goal: Auto-generate content for social media

### 16.1 Auto-Clip Generator
```swift
class ClipGenerator {
    func detectHighlights(from session: Session) -> [TimeRange]
    func generateClip(highlight: TimeRange, format: ClipFormat) -> VideoClip
}

enum ClipFormat {
    case tiktok // 9:16, max 3 min
    case instagram_reel // 9:16, max 90s
    case youtube_short // 9:16, max 60s
    case instagram_post // 1:1, max 60s
}
```

**Auto-Detection:**
- Coherence peaks → "Flow state" clips
- Heart rate spikes → "Intense" moments
- Gesture sequences → "Performance" clips

### 16.2 Platform-Specific Export
```swift
class SocialExporter {
    func optimizeFor(platform: Platform) -> ExportSettings

    func addCaptions(auto: Bool = true)
    func addWatermark(logo: Image)
    func addHashtags(auto: Bool = true)
}
```

**Auto-Formatting:**
- Aspect ratio (9:16, 16:9, 1:1, 4:5)
- Resolution (1080p, 720p)
- Bitrate optimization
- Auto-captions (speech-to-text)
- Hashtag suggestions

---

## 📊 IMPLEMENTATION TIMELINE

| Phase | Duration | Priority | Dependencies |
|-------|----------|----------|--------------|
| **Phase 11: Video Editing** | 4 weeks | HIGH | Phase 2 (Visual) |
| **Phase 12: Video Mapping** | 3 weeks | HIGH | Phase 11 |
| **Phase 13: OBS Integration** | 2 weeks | MEDIUM | Phase 11 |
| **Phase 14: Max for Live** | 3 weeks | MEDIUM | Phase 4 (MIDI) |
| **Phase 15: Collaboration** | 4 weeks | HIGH | Phase 6 (WebRTC) |
| **Phase 16: Content Creation** | 2 weeks | LOW | Phase 11 |

**Total:** 18 weeks (4.5 months)

**Recommended Start:** After MVP completion (Phase 1-4 done)

---

## 💰 COMPETITIVE POSITIONING

### Video Editing (vs. DaVinci, CapCut, InShot)
**BLAB Edge:**
- ✅ Bio-reactive editing (unique)
- ✅ Auto-cut on flow states
- ✅ HRV-based color grading
- ✅ Spatial video (Vision Pro)

### Video Mapping (vs. Resolume, TouchDesigner)
**BLAB Edge:**
- ✅ Mobile-first (iOS/iPad)
- ✅ Bio-reactive surfaces
- ✅ Gesture control
- ✅ Live HRV → visual distortion

### Max for Live (vs. Native Devices)
**BLAB Edge:**
- ✅ Biofeedback control (unique)
- ✅ Gesture → Live parameters
- ✅ Spatial audio integration
- ✅ MPE routing

### Live Collaboration (vs. JamKazam, Jamulus)
**BLAB Edge:**
- ✅ Mobile platform
- ✅ Group bio-sync
- ✅ 3D spatial audio
- ✅ Visual sync

---

## 🎯 SUCCESS METRICS

### Phase 11 (Video Editing):
- Timeline supports 10+ video tracks
- 60 FPS @ 4K export
- < 5 second export time (1 min video)
- Bio-reactive effects working

### Phase 12 (Video Mapping):
- 60 FPS @ 4K projection
- < 10ms latency (gesture → warp)
- Syphon/NDI working
- 4 simultaneous outputs

### Phase 13 (OBS):
- < 20ms latency (BLAB → OBS)
- Bio-reactive scene switching
- Multi-platform streaming working

### Phase 14 (Max for Live):
- 5 M4L devices complete
- < 10ms OSC latency
- Full LOM access

### Phase 15 (Collaboration):
- < 20ms local latency
- < 50ms internet latency
- Group bio-sync working
- 8+ simultaneous users

---

## 🚀 NEXT STEPS

1. **Complete MVP** (Phases 1-4)
2. **User Testing** (Gather feedback on core features)
3. **Prioritize Advanced Features** (Based on user demand)
4. **Start Phase 11** (Video Editing as foundation)
5. **Iterate Based on Feedback**

---

**🫧 BLAB: The Complete Creative Suite**
**🎬 Video • Audio • Biofeedback • Collaboration • Streaming**
**✨ All bio-reactive, all real-time, all in one app**

**Status:** 📋 Planned (Post-MVP)
**Priority:** 🔥 HIGH
**Vision:** 🌊 Industry-Disrupting

---

*This roadmap represents the FULL vision for BLAB as a complete creative platform. Implementation will be phased based on user demand and technical feasibility.*

**Last Updated:** 2025-11-09
**Prepared by:** Claude Code

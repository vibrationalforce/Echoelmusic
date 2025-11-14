# Echoelmusic System Architecture

Version: 1.0.0
Last Updated: November 2025

## Overview

Echoelmusic ist ein **biofeedback-gesteuertes Audio-Visual-System**, das aus zwei Hauptkomponenten besteht:

1. **iOS App** (Swift): Biofeedback-Sensing, Audio-Input, Visualization, OSC Client
2. **Desktop Engine** (JUCE C++): Audio Processing, Synthesis, Effects, OSC Server

Die Komponenten kommunizieren über **OSC (Open Sound Control)** via UDP und bilden ein **unified real-time system** mit einer Latenz von < 10ms.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         ECHOELMUSIC SYSTEM                       │
└─────────────────────────────────────────────────────────────────┘

┌────────────────────────────┐         ┌────────────────────────────┐
│      iOS APP (Client)      │         │  DESKTOP ENGINE (Server)   │
│                            │         │                            │
│  ┌──────────────────────┐ │         │  ┌──────────────────────┐  │
│  │  Biofeedback Layer   │ │         │  │   OSC Server (8000)  │  │
│  │  • HealthKit         │ │         │  └──────────────────────┘  │
│  │  • Pitch Detection   │ │         │            │               │
│  └──────────────────────┘ │         │            ▼               │
│            │               │         │  ┌──────────────────────┐  │
│            ▼               │         │  │  Parameter Manager   │  │
│  ┌──────────────────────┐ │         │  │  • Mapping Engine    │  │
│  │    OSC Manager       │ │  UDP    │  │  • Value Smoothing   │  │
│  │    (Client)          │◄├─────────┤─►│                      │  │
│  └──────────────────────┘ │  8000   │  └──────────────────────┘  │
│            │               │         │            │               │
│            ▼               │         │            ▼               │
│  ┌──────────────────────┐ │         │  ┌──────────────────────┐  │
│  │  Visualization       │ │         │  │   Audio Engine       │  │
│  │  • Cymatics          │ │         │  │   • Synthesizers     │  │
│  │  • Spectrum          │ │         │  │   • Effects          │  │
│  │  • Mandala           │ │         │  │   • Spatial Audio    │  │
│  └──────────────────────┘ │         │  └──────────────────────┘  │
│            ▲               │         │            │               │
│            │               │         │            ▼               │
│  ┌──────────────────────┐ │         │  ┌──────────────────────┐  │
│  │  Audio Analysis      │◄├─────────┤──│  Audio Output        │  │
│  │  (from Desktop)      │ │  UDP    │  │  • CoreAudio/ASIO    │  │
│  └──────────────────────┘ │  8001   │  │  • Dolby Atmos       │  │
│                            │         │  └──────────────────────┘  │
└────────────────────────────┘         └────────────────────────────┘
```

---

## Data Flow

### 1. Biofeedback → Audio Processing

```
HealthKit (iOS)
    │
    ├─► Heart Rate (72 bpm) ──────┐
    ├─► HRV (45ms) ────────────────┤
    └─► Breath Rate (16 bpm) ──────┤
                                   │
Microphone (iOS)                   │
    │                              │
    └─► Pitch (220 Hz, 0.85) ─────┤
                                   │
                                   ▼
                         OSC Message Encoding
                                   │
                                   ▼
                         UDP Packet (Port 8000)
                                   │
                                   ▼
                         Desktop OSC Server
                                   │
                                   ▼
                         Parameter Mapping
                         • HR → Tempo/Rhythm
                         • HRV → Reverb/Space
                         • Breath → Filter Cutoff
                         • Pitch → Harmony/Melody
                                   │
                                   ▼
                         Audio Engine Parameters
                                   │
                                   ▼
                         Synthesis + Effects
                                   │
                                   ▼
                         Audio Output (Speakers)
```

### 2. Audio Analysis → Visualization

```
Desktop Audio Engine
    │
    ├─► RMS Level (-12 dB) ────────┐
    ├─► Peak Level (-6 dB) ─────────┤
    └─► Spectrum (8 bands) ─────────┤
                                    │
                                    ▼
                          OSC Message Encoding
                                    │
                                    ▼
                          UDP Packet (Port 8001)
                                    │
                                    ▼
                          iOS OSC Client
                                    │
                                    ▼
                          Visualization Renderer
                          • Cymatics (Amplitude)
                          • Spectrum (Frequency)
                          • Mandala (Geometry)
                                    │
                                    ▼
                          Metal Shaders (GPU)
                                    │
                                    ▼
                          Screen Display
```

---

## Component Details

### iOS App Architecture

#### 1. Biofeedback Layer

**HealthKitManager.swift**:
```swift
class HealthKitManager {
    // Permissions
    func requestAuthorization()

    // Real-time queries
    func startHeartRateMonitoring()
    func startHRVMonitoring()
    func startBreathRateMonitoring()

    // Callbacks
    var onHeartRateUpdate: ((Double) -> Void)?
    var onHRVUpdate: ((Double) -> Void)?
}
```

**MicrophoneManager.swift**:
```swift
class MicrophoneManager {
    // Audio input
    func startRecording()

    // Pitch detection (YIN algorithm)
    func detectPitch() -> (frequency: Float, confidence: Float)

    // Amplitude tracking
    func getAmplitude() -> Float
}
```

#### 2. OSC Client Layer

**OSCManager.swift**:
```swift
class OSCManager {
    // Connection
    func connect(to host: String, port: UInt16)
    func disconnect()

    // Send biofeedback
    func sendHeartRate(_ bpm: Float)
    func sendHRV(_ ms: Float)
    func sendPitch(frequency: Float, confidence: Float)

    // Receive analysis
    func onAnalysisReceived: ((RMS, Peak, Spectrum) -> Void)?
}
```

#### 3. Visualization Layer

**CymaticsRenderer.swift** (Metal):
- Amplitude → Vertex Displacement
- Frequency → Wave Pattern
- 60 FPS rendering

**VisualizationMode.swift**:
- Scene management
- Mode switching (Cymatics, Mandala, Spectrum)
- Parameter interpolation

#### 4. Spatial Audio

**SpatialAudioEngine.swift**:
- ARKit Face Tracking → Head Position
- Hand Tracking → Gesture Control
- AVAudioEngine Spatial Mixer

---

### Desktop Engine Architecture

#### 1. OSC Server Layer

**OSCManager.h/cpp**:
```cpp
class OSCManager : public OSCReceiver {
    // Callbacks für Biofeedback
    std::function<void(float)> onHeartRateReceived;
    std::function<void(float)> onHRVReceived;
    std::function<void(float, float)> onPitchReceived;

    // Send analysis
    void sendAudioAnalysis(float rms, float peak);
    void sendSpectrum(const std::vector<float>&);
};
```

#### 2. Parameter Mapping Engine

**BioParameterMapper.cpp**:
```cpp
class BioParameterMapper {
    // Mappings
    float mapHeartRateToTempo(float bpm);
    float mapHRVToReverb(float hrv);
    float mapBreathToFilterCutoff(float rate);
    float mapPitchToHarmony(float freq);

    // Smoothing (exponential moving average)
    float smooth(float newValue, float oldValue, float alpha);
};
```

#### 3. Audio Processing Pipeline

```
Audio Input (optional)
    │
    ▼
┌─────────────────────────┐
│   Biofeedback Synth     │
│   • Oscillators         │
│   • Granular Engine     │
│   • Sampler             │
└─────────────────────────┘
    │
    ▼
┌─────────────────────────┐
│   Effects Chain         │
│   • Reverb              │
│   • Delay               │
│   • Filter              │
│   • Distortion          │
└─────────────────────────┘
    │
    ▼
┌─────────────────────────┐
│   Spatial Processor     │
│   • Dolby Atmos         │
│   • Ambisonics          │
│   • Binaural            │
└─────────────────────────┘
    │
    ▼
┌─────────────────────────┐
│   Analysis              │
│   • RMS/Peak            │
│   • FFT Spectrum        │
│   • CPU Monitoring      │
└─────────────────────────┘
    │
    ├─► Audio Output (CoreAudio/ASIO)
    └─► OSC Messages (to iOS)
```

#### 4. Synthesis Engine

**EchoelSynth.cpp**:
```cpp
class EchoelSynth {
    // Oscillators
    std::vector<Oscillator> oscillators;

    // Granular
    GranularEngine granular;

    // Process
    void processBlock(AudioBuffer<float>& buffer) {
        // Apply biofeedback parameters
        // Generate audio
    }
};
```

---

## OSC Bridge Implementation

### Connection Setup

**1. Discovery (Optional - Bonjour)**:
```
Desktop publishes: _echoel._udp.local (Port 8000)
iOS discovers: NSNetServiceBrowser
iOS connects to discovered IP
```

**2. Manual Connection**:
```
User enters Desktop IP in iOS app
iOS creates UDP connection to IP:8000
```

### Message Flow

**High-Frequency Messages** (60 Hz):
- `/echoel/audio/pitch`
- `/echoel/audio/amplitude`

**Medium-Frequency Messages** (30 Hz):
- `/echoel/analysis/rms`
- `/echoel/analysis/spectrum`

**Low-Frequency Messages** (1 Hz):
- `/echoel/bio/heartrate`
- `/echoel/bio/hrv`
- `/echoel/status/cpu`

### Latency Optimization

**Target: < 10ms Total Latency**

| Stage                     | Latency | Optimization                      |
|---------------------------|---------|-----------------------------------|
| Biofeedback Sensing       | 1-2 ms  | Direct API access                 |
| OSC Encoding (iOS)        | < 1 ms  | Preallocated buffers              |
| UDP Transmission          | 1-3 ms  | Local network                     |
| OSC Decoding (Desktop)    | < 1 ms  | Optimized parser                  |
| Parameter Mapping         | < 1 ms  | Lock-free queues                  |
| Audio Processing          | 3-5 ms  | Low buffer size (256 samples)     |
| **Total**                 | **6-13 ms** | Acceptable for real-time      |

**Strategies**:
- Use lock-free queues für Inter-Thread-Communication
- Avoid memory allocation im Audio-Thread
- UDP statt TCP (keine Bestätigungen)
- Minimize OSC message size

---

## Biofeedback → Audio Mapping Strategies

### 1. Heart Rate → Tempo/Energy

```cpp
// Linear mapping
float tempo = map(heartRate, 40.0f, 200.0f, 60.0f, 180.0f);

// Energy modulation
float energy = map(heartRate, 60.0f, 100.0f, 0.0f, 1.0f);
oscillatorGain *= energy;
```

### 2. HRV → Spatial Dimension

```cpp
// High HRV = relaxed = mehr Reverb/Space
float reverbAmount = map(hrv, 0.0f, 100.0f, 0.1f, 0.9f);

// Spatial width
float spatialSpread = map(hrv, 0.0f, 100.0f, 0.0f, 1.0f);
```

### 3. Breath Rate → Filter Modulation

```cpp
// Breath rate als LFO für Filter cutoff
float breathLFO = sin(breathRate * 2.0f * M_PI * time);
float cutoff = baseFreq + (breathLFO * modulationDepth);
filter.setCutoff(cutoff);
```

### 4. Voice Pitch → Harmonic Content

```cpp
// Quantize pitch to musical scale
float quantizedPitch = quantizeToScale(detectedPitch, Scale::Minor);

// Use as base frequency
oscillator.setFrequency(quantizedPitch);

// Generate harmonics
for (int i = 1; i <= 5; ++i) {
    harmonicOsc[i].setFrequency(quantizedPitch * i);
}
```

---

## Threading Model

### iOS App

```
Main Thread (60 Hz)
    │
    ├─► UI Updates (SwiftUI)
    └─► Visualization Rendering (Metal)

Background Queue (Concurrent)
    │
    ├─► HealthKit Queries
    ├─► OSC Message Sending
    └─► Network Management

Audio Queue (High Priority)
    │
    └─► Microphone Processing
        └─► Pitch Detection
```

### Desktop Engine

```
Main Thread (60 Hz)
    │
    └─► UI Updates (JUCE Components)

OSC Thread
    │
    ├─► OSC Message Receiving
    └─► Parameter Updates (via lock-free queue)

Audio Thread (Real-Time)
    │
    ├─► Read Parameters from queue
    ├─► Synthesis
    ├─► Effects Processing
    └─► Audio Output

Analysis Thread (30 Hz)
    │
    ├─► FFT Spectrum Analysis
    ├─► RMS/Peak Calculation
    └─► OSC Messages to iOS
```

**Critical**: Audio Thread darf NIEMALS blocken!
- Keine Locks
- Keine Memory Allocation
- Keine I/O Operations
- Use lock-free queues für Parameter-Updates

---

## State Management

### iOS App State

```swift
class AppState: ObservableObject {
    // Connection
    @Published var oscConnected: Bool = false
    @Published var desktopIP: String = ""

    // Biofeedback
    @Published var currentHeartRate: Double = 0
    @Published var currentHRV: Double = 0
    @Published var currentPitch: Float = 0

    // Analysis (from Desktop)
    @Published var audioRMS: Float = -80
    @Published var audioSpectrum: [Float] = Array(repeating: -80, count: 8)

    // Scene
    @Published var currentScene: SceneType = .ambient
}
```

### Desktop Engine State

```cpp
struct EngineState {
    // Connection
    bool oscConnected = false;
    std::string clientIP;

    // Biofeedback (latest values)
    std::atomic<float> heartRate{0.0f};
    std::atomic<float> hrv{0.0f};
    std::atomic<float> pitchFreq{0.0f};

    // Audio
    std::atomic<float> masterGain{0.8f};
    std::atomic<int> currentScene{0};

    // Performance
    std::atomic<float> cpuLoad{0.0f};
};
```

---

## Error Handling & Resilience

### Network Issues

**Connection Loss Detection**:
```swift
// iOS sends ping every 2 seconds
timer.schedule(every: 2.0) {
    oscManager.sendPing(timestamp: Date().timeIntervalSince1970)
}

// If no pong received within 5 seconds → disconnect
if Date().timeIntervalSince1970 - lastPongTime > 5.0 {
    oscManager.disconnect()
}
```

**Auto-Reconnect**:
```swift
func attemptReconnect() {
    reconnectAttempts += 1
    let delay = min(reconnectAttempts * 2, 30) // Exponential backoff, max 30s

    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        oscManager.connect(to: lastKnownIP)
    }
}
```

### Audio Dropouts

**Desktop Buffer Underrun Prevention**:
```cpp
if (audioBuffer.isEmpty()) {
    // Fill with silence instead of crashing
    audioBuffer.clear();
    logWarning("Buffer underrun detected");
    cpuOverloadCount++;
}
```

### Invalid Data

**Range Clamping**:
```cpp
float safeHeartRate = std::clamp(receivedHR, 40.0f, 200.0f);
float safeHRV = std::clamp(receivedHRV, 0.0f, 200.0f);
```

---

## Performance Optimization

### iOS

1. **Minimize OSC sending rate**:
   - Pitch: 60 Hz (necessary for responsiveness)
   - Heart Rate: 1 Hz (sufficient)

2. **Metal rendering**:
   - Use instanced rendering
   - Precompute static geometry
   - LOD based on device performance

3. **HealthKit queries**:
   - Anchor queries (nur neue Daten)
   - Background delivery

### Desktop

1. **Audio buffer size**:
   - 256 samples @ 48kHz = 5.3ms latency
   - Balance zwischen Latency und CPU load

2. **DSP optimization**:
   - Use SIMD (SSE/AVX, ARM NEON)
   - Table lookups für Oscillatoren
   - Efficient filter implementations

3. **FFT**:
   - Use Accelerate (macOS) oder IPP (Windows)
   - Power-of-2 sizes (2048, 4096)
   - Window functions (Hann, Blackman)

---

## Security Considerations

### Network

- OSC über lokales WLAN nur
- Optional: OSC über VPN für remote sessions
- No encryption in v1.0 (future: OSC over TLS)

### HealthKit

- User muss explicit permissions geben
- Daten werden nicht gespeichert/geloggt
- Privacy-compliant

---

## Future Architecture Extensions

### 1. Multi-Client Support

Desktop kann mehrere iOS Clients bedienen:
```
iOS Client 1 ──┐
iOS Client 2 ──┤──► Desktop Engine ──► Mixed Audio
iOS Client 3 ──┘
```

### 2. Cloud Synchronization

Session recording → Cloud storage → Playback

### 3. WebRTC Integration

Browser-based remote collaboration:
```
iOS App ──► WebRTC ──► Browser Client (anywhere)
```

### 4. Machine Learning

ML models für adaptive parameter mapping:
```
Biofeedback History ──► ML Model ──► Optimized Mappings
```

---

## Conclusion

Die Echoelmusic-Architektur ist designed für:
- **Low Latency** (< 10ms)
- **Real-time Responsiveness**
- **Robustness** (error handling, reconnection)
- **Extensibility** (modulare Struktur)

Die OSC Bridge ist das Herzstück und ermöglicht die Entkopplung von iOS Sensing und Desktop Processing, was flexible Entwicklung und Testing ermöglicht.

---

**Next Steps**:
1. Implement OSC Templates (siehe osc-protocol.md)
2. Build Desktop Audio Engine MVP
3. Integrate LED control (UDP socket)
4. Performance testing & optimization

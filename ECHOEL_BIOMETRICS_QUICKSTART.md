# EchoelBiometrics™ Quick Start Guide

**Transform physiological data into musical expression in 5 minutes**

## 🚀 Quick Start (iOS)

### 1. Minimal Setup

```swift
import Echoelmusic

// Start all biometric systems
EchoelFlowManager.shared.start()

// Subscribe to unified data stream
EchoelFlowManager.shared.subscribeToBioData()
    .sink { bioData in
        print("❤️ Heart Rate: \(bioData.heartRate) BPM")
        print("🧠 Meditation: \(bioData.meditation)/100")
        print("👁️ Gaze: (\(bioData.gazePosition.x), \(bioData.gazePosition.y))")
    }
    .store(in: &cancellables)
```

**That's it!** You now have access to:
- Eye tracking (via ARKit)
- Heart rate & HRV (via HealthKit)
- Sleep & recovery (via Oura API)
- Neural states (via Muse EEG)

---

## 🎵 Map Biometrics to Audio

### Option A: Auto-Mapping (Recommended)

```swift
// Get pre-configured audio parameters
let audioParams = EchoelFlowManager.shared.mapToAudioParameters()

// Apply to your audio engine
audioEngine.setParameters(audioParams)
// Returns: filterCutoff, reverbSize, stereoPan, tempo, etc.
```

### Option B: Manual Mapping

```swift
let bioData = EchoelFlowManager.shared.getCurrentBioData()

// Eye gaze → Stereo pan
let pan = bioData.gazePosition.x * 2.0 - 1.0  // -1 to 1

// HRV → Filter cutoff
let cutoff = 200 + (bioData.hrvRMSSD * 180)  // 200-18200 Hz

// Coherence → Reverb amount
let reverb = bioData.coherence / 100.0  // 0-1

// Heart rate → Tempo
let tempo = bioData.heartRate  // BPM
```

---

## 🧘 Neurofeedback Training

Train specific brain states through audio rewards:

```swift
// Train meditation (alpha waves) for 10 minutes
EchoelMindManager.shared.startNeurofeedbackTraining(
    target: .meditation,
    duration: 600  // seconds
)

// Get audio feedback (rewards desired brain state)
let params = EchoelMindManager.shared.getNeurofeedbackAudioParams()
audioEngine.setParameters(params)
```

**Supported brain states:**
- `.meditation` - Alpha waves (relaxation)
- `.deepFocus` - Beta waves (concentration)
- `.creativeInsight` - Theta waves (creativity)
- `.peakPerformance` - Gamma waves (flow)

---

## 👥 Group Coherence

Sync music to group heart coherence:

```swift
// Add participants
groupSync.addParticipant("Alice", data: aliceBioData)
groupSync.addParticipant("Bob", data: bobBioData)

// Get group coherence score (0-100)
let coherence = groupSync.getGroupCoherence()
print("💓 Group coherence: \(coherence)/100")

// Get optimal tempo for group
let groupTempo = groupSync.getOptimalTempo()
audioEngine.setTempo(groupTempo)
```

**Use cases:**
- Meditation groups
- Therapy sessions
- Collaborative music creation
- Live performances (audience sync)

---

## 🌅 Circadian Optimization

Adapt audio to user's circadian rhythm:

```swift
// Configure Oura Ring
EchoelRingManager.shared.configure(accessToken: "YOUR_TOKEN")

// Fetch today's sleep data
EchoelRingManager.shared.fetchTodaysData()

// Get current circadian phase
let phase = EchoelRingManager.shared.getCurrentCircadianPhase()
// Returns: .morning, .midday, .afternoon, .evening, .night

// Get optimized audio parameters
let params = EchoelRingManager.shared.getCircadianAudioParameters()
audioEngine.setParameters(params)
```

**What it does:**
- Morning: Energizing, bright tones
- Midday: Focused, clear mix
- Afternoon: Creative, experimental
- Evening: Relaxing, warm tones
- Night: Minimal, ambient

---

## 🎯 Individual Systems

### EchoelVision™ (Eye Tracking)

```swift
// Start eye tracking
EchoelVisionManager.shared.startTracking()

// Get current eye metrics
let metrics = EchoelVisionManager.shared.getCurrentMetrics()
print("👁️ Gaze: \(metrics.gazeX), \(metrics.gazeY)")
print("👁️ Pupil: \(metrics.pupilDiameter) mm")
print("👁️ Cognitive load: \(metrics.cognitiveLoad)/100")

// Get cognitive state
let state = device.getCognitiveState()
// Returns: .deepFocus, .distracted, .fatigued, etc.
```

### EchoelMind™ (EEG)

```swift
// Connect to Muse headband
EchoelMindManager.shared.connectMuse()
EchoelMindManager.shared.startMonitoring()

// Get neural metrics
let metrics = EchoelMindManager.shared.getCurrentMetrics()
print("🧠 Alpha: \(metrics.bands.alpha * 100)%")
print("🧠 Beta: \(metrics.bands.beta * 100)%")
print("🧠 Meditation: \(metrics.meditation)/100")
print("🧠 Attention: \(metrics.attention)/100")

// Get neural state
print("🧠 State: \(metrics.state.rawValue)")
// Returns: .deepFocus, .flowState, .meditation, etc.
```

### EchoelRing™ (Oura)

```swift
// Configure with API token
EchoelRingManager.shared.configure(accessToken: "YOUR_TOKEN")

// Fetch today's data
EchoelRingManager.shared.fetchTodaysData()

// Subscribe to sleep data
EchoelRingManager.shared.subscribeToSleepData()
    .sink { sleepData in
        print("💤 Sleep score: \(sleepData.sleepScore)/100")
        print("💤 Deep sleep: \(sleepData.deepSleepMinutes) min")
        print("💤 REM sleep: \(sleepData.remSleepMinutes) min")
    }
    .store(in: &cancellables)

// Subscribe to readiness data
EchoelRingManager.shared.subscribeToReadinessData()
    .sink { readinessData in
        print("⚡ Readiness: \(readinessData.readinessScore)/100")
        print("❤️ Resting HR: \(readinessData.restingHeartRate) BPM")
    }
    .store(in: &cancellables)
```

---

## 🔬 ULTRATHINK Integration

### Feature Flags

```swift
import EchoelBiometrics

// Enable specific features
BiometricFeatureFlags.enable(.eyeTracking)
BiometricFeatureFlags.enable(.eegMonitoring)
BiometricFeatureFlags.enable(.ouraIntegration)

// Check if enabled
if BiometricFeatureFlags.isEnabled(.eyeTracking) {
    startEyeTracking()
}

// Disable for debugging
BiometricFeatureFlags.disable(.neurofeedbackTraining)
```

### Performance Profiling

```swift
let ultrathink = EchoelBiometricsULTRATHINK()

// Start profiling
ultrathink.startPerformanceProfiling()

// Check performance
let metrics = ultrathink.getPerformanceMetrics()
print("CPU Usage: \(metrics.cpuUsagePercent)%")
print("Latency: \(metrics.latencyMs) ms")

// Ensure < 5% CPU overhead
if ultrathink.isPerformanceAcceptable() {
    print("✅ Performance is acceptable")
}
```

### DAW Export

```swift
let dawExporter = ultrathink.getDAWExporter()

// Export HRV as MIDI CC
dawExporter.exportHRVasMIDICC(ccNumber: 74)  // CC 74 = Filter cutoff

// Export EEG as automation lanes
dawExporter.exportEEGasAutomation()

// Export eye gaze as XY controller
dawExporter.exportGazeAsXYPad()
```

### Lighting Control

```swift
let lighting = ultrathink.getLightingController()

// Sync Philips Hue to heart rate
lighting.syncHueToHeartRate(heartRate: 70.0)  // 60-120 BPM → warm-cool

// Sync DMX to HRV coherence
lighting.syncDMXtoCoherence(coherence: 80.0)  // 0-100 → brightness

// Sync WLED to neural state
lighting.syncWLEDtoNeuralState(state: .peakPerformance)
```

---

## 💡 Wellness Insights

Get AI-driven wellness recommendations:

```swift
let insights = EchoelFlowManager.shared.getWellnessInsights()

for insight in insights {
    print("💡 \(insight)")
}

// Example output:
// 💡 Low sleep score (58). Consider earlier bedtime.
// 💡 High stress detected. Try breathing exercises.
// 💡 Excellent coherence! You're in the zone.
```

---

## 📊 Export Session Data

Export biometric session as JSON:

```swift
let jsonData = EchoelFlowManager.shared.exportAsJSON()

// Save to file
try? jsonData?.write(to: fileURL, atomically: true, encoding: .utf8)

// Send to research database (anonymized)
uploadToResearchDB(jsonData)
```

**JSON structure:**
```json
{
  "timestamp": 1731916800000000,
  "state": "Peak Performance",
  "vision": {
    "gaze_x": 0.5,
    "gaze_y": 0.3,
    "pupil_diameter": 4.5,
    "focus_level": 75
  },
  "neural": {
    "alpha": 60,
    "beta": 70,
    "gamma": 80,
    "meditation": 65
  },
  "cardiac": {
    "heart_rate": 72,
    "hrv_rmssd": 55,
    "coherence": 82
  },
  "sleep": {
    "sleep_score": 85,
    "readiness_score": 88
  }
}
```

---

## 🔧 Advanced Configuration

### Custom Biometric Mapping

```swift
// Create custom audio mapping
func customMapping(_ bioData: EchoelBioData) -> [String: Float] {
    return [
        "custom_filter": bioData.alpha / 100.0 * 8000,
        "custom_reverb": bioData.coherence / 100.0,
        "custom_tempo": bioData.heartRate * 1.5,  // 1.5x HR
        "custom_pan": (bioData.gazePosition.x - 0.5) * 2.0
    ]
}

let params = customMapping(bioData)
audioEngine.setParameters(params)
```

### Circadian Phase Sync (Remote Collaboration)

```swift
// Sync collaborators across time zones by circadian phase
let circadianSync = CircadianPhaseSync()

// Add users with their wake times
circadianSync.addUser(CircadianProfile(
    userID: "Alice",
    wakeTimestamp: aliceWakeTime,
    sleepScore: 85.0
))

circadianSync.addUser(CircadianProfile(
    userID: "Bob",
    wakeTimestamp: bobWakeTime,
    sleepScore: 78.0
))

// Find optimal collaboration window
let window = circadianSync.getOptimalCollaborationWindow()
print(window)  // "Optimal - All in creative phase"
```

---

## 🎨 Complete Example

```swift
import Echoelmusic
import Combine

class MyBiometricMusicApp {
    private var cancellables = Set<AnyCancellable>()

    func start() {
        // 1. Configure Oura Ring (optional)
        EchoelRingManager.shared.configure(accessToken: "YOUR_TOKEN")

        // 2. Start all biometric systems
        EchoelFlowManager.shared.start()

        // 3. Subscribe to unified biometric stream
        EchoelFlowManager.shared.subscribeToBioData()
            .sink { [weak self] bioData in
                self?.updateAudio(with: bioData)
            }
            .store(in: &cancellables)

        // 4. Subscribe to state changes
        EchoelFlowManager.shared.subscribeToState()
            .sink { [weak self] state in
                self?.updateVisuals(for: state)
            }
            .store(in: &cancellables)

        print("✅ Biometric music system running!")
    }

    private func updateAudio(with bioData: EchoelBioData) {
        let params = EchoelFlowManager.shared.mapToAudioParameters()

        // Apply to your audio engine
        audioEngine.filterCutoff = params["filter_cutoff"] ?? 1000
        audioEngine.reverbSize = params["reverb_size"] ?? 0.5
        audioEngine.stereoPan = params["stereo_pan"] ?? 0.0
        audioEngine.tempo = params["heart_rate_tempo"] ?? 120
    }

    private func updateVisuals(for state: PhysiologicalState) {
        let profile = state.audioProfile

        // Update UI, lighting, visuals, etc.
        ui.setEnergy(profile["energy"] ?? 0.5)
        lighting.setBrightness(profile["clarity"] ?? 0.5)
    }
}

// Run it
let app = MyBiometricMusicApp()
app.start()
```

---

## 📚 API Reference

### EchoelFlowManager (Master Coordinator)

| Method | Description | Returns |
|--------|-------------|---------|
| `start()` | Start all biometric systems | `Void` |
| `stop()` | Stop all biometric systems | `Void` |
| `subscribeToBioData()` | Subscribe to unified data stream | `AnyPublisher<EchoelBioData, Never>` |
| `subscribeToState()` | Subscribe to state changes | `AnyPublisher<PhysiologicalState, Never>` |
| `getCurrentBioData()` | Get current biometric snapshot | `EchoelBioData` |
| `getCurrentState()` | Get current physiological state | `PhysiologicalState` |
| `mapToAudioParameters()` | Get audio parameter mapping | `[String: Float]` |
| `getWellnessInsights()` | Get AI recommendations | `[String]` |
| `exportAsJSON()` | Export session as JSON | `String?` |

### EchoelVisionManager (Eye Tracking)

| Method | Description | Returns |
|--------|-------------|---------|
| `startTracking()` | Start eye tracking | `Void` |
| `stopTracking()` | Stop eye tracking | `Void` |
| `subscribeToMetrics()` | Subscribe to eye metrics | `AnyPublisher<EyeMetrics, Never>` |
| `getCurrentMetrics()` | Get current eye metrics | `EyeMetrics?` |

### EchoelMindManager (EEG)

| Method | Description | Returns |
|--------|-------------|---------|
| `connectMuse()` | Connect to Muse headband | `Void` |
| `startMonitoring()` | Start EEG monitoring | `Void` |
| `stopMonitoring()` | Stop EEG monitoring | `Void` |
| `subscribeToMetrics()` | Subscribe to neural metrics | `AnyPublisher<NeuralMetrics, Never>` |
| `getCurrentMetrics()` | Get current neural metrics | `NeuralMetrics?` |
| `startNeurofeedbackTraining(target:duration:)` | Start training session | `Void` |
| `getNeurofeedbackAudioParams()` | Get training audio params | `[String: Float]` |

### EchoelRingManager (Oura)

| Method | Description | Returns |
|--------|-------------|---------|
| `configure(accessToken:)` | Configure Oura API | `Void` |
| `fetchTodaysData()` | Fetch today's wellness data | `Void` |
| `subscribeToSleepData()` | Subscribe to sleep data | `AnyPublisher<OuraSleepData, Never>` |
| `subscribeToReadinessData()` | Subscribe to readiness | `AnyPublisher<OuraReadinessData, Never>` |
| `getCurrentCircadianPhase()` | Get circadian phase | `CircadianPhase` |
| `getCircadianAudioParameters()` | Get phase-optimized audio | `[String: Float]` |

---

## 🔐 Privacy & Security

**All biometric data is:**
- ✅ Processed on-device by default
- ✅ Encrypted with AES-256 (if stored)
- ✅ Never sent to cloud without explicit consent
- ✅ Anonymized before any analytics
- ✅ HIPAA & GDPR compliant

**User control:**
- Users can disable any sensor
- Data can be exported or deleted anytime
- No mandatory cloud services

---

## 🎓 Learning Resources

1. **Architecture Overview**: `ECHOEL_BIOMETRICS_ARCHITECTURE.md`
2. **Full Example**: `Sources/Examples/BiometricIntegrationExample.swift`
3. **ULTRATHINK Integration**: `HIGHCLASS_SUMMARY.md`
4. **API Documentation**: (Auto-generated from source)

---

## 🐛 Troubleshooting

### ARKit eye tracking not working
- Ensure device has TrueDepth camera (Face ID)
- Check camera permissions in Settings
- Test on iPhone X or newer

### Muse connection failing
- Ensure Bluetooth is enabled
- Pair Muse in iOS Settings first
- Check battery level on headband

### Oura API returning errors
- Verify access token is valid
- Check internet connection
- Ensure token has required scopes

### High CPU usage
- Reduce update frequency: `EchoelFlowManager.shared.updateInterval = 1.0/15.0` (15 Hz)
- Disable unused features: `BiometricFeatureFlags.disable(.eyeTracking)`
- Check performance: `ultrathink.getPerformanceMetrics()`

---

## 🚀 Next Steps

1. **Try the examples**: Run `BiometricIntegrationExample.swift`
2. **Customize mappings**: Create your own biometric → audio mappings
3. **Integrate with your app**: Add to existing music/wellness app
4. **Contribute**: Submit PRs with new biometric devices
5. **Research**: Use for scientific studies (all data exportable)

---

**Built with ❤️ by the Echoel Development Team**

*Every heartbeat is a kick drum. Every breath is a bassline. Every thought is a melody.*

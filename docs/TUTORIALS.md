# Echoelmusic Tutorials

## Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 17.0+ / macOS 14.0+ / visionOS 1.0+
- Apple Watch (recommended for biofeedback)
- Swift 5.9+

### Installation

```bash
# Clone the repository
git clone https://github.com/vibrationalforce/Echoelmusic.git
cd Echoelmusic

# Open in Xcode
open Package.swift
```

### Project Structure

```
Echoelmusic/
├── Sources/Echoelmusic/
│   ├── Audio/           # Audio generation
│   ├── Autopilot/       # Biofeedback control
│   ├── Biofeedback/     # Sensor integration
│   ├── Control/         # Vehicle systems
│   ├── Synthesis/       # Sound synthesis
│   └── Visual/          # Visualizations
└── Tests/               # Test suite
```

---

## Tutorial 1: Your First Binaural Beat Session

Create a simple meditation app with binaural beats.

### Step 1: Import and Initialize

```swift
import Echoelmusic

class MeditationViewController: UIViewController {
    let generator = BinauralBeatGenerator()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudio()
    }

    func setupAudio() {
        // Configure for theta meditation (6 Hz)
        generator.baseFrequency = 200.0
        generator.beatFrequency = 6.0
        generator.volume = 0.7
    }
}
```

### Step 2: Add Playback Controls

```swift
@IBAction func startMeditation(_ sender: UIButton) {
    generator.start()
    sender.setTitle("Stop", for: .normal)
}

@IBAction func stopMeditation(_ sender: UIButton) {
    generator.stop()
    sender.setTitle("Start", for: .normal)
}
```

### Step 3: Add Frequency Selection

```swift
enum MeditationMode: Double {
    case deepSleep = 2.0      // Delta
    case meditation = 6.0      // Theta
    case relaxation = 10.0     // Alpha
    case focus = 18.0          // Beta
}

func setMode(_ mode: MeditationMode) {
    generator.setBeatFrequency(mode.rawValue)
}
```

### Complete Example

```swift
import SwiftUI
import Echoelmusic

struct MeditationView: View {
    @StateObject private var viewModel = MeditationViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Binaural Meditation")
                .font(.largeTitle)

            Picker("Mode", selection: $viewModel.mode) {
                Text("Sleep").tag(MeditationMode.deepSleep)
                Text("Meditate").tag(MeditationMode.meditation)
                Text("Relax").tag(MeditationMode.relaxation)
                Text("Focus").tag(MeditationMode.focus)
            }
            .pickerStyle(.segmented)

            Button(viewModel.isPlaying ? "Stop" : "Start") {
                viewModel.togglePlayback()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

class MeditationViewModel: ObservableObject {
    private let generator = BinauralBeatGenerator()

    @Published var isPlaying = false
    @Published var mode: MeditationMode = .meditation {
        didSet { generator.setBeatFrequency(mode.rawValue) }
    }

    func togglePlayback() {
        if isPlaying {
            generator.stop()
        } else {
            generator.start()
        }
        isPlaying.toggle()
    }
}
```

---

## Tutorial 2: Isochronic Tones with Effects

Create immersive audio with the EFx modeling chain.

### Step 1: Basic Setup

```swift
import Echoelmusic

let isoGenerator = IsochronicToneGenerator()

// Configure base parameters
isoGenerator.configure(IsochronicConfiguration(
    baseFrequency: 432.0,      // A=432 Hz tuning
    pulseRate: 10.0,           // Alpha entrainment
    waveform: .harmonic,       // Rich sound
    pulseShape: .gaussian,     // Soft pulses
    dutyCycle: 0.5             // 50% on/off
))
```

### Step 2: Enable Effects Chain

```swift
// Enable the EFx modeling chain
isoGenerator.effectsEnabled = true

// Effects are automatically configured:
// 1. SoftCompressor - Smooths dynamics
// 2. HarmonicEnhancer - Adds warmth
// 3. SpatialWidener - Stereo expansion
// 4. ResonanceFilter - Frequency shaping
```

### Step 3: Use Scientific Presets

```swift
// Apply research-backed presets
isoGenerator.applyPreset(.thetaMeditation)  // 6 Hz - Deep meditation
isoGenerator.applyPreset(.gammaInsight)     // 40 Hz - Cognitive boost
isoGenerator.applyPreset(.schumann)         // 7.83 Hz - Earth resonance
```

### Step 4: Custom Configuration

```swift
// Create custom configuration
let customConfig = IsochronicConfiguration(
    baseFrequency: 528.0,      // "Healing" frequency
    pulseRate: 7.83,           // Schumann resonance
    waveform: .sine,           // Pure tone
    pulseShape: .smooth,       // Gentle pulsing
    dutyCycle: 0.6             // Longer on-time
)

isoGenerator.configure(customConfig)
isoGenerator.start()
```

---

## Tutorial 3: Biofeedback-Driven Audio

Connect your Apple Watch for adaptive audio.

### Step 1: Request HealthKit Access

```swift
import HealthKit
import Echoelmusic

class BiofeedbackSession {
    let healthKit = HealthKitManager()
    let autopilot = AutopilotSystem()

    func requestAccess() async throws {
        try await healthKit.requestAuthorization()
    }
}
```

### Step 2: Start Biometric Streaming

```swift
func startSession(mode: AutopilotMode) {
    // Start the autopilot
    autopilot.start(mode: mode)

    // Stream heart rate data
    healthKit.startHeartRateStreaming { [weak self] dataPoint in
        self?.autopilot.feedBiometrics(dataPoint)
    }
}
```

### Step 3: Respond to State Changes

```swift
func setupCallbacks() {
    autopilot.onStateChange = { state in
        print("Current state: \(state.detectedState)")
        print("Target frequency: \(state.targetFrequency) Hz")
        print("Audio adapting: \(state.isAdapting)")
    }

    autopilot.onCoherenceChange = { coherence in
        if coherence > 0.8 {
            print("High coherence achieved!")
        }
    }
}
```

### Complete SwiftUI Example

```swift
import SwiftUI
import Echoelmusic

struct BiofeedbackView: View {
    @StateObject private var session = BiofeedbackViewModel()

    var body: some View {
        VStack {
            // Biometric display
            HStack {
                MetricCard(title: "Heart Rate",
                          value: "\(Int(session.heartRate))",
                          unit: "BPM")
                MetricCard(title: "HRV",
                          value: "\(Int(session.hrv))",
                          unit: "ms")
                MetricCard(title: "Coherence",
                          value: String(format: "%.0f%%", session.coherence * 100),
                          unit: "")
            }

            // State indicator
            Text(session.currentState)
                .font(.title2)
                .foregroundColor(session.stateColor)

            // Mode picker
            Picker("Mode", selection: $session.mode) {
                ForEach(AutopilotMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }

            // Control button
            Button(session.isActive ? "End Session" : "Start Session") {
                session.toggle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

---

## Tutorial 4: Vehicle Autopilot Integration

Control autonomous vehicles with Echoelmusic.

### Step 1: Configure Vehicle

```swift
import Echoelmusic
import CoreLocation

let autopilot = VehicleAutopilot()

// Configure for electric car
autopilot.configure(VehicleConfiguration(
    type: .car,
    wheelbase: 2.7,           // meters
    trackWidth: 1.6,          // meters
    maxSpeed: 50.0,           // m/s
    maxAcceleration: 3.0,     // m/s²
    maxSteeringAngle: 35.0    // degrees
))
```

### Step 2: Set Destination

```swift
// Set navigation destination
let destination = CLLocationCoordinate2D(
    latitude: 37.7749,
    longitude: -122.4194
)

autopilot.setDestination(destination)
```

### Step 3: Enable Autonomy

```swift
// Start with conditional autonomy
autopilot.setDrivingMode(.conditionalAutonomy)

// Monitor status
autopilot.onStatusUpdate = { status in
    print("Speed: \(status.speed) m/s")
    print("Distance remaining: \(status.distanceToDestination) m")
    print("ETA: \(status.estimatedArrival)")
}

// Handle safety events
autopilot.onSafetyEvent = { event in
    switch event {
    case .obstacleDetected(let distance):
        print("Obstacle at \(distance)m - slowing down")
    case .emergencyBraking:
        print("Emergency braking activated!")
    case .driverAttentionRequired:
        print("Please take control")
    }
}
```

### Step 4: Emergency Controls

```swift
// Emergency stop
autopilot.emergencyStop()

// Return to manual control
autopilot.setDrivingMode(.manual)

// Pull over safely
autopilot.pullOver()
```

---

## Tutorial 5: Multi-Domain Vehicle Control

Control vehicles that transition between land, air, and water.

### Step 1: Initialize Controller

```swift
import Echoelmusic

let multiDomain = MultiDomainController()

// Configure for flying car
multiDomain.initialize(vehicle: VehicleCapabilities(
    supportedDomains: [.land, .air],
    transitionCapabilities: [
        DomainTransition(from: .land, to: .air),
        DomainTransition(from: .air, to: .land)
    ],
    maxAltitude: 3000,          // meters
    maxSpeed: [
        .land: 50,              // m/s on ground
        .air: 100               // m/s in flight
    ]
))
```

### Step 2: Monitor Current State

```swift
multiDomain.onStateUpdate = { state in
    print("Domain: \(state.currentDomain)")
    print("Altitude: \(state.altitude)m")
    print("Speed: \(state.speed) m/s")
    print("Heading: \(state.heading)°")
}
```

### Step 3: Request Domain Transition

```swift
// Transition from land to air
multiDomain.requestTransition(to: .air) { result in
    switch result {
    case .success:
        print("Takeoff successful!")
    case .failure(let error):
        switch error {
        case .insufficientSpeed:
            print("Need more speed for takeoff")
        case .unsafeConditions:
            print("Weather or obstacles prevent takeoff")
        case .systemNotReady:
            print("Flight systems not initialized")
        }
    }
}
```

### Step 4: Handle Transitions

```swift
multiDomain.onTransitionProgress = { phase, progress in
    switch phase {
    case .preparing:
        print("Preparing for transition...")
    case .transitioning:
        print("Transitioning: \(Int(progress * 100))%")
    case .stabilizing:
        print("Stabilizing in new domain...")
    case .complete:
        print("Transition complete!")
    }
}
```

---

## Tutorial 6: Neural Interface Control

Control vehicles with your thoughts using EEG.

### Step 1: Connect Neural Device

```swift
import Echoelmusic

let neural = NeuralInterfaceLayer()

// Connect to Muse headband
Task {
    do {
        try await neural.connect(to: .eegMuse)
        print("Connected to Muse")
    } catch {
        print("Connection failed: \(error)")
    }
}
```

### Step 2: Calibration

```swift
// Start calibration session
neural.startCalibration { progress, instruction in
    print("Calibration \(Int(progress * 100))%")
    print("Instruction: \(instruction)")
    // "Think about moving left"
    // "Think about moving right"
    // "Think about stopping"
}
```

### Step 3: Read Mental State

```swift
neural.onMentalStateUpdate = { state in
    // Brainwave power
    print("Alpha: \(state.alphaPower)")  // Relaxation
    print("Beta: \(state.betaPower)")    // Focus
    print("Theta: \(state.thetaPower)")  // Meditation

    // Derived states
    print("Attention: \(state.attention)")
    print("Stress: \(state.stress)")
}
```

### Step 4: Detect Movement Intentions

```swift
neural.onIntentionDetected = { intention in
    guard intention.confidence > 0.7 else { return }

    switch intention.type {
    case .move:
        switch intention.direction {
        case .forward:
            vehicle.accelerate()
        case .left:
            vehicle.turnLeft(intensity: intention.intensity)
        case .right:
            vehicle.turnRight(intensity: intention.intensity)
        case .stop:
            vehicle.stop()
        }
    case .grab:
        robotArm.grab()
    case .release:
        robotArm.release()
    }
}
```

### Step 5: Alternative Control Methods

```swift
// Fallback to gesture control
let gesture = GestureController()
gesture.onGesture = { gesture in
    vehicle.execute(gesture.toCommand())
}

// Voice backup
let voice = VoiceController()
voice.registerCommand("stop") { vehicle.emergencyStop() }
voice.registerCommand("land") { vehicle.requestTransition(to: .land) }

// Gaze tracking
let gaze = GazeController()
gaze.onGazeDirection = { direction in
    vehicle.steer(toward: direction)
}
```

---

## Tutorial 7: Spatial Audio for visionOS

Create immersive 3D audio experiences.

### Step 1: Setup Spatial Audio

```swift
import Echoelmusic
import RealityKit

class SpatialAudioSession {
    let spatialEngine = SpatialAudioEngine()

    func setup() {
        // Enable head tracking
        spatialEngine.headTrackingEnabled = true

        // Configure room acoustics
        spatialEngine.roomModel = .mediumRoom
        spatialEngine.reverbLevel = 0.3
    }
}
```

### Step 2: Position Audio Sources

```swift
// Create positioned audio source
let meditationSource = spatialEngine.createSource(
    position: SIMD3<Float>(0, 1.5, -2),  // 2m in front
    content: binauralGenerator
)

// Create ambient sources
let leftAmbient = spatialEngine.createSource(
    position: SIMD3<Float>(-3, 1, 0),
    content: natureGenerator
)

let rightAmbient = spatialEngine.createSource(
    position: SIMD3<Float>(3, 1, 0),
    content: waterGenerator
)
```

### Step 3: Animate Sources

```swift
// Orbit source around listener
spatialEngine.animate(meditationSource) { time in
    let angle = time * 0.1  // Slow rotation
    return SIMD3<Float>(
        sin(angle) * 2,
        1.5,
        cos(angle) * 2
    )
}
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| No audio output | Check volume, headphone connection |
| HealthKit denied | Go to Settings > Privacy > Health |
| Bluetooth not connecting | Restart Bluetooth, re-pair device |
| High CPU usage | Reduce effect chain, lower quality |
| Calibration failing | Ensure quiet environment, follow prompts |

### Debug Mode

```swift
// Enable debug logging
Echoelmusic.debugMode = true

// View real-time metrics
Echoelmusic.onDebugMetrics = { metrics in
    print("CPU: \(metrics.cpuUsage)%")
    print("Buffer: \(metrics.bufferHealth)")
    print("Latency: \(metrics.latencyMs)ms")
}
```

---

## Next Steps

- Read the [API Reference](API_REFERENCE.md) for detailed documentation
- Explore [Scientific Basis](SCIENTIFIC_BASIS.md) for research references
- Join our [Discord Community](https://discord.gg/echoelmusic) for support

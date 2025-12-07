# Echoelmusic API Reference

## Table of Contents

1. [Audio Module](#audio-module)
2. [Autopilot System](#autopilot-system)
3. [Biofeedback Integration](#biofeedback-integration)
4. [Vehicle Control](#vehicle-control)
5. [Neural Interfaces](#neural-interfaces)
6. [Synthesis Engine](#synthesis-engine)

---

## Audio Module

### BinauralBeatGenerator

Generates binaural beats for brainwave entrainment.

```swift
import Echoelmusic

// Initialize generator
let generator = BinauralBeatGenerator()

// Configure frequencies
generator.baseFrequency = 200.0      // Hz (carrier frequency)
generator.beatFrequency = 10.0       // Hz (entrainment target)

// Start/Stop
generator.start()
generator.stop()

// Real-time adjustment
generator.setBeatFrequency(7.83)     // Schumann resonance
```

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `baseFrequency` | `Double` | 200.0 | Carrier frequency in Hz (100-500) |
| `beatFrequency` | `Double` | 10.0 | Target brainwave frequency (0.5-100) |
| `volume` | `Float` | 0.7 | Output volume (0.0-1.0) |
| `isPlaying` | `Bool` | false | Playback state |

---

### IsochronicToneGenerator

Creates pulsed tones for entrainment without headphones.

```swift
let isoGenerator = IsochronicToneGenerator()

// Configure
isoGenerator.configure(IsochronicConfiguration(
    baseFrequency: 432.0,
    pulseRate: 10.0,
    waveform: .harmonic,
    pulseShape: .gaussian,
    dutyCycle: 0.5
))

// Apply preset
isoGenerator.applyPreset(.alphaRelaxation)

// Enable effects chain
isoGenerator.effectsEnabled = true
```

#### Waveforms

| Waveform | Character | Best For |
|----------|-----------|----------|
| `.sine` | Pure, smooth | General meditation |
| `.triangle` | Warm, natural | Relaxation |
| `.square` | Rich, buzzy | Focus, alertness |
| `.sawtooth` | Bright, edgy | Energy, motivation |
| `.harmonic` | Complex, full | Immersive sessions |

#### Pulse Shapes

| Shape | Description | Effect |
|-------|-------------|--------|
| `.sharp` | Hard on/off | Strong entrainment |
| `.smooth` | Cosine fade | Gentle, comfortable |
| `.exponential` | Fast attack, slow decay | Natural feel |
| `.gaussian` | Bell curve | Soft, ambient |
| `.ramp` | Linear rise/fall | Progressive |

#### Scientific Presets

```swift
public enum IsochronicPreset: String, CaseIterable {
    case deltaDeepSleep      // 2 Hz - Deep sleep induction
    case thetaMeditation     // 6 Hz - Meditative state
    case alphaRelaxation     // 10 Hz - Calm alertness
    case smmr                // 10 Hz - Sensory-motor rhythm
    case lowBetaFocus        // 14 Hz - Mild focus
    case midBetaConcentration // 18 Hz - Active concentration
    case highBetaAlertness   // 22 Hz - High alertness
    case gammaInsight        // 40 Hz - Cognitive enhancement
    case schumann            // 7.83 Hz - Earth resonance
    case custom              // User-defined
}
```

---

## Autopilot System

### AutopilotSystem

Biofeedback-driven audio control system.

```swift
let autopilot = AutopilotSystem()

// Start with mode
autopilot.start(mode: .meditation)

// Feed biometrics
autopilot.feedBiometrics(BiometricDataPoint(
    heartRate: 72.0,
    hrv: 45.0,
    coherence: 0.65
))

// Get current state
let state = autopilot.currentState
print("Mode: \(state.mode)")
print("Audio adapting to: \(state.targetFrequency) Hz")
```

#### Autopilot Modes

| Mode | Target Frequency | Scientific Basis |
|------|-----------------|------------------|
| `.meditation` | Theta (4-8 Hz) | Peer-reviewed |
| `.focus` | Beta (15-25 Hz) | Peer-reviewed |
| `.sleep` | Delta (0.5-4 Hz) | Peer-reviewed |
| `.creativity` | Theta-Alpha (6-10 Hz) | Preliminary |
| `.energy` | Beta-Gamma (20-40 Hz) | Preliminary |
| `.recovery` | Alpha (8-13 Hz) | Preliminary |
| `.balanced` | Alpha (8-12 Hz) | Preliminary |
| `.custom` | User-defined | - |

### StateAnalyzer

Analyzes biometric data to detect mental states.

```swift
let analyzer = StateAnalyzer()

// Process biometrics
let result = analyzer.analyze(biometrics)

// Access detected state
print("Stress Level: \(result.stressLevel)")      // 0.0-1.0
print("Relaxation: \(result.relaxationLevel)")    // 0.0-1.0
print("Coherence: \(result.coherenceScore)")      // 0.0-1.0
print("Detected State: \(result.primaryState)")   // .stressed, .neutral, .relaxed, .flow
```

---

## Biofeedback Integration

### BiometricDataPoint

```swift
public struct BiometricDataPoint: Codable {
    public var heartRate: Double        // BPM (40-200)
    public var hrv: Double              // RMSSD in ms (0-200)
    public var coherence: Double?       // 0.0-1.0
    public var respirationRate: Double? // Breaths per minute
    public var skinConductance: Double? // Microsiemens
    public var temperature: Double?     // Celsius
    public var timestamp: Date
}
```

### HealthKitManager

Integrates with Apple HealthKit for real-time biometrics.

```swift
let healthKit = HealthKitManager()

// Request authorization
try await healthKit.requestAuthorization()

// Start streaming
healthKit.startHeartRateStreaming { dataPoint in
    autopilot.feedBiometrics(dataPoint)
}

// Query historical data
let hrvData = try await healthKit.queryHRV(
    from: Date().addingTimeInterval(-3600),
    to: Date()
)
```

---

## Vehicle Control

### VehicleAutopilot

SAE Level 4/5 autonomous vehicle control.

```swift
let vehicleAutopilot = VehicleAutopilot()

// Configure
vehicleAutopilot.configure(VehicleConfiguration(
    type: .car,
    wheelbase: 2.7,
    maxSpeed: 50.0,
    maxSteeringAngle: 35.0
))

// Set destination
vehicleAutopilot.setDestination(
    CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
)

// Enable autonomous mode
vehicleAutopilot.setDrivingMode(.highAutonomy)

// Emergency stop
vehicleAutopilot.emergencyStop()
```

#### Driving Modes (SAE Levels)

| Mode | SAE Level | Description |
|------|-----------|-------------|
| `.manual` | 0 | No automation |
| `.assistedSteering` | 1 | Steering assist only |
| `.adaptiveCruise` | 2 | Steering + speed control |
| `.conditionalAutonomy` | 3 | Full autonomy, driver backup |
| `.highAutonomy` | 4 | Full autonomy, limited scenarios |
| `.fullAutonomy` | 5 | Complete autonomy |

### MultiDomainController

Universal controller for land, air, water, and underwater vehicles.

```swift
let controller = MultiDomainController()

// Initialize for multi-domain vehicle
controller.initialize(vehicle: VehicleCapabilities(
    supportedDomains: [.land, .air, .water],
    transitionCapabilities: [
        DomainTransition(from: .land, to: .air),
        DomainTransition(from: .air, to: .water)
    ]
))

// Transition between domains
controller.requestTransition(to: .air) { result in
    switch result {
    case .success:
        print("Now airborne!")
    case .failure(let error):
        print("Transition failed: \(error)")
    }
}

// Get current domain
let domain = controller.currentDomain  // .land, .air, .water, .underwater
```

#### Vehicle Domains

| Domain | Vehicle Types | Control Axes |
|--------|--------------|--------------|
| `.land` | Cars, trucks, rovers | Throttle, steering, brake |
| `.air` | Drones, eVTOL, helicopters | Throttle, pitch, roll, yaw |
| `.water` | Boats, ships, jetskis | Throttle, rudder, trim |
| `.underwater` | ROV, submarine, AUV | Throttle, pitch, yaw, depth |
| `.space` | Spacecraft | 6-DOF thrusters |

---

## Neural Interfaces

### NeuralInterfaceLayer

Brain-computer interface for neural control.

```swift
let neural = NeuralInterfaceLayer()

// Connect to device
try await neural.connect(to: .eegMuse)

// Start calibration
neural.startCalibration { progress in
    print("Calibration: \(progress * 100)%")
}

// Get mental state
neural.onMentalStateUpdate = { state in
    print("Attention: \(state.attention)")
    print("Meditation: \(state.meditation)")
}

// Get movement intentions
neural.onIntentionDetected = { intention in
    if intention.confidence > 0.7 {
        vehicleController.execute(intention)
    }
}
```

#### Supported Interfaces

| Interface | Type | Channels | Invasive |
|-----------|------|----------|----------|
| `.neuralink` | Implant | 1024 | Yes |
| `.eegOpenBCI` | EEG | 16 | No |
| `.eegMuse` | EEG | 4 | No |
| `.eegEmotiv` | EEG | 14 | No |
| `.emg` | Muscle | 8 | No |
| `.eog` | Eye | 4 | No |
| `.fnirs` | Optical | 16 | No |

#### MentalState Structure

```swift
public struct MentalState: Codable {
    // Brainwave power (0.0-1.0)
    public var deltaPower: Double   // Deep sleep
    public var thetaPower: Double   // Meditation
    public var alphaPower: Double   // Relaxation
    public var betaPower: Double    // Focus
    public var gammaPower: Double   // Cognition

    // Derived metrics (0.0-1.0)
    public var attention: Double
    public var meditation: Double
    public var stress: Double
    public var engagement: Double
    public var drowsiness: Double
}
```

#### Alternative Control Methods

```swift
// Gesture control
let gesture = GestureController()
gesture.onGestureDetected = { gesture in
    switch gesture {
    case .swipeLeft: vehicle.turnLeft()
    case .swipeRight: vehicle.turnRight()
    case .fist: vehicle.stop()
    }
}

// Voice commands
let voice = VoiceController()
voice.registerCommand("stop") { vehicle.emergencyStop() }
voice.registerCommand("go home") { vehicle.navigateHome() }

// Gaze tracking
let gaze = GazeController()
gaze.onGazeDirection = { direction in
    vehicle.steer(toward: direction)
}
```

---

## Synthesis Engine

### Synthesizer Types

```swift
// Subtractive synthesis
let subtractive = SubtractiveSynth()
subtractive.setWaveform(.sawtooth)
subtractive.setCutoff(2000)
subtractive.setResonance(0.5)

// FM synthesis
let fm = FMSynth()
fm.setCarrierFrequency(440)
fm.setModulatorRatio(2.0)
fm.setModulationIndex(5.0)

// Wavetable synthesis
let wavetable = WavetableSynth()
wavetable.loadWavetable(.organic)
wavetable.setPosition(0.5)

// Granular synthesis
let granular = GranularSynth()
granular.loadSample(audioFile)
granular.setGrainSize(0.05)
granular.setDensity(20)

// Additive synthesis
let additive = AdditiveSynth()
additive.setPartials(harmonics)

// Physical modeling
let physical = PhysicalModelSynth()
physical.setModel(.string)
physical.excite()
```

---

## Error Handling

All async operations use Swift's modern error handling:

```swift
do {
    try await autopilot.start(mode: .meditation)
} catch AutopilotError.noHealthKitAccess {
    print("Please enable HealthKit access")
} catch AutopilotError.invalidConfiguration {
    print("Invalid configuration")
} catch {
    print("Unexpected error: \(error)")
}
```

### Common Errors

| Error | Description | Resolution |
|-------|-------------|------------|
| `noHealthKitAccess` | HealthKit not authorized | Request permissions |
| `deviceNotConnected` | Neural device offline | Check Bluetooth |
| `calibrationRequired` | BCI needs calibration | Run calibration |
| `transitionUnsafe` | Domain switch blocked | Wait for safe conditions |
| `emergencyActive` | Safety system engaged | Resolve emergency |

---

## Thread Safety

All Echoelmusic APIs are thread-safe. Callbacks are delivered on the main thread unless specified otherwise:

```swift
// Main thread callback (default)
autopilot.onStateChange = { state in
    updateUI(state)  // Safe
}

// Background queue callback
autopilot.onStateChange(queue: .global()) { state in
    processData(state)  // Background work
    DispatchQueue.main.async {
        updateUI(state)  // UI update
    }
}
```

---

## Version Compatibility

| API Version | iOS | macOS | visionOS |
|-------------|-----|-------|----------|
| 1.0 | 17.0+ | 14.0+ | 1.0+ |

---

## Support

- Documentation: [COMPLETE_GUIDE.md](../COMPLETE_GUIDE.md)
- Tutorials: [TUTORIALS.md](TUTORIALS.md)
- Issues: [GitHub Issues](https://github.com/vibrationalforce/Echoelmusic/issues)

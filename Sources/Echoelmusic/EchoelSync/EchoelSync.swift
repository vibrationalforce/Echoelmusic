//
//  EchoelSync.swift
//  Echoelmusic
//
//  Central hub for biofeedback-to-OSC pipeline
//  "Echoelmusic is the bridge, not the destination"
//
//  Architecture Philosophy:
//  - Echoelmusic captures biometric data (HealthKit, Apple Watch, BLE sensors)
//  - Converts to standardized OSC messages
//  - Routes to professional creative tools (Ableton, Resolume, TouchDesigner, etc.)
//  - Audio/Visual processing happens in external DAWs/VJing software
//

import Foundation
import Combine
import Network

// MARK: - EchoelSync Core

/// Central OSC/Biofeedback routing hub
/// Connects HealthKit → Bio Processing → OSC → External Tools
@MainActor
final class EchoelSync: ObservableObject {

    // MARK: - Singleton

    static let shared = EchoelSync()

    // MARK: - Published State

    /// Current biofeedback values (normalized 0-1)
    @Published var bioState = BioState()

    /// Connection status to OSC targets
    @Published var oscConnections: [OSCTarget: ConnectionStatus] = [:]

    /// Active data flow indicators
    @Published var isStreaming = false

    /// Last OSC message sent (for debugging)
    @Published var lastOSCMessage: String = ""

    // MARK: - OSC Configuration

    /// OSC output targets
    struct OSCTarget: Hashable {
        let name: String
        let host: String
        let port: UInt16

        static let ableton = OSCTarget(name: "Ableton Live", host: "127.0.0.1", port: 9000)
        static let resolume = OSCTarget(name: "Resolume Arena", host: "127.0.0.1", port: 7000)
        static let touchDesigner = OSCTarget(name: "TouchDesigner", host: "127.0.0.1", port: 9001)
        static let obs = OSCTarget(name: "OBS Studio", host: "127.0.0.1", port: 4455)
        static let max = OSCTarget(name: "Max/MSP", host: "127.0.0.1", port: 8000)
        static let custom = OSCTarget(name: "Custom", host: "127.0.0.1", port: 8080)
    }

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    // MARK: - OSC Address Space

    /// Standardized OSC address space for Echoelmusic
    /// All external tools should listen to these addresses
    enum OSCAddress: String {
        // Heart
        case heartBPM = "/echoelmusic/bio/heart/bpm"           // float [40-200]
        case heartHRV = "/echoelmusic/bio/heart/hrv"           // float [0-1] normalized
        case heartCoherence = "/echoelmusic/bio/heart/coherence" // float [0-1]

        // Breath
        case breathRate = "/echoelmusic/bio/breath/rate"       // float [4-30]
        case breathPhase = "/echoelmusic/bio/breath/phase"     // float [0-1] inhale→exhale
        case breathDepth = "/echoelmusic/bio/breath/depth"     // float [0-1]

        // Motion
        case motionEnergy = "/echoelmusic/bio/motion/energy"   // float [0-1]
        case motionX = "/echoelmusic/bio/motion/x"             // float [-1 to 1]
        case motionY = "/echoelmusic/bio/motion/y"             // float [-1 to 1]
        case motionZ = "/echoelmusic/bio/motion/z"             // float [-1 to 1]

        // Composite
        case overallCoherence = "/echoelmusic/bio/coherence"   // float [0-1]
        case flowState = "/echoelmusic/bio/flow"               // float [0-1]
        case arousal = "/echoelmusic/bio/arousal"              // float [0-1] calm→excited
        case valence = "/echoelmusic/bio/valence"              // float [0-1] negative→positive

        // Mapped Audio Parameters (for DAW automation)
        case audioReverbWet = "/echoelmusic/audio/reverb/wet"  // float [0-1]
        case audioFilterCutoff = "/echoelmusic/audio/filter/cutoff" // float [20-20000] Hz
        case audioTempo = "/echoelmusic/audio/tempo"           // float [40-200] BPM
        case audioAmplitude = "/echoelmusic/audio/amplitude"   // float [0-1]

        // Visual Parameters (for VJ software)
        case visualHue = "/echoelmusic/visual/hue"             // float [0-1]
        case visualSaturation = "/echoelmusic/visual/saturation" // float [0-1]
        case visualIntensity = "/echoelmusic/visual/intensity" // float [0-1]
        case visualSpeed = "/echoelmusic/visual/speed"         // float [0-1]

        // System
        case ping = "/echoelmusic/system/ping"                 // int 1 (keepalive)
        case version = "/echoelmusic/system/version"           // string "1.0.0"
    }

    // MARK: - Bio State

    /// Current biometric state (all normalized 0-1 unless noted)
    struct BioState {
        // Raw values
        var heartRate: Double = 72.0        // BPM (40-200)
        var hrvSDNN: Double = 50.0          // ms (20-100)
        var coherenceScore: Float = 0.5     // HeartMath coherence (0-1)
        var breathingRate: Float = 12.0     // breaths/min (4-30)
        var breathPhase: Float = 0.5        // 0=inhale, 1=exhale

        // Motion
        var motionEnergy: Float = 0.3       // Activity level (0-1)
        var motionVector: SIMD3<Float> = SIMD3(0, 0, 0)

        // Derived/Composite
        var flowState: Float = 0.5          // Optimal performance zone (0-1)
        var arousal: Float = 0.5            // Calm (0) to Excited (1)
        var valence: Float = 0.5            // Negative (0) to Positive (1)

        // Timestamps
        var lastUpdate: Date = Date()

        /// Normalized HRV (0-1)
        var hrvNormalized: Float {
            Float((hrvSDNN - 20.0) / 80.0).clamped(to: 0...1)
        }

        /// Normalized heart rate (0-1)
        var heartRateNormalized: Float {
            Float((heartRate - 40.0) / 160.0).clamped(to: 0...1)
        }

        /// Normalized breathing rate (0-1)
        var breathRateNormalized: Float {
            ((breathingRate - 4.0) / 26.0).clamped(to: 0...1)
        }
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var oscConnections_internal: [OSCTarget: NWConnection] = [:]
    private var streamTimer: Timer?
    private var bioParameterMapper = BioParameterMapper()

    /// Stream rate (messages per second)
    var streamRate: Double = 30.0 // 30 Hz default

    // MARK: - Initialization

    private init() {
        setupBioStateObserver()
    }

    // MARK: - Setup

    private func setupBioStateObserver() {
        // React to bio state changes
        $bioState
            .throttle(for: .milliseconds(Int(1000 / streamRate)), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] state in
                self?.broadcastBioState(state)
            }
            .store(in: &cancellables)
    }

    // MARK: - OSC Connection Management

    /// Connect to an OSC target
    func connect(to target: OSCTarget) {
        oscConnections[target] = .connecting

        let connection = NWConnection(
            host: NWEndpoint.Host(target.host),
            port: NWEndpoint.Port(rawValue: target.port)!,
            using: .udp
        )

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.oscConnections[target] = .connected
                    print("✅ OSC connected: \(target.name) (\(target.host):\(target.port))")
                case .failed(let error):
                    self?.oscConnections[target] = .error(error.localizedDescription)
                    print("❌ OSC failed: \(target.name) - \(error)")
                case .cancelled:
                    self?.oscConnections[target] = .disconnected
                default:
                    break
                }
            }
        }

        connection.start(queue: .global(qos: .userInteractive))
        oscConnections_internal[target] = connection
    }

    /// Disconnect from an OSC target
    func disconnect(from target: OSCTarget) {
        oscConnections_internal[target]?.cancel()
        oscConnections_internal.removeValue(forKey: target)
        oscConnections[target] = .disconnected
    }

    /// Disconnect all
    func disconnectAll() {
        for target in oscConnections_internal.keys {
            disconnect(from: target)
        }
    }

    // MARK: - Biofeedback Input

    /// Update from HealthKit/Apple Watch
    func updateFromHealthKit(
        heartRate: Double? = nil,
        hrvSDNN: Double? = nil,
        respiratoryRate: Double? = nil
    ) {
        if let hr = heartRate {
            bioState.heartRate = hr
        }
        if let hrv = hrvSDNN {
            bioState.hrvSDNN = hrv
        }
        if let rr = respiratoryRate {
            bioState.breathingRate = Float(rr)
        }

        // Calculate derived values
        calculateDerivedBioState()
        bioState.lastUpdate = Date()
    }

    /// Update from CoreMotion
    func updateFromMotion(energy: Float, vector: SIMD3<Float>) {
        bioState.motionEnergy = energy.clamped(to: 0...1)
        bioState.motionVector = vector
        bioState.lastUpdate = Date()
    }

    /// Update coherence from HeartMath algorithm
    func updateCoherence(_ score: Float) {
        bioState.coherenceScore = score.clamped(to: 0...1)
        calculateDerivedBioState()
    }

    /// Update breathing phase (0=inhale start, 0.5=peak inhale, 1=exhale end)
    func updateBreathPhase(_ phase: Float) {
        bioState.breathPhase = phase.clamped(to: 0...1)
    }

    // MARK: - Derived State Calculation

    private func calculateDerivedBioState() {
        // Flow state: optimal HRV + coherence + moderate heart rate
        let hrvFactor = bioState.hrvNormalized
        let coherenceFactor = bioState.coherenceScore
        let hrOptimal: Float = 1.0 - abs(bioState.heartRateNormalized - 0.4) * 2 // Optimal around 72 BPM

        bioState.flowState = (hrvFactor * 0.3 + coherenceFactor * 0.5 + hrOptimal * 0.2).clamped(to: 0...1)

        // Arousal: heart rate + motion energy
        bioState.arousal = (bioState.heartRateNormalized * 0.7 + bioState.motionEnergy * 0.3).clamped(to: 0...1)

        // Valence: coherence + HRV (higher = more positive)
        bioState.valence = (bioState.coherenceScore * 0.6 + hrvFactor * 0.4).clamped(to: 0...1)
    }

    // MARK: - OSC Broadcasting

    /// Start continuous OSC streaming
    func startStreaming(rate: Double = 30.0) {
        streamRate = rate
        isStreaming = true

        streamTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / rate, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.broadcastBioState(self.bioState)
            }
        }

        print("📡 EchoelSync streaming started at \(Int(rate)) Hz")
    }

    /// Stop OSC streaming
    func stopStreaming() {
        streamTimer?.invalidate()
        streamTimer = nil
        isStreaming = false
        print("📡 EchoelSync streaming stopped")
    }

    /// Broadcast current bio state to all connected OSC targets
    private func broadcastBioState(_ state: BioState) {
        // Heart
        sendOSC(.heartBPM, value: Float(state.heartRate))
        sendOSC(.heartHRV, value: state.hrvNormalized)
        sendOSC(.heartCoherence, value: state.coherenceScore)

        // Breath
        sendOSC(.breathRate, value: state.breathingRate)
        sendOSC(.breathPhase, value: state.breathPhase)

        // Motion
        sendOSC(.motionEnergy, value: state.motionEnergy)
        sendOSC(.motionX, value: state.motionVector.x)
        sendOSC(.motionY, value: state.motionVector.y)
        sendOSC(.motionZ, value: state.motionVector.z)

        // Composite
        sendOSC(.overallCoherence, value: state.coherenceScore)
        sendOSC(.flowState, value: state.flowState)
        sendOSC(.arousal, value: state.arousal)
        sendOSC(.valence, value: state.valence)

        // Map to audio parameters
        let audioParams = bioParameterMapper.mapBioToAudio(state)
        sendOSC(.audioReverbWet, value: audioParams.reverbWet)
        sendOSC(.audioFilterCutoff, value: audioParams.filterCutoff)
        sendOSC(.audioTempo, value: audioParams.tempo)
        sendOSC(.audioAmplitude, value: audioParams.amplitude)

        // Visual parameters
        let visualParams = bioParameterMapper.mapBioToVisual(state)
        sendOSC(.visualHue, value: visualParams.hue)
        sendOSC(.visualSaturation, value: visualParams.saturation)
        sendOSC(.visualIntensity, value: visualParams.intensity)
        sendOSC(.visualSpeed, value: visualParams.speed)
    }

    /// Send single OSC message to all connected targets
    private func sendOSC(_ address: OSCAddress, value: Float) {
        let message = createOSCMessage(address: address.rawValue, value: value)

        for (_, connection) in oscConnections_internal {
            connection.send(content: message, completion: .idempotent)
        }

        lastOSCMessage = "\(address.rawValue) = \(String(format: "%.3f", value))"
    }

    /// Create OSC message data
    private func createOSCMessage(address: String, value: Float) -> Data {
        var data = Data()

        // Address (null-padded to 4-byte boundary)
        data.append(contentsOf: address.utf8)
        data.append(0)
        while data.count % 4 != 0 { data.append(0) }

        // Type tag
        data.append(contentsOf: ",f".utf8)
        data.append(0)
        data.append(0)

        // Float value (big-endian)
        var bigEndianValue = value.bitPattern.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: &bigEndianValue) { Array($0) })

        return data
    }

    // MARK: - Quick Connect Presets

    /// Connect to common creative tool setup
    func connectCreativeSetup() {
        connect(to: .ableton)
        connect(to: .resolume)
        connect(to: .touchDesigner)
    }

    /// Connect to live performance setup
    func connectLiveSetup() {
        connect(to: .ableton)
        connect(to: .resolume)
        connect(to: .obs)
    }
}

// MARK: - Bio Parameter Mapper Integration

extension EchoelSync {

    /// Audio parameters mapped from bio state
    struct AudioParameters {
        var reverbWet: Float = 0.3
        var filterCutoff: Float = 1000.0
        var tempo: Float = 60.0
        var amplitude: Float = 0.5
    }

    /// Visual parameters mapped from bio state
    struct VisualParameters {
        var hue: Float = 0.5
        var saturation: Float = 0.7
        var intensity: Float = 0.5
        var speed: Float = 1.0
    }
}

// MARK: - BioParameterMapper (Integrated)

/// Maps biometric signals to audio/visual control parameters
class BioParameterMapper {

    // MARK: - Mapping Ranges

    private let reverbRange = (min: Float(0.1), max: Float(0.8))
    private let filterRange = (min: Float(200), max: Float(2000))
    private let tempoRange = (min: Float(60), max: Float(120))
    private let amplitudeRange = (min: Float(0.3), max: Float(0.8))

    // MARK: - Bio → Audio Mapping

    func mapBioToAudio(_ state: EchoelSync.BioState) -> EchoelSync.AudioParameters {
        var params = EchoelSync.AudioParameters()

        // Coherence → Reverb (higher coherence = more reverb/space)
        params.reverbWet = lerp(from: reverbRange.min, to: reverbRange.max, t: state.coherenceScore)

        // Heart rate → Filter cutoff (higher HR = brighter sound)
        params.filterCutoff = lerp(from: filterRange.min, to: filterRange.max, t: state.heartRateNormalized)

        // Breathing rate → Tempo (synchronized breathing guidance)
        params.tempo = state.breathingRate * 10 // breaths/min * 10 = BPM
        params.tempo = params.tempo.clamped(to: tempoRange.min...tempoRange.max)

        // HRV + Coherence → Amplitude
        let combinedFactor = state.hrvNormalized * 0.5 + state.coherenceScore * 0.5
        params.amplitude = lerp(from: amplitudeRange.min, to: amplitudeRange.max, t: combinedFactor)

        return params
    }

    // MARK: - Bio → Visual Mapping

    func mapBioToVisual(_ state: EchoelSync.BioState) -> EchoelSync.VisualParameters {
        var params = EchoelSync.VisualParameters()

        // Coherence → Hue (low=red, high=blue/purple)
        params.hue = state.coherenceScore * 0.7 + 0.1 // 0.1-0.8 range

        // HRV → Saturation (higher HRV = more vibrant)
        params.saturation = state.hrvNormalized * 0.5 + 0.5 // 0.5-1.0 range

        // Motion energy → Intensity
        params.intensity = state.motionEnergy * 0.6 + 0.3 // 0.3-0.9 range

        // Heart rate → Animation speed
        params.speed = state.heartRateNormalized * 1.5 + 0.5 // 0.5-2.0 range

        return params
    }

    // MARK: - Utility

    private func lerp(from: Float, to: Float, t: Float) -> Float {
        return from + (to - from) * t
    }
}

// MARK: - Float Extension

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - SIMD3 Extension

extension SIMD3 where Scalar == Float {
    var magnitude: Float {
        return sqrt(x * x + y * y + z * z)
    }
}

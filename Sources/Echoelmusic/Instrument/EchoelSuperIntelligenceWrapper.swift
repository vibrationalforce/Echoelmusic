import Foundation
import CoreMIDI
import Combine

/**
 * EchoelSuperIntelligenceWrapper
 *
 * Swift wrapper for the C++ EchoelSuperIntelligence engine.
 * Integrates with:
 * - EchoelUniversalCore (master hub)
 * - MPEZoneManager (voice allocation)
 * - QuantumIntelligenceEngine (quantum algorithms)
 * - HealthKitManager (bio-data)
 *
 * Usage:
 * ```swift
 * let intelligence = EchoelSuperIntelligenceWrapper()
 * intelligence.prepare(sampleRate: 48000, blockSize: 512)
 *
 * // Connect to bio-data
 * intelligence.updateBioData(heartRate: 72, hrv: 0.65, coherence: 0.7)
 *
 * // Play MPE note
 * let voice = intelligence.startNote(channel: 1, note: 60, velocity: 0.8)
 * intelligence.updateVoice(voice, pressure: 0.5, slide: 0.3, glide: 0.1)
 * intelligence.stopNote(voice, releaseVelocity: 0.3)
 * ```
 */
@MainActor
final class EchoelSuperIntelligenceWrapper: ObservableObject {

    // MARK: - Published State

    @Published var isReady = false
    @Published var activeVoiceCount = 0
    @Published var currentPreset: IntelligencePreset = .pureInstrument
    @Published var wiseModeState = WiseModeState()
    @Published var bioState = BioState()
    @Published var quantumState = QuantumState()

    // MARK: - State Types

    struct WiseModeState {
        var predictiveEnabled = false
        var harmonicEnabled = false
        var bioSyncEnabled = false
        var gestureMemoryEnabled = false
        var quantumCreativityEnabled = false
        var learningRate: Float = 0.1
        var adaptationSpeed: Float = 0.5
        var detectedKey: Int = 0      // 0-11 (C, C#, D, ...)
        var detectedScale: Int = 0    // 0=Major, 1=Minor, 2=Dorian, etc.
    }

    struct BioState {
        var heartRate: Float = 70
        var hrv: Float = 0.5
        var coherence: Float = 0.5
        var stress: Float = 0.5
        var breathingRate: Float = 12
        var breathingPhase: Float = 0
    }

    struct QuantumState {
        var superpositionStrength: Float = 0.5
        var entanglementStrength: Float = 0.5
        var creativity: Float = 0.5
        var coherenceTime: Float = 100  // microseconds
    }

    enum IntelligencePreset: Int, CaseIterable {
        case pureInstrument = 0
        case seaboardExpressive
        case meditativeFlow
        case quantumExplorer
        case bioReactive
        case gestureArtist
        case harmonicWise
        case breathSync
        case neuralLink
        case cosmicVoyager
        case innerJourney
        case collectiveConsciousness

        var name: String {
            switch self {
            case .pureInstrument: return "Pure Instrument"
            case .seaboardExpressive: return "Seaboard Expressive"
            case .meditativeFlow: return "Meditative Flow"
            case .quantumExplorer: return "Quantum Explorer"
            case .bioReactive: return "Bio-Reactive"
            case .gestureArtist: return "Gesture Artist"
            case .harmonicWise: return "Harmonic Wise"
            case .breathSync: return "Breath Sync"
            case .neuralLink: return "Neural Link"
            case .cosmicVoyager: return "Cosmic Voyager"
            case .innerJourney: return "Inner Journey"
            case .collectiveConsciousness: return "Collective Consciousness"
            }
        }

        var description: String {
            switch self {
            case .pureInstrument:
                return "Clean, unmodified instrument response"
            case .seaboardExpressive:
                return "Optimized for ROLI Seaboard 5D Touch"
            case .meditativeFlow:
                return "Bio-synced for meditation and healing"
            case .quantumExplorer:
                return "Maximum quantum creativity and variation"
            case .bioReactive:
                return "Full bio-reactive modulation"
            case .gestureArtist:
                return "Enhanced gesture memory and learning"
            case .harmonicWise:
                return "AI-assisted harmonic intelligence"
            case .breathSync:
                return "Synchronized to breathing patterns"
            case .neuralLink:
                return "Ready for neural interface devices"
            case .cosmicVoyager:
                return "Expansive, evolving soundscapes"
            case .innerJourney:
                return "Deep introspective sound design"
            case .collectiveConsciousness:
                return "Multi-user bio-sync enabled"
            }
        }
    }

    // MARK: - Private Properties

    private var engineHandle: UnsafeMutableRawPointer?
    private var cancellables = Set<AnyCancellable>()

    // Cached controller info
    private var registeredControllers: [ControllerType] = []

    // MARK: - Controller Types

    enum ControllerType: Int {
        case unknown = 0
        // MPE Controllers
        case roliSeaboard, roliSeaboard2, roliLumi, roliAirwave
        case senselMorph, linnstrument, continuumFingerboard
        case expressiveEOsmose, eraeTouch, jouePlay
        case keithMcMillenKBoard, madronaLabsSoundplane
        // Classic Controllers
        case standardMIDI, aftertouchKeyboard, breathController
        case guitarMIDI, drumPad, djController
        // Future Hardware
        case neuralInterface, spatialGesture, hapticController
        case aiCoPilot, biometricWearable, vrMotionController

        var supportsMPE: Bool {
            switch self {
            case .roliSeaboard, .roliSeaboard2, .roliLumi, .roliAirwave,
                 .senselMorph, .linnstrument, .continuumFingerboard,
                 .expressiveEOsmose, .eraeTouch, .jouePlay,
                 .keithMcMillenKBoard, .madronaLabsSoundplane:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Initialization

    init() {
        print("[SuperIntelligence] Wrapper initialized")
    }

    deinit {
        shutdown()
    }

    // MARK: - Engine Lifecycle

    func prepare(sampleRate: Double, blockSize: Int) {
        guard engineHandle == nil else {
            print("[SuperIntelligence] Already prepared")
            return
        }

        engineHandle = ESI_Create(sampleRate, Int32(blockSize))

        if engineHandle != nil {
            isReady = true
            print("[SuperIntelligence] Engine ready at \(sampleRate) Hz")

            // Auto-detect connected controllers
            detectConnectedControllers()
        } else {
            print("[SuperIntelligence] ERROR: Failed to create engine")
        }
    }

    func shutdown() {
        if let handle = engineHandle {
            ESI_Destroy(handle)
            engineHandle = nil
            isReady = false
            print("[SuperIntelligence] Engine shutdown")
        }
    }

    // MARK: - Bio-Data Integration

    /// Update bio-data from HealthKit or wearables
    func updateBioData(heartRate: Float, hrv: Float, coherence: Float,
                       stress: Float = 0.5, breathingRate: Float = 12, breathingPhase: Float = 0) {
        guard let handle = engineHandle else { return }

        var bioData = ESI_BioState()
        bioData.heartRate = heartRate
        bioData.hrv = hrv
        bioData.coherence = coherence
        bioData.stress = stress
        bioData.breathingRate = breathingRate
        bioData.breathingPhase = breathingPhase

        ESI_UpdateBioData(handle, &bioData)

        // Update published state
        bioState.heartRate = heartRate
        bioState.hrv = hrv
        bioState.coherence = coherence
        bioState.stress = stress
        bioState.breathingRate = breathingRate
        bioState.breathingPhase = breathingPhase
    }

    /// Get current bio-modulated parameters
    func getBioModulatedParameters() -> (filterCutoff: Float, reverbMix: Float,
                                          compressionRatio: Float, delayTime: Float) {
        guard let handle = engineHandle else {
            return (1000, 0.3, 2.0, 500)
        }

        var filterCutoff: Float = 0
        var reverbMix: Float = 0
        var compressionRatio: Float = 0
        var delayTime: Float = 0

        ESI_GetBioModulatedParams(handle, &filterCutoff, &reverbMix, &compressionRatio, &delayTime)

        return (filterCutoff, reverbMix, compressionRatio, delayTime)
    }

    // MARK: - MPE Voice Control

    /// Start a new MPE voice
    func startNote(channel: Int, note: Int, velocity: Float) -> Int {
        guard let handle = engineHandle else { return -1 }

        let voiceIndex = ESI_StartMPEVoice(handle, Int32(channel), Int32(note), velocity)
        updateVoiceCount()
        return Int(voiceIndex)
    }

    /// Update MPE voice expression
    func updateVoice(_ voiceIndex: Int, pressure: Float, slide: Float, glide: Float) {
        guard let handle = engineHandle else { return }
        ESI_UpdateMPEVoice(handle, Int32(voiceIndex), pressure, slide, glide)
    }

    /// Stop MPE voice
    func stopNote(_ voiceIndex: Int, releaseVelocity: Float = 0) {
        guard let handle = engineHandle else { return }
        ESI_StopMPEVoice(handle, Int32(voiceIndex), releaseVelocity)
        updateVoiceCount()
    }

    private func updateVoiceCount() {
        guard let handle = engineHandle else { return }

        var voices = [ESI_MPEVoice](repeating: ESI_MPEVoice(), count: 48)
        let count = ESI_GetActiveMPEVoices(handle, &voices, 48)
        activeVoiceCount = Int(count)
    }

    // MARK: - Quantum Integration

    /// Update quantum state from QuantumIntelligenceEngine
    func updateQuantumState(superposition: Float, entanglement: Float, creativity: Float) {
        guard let handle = engineHandle else { return }

        var state = ESI_QuantumState()
        state.superpositionStrength = superposition
        state.entanglementStrength = entanglement
        state.creativity = creativity
        state.quantumMode = 1  // Hybrid

        ESI_UpdateQuantumState(handle, &state)

        quantumState.superpositionStrength = superposition
        quantumState.entanglementStrength = entanglement
        quantumState.creativity = creativity
    }

    /// Get quantum variation for a parameter
    func getQuantumVariation(for parameter: Int, baseValue: Float) -> Float {
        guard let handle = engineHandle else { return baseValue }
        return ESI_GetQuantumVariation(handle, Int32(parameter), baseValue)
    }

    // MARK: - Wise Mode Control

    /// Enable/disable Wise Mode features
    func setWiseModeFeature(_ feature: WiseModeFeature, enabled: Bool) {
        guard let handle = engineHandle else { return }
        ESI_SetWiseModeFeature(handle, Int32(feature.rawValue), enabled ? 1 : 0)

        // Update published state
        switch feature {
        case .predictiveArticulation:
            wiseModeState.predictiveEnabled = enabled
        case .harmonicIntelligence:
            wiseModeState.harmonicEnabled = enabled
        case .bioSyncAdaptation:
            wiseModeState.bioSyncEnabled = enabled
        case .gestureMemory:
            wiseModeState.gestureMemoryEnabled = enabled
        case .quantumCreativity:
            wiseModeState.quantumCreativityEnabled = enabled
        default:
            break
        }
    }

    enum WiseModeFeature: Int {
        case predictiveArticulation = 0
        case harmonicIntelligence
        case bioSyncAdaptation
        case gestureMemory
        case quantumCreativity
        case autoExpression
        case scaleAwareness
        case dynamicTimbre
        case breathSync
        case emotionMapping
    }

    /// Set learning rate for Wise Mode AI
    func setWiseModeLearningRate(_ rate: Float) {
        guard let handle = engineHandle else { return }
        ESI_SetWiseModeLearningRate(handle, rate)
        wiseModeState.learningRate = rate
    }

    /// Detect scale and key from played notes
    func detectScaleAndKey(from notes: [Int]) {
        guard let handle = engineHandle else { return }

        notes.withUnsafeBufferPointer { buffer in
            ESI_DetectScaleAndKey(handle, buffer.baseAddress, Int32(notes.count))
        }

        // Update from cached state
        var state = ESI_WiseModeState()
        ESI_GetWiseModeState(handle, &state)
        wiseModeState.detectedKey = Int(state.detectedKey)
        wiseModeState.detectedScale = Int(state.detectedScale)
    }

    // MARK: - Hardware Controller Support

    /// Register a hardware controller
    func registerController(_ type: ControllerType, name: String) {
        guard let handle = engineHandle else { return }

        var info = ESI_ControllerInfo()
        info.controllerType = Int32(type.rawValue)
        info.hasMPE = type.supportsMPE ? 1 : 0
        info.has5DTouch = (type == .roliSeaboard || type == .roliSeaboard2) ? 1 : 0
        info.hasAirwave = (type == .roliAirwave) ? 1 : 0
        info.pitchBendRange = type.supportsMPE ? 48 : 2

        // Copy name
        name.withCString { cString in
            strncpy(&info.name.0, cString, 63)
        }

        ESI_RegisterController(handle, &info)
        registeredControllers.append(type)
    }

    /// Auto-detect connected controllers
    private func detectConnectedControllers() {
        // Check MIDI devices and auto-register known controllers
        // This would integrate with MIDIController.swift

        // For now, register standard MIDI as fallback
        registerController(.standardMIDI, name: "Standard MIDI")
    }

    // MARK: - Audio Processing

    /// Process audio block
    func processAudio(left: UnsafeMutablePointer<Float>,
                      right: UnsafeMutablePointer<Float>,
                      sampleCount: Int) {
        guard let handle = engineHandle else { return }
        ESI_ProcessBlock(handle, left, right, Int32(sampleCount))
    }

    /// Process MIDI message
    func processMIDI(_ data: [UInt8], sampleOffset: Int = 0) {
        guard let handle = engineHandle else { return }

        data.withUnsafeBytes { buffer in
            ESI_ProcessMIDI(handle, buffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                           Int32(data.count), Int32(sampleOffset))
        }
    }

    // MARK: - Universal Core Integration

    /// Receive state from EchoelUniversalCore
    func receiveUniversalState(coherence: Float, energy: Float, flow: Float, creativity: Float) {
        guard let handle = engineHandle else { return }
        ESI_ReceiveUniversalState(handle, coherence, energy, flow, creativity)
    }

    /// Get state for EchoelUniversalCore
    func getStateForUniversalCore() -> (coherence: Float, energy: Float, creativity: Float) {
        guard let handle = engineHandle else {
            return (0.5, 0.5, 0.5)
        }

        var coherence: Float = 0
        var energy: Float = 0
        var creativity: Float = 0

        ESI_GetStateForUniversalCore(handle, &coherence, &energy, &creativity)

        return (coherence, energy, creativity)
    }

    // MARK: - Presets

    /// Load preset
    func loadPreset(_ preset: IntelligencePreset) {
        guard let handle = engineHandle else { return }
        ESI_LoadPreset(handle, ESI_Preset(rawValue: UInt32(preset.rawValue)))
        currentPreset = preset
        print("[SuperIntelligence] Loaded preset: \(preset.name)")
    }

    // MARK: - State Serialization

    /// Save engine state
    func saveState() -> Data? {
        guard let handle = engineHandle else { return nil }

        let size = ESI_SerializeState(handle, nil, 0)
        guard size > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: Int(size))
        ESI_SerializeState(handle, &buffer, size)

        return Data(bytes: buffer, count: Int(size))
    }

    /// Load engine state
    func loadState(_ data: Data) -> Bool {
        guard let handle = engineHandle else { return false }

        return data.withUnsafeBytes { buffer -> Bool in
            let result = ESI_DeserializeState(handle,
                buffer.baseAddress?.assumingMemoryBound(to: CChar.self),
                Int32(data.count))
            return result != 0
        }
    }
}

// MARK: - Integration with EchoelUniversalCore

extension EchoelSuperIntelligenceWrapper {

    /// Connect to EchoelUniversalCore
    func connectToUniversalCore(_ core: EchoelUniversalCore) {
        // Subscribe to bio-data updates
        core.$globalCoherence
            .sink { [weak self] coherence in
                self?.updateBioData(
                    heartRate: 70,
                    hrv: coherence,
                    coherence: coherence
                )
            }
            .store(in: &cancellables)

        // Subscribe to system state
        core.$systemState
            .sink { [weak self] state in
                self?.receiveUniversalState(
                    coherence: state.coherence,
                    energy: state.energy,
                    flow: state.flow,
                    creativity: state.creativity
                )
            }
            .store(in: &cancellables)

        // Subscribe to quantum field
        core.$quantumField
            .sink { [weak self] field in
                self?.updateQuantumState(
                    superposition: field.superpositionStrength,
                    entanglement: 0.5,
                    creativity: field.creativity
                )
            }
            .store(in: &cancellables)

        print("[SuperIntelligence] Connected to EchoelUniversalCore")
    }
}

// MARK: - Integration with MPEZoneManager

extension EchoelSuperIntelligenceWrapper {

    /// Connect to MPEZoneManager for voice allocation
    func connectToMPEManager(_ mpe: MPEZoneManager) {
        // Subscribe to active voices
        mpe.$activeVoices
            .sink { [weak self] voices in
                for voice in voices {
                    // Sync expression to engine
                    self?.updateVoice(
                        Int(voice.channel),
                        pressure: voice.pressure,
                        slide: voice.brightness,
                        glide: voice.pitchBend
                    )
                }
            }
            .store(in: &cancellables)

        print("[SuperIntelligence] Connected to MPEZoneManager")
    }
}

// MARK: - Integration with QuantumIntelligenceEngine

extension EchoelSuperIntelligenceWrapper {

    /// Connect to QuantumIntelligenceEngine
    func connectToQuantumEngine(_ quantum: QuantumIntelligenceEngine) {
        // Subscribe to quantum state
        quantum.$entanglementStrength
            .combineLatest(quantum.$quantumAdvantage)
            .sink { [weak self] entanglement, advantage in
                self?.updateQuantumState(
                    superposition: advantage / 10.0,
                    entanglement: entanglement,
                    creativity: entanglement * 0.8
                )
            }
            .store(in: &cancellables)

        print("[SuperIntelligence] Connected to QuantumIntelligenceEngine")
    }
}

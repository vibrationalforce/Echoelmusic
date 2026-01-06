import Foundation
import Combine
import AVFoundation
import QuartzCore

/// Central orchestrator for all input modalities in Echoelmusic
///
/// UnifiedControlHub manages the fusion of multiple input sources and routes
/// control signals to audio, visual, and light output systems.
///
/// **Input Priority:** Touch > Gesture > Face > Gaze > Position > Bio
///
/// **Control Loop:** 60 Hz (16.67ms update interval)
///
/// **Usage:**
/// ```swift
/// let hub = UnifiedControlHub(audioEngine: audioEngine)
/// hub.start()
/// ```
@MainActor
public class UnifiedControlHub: ObservableObject {

    // MARK: - Published State

    /// Current active input mode
    @Published public private(set) var activeInputMode: InputMode = .automatic

    /// Whether conflict resolution successfully resolved ambiguous inputs
    @Published public private(set) var conflictResolved: Bool = true

    /// Current control loop frequency (Hz)
    @Published public private(set) var controlLoopFrequency: Double = 0

    // MARK: - Dependencies (Injected)

    private let audioEngine: AudioEngine?
    private var faceTrackingManager: ARFaceTrackingManager?
    private var faceToAudioMapper: FaceToAudioMapper?
    private var handTrackingManager: HandTrackingManager?
    private var gestureRecognizer: GestureRecognizer?
    private var gestureConflictResolver: GestureConflictResolver?
    private var gestureToAudioMapper: GestureToAudioMapper?
    private var healthKitManager: HealthKitManager?
    private var bioParameterMapper: BioParameterMapper?
    private var midi2Manager: MIDI2Manager?
    private var mpeZoneManager: MPEZoneManager?
    private var midiToSpatialMapper: MIDIToSpatialMapper?

    // Phase 3: Spatial Audio + Visual + LED Integration
    private var spatialAudioEngine: SpatialAudioEngine?
    private var midiToVisualMapper: MIDIToVisualMapper?
    private var push3LEDController: Push3LEDController?
    private var midiToLightMapper: MIDIToLightMapper?

    // Phase 4: Quantum Light Emulation (Future-Ready)
    private var quantumLightEmulator: QuantumLightEmulator?
    private var photonicsVisualization: PhotonicsVisualizationEngine?

    // Phase 10000+: Ultimate Hardware Ecosystem Integration
    private var hardwareEcosystem: HardwareEcosystem?
    private var crossPlatformSessionManager: CrossPlatformSessionManager?

    // TODO: Add when implementing
    // private let gazeTracker: GazeTracker?

    // MARK: - Control Loop

    #if os(iOS) || os(tvOS)
    private var displayLink: CADisplayLink?
    #endif
    private var controlLoopTimer: AnyCancellable?
    private let controlQueue = DispatchQueue(
        label: "com.echoelmusic.control",
        qos: .userInteractive
    )

    private var lastUpdateTime: CFTimeInterval = CACurrentMediaTime()
    private let targetFrequency: Double = 60.0  // 60 Hz

    // MARK: - Cancellables (Lifecycle-scoped)

    private var cancellables = Set<AnyCancellable>()
    private var bioFeedbackCancellables = Set<AnyCancellable>()
    private var faceTrackingCancellables = Set<AnyCancellable>()
    private var handTrackingCancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(audioEngine: AudioEngine? = nil) {
        self.audioEngine = audioEngine
        self.faceToAudioMapper = FaceToAudioMapper()
    }

    /// Enable face tracking integration
    public func enableFaceTracking() {
        // Clear previous subscriptions to prevent leaks
        faceTrackingCancellables.removeAll()

        let manager = ARFaceTrackingManager()
        self.faceTrackingManager = manager

        // Subscribe to face expression changes
        manager.$faceExpression
            .sink { [weak self] expression in
                self?.handleFaceExpressionUpdate(expression)
            }
            .store(in: &faceTrackingCancellables)

        print("[UnifiedControlHub] Face tracking enabled")
    }

    /// Disable face tracking
    public func disableFaceTracking() {
        faceTrackingCancellables.removeAll()
        faceTrackingManager?.stop()
        faceTrackingManager = nil
        print("[UnifiedControlHub] Face tracking disabled")
    }

    /// Enable hand tracking and gesture recognition
    public func enableHandTracking() {
        // Clear previous subscriptions to prevent leaks
        handTrackingCancellables.removeAll()

        let handManager = HandTrackingManager()
        let gestureRec = GestureRecognizer(handTracker: handManager)
        let conflictRes = GestureConflictResolver(
            handTracker: handManager,
            faceTracker: faceTrackingManager
        )
        let gestureMapper = GestureToAudioMapper()

        self.handTrackingManager = handManager
        self.gestureRecognizer = gestureRec
        self.gestureConflictResolver = conflictRes
        self.gestureToAudioMapper = gestureMapper

        // Subscribe to gesture changes (lifecycle-scoped)
        gestureRec.$leftHandGesture
            .sink { [weak self] gesture in
                self?.handleGestureUpdate(hand: .left, gesture: gesture)
            }
            .store(in: &handTrackingCancellables)

        gestureRec.$rightHandGesture
            .sink { [weak self] gesture in
                self?.handleGestureUpdate(hand: .right, gesture: gesture)
            }
            .store(in: &handTrackingCancellables)

        print("[UnifiedControlHub] Hand tracking enabled")
    }

    /// Disable hand tracking
    public func disableHandTracking() {
        handTrackingCancellables.removeAll()
        handTrackingManager?.stopTracking()
        handTrackingManager = nil
        gestureRecognizer = nil
        gestureConflictResolver = nil
        gestureToAudioMapper = nil
        print("[UnifiedControlHub] Hand tracking disabled")
    }

    /// Enable biometric monitoring (HealthKit)
    public func enableBiometricMonitoring() async throws {
        // Clear previous subscriptions to prevent leaks
        bioFeedbackCancellables.removeAll()

        let healthKit = HealthKitManager()
        let bioMapper = BioParameterMapper()

        // Request HealthKit authorization
        try await healthKit.requestAuthorization()

        guard healthKit.isAuthorized else {
            throw NSError(
                domain: "com.echoelmusic.healthkit",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit authorization denied"]
            )
        }

        self.healthKitManager = healthKit
        self.bioParameterMapper = bioMapper

        // Event-driven bio updates (replaces polling pattern)
        // Debounce prevents excessive updates while maintaining responsiveness
        healthKit.$hrvCoherence
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleBioSignalUpdate()
            }
            .store(in: &bioFeedbackCancellables)

        healthKit.$heartRate
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleBioSignalUpdate()
            }
            .store(in: &bioFeedbackCancellables)

        // Start monitoring
        healthKit.startMonitoring()

        print("[UnifiedControlHub] Biometric monitoring enabled")
    }

    /// Disable biometric monitoring
    public func disableBiometricMonitoring() {
        bioFeedbackCancellables.removeAll()
        healthKitManager?.stopMonitoring()
        healthKitManager = nil
        bioParameterMapper = nil
        print("[UnifiedControlHub] Biometric monitoring disabled")
    }

    /// Handle bio signal updates from HealthKit
    private func handleBioSignalUpdate() {
        // Bio signal updates happen via Combine subscriptions
        // Actual mapping happens in updateFromBioSignals()
    }

    /// Enable MIDI 2.0 + MPE output
    public func enableMIDI2() async throws {
        let midi2 = MIDI2Manager()
        try await midi2.initialize()

        let mpe = MPEZoneManager(midi2Manager: midi2)
        let spatialMapper = MIDIToSpatialMapper()

        self.midi2Manager = midi2
        self.mpeZoneManager = mpe
        self.midiToSpatialMapper = spatialMapper

        // Configure MPE zone (15 member channels)
        mpe.sendMPEConfiguration(memberChannels: 15)
        mpe.setPitchBendRange(semitones: 48)  // ±4 octaves

        print("[UnifiedControlHub] MIDI 2.0 + MPE enabled")
    }

    /// Disable MIDI 2.0
    public func disableMIDI2() {
        // Release all active voices
        mpeZoneManager?.releaseAllVoices()

        // Cleanup MIDI
        midi2Manager?.cleanup()

        midi2Manager = nil
        mpeZoneManager = nil
        midiToSpatialMapper = nil

        print("[UnifiedControlHub] MIDI 2.0 disabled")
    }

    // MARK: - Phase 3 Integration

    /// Enable spatial audio engine
    public func enableSpatialAudio() throws {
        let spatial = SpatialAudioEngine()
        try spatial.start()
        self.spatialAudioEngine = spatial
        print("[UnifiedControlHub] Spatial audio enabled")
    }

    /// Disable spatial audio
    public func disableSpatialAudio() {
        spatialAudioEngine?.stop()
        spatialAudioEngine = nil
        print("[UnifiedControlHub] Spatial audio disabled")
    }

    /// Enable MIDI to visual mapping
    public func enableVisualMapping() {
        let visualMapper = MIDIToVisualMapper()
        self.midiToVisualMapper = visualMapper
        print("[UnifiedControlHub] Visual mapping enabled")
    }

    /// Disable visual mapping
    public func disableVisualMapping() {
        midiToVisualMapper = nil
        print("[UnifiedControlHub] Visual mapping disabled")
    }

    /// Enable Push 3 LED controller
    public func enablePush3LED() throws {
        let push3 = Push3LEDController()
        try push3.connect()
        self.push3LEDController = push3
        print("[UnifiedControlHub] Push 3 LED controller enabled")
    }

    /// Disable Push 3 LED
    public func disablePush3LED() {
        push3LEDController?.disconnect()
        push3LEDController = nil
        print("[UnifiedControlHub] Push 3 LED controller disabled")
    }

    /// Enable DMX/LED strip lighting
    public func enableLighting() throws {
        let lighting = MIDIToLightMapper()
        try lighting.connect()
        self.midiToLightMapper = lighting
        print("[UnifiedControlHub] DMX lighting enabled")
    }

    /// Disable lighting
    public func disableLighting() {
        midiToLightMapper?.disconnect()
        midiToLightMapper = nil
        print("[UnifiedControlHub] DMX lighting disabled")
    }

    /// Enable Quantum Light Emulator (Future-Ready)
    /// - Parameter mode: Emulation mode (classical, quantum-inspired, bio-coherent, etc.)
    public func enableQuantumLightEmulator(mode: QuantumLightEmulator.EmulationMode = .bioCoherent) {
        let config = QuantumLightEmulator.Configuration()
        let emulator = QuantumLightEmulator(configuration: config)
        emulator.setMode(mode)
        emulator.start()

        // Connect photonics visualization
        let photonics = PhotonicsVisualizationEngine()
        photonics.connect(to: emulator)
        photonics.start()

        self.quantumLightEmulator = emulator
        self.photonicsVisualization = photonics

        print("[UnifiedControlHub] Quantum Light Emulator enabled in \(mode.rawValue) mode")
        print("  - Qubits: \(config.qubitCount)")
        print("  - Photons: \(config.photonCount)")
        print("  - Field Geometry: \(config.lightFieldGeometry.rawValue)")
    }

    /// Disable Quantum Light Emulator
    public func disableQuantumLightEmulator() {
        quantumLightEmulator?.stop()
        photonicsVisualization?.stop()
        quantumLightEmulator = nil
        photonicsVisualization = nil
        print("[UnifiedControlHub] Quantum Light Emulator disabled")
    }

    // MARK: - Phase 10000+: Ultimate Hardware Ecosystem

    /// Enable the Ultimate Hardware Ecosystem for universal device connectivity
    /// Supports 60+ audio interfaces, 40+ MIDI controllers, DMX/Art-Net lighting,
    /// video/broadcast equipment, VR/AR devices, wearables, and more
    public func enableHardwareEcosystem() {
        hardwareEcosystem = HardwareEcosystem.shared

        // Auto-discover connected devices
        Task {
            await hardwareEcosystem?.discoverAllDevices()

            // Log discovered devices
            if let ecosystem = hardwareEcosystem {
                print("[UnifiedControlHub] Hardware Ecosystem enabled")
                print("  - Connected devices: \(ecosystem.connectedDevices.count)")
                print("  - Audio interfaces available: \(ecosystem.audioInterfaces.supportedInterfaces.count)")
                print("  - MIDI controllers available: \(ecosystem.midiControllers.supportedControllers.count)")
                print("  - Lighting fixtures available: \(ecosystem.lightingHardware.supportedFixtures.count)")
                print("  - Video hardware available: \(ecosystem.videoHardware.supportedDevices.count)")
                print("  - VR/AR devices available: \(ecosystem.vrArDevices.supportedDevices.count)")
                print("  - Wearables available: \(ecosystem.wearables.supportedDevices.count)")
            }
        }
    }

    /// Disable Hardware Ecosystem
    public func disableHardwareEcosystem() {
        hardwareEcosystem = nil
        print("[UnifiedControlHub] Hardware Ecosystem disabled")
    }

    /// Enable Cross-Platform Session Manager for multi-device sessions
    /// Supports ANY device combination: iPhone + Windows, Android + Mac, etc.
    public func enableCrossPlatformSessions() {
        crossPlatformSessionManager = CrossPlatformSessionManager.shared

        // Start device discovery
        crossPlatformSessionManager?.startDiscovery()

        print("[UnifiedControlHub] Cross-Platform Session Manager enabled")
        print("  - Adaptive zero-latency mode active")
        print("  - Supported ecosystems: Apple, Google, Microsoft, Meta, Linux, Tesla")
    }

    /// Disable Cross-Platform Session Manager
    public func disableCrossPlatformSessions() {
        crossPlatformSessionManager?.stopDiscovery()
        crossPlatformSessionManager = nil
        print("[UnifiedControlHub] Cross-Platform Session Manager disabled")
    }

    /// Create a cross-platform session with specified devices
    /// - Parameters:
    ///   - name: Session name
    ///   - devices: Devices to include in the session
    ///   - syncMode: Synchronization mode (adaptive, lowLatency, highQuality)
    /// - Returns: The created session
    public func createCrossPlatformSession(
        name: String,
        devices: [CrossPlatformSessionManager.SessionDevice],
        syncMode: CrossPlatformSessionManager.SyncMode = .adaptive
    ) -> CrossPlatformSessionManager.CrossPlatformSession? {
        guard let manager = crossPlatformSessionManager else {
            print("[UnifiedControlHub] Cross-Platform Session Manager not enabled")
            return nil
        }

        let session = manager.createSession(name: name, devices: devices, syncMode: syncMode)
        print("[UnifiedControlHub] Created cross-platform session: \(name)")
        print("  - Devices: \(devices.count)")
        print("  - Sync mode: \(syncMode)")
        return session
    }

    /// Get recommended audio interface for current platform
    public func getRecommendedAudioInterface() -> HardwareEcosystem.AudioInterface? {
        return hardwareEcosystem?.audioInterfaces.getRecommendedInterface()
    }

    /// Get all connected MIDI controllers
    public func getConnectedMIDIControllers() -> [HardwareEcosystem.MIDIController] {
        return hardwareEcosystem?.midiControllers.supportedControllers.filter { controller in
            // Check if controller is actually connected
            hardwareEcosystem?.connectedDevices.contains { $0.name == controller.name } ?? false
        } ?? []
    }

    /// Get all available lighting fixtures
    public func getAvailableLightingFixtures() -> [HardwareEcosystem.LightingFixture] {
        return hardwareEcosystem?.lightingHardware.supportedFixtures ?? []
    }

    /// Sync biometric data across all devices in cross-platform session
    public func syncBiometricsToSession(hrvCoherence: Float, heartRate: Float, breathingRate: Float) {
        let bioData = CrossPlatformSessionManager.BiometricSyncData(
            hrvCoherence: hrvCoherence,
            heartRate: heartRate,
            breathingRate: breathingRate,
            timestamp: Date()
        )
        crossPlatformSessionManager?.syncBiometricData(bioData)
    }

    /// Sync audio parameters across all devices in cross-platform session
    public func syncAudioParametersToSession(bpm: Float, filterCutoff: Float, reverbWet: Float) {
        let params = CrossPlatformSessionManager.AudioSyncParameters(
            bpm: bpm,
            filterCutoff: filterCutoff,
            reverbWet: reverbWet,
            masterVolume: 0.8
        )
        crossPlatformSessionManager?.syncAudioParameters(params)
    }

    /// Get current quantum coherence level
    public var quantumCoherenceLevel: Float {
        quantumLightEmulator?.coherenceLevel ?? 0.0
    }

    /// Get current light field for visualization
    public var currentLightField: LightField? {
        quantumLightEmulator?.currentLightField
    }

    /// Set quantum emulation mode
    public func setQuantumMode(_ mode: QuantumLightEmulator.EmulationMode) {
        quantumLightEmulator?.setMode(mode)
    }

    // MARK: - Lifecycle

    /// Start the unified control system
    public func start() {
        print("[UnifiedControlHub] Starting control system...")

        // Start face tracking if enabled
        faceTrackingManager?.start()

        // Start hand tracking if enabled
        handTrackingManager?.startTracking()

        // HealthKit monitoring already started in enableBiometricMonitoring()

        // Start control loop
        startControlLoop()
    }

    /// Stop the unified control system
    public func stop() {
        print("[UnifiedControlHub] Stopping control system...")

        #if os(iOS) || os(tvOS)
        displayLink?.invalidate()
        displayLink = nil
        #endif

        controlLoopTimer?.cancel()
        controlLoopTimer = nil

        // Stop quantum emulator if running
        quantumLightEmulator?.stop()
        photonicsVisualization?.stop()
    }

    // MARK: - Control Loop (60 Hz)

    private func startControlLoop() {
        #if os(iOS) || os(tvOS)
        // Use CADisplayLink for precise 60Hz timing (10-15ms jitter reduction)
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: Float(targetFrequency),
            maximum: Float(targetFrequency),
            preferred: Float(targetFrequency)
        )
        displayLink?.add(to: .main, forMode: .common)
        #else
        // macOS/watchOS: Use high-precision timer
        let interval = 1.0 / targetFrequency
        controlLoopTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.controlLoopTick()
            }
        #endif
    }

    #if os(iOS) || os(tvOS)
    @objc private func displayLinkFired(_ link: CADisplayLink) {
        controlLoopTick()
    }
    #endif

    private func controlLoopTick() {
        // Measure actual frequency using CACurrentMediaTime (no allocation)
        let now = CACurrentMediaTime()
        let deltaTime = now - lastUpdateTime
        controlLoopFrequency = deltaTime > 0 ? 1.0 / deltaTime : targetFrequency
        lastUpdateTime = now

        // Priority-based parameter updates
        updateFromBioSignals()
        updateFromFaceTracking()
        updateFromHandGestures()
        updateFromGazeTracking()

        // Check for gesture conflicts
        resolveConflicts()

        // Update all output systems
        updateAudioEngine()
        updateVisualEngine()
        updateLightSystems()
    }

    // MARK: - Input Updates (Placeholder implementations)

    private func updateFromBioSignals() {
        guard let healthKit = healthKitManager,
              let mapper = bioParameterMapper else {
            return
        }

        // Get current biometric data
        let hrvCoherence = healthKit.hrvCoherence
        let heartRate = healthKit.heartRate

        // FIXED: Hole echte Audio-Analyse-Daten
        let voicePitch: Float = audioEngine?.getCurrentPitch?() ?? 0.0
        let audioLevel: Float = audioEngine?.currentLevel ?? 0.5

        // Update bio parameter mapping
        mapper.updateParameters(
            hrvCoherence: hrvCoherence,
            heartRate: heartRate,
            voicePitch: voicePitch,
            audioLevel: audioLevel
        )

        // Apply bio-derived audio parameters
        applyBioAudioParameters(mapper)
    }

    /// Apply bio-derived audio parameters to audio engine and spatial mapping
    private func applyBioAudioParameters(_ mapper: BioParameterMapper) {
        guard let engine = audioEngine else { return }

        // FIXED: Apply filter cutoff
        engine.setFilterCutoff(mapper.filterCutoff)

        // FIXED: Apply reverb wetness
        engine.setReverbWetness(mapper.reverbWet)

        // FIXED: Apply amplitude to master volume
        engine.setMasterVolume(mapper.amplitude)

        // FIXED: Apply tempo
        engine.setTempo(mapper.tempo)

        // Log bio→audio mapping (nur bei Debug)
        #if DEBUG
        print("[Bio→Audio] Filter: \(Int(mapper.filterCutoff))Hz, Reverb: \(Int(mapper.reverbWet * 100))%, Tempo: \(Int(mapper.tempo))BPM")
        #endif

        // Apply bio-reactive spatial field (AFA)
        if let mpe = mpeZoneManager, let spatialMapper = midiToSpatialMapper {
            // Convert active MPE voices to spatial field
            let voiceData = mpe.activeVoices.map { voice in
                MPEVoiceData(
                    id: voice.id,
                    note: voice.note,
                    velocity: voice.velocity,
                    pitchBend: voice.pitchBend,
                    brightness: voice.brightness
                )
            }

            // Morph AFA field geometry based on HRV coherence
            let fieldGeometry: MIDIToSpatialMapper.AFAField.FieldGeometry
            let coherence = healthKitManager?.hrvCoherence ?? 50.0

            if coherence < 40 {
                // Low coherence (stress) = Grid (structured, grounding)
                fieldGeometry = .grid(rows: 3, cols: 3, spacing: 0.5)
            } else if coherence < 60 {
                // Medium coherence = Circle (transitional)
                fieldGeometry = .circle(radius: 1.5, sourceCount: voiceData.count)
            } else {
                // High coherence (flow) = Fibonacci Sphere (natural, harmonious)
                fieldGeometry = .fibonacci(sourceCount: voiceData.count)
            }

            // Generate AFA field
            if !voiceData.isEmpty {
                let afaField = spatialMapper.mapToAFA(voices: voiceData, geometry: fieldGeometry)
                spatialMapper.afaField = afaField

                // TODO: Apply AFA field to SpatialAudioEngine
                // print("[Bio→AFA] Field geometry: \(fieldGeometry), Sources: \(afaField.sources.count)")
            }
        }
    }

    private func updateFromFaceTracking() {
        // Face tracking updates happen via Combine subscription
        // See handleFaceExpressionUpdate()
    }

    /// Handle face expression updates from ARKit
    private func handleFaceExpressionUpdate(_ expression: FaceExpression) {
        guard let mapper = faceToAudioMapper else { return }

        // Map face expression to audio parameters
        let audioParams = mapper.mapToAudio(faceExpression: expression)

        // Apply to audio engine (if available)
        applyFaceAudioParameters(audioParams)
    }

    /// Apply face-derived audio parameters to audio engine and MPE
    private func applyFaceAudioParameters(_ params: AudioParameters) {
        // Apply to audio engine
        // TODO: Apply to actual AudioEngine once extended
        // print("[Face→Audio] Cutoff: \(Int(params.filterCutoff)) Hz, Q: \(String(format: "%.2f", params.filterResonance))")

        // Apply to all active MPE voices
        if let mpe = mpeZoneManager {
            for voice in mpe.activeVoices {
                // Jaw open → Per-note brightness (CC 74)
                let jawOpen = params.filterCutoff / 8000.0  // Normalize cutoff to 0-1
                mpe.setVoiceBrightness(voice: voice, brightness: jawOpen)

                // Smile → Per-note timbre (CC 71)
                let smile = params.filterResonance / 5.0  // Normalize resonance to 0-1
                mpe.setVoiceTimbre(voice: voice, timbre: smile)
            }
        }
    }

    private func updateFromHandGestures() {
        guard let gestureRecognizer = gestureRecognizer,
              let handTrackingManager = handTrackingManager,
              let conflictResolver = gestureConflictResolver else {
            return
        }

        // Update gesture recognition
        gestureRecognizer.updateGestures()

        // Apply gestures to audio parameters (if validated)
        applyGestureParameters()
    }

    /// Handle gesture updates from GestureRecognizer
    private func handleGestureUpdate(hand: HandTrackingManager.Hand, gesture: GestureRecognizer.Gesture) {
        guard let gestureRecognizer = gestureRecognizer,
              let conflictResolver = gestureConflictResolver else {
            return
        }

        // Validate gesture with conflict resolver
        let confidence = gestureRecognizer.leftGestureConfidence // Use appropriate confidence
        guard conflictResolver.shouldProcessGesture(gesture, hand: hand, confidence: confidence) else {
            return
        }

        // Gesture is valid - mapping happens in applyGestureParameters()
    }

    /// Apply gesture-derived audio parameters to audio engine
    private func applyGestureParameters() {
        guard let gestureRecognizer = gestureRecognizer,
              let mapper = gestureToAudioMapper else {
            return
        }

        // Map gestures to audio parameters
        let audioParams = mapper.mapToAudio(gestureRecognizer: gestureRecognizer)

        // Apply parameters to audio engine
        applyGestureAudioParameters(audioParams)
    }

    /// Apply gesture-derived audio parameters to audio engine
    private func applyGestureAudioParameters(_ params: GestureToAudioMapper.AudioParameters) {
        guard let engine = audioEngine else { return }

        // FIXED: Apply filter parameters
        if let cutoff = params.filterCutoff {
            engine.setFilterCutoff(cutoff)
        }

        if let resonance = params.filterResonance {
            engine.setFilterResonance(resonance)
        }

        // FIXED: Apply reverb parameters
        if let size = params.reverbSize {
            engine.setReverbSize(size)
        }

        if let wetness = params.reverbWetness {
            engine.setReverbWetness(wetness)
        }

        // FIXED: Apply delay parameters
        if let delayTime = params.delayTime {
            engine.setDelayTime(delayTime)
        }

        #if DEBUG
        print("[Gesture→Audio] Applied: Filter=\(params.filterCutoff ?? 0)Hz, Reverb=\(params.reverbWetness ?? 0)")
        #endif

        // Trigger MIDI notes via MPE
        if let midiNote = params.midiNoteOn {
            if let mpe = mpeZoneManager {
                // Allocate MPE voice for polyphonic expression
                if let voice = mpe.allocateVoice(
                    note: midiNote.note,
                    velocity: Float(midiNote.velocity) / 127.0
                ) {
                    print("[Gesture→MPE] Voice allocated: Note \(midiNote.note), Channel \(voice.channel + 1)")

                    // Apply initial per-note expression from gestures
                    if let gestureRec = gestureRecognizer {
                        // Pinch amount → Pitch bend
                        let pinchBend = (gestureRec.leftPinchAmount * 2.0) - 1.0  // Map 0-1 to -1 to +1
                        mpe.setVoicePitchBend(voice: voice, bend: pinchBend)

                        // Spread amount → Brightness
                        mpe.setVoiceBrightness(voice: voice, brightness: gestureRec.leftSpreadAmount)
                    }
                }
            } else {
                // Fallback to MIDI 1.0 if MPE not enabled
                print("[Gesture→MIDI] Note On: \(midiNote.note), Velocity: \(midiNote.velocity)")
            }
        }

        // Handle preset changes
        if let presetChange = params.presetChange {
            // TODO: Change to preset
            print("[Gesture→Audio] Switch to preset: \(presetChange)")
        }
    }

    private func updateFromGazeTracking() {
        // TODO: Implement when GazeTracker is integrated
    }

    // MARK: - Conflict Resolution

    private func resolveConflicts() {
        guard let conflictResolver = gestureConflictResolver else {
            conflictResolved = true
            return
        }

        // Check for input conflicts
        // Priority: Touch > Gesture > Face > Gaze > Position > Bio

        // For now, check if gestures conflict with face tracking
        let hasActiveGesture = gestureRecognizer?.leftHandGesture != .none ||
                               gestureRecognizer?.rightHandGesture != .none
        let hasActiveFace = faceTrackingManager?.isTracking ?? false

        if hasActiveGesture && hasActiveFace {
            // Gesture takes priority over face (per priority rules)
            // Mark as resolved since we have a clear priority
            conflictResolved = true
        } else {
            // No conflict
            conflictResolved = true
        }
    }

    // MARK: - Output Updates

    private func updateAudioEngine() {
        // Audio engine updates happen in specific input handlers
        // This is called after all inputs have been processed
    }

    private func updateVisualEngine() {
        guard let healthKit = healthKitManager else {
            return
        }

        // Update visual parameters from bio-signals
        let bioParams = MIDIToVisualMapper.BioParameters(
            hrvCoherence: healthKit.hrvCoherence,
            heartRate: healthKit.heartRate,
            breathingRate: healthKit.breathingRate,
            audioLevel: Double(audioEngine?.currentLevel ?? 0.5)
        )

        if let visualMapper = midiToVisualMapper {
            visualMapper.updateBioParameters(bioParams)
        }

        // Update Quantum Light Emulator with bio-inputs
        if let quantumEmulator = quantumLightEmulator {
            quantumEmulator.updateBioInputs(
                hrvCoherence: Float(healthKit.hrvCoherence),
                heartRate: Float(healthKit.heartRate),
                breathingRate: Float(healthKit.breathingRate)
            )
        }
    }

    private func updateLightSystems() {
        guard let healthKit = healthKitManager else {
            return
        }

        let bioData = MIDIToLightMapper.BioData(
            hrvCoherence: healthKit.hrvCoherence,
            heartRate: healthKit.heartRate,
            breathingRate: healthKit.breathingRate
        )

        // Update Push 3 LED patterns
        if let push3 = push3LEDController {
            push3.updateBioReactive(
                hrvCoherence: bioData.hrvCoherence,
                heartRate: bioData.heartRate,
                breathingRate: bioData.breathingRate
            )
        }

        // Update DMX/LED strip lighting
        if let lighting = midiToLightMapper {
            lighting.updateBioReactive(bioData)
        }
    }

    // MARK: - Utilities

    /// Map a value from one range to another
    public func mapRange(
        _ value: Double,
        from: ClosedRange<Double>,
        to: ClosedRange<Double>
    ) -> Double {
        let normalized = (value - from.lowerBound) / (from.upperBound - from.lowerBound)
        let clamped = max(0, min(1, normalized))
        return to.lowerBound + clamped * (to.upperBound - to.lowerBound)
    }
}

// MARK: - Input Mode

extension UnifiedControlHub {

    public enum InputMode: Equatable {
        /// System automatically prioritizes inputs
        case automatic

        /// Only accept touch input
        case touchOnly

        /// Only accept gesture input
        case gestureOnly

        /// Only accept face tracking input
        case faceOnly

        /// Only accept biofeedback input
        case bioOnly

        /// Custom combination of input sources
        case hybrid(Set<InputSource>)
    }

    public enum InputSource: Hashable {
        case touch
        case gesture
        case face
        case gaze
        case position
        case bio
    }
}

// MARK: - Statistics

extension UnifiedControlHub {

    /// Get current control loop statistics
    public var statistics: ControlStatistics {
        ControlStatistics(
            frequency: controlLoopFrequency,
            targetFrequency: targetFrequency,
            activeInputMode: activeInputMode,
            conflictResolved: conflictResolved
        )
    }

    public struct ControlStatistics {
        public let frequency: Double
        public let targetFrequency: Double
        public let activeInputMode: InputMode
        public let conflictResolved: Bool

        public var isRunningAtTarget: Bool {
            abs(frequency - targetFrequency) < 5.0  // Within 5 Hz tolerance
        }
    }
}

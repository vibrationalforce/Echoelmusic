import Foundation
import Combine
import AVFoundation
import QuartzCore
import os.signpost

/// Global logger instance for UnifiedControlHub
private let Log = EchoelLogger.shared

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

    /// Use octave-based color mapping for lighting (f × 2^n, CIE 1931)
    @Published public var useOctaveBasedLighting: Bool = true

    /// Octave shift for heart rate → audio frequency mapping (default: 6)
    @Published public var lightingOctaveShift: Int = 6

    // MARK: - Dependencies (Injected)

    private let audioEngine: AudioEngine?
    private var faceTrackingManager: ARFaceTrackingManager?
    private var faceToAudioMapper: FaceToAudioMapper?
    private var handTrackingManager: HandTrackingManager?
    private var gestureRecognizer: GestureRecognizer?
    private var gestureConflictResolver: GestureConflictResolver?
    private var gestureToAudioMapper: GestureToAudioMapper?
    private var healthKitEngine: UnifiedHealthKitEngine?
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

    // Phase 10000: ILDA Laser Control (Ether Dream, LaserCube, Beyond)
    private var iLDALaserController: ILDALaserController?

    // Phase λ∞: Lambda Mode Engine
    private var lambdaModeEngine: LambdaModeEngine?

    // Phase 10000+: Ultimate Hardware Ecosystem Integration
    private var hardwareEcosystem: HardwareEcosystem?
    private var crossPlatformSessionManager: CrossPlatformSessionManager?

    // Phase λ∞: Eye Gaze Tracking Integration
    private var gazeTracker: GazeTracker?
    private var gazeTrackingCancellables = Set<AnyCancellable>()

    // MARK: - Control Loop

    #if os(iOS) || os(tvOS)
    private var displayLink: CADisplayLink?
    #endif
    // LAMBDA LOOP: High-precision timer for non-iOS platforms
    private var controlLoopTimer: DispatchSourceTimer?
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

    /// Pre-allocated buffer for MPE voice data to avoid per-tick allocations
    private var voiceDataBuffer: [MPEVoiceData] = []

    /// Whether the app is currently in the background (pauses non-essential loops)
    private var isBackgrounded: Bool = false

    /// Current thermal pressure level for adaptive quality
    private var thermalPressure: ThermalPressure = .nominal

    /// Thermal pressure levels for adaptive resource scaling
    enum ThermalPressure {
        case nominal, fair, serious, critical

        #if canImport(UIKit)
        init(state: ProcessInfo.ThermalState) {
            switch state {
            case .nominal: self = .nominal
            case .fair: self = .fair
            case .serious: self = .serious
            case .critical: self = .critical
            @unknown default: self = .fair
            }
        }
        #endif
    }

    public init(audioEngine: AudioEngine? = nil) {
        self.audioEngine = audioEngine
        self.faceToAudioMapper = FaceToAudioMapper()
        observeAppLifecycle()
        observeThermalState()
    }

    deinit {
        // Clean up DisplayLink to prevent retain cycle leaks
        #if os(iOS) || os(tvOS)
        displayLink?.invalidate()
        displayLink = nil
        #endif
        controlLoopTimer?.cancel()
        controlLoopTimer = nil
    }

    // MARK: - App Lifecycle & Thermal State

    private func observeAppLifecycle() {
        #if canImport(UIKit) && !os(watchOS)
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleEnteredBackground()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleEnteredForeground()
            }
            .store(in: &cancellables)

        // Low Power Mode detection
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.handlePowerStateChange()
            }
            .store(in: &cancellables)
        #endif
    }

    private func observeThermalState() {
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleThermalStateChange()
            }
            .store(in: &cancellables)
        // Set initial state
        #if canImport(UIKit)
        thermalPressure = ThermalPressure(state: ProcessInfo.processInfo.thermalState)
        #endif
    }

    private func handleEnteredBackground() {
        guard !isBackgrounded else { return }
        isBackgrounded = true
        Log.info("App backgrounded — pausing non-essential loops", category: .system)
        // Pause visual/lighting loops; keep audio alive
        #if os(iOS) || os(tvOS)
        displayLink?.isPaused = true
        #endif
        quantumLightEmulator?.stop()
        push3LEDController?.clearGrid()
    }

    private func handleEnteredForeground() {
        guard isBackgrounded else { return }
        isBackgrounded = false
        Log.info("App foregrounded — resuming loops", category: .system)
        #if os(iOS) || os(tvOS)
        displayLink?.isPaused = false
        #endif
    }

    private func handleThermalStateChange() {
        #if canImport(UIKit)
        thermalPressure = ThermalPressure(state: ProcessInfo.processInfo.thermalState)
        #endif
        switch thermalPressure {
        case .nominal:
            Log.info("Thermal: nominal", category: .system)
        case .fair:
            Log.info("Thermal: fair — reducing visual fidelity", category: .system)
        case .serious:
            Log.warning("Thermal: serious — disabling non-essential visual processing", category: .system)
            quantumLightEmulator?.stop()
        case .critical:
            Log.warning("Thermal: critical — minimal mode", category: .system)
            quantumLightEmulator?.stop()
            push3LEDController?.clearGrid()
        }
    }

    private func handlePowerStateChange() {
        #if canImport(UIKit) && !os(watchOS)
        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        if isLowPower {
            Log.info("Low Power Mode enabled — throttling updates", category: .system)
        } else {
            Log.info("Low Power Mode disabled — restoring full performance", category: .system)
        }
        #endif
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

        Log.info("🎭 Face tracking enabled", category: .system)
    }

    /// Disable face tracking
    public func disableFaceTracking() {
        faceTrackingCancellables.removeAll()
        faceTrackingManager?.stop()
        faceTrackingManager = nil
        Log.info("🎭 Face tracking disabled", category: .system)
    }

    /// Enable hand tracking and gesture recognition
    public func enableHandTracking() {
        // Clear previous subscriptions to prevent leaks
        handTrackingCancellables.removeAll()

        let handManager = HandTrackingManager()
        let gestureRec = GestureRecognizer(handTracker: handManager)
        let conflictRes = GestureConflictResolver(
            gestureRecognizer: gestureRec,
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

        Log.info("👋 Hand tracking enabled", category: .system)
    }

    /// Disable hand tracking
    public func disableHandTracking() {
        handTrackingCancellables.removeAll()
        handTrackingManager?.stopTracking()
        handTrackingManager = nil
        gestureRecognizer = nil
        gestureConflictResolver = nil
        gestureToAudioMapper = nil
        Log.info("👋 Hand tracking disabled", category: .system)
    }

    /// Enable biometric monitoring (HealthKit)
    public func enableBiometricMonitoring() async throws {
        // Clear previous subscriptions to prevent leaks
        bioFeedbackCancellables.removeAll()

        // Use unified HealthKit engine (singleton)
        let healthKit = UnifiedHealthKitEngine.shared
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

        self.healthKitEngine = healthKit
        self.bioParameterMapper = bioMapper

        // Event-driven bio updates (replaces polling pattern)
        // 16ms debounce = one frame at 60Hz — keeps full budget for bio→audio pipeline
        healthKit.$coherence
            .debounce(for: .milliseconds(16), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleBioSignalUpdate()
            }
            .store(in: &bioFeedbackCancellables)

        healthKit.$heartRate
            .debounce(for: .milliseconds(16), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleBioSignalUpdate()
            }
            .store(in: &bioFeedbackCancellables)

        // Start streaming
        healthKit.startStreaming()

        Log.biofeedback("💓 Biometric monitoring enabled")
    }

    /// Disable biometric monitoring
    public func disableBiometricMonitoring() {
        bioFeedbackCancellables.removeAll()
        healthKitEngine?.stopStreaming()
        healthKitEngine = nil
        bioParameterMapper = nil
        Log.biofeedback("💓 Biometric monitoring disabled")
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

        Log.midi("🎹 MIDI 2.0 + MPE enabled")
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

        Log.midi("🎹 MIDI 2.0 disabled")
    }

    // MARK: - Phase 3 Integration

    /// Enable spatial audio engine
    public func enableSpatialAudio() throws {
        let spatial = SpatialAudioEngine()
        try spatial.start()
        self.spatialAudioEngine = spatial
        Log.spatial("🔊 Spatial audio enabled")
    }

    /// Disable spatial audio
    public func disableSpatialAudio() {
        spatialAudioEngine?.stop()
        spatialAudioEngine = nil
        Log.spatial("🔊 Spatial audio disabled")
    }

    /// Enable MIDI to visual mapping
    public func enableVisualMapping() {
        let visualMapper = MIDIToVisualMapper()
        self.midiToVisualMapper = visualMapper
        Log.info("🎨 Visual mapping enabled", category: .system)
    }

    /// Disable visual mapping
    public func disableVisualMapping() {
        midiToVisualMapper = nil
        Log.info("🎨 Visual mapping disabled", category: .system)
    }

    /// Enable Push 3 LED controller
    public func enablePush3LED() throws {
        let push3 = Push3LEDController()
        try push3.connect()
        self.push3LEDController = push3
        Log.info("💡 Push 3 LED controller enabled", category: .system)
    }

    /// Disable Push 3 LED
    public func disablePush3LED() {
        push3LEDController?.disconnect()
        push3LEDController = nil
        Log.info("💡 Push 3 LED controller disabled", category: .system)
    }

    /// Enable DMX/LED strip lighting
    public func enableLighting() throws {
        let lighting = MIDIToLightMapper()
        try lighting.connect()
        self.midiToLightMapper = lighting
        Log.info("💡 DMX lighting enabled", category: .system)
    }

    /// Disable lighting
    public func disableLighting() {
        midiToLightMapper?.disconnect()
        midiToLightMapper = nil
        Log.info("💡 DMX lighting disabled", category: .system)
    }

    /// Enable ILDA laser control
    /// Supports: Ether Dream, LaserCube, Pangolin Beyond, Generic ILDA DACs
    /// - Parameters:
    ///   - dacType: Type of DAC to connect to
    ///   - address: DAC network address (default: 192.168.1.100)
    ///   - port: DAC port (default: 7765 for Ether Dream)
    public func enableLaserControl(
        dacType: ILDALaserController.DACType = .etherDream,
        address: String = "192.168.1.100",
        port: UInt16 = ILDAConstants.etherDreamPort
    ) async throws {
        let laser = ILDALaserController()
        try await laser.connect(type: dacType, address: address, port: port)
        laser.startOutput(frameRate: 30)
        self.iLDALaserController = laser
        Log.led("🔦 ILDA Laser enabled: \(dacType.rawValue) @ \(address):\(port)")
    }

    /// Disable laser control
    public func disableLaserControl() {
        iLDALaserController?.stopOutput()
        iLDALaserController?.disconnect()
        iLDALaserController = nil
        Log.led("🔦 ILDA Laser disabled")
    }

    /// Set laser pattern
    public func setLaserPattern(_ pattern: LaserPattern) {
        iLDALaserController?.currentPattern = pattern
    }

    /// Get available laser patterns
    public var availableLaserPatterns: [LaserPattern] {
        LaserPattern.allCases
    }

    // MARK: - Phase λ∞: Lambda Mode

    /// Enable Lambda Mode with physical light output
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public func enableLambdaMode() {
        let lambda = LambdaModeEngine()

        // Connect Lambda Mode to physical lights if available
        if let lighting = midiToLightMapper {
            lambda.connectToLightMapper(lighting)
        }

        lambda.activate()
        self.lambdaModeEngine = lambda
        Log.lambda("λ∞ Lambda Mode enabled with physical light output")
    }

    /// Disable Lambda Mode
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public func disableLambdaMode() {
        lambdaModeEngine?.deactivate()
        lambdaModeEngine?.disconnectFromLightMapper()
        lambdaModeEngine = nil
        Log.lambda("λ∞ Lambda Mode disabled")
    }

    /// Get current Lambda Mode state
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public var lambdaState: LambdaState? {
        lambdaModeEngine?.state
    }

    /// Get Lambda Mode score (0-1)
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public var lambdaScore: Double {
        lambdaModeEngine?.lambdaScore ?? 0.0
    }

    /// Update Lambda Mode with bio data from HealthKit
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public func updateLambdaModeWithBioData() {
        guard let lambda = lambdaModeEngine,
              let healthKit = healthKitEngine else { return }

        var bioData = UnifiedBioData()
        bioData.heartRate = healthKit.heartRate
        bioData.hrvCoherence = AudioConstants.Coherence.normalize(healthKit.coherence)
        bioData.breathingRate = healthKit.breathingRate
        lambda.updateBioData(bioData)
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

        Log.info("⚛️ Quantum Light Emulator enabled in \(mode.rawValue) mode\n  - Qubits: \(config.qubitCount)\n  - Photons: \(config.photonCount)\n  - Field Geometry: \(config.lightFieldGeometry.rawValue)", category: .system)
    }

    /// Disable Quantum Light Emulator
    public func disableQuantumLightEmulator() {
        quantumLightEmulator?.stop()
        photonicsVisualization?.stop()
        quantumLightEmulator = nil
        photonicsVisualization = nil
        Log.info("⚛️ Quantum Light Emulator disabled", category: .system)
    }

    // MARK: - Phase 10000+: Ultimate Hardware Ecosystem

    /// Enable the Ultimate Hardware Ecosystem for universal device connectivity
    /// Supports 60+ audio interfaces, 40+ MIDI controllers, DMX/Art-Net lighting,
    /// video/broadcast equipment, VR/AR devices, wearables, and more
    public func enableHardwareEcosystem() {
        hardwareEcosystem = HardwareEcosystem.shared

        // Log ecosystem status
        Task {
            // Log discovered devices
            if let ecosystem = hardwareEcosystem {
                Log.info("🔌 Hardware Ecosystem enabled\n  - Connected devices: \(ecosystem.connectedDevices.count)\n  - Audio interfaces available: \(ecosystem.audioInterfaces.interfaces.count)\n  - MIDI controllers available: \(ecosystem.midiControllers.controllers.count)\n  - Lighting fixtures available: \(ecosystem.lightingHardware.supportedFixtures.count)", category: .system)
            }
        }
    }

    /// Disable Hardware Ecosystem
    public func disableHardwareEcosystem() {
        hardwareEcosystem = nil
        Log.info("🔌 Hardware Ecosystem disabled", category: .system)
    }

    /// Enable Cross-Platform Session Manager for multi-device sessions
    /// Supports ANY device combination: iPhone + Windows, Android + Mac, etc.
    public func enableCrossPlatformSessions() {
        crossPlatformSessionManager = CrossPlatformSessionManager.shared

        // Start device discovery
        crossPlatformSessionManager?.startDiscovery()

        Log.info("🌐 Cross-Platform Session Manager enabled\n  - Adaptive zero-latency mode active\n  - Supported ecosystems: Apple, Google, Microsoft, Meta, Linux, Tesla", category: .system)
    }

    /// Disable Cross-Platform Session Manager
    public func disableCrossPlatformSessions() {
        crossPlatformSessionManager?.stopDiscovery()
        crossPlatformSessionManager = nil
        Log.info("🌐 Cross-Platform Session Manager disabled", category: .system)
    }

    /// Create a cross-platform session with specified devices
    /// - Parameters:
    ///   - name: Session name
    ///   - devices: Devices to include in the session
    ///   - syncMode: Synchronization mode (adaptive, lowLatency, highQuality)
    /// - Returns: The created session
    public func createCrossPlatformSession(
        name: String,
        devices: [SessionDevice],
        syncMode: SyncMode = .adaptive
    ) -> CrossPlatformSession? {
        guard let manager = crossPlatformSessionManager else {
            Log.warning("⚠️ Cross-Platform Session Manager not enabled", category: .system)
            return nil
        }

        let session = manager.createSession(name: name, devices: devices, syncMode: syncMode)
        Log.info("🌐 Created cross-platform session: \(name)\n  - Devices: \(devices.count)\n  - Sync mode: \(syncMode)", category: .system)
        return session
    }

    /// Get recommended audio interface for current platform
    public func getRecommendedAudioInterface() -> AudioInterfaceRegistry.AudioInterface? {
        return hardwareEcosystem?.audioInterfaces.interfaces.first
    }

    /// Get all connected MIDI controllers
    public func getConnectedMIDIControllers() -> [MIDIControllerRegistry.MIDIController] {
        guard let ecosystem = hardwareEcosystem else { return [] }
        // O(1) lookup set instead of O(n) linear scan per controller
        let connectedNames = Set(ecosystem.connectedDevices.map { $0.name })
        return ecosystem.midiControllers.controllers.filter { connectedNames.contains($0.model) }
    }

    /// Get all available lighting fixtures
    public func getAvailableLightingFixtures() -> [LightingHardwareRegistry.LightingFixture] {
        return hardwareEcosystem?.lightingHardware.supportedFixtures ?? []
    }

    /// Sync biometric data across all devices in cross-platform session
    public func syncBiometricsToSession(hrvCoherence: Float, heartRate: Float, breathingRate: Float) {
        let bioData = BiometricSyncData(
            heartRate: Double(heartRate),
            coherence: Double(hrvCoherence),
            breathingRate: Double(breathingRate),
            sourceDeviceId: UUID().uuidString
        )
        crossPlatformSessionManager?.syncBiometricData(bioData)
    }

    /// Sync audio parameters across all devices in cross-platform session
    public func syncAudioParametersToSession(bpm: Float, filterCutoff: Float, reverbWet: Float) {
        let params = AudioSyncParameters(
            bpm: Double(bpm),
            volume: 0.8,
            reverbMix: reverbWet,
            filterCutoff: filterCutoff,
            sourceDeviceId: UUID().uuidString
        )
        crossPlatformSessionManager?.syncAudioParameters(params)
    }

    // MARK: - Phase λ∞: Eye Gaze Tracking

    /// Enable eye gaze tracking for bio-reactive control
    /// Available on visionOS, iPad Pro with Face ID, and ARKit-enabled devices
    @available(iOS 15.0, macOS 12.0, *)
    public func enableGazeTracking() {
        gazeTrackingCancellables.removeAll()

        let tracker = GazeTracker()
        self.gazeTracker = tracker

        // Subscribe to gaze updates
        tracker.$currentGaze
            .debounce(for: .milliseconds(16), scheduler: DispatchQueue.main)
            .sink { [weak self] gazeData in
                self?.handleGazeUpdate(gazeData)
            }
            .store(in: &gazeTrackingCancellables)

        // Subscribe to attention level changes — use removeDuplicates instead of debounce
        // to avoid 50ms latency while still filtering redundant updates
        tracker.$attentionLevel
            .removeDuplicates(by: { abs($0 - $1) < 0.01 })
            .sink { [weak self] attention in
                self?.handleAttentionChange(attention)
            }
            .store(in: &gazeTrackingCancellables)

        // Subscribe to zone changes for discrete control
        tracker.$currentZone
            .removeDuplicates()
            .sink { [weak self] zone in
                self?.handleGazeZoneChange(zone)
            }
            .store(in: &gazeTrackingCancellables)

        tracker.startTracking()

        Log.spatial("👁️ Gaze tracking enabled\n  - Available: \(tracker.isAvailable)\n  - Tracking: \(tracker.isTracking)")
    }

    /// Disable eye gaze tracking
    @available(iOS 15.0, macOS 12.0, *)
    public func disableGazeTracking() {
        gazeTrackingCancellables.removeAll()
        gazeTracker?.stopTracking()
        gazeTracker = nil
        Log.spatial("👁️ Gaze tracking disabled")
    }

    /// Handle gaze data updates
    @available(iOS 15.0, macOS 12.0, *)
    private func handleGazeUpdate(_ gazeData: GazeData) {
        guard let tracker = gazeTracker else { return }

        let params = tracker.getControlParameters()

        // Apply gaze-based audio panning
        if let spatial = spatialAudioEngine {
            // Map gaze X to pan (-1 to +1)
            let pan = params.audioPan
            spatial.setPan(pan)
        }

        // Apply gaze-based filter modulation
        if let engine = audioEngine {
            // Filter cutoff based on attention and stability
            let cutoffFactor = params.filterCutoff
            let baseCutoff: Float = 200.0
            let maxCutoff: Float = 8000.0
            let cutoff = baseCutoff + cutoffFactor * (maxCutoff - baseCutoff)
            engine.setFilterCutoff(cutoff)
        }

        // Apply to quantum light emulator
        if let quantum = quantumLightEmulator {
            // Map arousal to quantum coherence influence
            quantum.updateGazeInputs(
                gazeX: params.gazeX,
                gazeY: params.gazeY,
                attention: params.attention,
                arousal: params.arousal
            )
        }

        // Apply to visuals
        if let visualMapper = midiToVisualMapper {
            visualMapper.updateGazeParameters(
                gazeX: params.gazeX,
                gazeY: params.gazeY,
                attention: params.attention,
                focus: params.focus
            )
        }
    }

    /// Handle attention level changes
    @available(iOS 15.0, macOS 12.0, *)
    private func handleAttentionChange(_ attention: Float) {
        // Modulate reverb based on attention (less attention = more reverb/dreamlike)
        let reverbWet = 1.0 - attention
        audioEngine?.setReverbWetness(reverbWet * 0.5)

        // Update visual intensity
        midiToVisualMapper?.setIntensity(attention)
    }

    /// Handle gaze zone changes for discrete audio-visual control
    @available(iOS 15.0, macOS 12.0, *)
    private func handleGazeZoneChange(_ zone: GazeZone) {
        // Map zones to presets or parameters
        switch zone {
        case .topLeft:
            // High frequencies, left pan
            audioEngine?.setFilterCutoff(6000)
        case .topCenter:
            // Bright, centered
            audioEngine?.setFilterCutoff(8000)
        case .topRight:
            // High frequencies, right pan
            audioEngine?.setFilterCutoff(6000)
        case .centerLeft:
            // Mid frequencies, left
            audioEngine?.setFilterCutoff(2000)
        case .center:
            // Balanced
            audioEngine?.setFilterCutoff(4000)
        case .centerRight:
            // Mid frequencies, right
            audioEngine?.setFilterCutoff(2000)
        case .bottomLeft:
            // Bass, left
            audioEngine?.setFilterCutoff(500)
        case .bottomCenter:
            // Deep bass
            audioEngine?.setFilterCutoff(200)
        case .bottomRight:
            // Bass, right
            audioEngine?.setFilterCutoff(500)
        }

        #if DEBUG
        Log.spatial("[Gaze→Audio] Zone: \(zone.displayName)")
        #endif
    }

    /// Get current gaze control parameters
    @available(iOS 15.0, macOS 12.0, *)
    public func getGazeControlParameters() -> GazeControlParameters? {
        return gazeTracker?.getControlParameters()
    }

    /// Check if gaze tracking is available
    @available(iOS 15.0, macOS 12.0, *)
    public var isGazeTrackingAvailable: Bool {
        gazeTracker?.isAvailable ?? false
    }

    /// Check if gaze tracking is currently active
    @available(iOS 15.0, macOS 12.0, *)
    public var isGazeTrackingActive: Bool {
        gazeTracker?.isTracking ?? false
    }

    /// Get current quantum coherence level
    public var quantumCoherenceLevel: Float {
        quantumLightEmulator?.coherenceLevel ?? 0.0
    }

    /// Get current light field for visualization
    public var currentEmulatorLightField: EmulatorLightField? {
        quantumLightEmulator?.currentEmulatorLightField
    }

    /// Set quantum emulation mode
    public func setQuantumMode(_ mode: QuantumLightEmulator.EmulationMode) {
        quantumLightEmulator?.setMode(mode)
    }

    // MARK: - Lifecycle

    /// Start the unified control system
    public func start() {
        Log.info("Starting control system...", category: .system)

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
        Log.info("Stopping control system...", category: .system)

        #if os(iOS) || os(tvOS)
        displayLink?.invalidate()
        displayLink = nil
        #endif

        // LAMBDA LOOP: Clean up high-precision timer
        controlLoopTimer?.cancel()
        controlLoopTimer = nil

        // Stop quantum emulator if running
        quantumLightEmulator?.stop()
        photonicsVisualization?.stop()

        // Stop ILDA laser
        iLDALaserController?.stopOutput()
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
        // LAMBDA LOOP: macOS/watchOS use DispatchSourceTimer for 50% lower jitter
        controlLoopTimer?.cancel()
        let interval = 1.0 / targetFrequency
        let timer = DispatchSource.makeTimerSource(flags: [], queue: controlQueue)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.controlLoopTick()
            }
        }
        timer.resume()
        controlLoopTimer = timer
        #endif
    }

    #if os(iOS) || os(tvOS)
    @objc private func displayLinkFired(_ link: CADisplayLink) {
        controlLoopTick()
    }
    #endif

    /// Signpost ID for Instruments profiling of control loop frame budget
    private let controlSignpostID = OSSignpostID(log: PerformanceSignposts.controlLoop)

    private func controlLoopTick() {
        // Skip entirely when backgrounded
        guard !isBackgrounded else { return }

        // os_signpost for Instruments frame budget visualization
        PerformanceSignposts.beginControlTick(controlSignpostID)
        defer { PerformanceSignposts.endControlTick(controlSignpostID) }

        // Measure actual frequency using CACurrentMediaTime (no allocation)
        let now = CACurrentMediaTime()
        let deltaTime = now - lastUpdateTime
        controlLoopFrequency = deltaTime > 0 ? 1.0 / deltaTime : targetFrequency
        lastUpdateTime = now

        // Priority-based parameter updates (always run — <1ms total)
        updateFromBioSignals()
        updateFromFaceTracking()
        updateFromHandGestures()
        updateFromGazeTracking()

        // Check for gesture conflicts
        resolveConflicts()

        // Update all output systems — skip visuals/lights under thermal pressure
        updateAudioEngine()
        if thermalPressure != .critical {
            updateVisualEngine()
        }
        if thermalPressure == .nominal || thermalPressure == .fair {
            updateLightSystems()
        }
    }

    // MARK: - Input Updates

    private func updateFromBioSignals() {
        guard let healthKit = healthKitEngine,
              let mapper = bioParameterMapper else {
            return
        }

        // Get current biometric data (coherence is 0-1, convert to 0-100 for compatibility)
        let hrvCoherence = healthKit.coherence * 100.0
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
        Log.biofeedback("[Bio→Audio] Filter: \(Int(mapper.filterCutoff))Hz, Reverb: \(Int(mapper.reverbWet * 100))%, Tempo: \(Int(mapper.tempo))BPM")
        #endif

        // Apply bio-reactive spatial field (AFA)
        if let mpe = mpeZoneManager, let spatialMapper = midiToSpatialMapper {
            // Convert active MPE voices to spatial field
            // Reuse pre-allocated buffer to avoid per-tick allocations in 60Hz loop
            voiceDataBuffer.removeAll(keepingCapacity: true)
            for voice in mpe.activeVoices {
                voiceDataBuffer.append(MPEVoiceData(
                    id: voice.id,
                    note: voice.note,
                    velocity: voice.velocity,
                    pitchBend: voice.pitchBend,
                    brightness: voice.brightness
                ))
            }
            let voiceData = voiceDataBuffer

            // Morph AFA field geometry based on HRV coherence
            let fieldGeometry: MIDIToSpatialMapper.AFAField.FieldGeometry
            let coherence = (healthKitEngine?.coherence ?? 0.5) * 100.0  // Convert 0-1 to 0-100

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

                // Apply AFA field to SpatialAudioEngine
                if let spatialEngine = spatialAudioEngine {
                    // Position sources according to AFA field geometry
                    for source in afaField.sources {
                        spatialEngine.updateSourcePosition(
                            id: source.id,
                            position: SIMD3<Float>(source.position.x, source.position.y, source.position.z)
                        )

                        // Apply coherence-based reverb blend
                        let reverbBlend = AudioConstants.Coherence.normalize(Float(coherence))
                        spatialEngine.setReverbBlend(reverbBlend)
                    }

                    #if DEBUG
                    Log.biofeedback("[Bio→AFA] Field geometry: \(fieldGeometry), Sources: \(afaField.sources.count), Coherence: \(coherence)%")
                    #endif
                }
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
        // Apply to actual AudioEngine
        if let engine = audioEngine {
            engine.setFilterCutoff(Float(params.filterCutoff))
            engine.setFilterResonance(Float(params.filterResonance))

            #if DEBUG
            Log.spatial("[Face→Audio] Cutoff: \(Int(params.filterCutoff)) Hz, Q: \(String(format: "%.2f", params.filterResonance))")
            #endif
        }

        // Apply to all active MPE voices
        if let mpe = mpeZoneManager {
            for voice in mpe.activeVoices {
                // Jaw open → Per-note brightness (CC 74)
                let jawOpen = Float(params.filterCutoff / 8000.0)  // Normalize cutoff to 0-1
                mpe.setVoiceBrightness(voice: voice, brightness: jawOpen)

                // Smile → Per-note timbre (CC 71)
                let smile = Float(params.filterResonance / 5.0)  // Normalize resonance to 0-1
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
        let confidence = gestureRecognizer.gestureConfidence // Use gesture confidence
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

        // FIXED: Apply filter parameters with explicit Float conversion
        if let cutoff = params.filterCutoff {
            engine.setFilterCutoff(Float(cutoff))
        }

        if let resonance = params.filterResonance {
            engine.setFilterResonance(Float(resonance))
        }

        // FIXED: Apply reverb parameters with explicit Float conversion
        if let size = params.reverbSize {
            engine.setReverbSize(Float(size))
        }

        if let wetness = params.reverbWetness {
            engine.setReverbWetness(Float(wetness))
        }

        // FIXED: Apply delay parameters
        if let delayTime = params.delayTime {
            engine.setDelayTime(delayTime)
        }

        #if DEBUG
        Log.info("[Gesture→Audio] Applied: Filter=\(params.filterCutoff ?? 0)Hz, Reverb=\(params.reverbWetness ?? 0)", category: .system)
        #endif

        // Trigger MIDI notes via MPE
        if let midiNote = params.midiNoteOn {
            if let mpe = mpeZoneManager {
                // Allocate MPE voice for polyphonic expression
                if let voice = mpe.allocateVoice(
                    note: midiNote.note,
                    velocity: Float(midiNote.velocity) / 127.0
                ) {
                    Log.midi("[Gesture→MPE] Voice allocated: Note \(midiNote.note), Channel \(voice.channel + 1)")

                    // Apply initial per-note expression from gestures
                    if let gestureRec = gestureRecognizer {
                        // Pinch amount → Pitch bend
                        let pinchBend = (gestureRec.leftPinchAmount * 2.0) - 1.0  // Map 0-1 to -1 to +1
                        mpe.setVoicePitchBend(voice: voice, bend: pinchBend)

                        // Spread amount → Brightness
                        mpe.setVoiceBrightness(voice: voice, brightness: gestureRec.rightPinchAmount)
                    }
                }
            } else {
                // Fallback to MIDI 1.0 if MPE not enabled
                Log.midi("[Gesture→MIDI] Note On: \(midiNote.note), Velocity: \(midiNote.velocity)")
            }
        }

        // Handle preset changes
        if let presetChange = params.presetChange {
            Log.info("[Gesture→Audio] Preset change requested: \(presetChange)", category: .system)
            audioEngine?.loadPreset(named: String(presetChange))
        }
    }

    private func updateFromGazeTracking() {
        // Gaze tracking updates happen via Combine subscription
        // See handleGazeUpdate(), handleAttentionChange(), handleGazeZoneChange()
        // This method is called at 60Hz but actual processing is event-driven

        if #available(iOS 15.0, macOS 12.0, *) {
            guard let tracker = gazeTracker, tracker.isTracking else { return }

            // Sync gaze data to cross-platform session if active
            if let _ = crossPlatformSessionManager?.activeSession {
                let params = tracker.getControlParameters()
                // Gaze-derived parameters can be synced as part of biometric data
                let hrvModifier = params.attention * 20  // Attention affects coherence perception
                syncBiometricsToSession(
                    hrvCoherence: Float(healthKitEngine?.coherence ?? 0.5) * 100 + Float(hrvModifier),
                    heartRate: Float(healthKitEngine?.heartRate ?? 72),
                    breathingRate: Float(healthKitEngine?.breathingRate ?? 12)
                )
            }
        }
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
        guard let healthKit = healthKitEngine else {
            return
        }

        // Update visual parameters from bio-signals
        let bioParams = MIDIToVisualMapper.BioParameters(
            hrvCoherence: healthKit.coherence,
            heartRate: healthKit.heartRate,
            breathingRate: healthKit.breathingRate,
            audioLevel: Float(audioEngine?.currentLevel ?? 0.5)
        )

        if let visualMapper = midiToVisualMapper {
            visualMapper.updateBioParameters(bioParams)
        }

        // Update Quantum Light Emulator with bio-inputs
        if let quantumEmulator = quantumLightEmulator {
            quantumEmulator.updateBioInputs(
                hrvCoherence: Float(healthKit.coherence),
                heartRate: Float(healthKit.heartRate),
                breathingRate: Float(healthKit.breathingRate)
            )
        }

        // Update Lambda Mode Engine with bio data
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            if let lambda = lambdaModeEngine {
                var bioData = UnifiedBioData()
                bioData.heartRate = healthKit.heartRate
                bioData.hrvCoherence = AudioConstants.Coherence.normalize(healthKit.coherence)
                bioData.breathingRate = healthKit.breathingRate
                lambda.updateBioData(bioData)
            }
        }
    }

    private func updateLightSystems() {
        guard let healthKit = healthKitEngine else {
            return
        }

        let bioData = MIDIToLightMapper.BioData(
            hrvCoherence: healthKit.coherence,
            heartRate: healthKit.heartRate,
            breathingRate: healthKit.breathingRate
        )

        // Update Push 3 LED patterns
        if let push3 = push3LEDController {
            push3.updateFromBioSignals(
                hrvCoherence: Double(bioData.hrvCoherence),
                heartRate: Double(bioData.heartRate)
            )
        }

        // Normalize coherence once using standard utility
        let normalizedCoherence = AudioConstants.Coherence.normalize(bioData.hrvCoherence)

        // Update DMX/LED strip lighting
        if let lighting = midiToLightMapper {
            if useOctaveBasedLighting {
                // Octave-based: HR → Audio (f × 2^n) → Light → CIE 1931 RGB
                // Uses UnifiedVisualSoundEngine.OctaveTransposition for physics
                lighting.updateFromOctaveBio(
                    heartRate: bioData.heartRate,
                    coherence: normalizedCoherence,
                    octaves: lightingOctaveShift
                )
            } else {
                // Legacy: Simple hue-based mapping
                lighting.updateBioReactive(bioData)
            }
        }

        // Update ILDA Laser with octave-based hue
        if let laser = iLDALaserController {
            if useOctaveBasedLighting {
                // Calculate octave-based hue from heart rate
                // HR → Audio (f × 2^n) → Light wavelength → Hue (0-1)
                let heartHz = Float(bioData.heartRate) / 60.0
                let audioFreq = heartHz * pow(2.0, Float(lightingOctaveShift))
                let hue = wavelengthToHue(audioFrequency: audioFreq)

                laser.updateBioReactive(
                    coherence: normalizedCoherence,
                    heartRate: bioData.heartRate,
                    hue: hue
                )
            } else {
                // Legacy: Simple coherence-based hue
                let hue = Float(normalizedCoherence) * 0.7  // 0-0.7 (red to violet)
                laser.updateBioReactive(
                    coherence: normalizedCoherence,
                    heartRate: bioData.heartRate,
                    hue: hue
                )
            }
        }
    }

    // MARK: - Octave Color Helpers

    /// Convert audio frequency to hue (0-1) via light wavelength
    /// Uses the physics-based octave transposition: Audio → Light (f × 2^n)
    private func wavelengthToHue(audioFrequency: Float) -> Float {
        // Audio to light: ~40 octaves up (20Hz → 400THz)
        // Visible light: 380-780nm (789-384 THz)
        let lightTHz = audioFrequency * pow(2.0, 40) / 1e12  // Convert to THz

        // Clamp to visible range
        let clampedTHz = max(384, min(789, lightTHz))

        // Convert frequency to wavelength: λ = c / f
        let wavelengthNm = 299792458.0 / (Double(clampedTHz) * 1e12) * 1e9

        // Map wavelength (380-780nm) to hue (0.0-0.83)
        // 380nm (violet) → 0.83, 780nm (red) → 0.0
        let normalizedWavelength = (wavelengthNm - 380) / 400  // 0-1
        let hue = Float((1.0 - normalizedWavelength) * 0.83)

        return max(0, min(1, hue))
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

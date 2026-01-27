import Foundation
import SwiftUI
import RealityKit
import AVFoundation
import Combine

#if os(visionOS)

// MARK: - Echoelmusic visionOS App

/// Main App structure for visionOS with immersive space support
@main
struct EchoelmusicVisionApp: App {

    @State private var immersionStyle: ImmersionStyle = .mixed

    var body: some Scene {
        // Main window
        WindowGroup {
            VisionContentView()
        }
        .windowStyle(.volumetric)

        // Immersive space for full experiences
        ImmersiveSpace(id: "echoelImmersive") {
            EchoelImmersiveSpace()
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed, .full, .progressive)

        // Experience picker window
        WindowGroup(id: "experiencePicker") {
            ImmersiveExperiencePicker()
        }
        .windowStyle(.plain)
        .defaultSize(width: 800, height: 600)

        // Bio display ornament
        WindowGroup(id: "bioDisplay") {
            SpatialBioDisplay()
        }
        .windowStyle(.plain)
        .defaultSize(width: 200, height: 200)
    }
}

// MARK: - Vision Content View

struct VisionContentView: View {

    @Environment(\.openWindow) var openWindow
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    @State private var manager = ImmersiveExperienceManager.shared
    @State private var visionApp = VisionApp()
    @StateObject private var healthKit = HealthKitManager()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                VaporwaveGradients.background
                    .ignoresSafeArea()

                VStack(spacing: VaporwaveSpacing.xl) {

                    // Header
                    headerSection

                    Spacer()

                    // Bio metrics
                    bioMetricsSection

                    Spacer()

                    // Quick actions
                    quickActionsSection

                    // Mode selector
                    modeSelector

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Echoelmusic")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                ImmersiveSettingsView()
            }
        }
        .task {
            do {
                try await healthKit.requestAuthorization()
            } catch {
                // Log error but don't crash - HealthKit is optional on visionOS
                Logger.warning("HealthKit authorization failed: \(error.localizedDescription)", subsystem: .healthKit)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            Text("ECHOELMUSIC")
                .font(VaporwaveTypography.heroTitle())
                .foregroundColor(VaporwaveColors.textPrimary)
                .neonGlow(color: VaporwaveColors.neonCyan, radius: 15)

            Text("Immersive Bio-Reactive Audio")
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textTertiary)
                .tracking(4)
        }
    }

    // MARK: - Bio Metrics

    private var bioMetricsSection: some View {
        HStack(spacing: VaporwaveSpacing.xxl) {
            // Heart Rate
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundColor(VaporwaveColors.heartRate)
                    .neonGlow(color: VaporwaveColors.heartRate, radius: 10)

                Text("\(Int(healthKit.heartRate))")
                    .font(VaporwaveTypography.data())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("BPM")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .hoverEffect(.lift)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Heart rate: \(Int(healthKit.heartRate)) beats per minute")

            // Coherence
            VStack(spacing: VaporwaveSpacing.sm) {
                VaporwaveProgressRing(
                    progress: healthKit.hrvCoherence / 100.0,
                    color: coherenceColor,
                    lineWidth: 6,
                    size: 80
                )
                .overlay {
                    Text("\(Int(healthKit.hrvCoherence))")
                        .font(VaporwaveTypography.data())
                        .foregroundColor(coherenceColor)
                }

                Text("Coherence")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .hoverEffect(.lift)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Coherence level: \(Int(healthKit.hrvCoherence)) percent, \(coherenceState)")

            // HRV
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 40))
                    .foregroundColor(VaporwaveColors.hrv)
                    .neonGlow(color: VaporwaveColors.hrv, radius: 10)

                Text(String(format: "%.0f", healthKit.hrvRMSSD))
                    .font(VaporwaveTypography.data())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("HRV ms")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .hoverEffect(.lift)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Heart rate variability: \(Int(healthKit.hrvRMSSD)) milliseconds")
        }
        .padding(VaporwaveSpacing.xl)
        .glassCard()
    }

    private var coherenceState: String {
        if healthKit.hrvCoherence < 40 {
            return "low"
        } else if healthKit.hrvCoherence < 60 {
            return "medium"
        } else {
            return "high"
        }
    }

    private var coherenceColor: Color {
        if healthKit.hrvCoherence < 40 {
            return VaporwaveColors.coherenceLow
        } else if healthKit.hrvCoherence < 60 {
            return VaporwaveColors.coherenceMedium
        } else {
            return VaporwaveColors.coherenceHigh
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        HStack(spacing: VaporwaveSpacing.lg) {
            // Start Experience
            VaporwaveControlButton(
                icon: "visionpro.fill",
                label: "Experience",
                isActive: manager.isImmersive,
                color: VaporwaveColors.neonPink,
                size: 80
            ) {
                openWindow(id: "experiencePicker")
            }

            // Record
            VaporwaveControlButton(
                icon: "record.circle",
                label: "Record",
                isActive: ImmersiveVideoCaptureManager.shared.captureState == .recording,
                color: VaporwaveColors.coral,
                size: 80
            ) {
                Task {
                    if ImmersiveVideoCaptureManager.shared.captureState == .recording {
                        _ = try? await ImmersiveVideoCaptureManager.shared.stopRecording()
                    } else {
                        try? await ImmersiveVideoCaptureManager.shared.startRecording()
                    }
                }
            }

            // Bio Display
            VaporwaveControlButton(
                icon: "waveform.path.ecg.rectangle",
                label: "Bio Display",
                color: VaporwaveColors.neonCyan,
                size: 80
            ) {
                openWindow(id: "bioDisplay")
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            Text("IMMERSION MODE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(VaporwaveColors.textTertiary)
                .tracking(2)

            HStack(spacing: VaporwaveSpacing.md) {
                ForEach(ImmersiveMode.allCases, id: \.self) { mode in
                    Button(action: {
                        Task {
                            await manager.setMode(mode)
                        }
                    }) {
                        VStack(spacing: VaporwaveSpacing.xs) {
                            Image(systemName: mode.systemImage)
                                .font(.system(size: 20))

                            Text(mode.rawValue)
                                .font(VaporwaveTypography.label())
                        }
                        .foregroundColor(manager.currentMode == mode ? VaporwaveColors.neonCyan : VaporwaveColors.textSecondary)
                        .padding(VaporwaveSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(manager.currentMode == mode ? VaporwaveColors.neonCyan.opacity(0.2) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(manager.currentMode == mode ? VaporwaveColors.neonCyan : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .hoverEffect(.highlight)
                }
            }
        }
    }
}

// MARK: - VisionApp (Legacy Support)
@MainActor
class VisionApp: ObservableObject {

    // MARK: - Published Properties

    /// Aktueller Immersion-Level
    @Published var immersionLevel: ImmersionLevel = .mixed

    /// Aktive 3D-Szene
    @Published var activeScene: ImmersiveScene?

    /// Spatial Audio aktiviert
    @Published var spatialAudioEnabled: Bool = true

    /// Eye-Tracking-Daten
    @Published var eyeTrackingData: EyeTrackingData?

    /// Hand-Tracking-Daten
    @Published var handTrackingData: HandTrackingData?

    // MARK: - Private Properties

    private let realityKitEngine: RealityKitEngine
    private let spatialAudioEngine: VisionSpatialAudioEngine
    private let eyeTracker: EyeTracker
    private let handTracker: HandTracker
    private let immersionController: ImmersionController

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Immersion Level

    enum ImmersionLevel: String, CaseIterable {
        case windowed = "Fenster-Modus"
        case mixed = "Mixed Reality"
        case full = "Vollständig Immersiv"

        var description: String {
            switch self {
            case .windowed:
                return "Normale App-Fenster mit Passthrough"
            case .mixed:
                return "3D-Inhalte gemischt mit Realität"
            case .full:
                return "Vollständige 360° Immersion"
            }
        }
    }

    // MARK: - Immersive Scene

    struct ImmersiveScene {
        let id: UUID = UUID()
        let type: SceneType
        var entities: [RealityKit.Entity] = []
        var audioSources: [SpatialAudioSource] = []

        enum SceneType: String, CaseIterable {
            case meditation = "Meditations-Raum"
            case cosmos = "Kosmos"
            case nature = "Natur"
            case abstract = "Abstrakte Geometrie"
            case particleField = "Partikel-Feld"
            case bioReactiveSphere = "Bio-Reaktive Sphäre"
            case quantumField = "Quanten-Feld"
            case sacredGeometry = "Heilige Geometrie"

            var description: String {
                switch self {
                case .meditation:
                    return "Ruhiger Raum mit sanften Farben und Formen"
                case .cosmos:
                    return "Galaxien, Sterne und kosmische Phänomene"
                case .nature:
                    return "Wald, Ozean oder Berge in 360°"
                case .abstract:
                    return "Abstrakte 3D-Geometrie reagiert auf Bio-Daten"
                case .particleField:
                    return "Millionen Partikel tanzen zu Herzschlag"
                case .bioReactiveSphere:
                    return "Sphäre pulsiert mit Herzfrequenz"
                case .quantumField:
                    return "Quantenphänomene visualisiert"
                case .sacredGeometry:
                    return "Blume des Lebens, Metatrons Würfel, etc."
                }
            }
        }

        struct SpatialAudioSource {
            let id: UUID = UUID()
            let position: SIMD3<Float>
            let soundType: SoundType
            var volume: Float = 1.0

            enum SoundType {
                case binauralBeat(frequency: Float)
                case tone(frequency: Float)
                case ambient(type: String)
                case heartbeat(bpm: Float)
                case breathGuide
            }
        }
    }

    // MARK: - Eye Tracking

    struct EyeTrackingData {
        var gazePoint: SIMD3<Float>
        var focusDistance: Float
        var pupilDilation: Float
        var blinkRate: Float
        var timestamp: Date

        /// Eye tracking für Fokus-basierte Meditation
        var isFocused: Bool {
            focusDistance < 2.0 && blinkRate < 20
        }
    }

    // MARK: - Hand Tracking

    struct HandTrackingData {
        var leftHand: HandPose?
        var rightHand: HandPose?
        var timestamp: Date

        struct HandPose {
            var position: SIMD3<Float>
            var rotation: SIMD4<Float>
            var gesture: Gesture?

            enum Gesture {
                case point
                case pinch
                case open
                case fist
                case peace
                case meditation // Daumen und Zeigefinger berühren sich
            }
        }

        /// Meditation-Geste erkannt (beide Hände)
        var isMeditationGesture: Bool {
            leftHand?.gesture == .meditation && rightHand?.gesture == .meditation
        }
    }

    // MARK: - Initialization

    init() {
        self.realityKitEngine = RealityKitEngine()
        self.spatialAudioEngine = VisionSpatialAudioEngine()
        self.eyeTracker = EyeTracker()
        self.handTracker = HandTracker()
        self.immersionController = ImmersionController()

        setupObservers()
        requestPermissions()
    }

    private func setupObservers() {
        // Eye Tracking Updates
        eyeTracker.dataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.eyeTrackingData = data
                self?.handleEyeTrackingUpdate(data)
            }
            .store(in: &cancellables)

        // Hand Tracking Updates
        handTracker.dataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.handTrackingData = data
                self?.handleHandTrackingUpdate(data)
            }
            .store(in: &cancellables)
    }

    private func requestPermissions() {
        // Request permissions for eye tracking, hand tracking, etc.
        Task {
            await eyeTracker.requestAuthorization()
            await handTracker.requestAuthorization()
        }
    }

    // MARK: - Scene Management

    func loadScene(type: ImmersiveScene.SceneType) async throws {
        log.info("👁️ Loading scene: \(type.rawValue)", category: .system)

        // Create scene
        var scene = ImmersiveScene(type: type)

        // Load 3D entities based on scene type
        scene.entities = await realityKitEngine.createEntities(for: type)

        // Setup spatial audio sources
        scene.audioSources = await spatialAudioEngine.createAudioSources(for: type)

        activeScene = scene

        // Start rendering
        await realityKitEngine.startRendering(scene: scene)
        await spatialAudioEngine.startAudio(sources: scene.audioSources)
    }

    func unloadScene() async {
        log.info("👁️ Unloading scene", category: .system)

        await realityKitEngine.stopRendering()
        await spatialAudioEngine.stopAudio()

        activeScene = nil
    }

    // MARK: - Immersion Control

    func setImmersionLevel(_ level: ImmersionLevel) async {
        log.info("👁️ Setting immersion level: \(level.rawValue)", category: .system)
        immersionLevel = level

        await immersionController.transitionTo(level)
    }

    // MARK: - Bio-Reactive Updates

    func updateWithBioData(heartRate: Double, hrv: Double, coherence: Double) async {
        guard let scene = activeScene else { return }

        // Update 3D geometrie basierend auf Bio-Daten
        await realityKitEngine.updateWithBioData(
            entities: scene.entities,
            heartRate: heartRate,
            hrv: hrv,
            coherence: coherence
        )

        // Update Spatial Audio basierend auf Bio-Daten
        await spatialAudioEngine.updateWithBioData(
            sources: scene.audioSources,
            heartRate: heartRate,
            coherence: coherence
        )
    }

    // MARK: - Eye Tracking Handling

    private func handleEyeTrackingUpdate(_ data: EyeTrackingData) {
        // Interaktion basierend auf Blick
        if data.isFocused {
            // User ist fokussiert - intensiviere Visualisierung
            Task {
                await realityKitEngine.setIntensity(1.0)
            }
        } else {
            // User ist abgelenkt - reduziere Intensität
            Task {
                await realityKitEngine.setIntensity(0.5)
            }
        }
    }

    // MARK: - Hand Tracking Handling

    private func handleHandTrackingUpdate(_ data: HandTrackingData) {
        // Erkennung von Meditations-Geste
        if data.isMeditationGesture {
            log.info("🙏 Meditation gesture detected", category: .system)
            // Starte automatisch Meditations-Session
            Task {
                try? await loadScene(type: .meditation)
            }
        }

        // Gesten für Interaktion
        if let leftGesture = data.leftHand?.gesture {
            handleGesture(leftGesture, hand: .left)
        }

        if let rightGesture = data.rightHand?.gesture {
            handleGesture(rightGesture, hand: .right)
        }
    }

    private func handleGesture(_ gesture: HandTrackingData.HandPose.Gesture, hand: HandSide) {
        log.info("👋 Gesture: \(gesture) (\(hand))", category: .system)

        switch gesture {
        case .pinch:
            // Pinch zum Steuern von Parametern
            break
        case .open:
            // Offene Hand zum Pausieren
            break
        case .fist:
            // Faust zum Stoppen
            break
        case .peace:
            // Peace-Zeichen zum Wechseln der Szene
            break
        default:
            break
        }
    }

    enum HandSide {
        case left, right
    }
}

// MARK: - RealityKit Engine

@MainActor
class RealityKitEngine {

    private var isRendering: Bool = false
    private var intensity: Float = 1.0

    func createEntities(for sceneType: VisionApp.ImmersiveScene.SceneType) async -> [Entity] {
        log.info("🎨 Creating 3D entities for: \(sceneType.rawValue)", category: .system)

        var entities: [Entity] = []

        switch sceneType {
        case .bioReactiveSphere:
            // Erstelle pulsierende Sphäre
            let sphere = ModelEntity(mesh: .generateSphere(radius: 1.0))
            entities.append(sphere)

        case .particleField:
            // Erstelle Partikel-System (10,000+ Partikel)
            for _ in 0..<10000 {
                let particle = ModelEntity(mesh: .generateSphere(radius: 0.01))
                entities.append(particle)
            }

        case .sacredGeometry:
            // Erstelle Blume des Lebens
            let geometry = createFlowerOfLife()
            entities.append(geometry)

        default:
            break
        }

        return entities
    }

    private func createFlowerOfLife() -> Entity {
        // Heilige Geometrie: Blume des Lebens
        let container = Entity()

        let radius: Float = 1.0
        let circleCount = 7

        for i in 0..<circleCount {
            let angle = Float(i) * (2.0 * .pi / Float(circleCount))
            let x = cos(angle) * radius
            let z = sin(angle) * radius

            let circle = ModelEntity(mesh: .generateSphere(radius: 0.2))
            circle.position = SIMD3(x, 0, z)

            container.addChild(circle)
        }

        return container
    }

    func startRendering(scene: VisionApp.ImmersiveScene) async {
        log.info("🎨 RealityKit rendering started", category: .system)
        isRendering = true
    }

    func stopRendering() async {
        log.info("🎨 RealityKit rendering stopped", category: .system)
        isRendering = false
    }

    func updateWithBioData(entities: [Entity], heartRate: Double, hrv: Double, coherence: Double) async {
        // Update entity positions, scales, colors based on bio-data
        for entity in entities {
            // Pulsiere mit Herzfrequenz
            let scale = Float(1.0 + hrv * 0.3 * sin(Date().timeIntervalSince1970 * heartRate / 60.0))
            entity.scale = SIMD3(repeating: scale)
        }
    }

    func setIntensity(_ intensity: Float) async {
        self.intensity = intensity
    }
}

// MARK: - Vision Spatial Audio Engine (renamed to avoid conflict with Spatial/SpatialAudioEngine)

@MainActor
class VisionSpatialAudioEngine {

    private var isPlaying: Bool = false

    func createAudioSources(for sceneType: VisionApp.ImmersiveScene.SceneType) async -> [VisionApp.ImmersiveScene.SpatialAudioSource] {
        log.info("🔊 Creating spatial audio sources for: \(sceneType.rawValue)", category: .system)

        var sources: [VisionApp.ImmersiveScene.SpatialAudioSource] = []

        switch sceneType {
        case .meditation:
            // Binaurale Beats in 3D positioniert
            sources.append(VisionApp.ImmersiveScene.SpatialAudioSource(
                position: SIMD3(-2, 0, -2),
                soundType: .binauralBeat(frequency: 7.83) // Schumann-Resonanz
            ))

            sources.append(VisionApp.ImmersiveScene.SpatialAudioSource(
                position: SIMD3(2, 0, -2),
                soundType: .binauralBeat(frequency: 7.83)
            ))

        case .cosmos:
            // Ambient Space Sounds
            sources.append(VisionApp.ImmersiveScene.SpatialAudioSource(
                position: SIMD3(0, 0, -5),
                soundType: .ambient(type: "space")
            ))

        default:
            break
        }

        return sources
    }

    func startAudio(sources: [VisionApp.ImmersiveScene.SpatialAudioSource]) async {
        log.info("🔊 Spatial Audio started with \(sources.count) sources", category: .system)
        isPlaying = true
    }

    func stopAudio() async {
        log.info("🔊 Spatial Audio stopped", category: .system)
        isPlaying = false
    }

    func updateWithBioData(sources: [VisionApp.ImmersiveScene.SpatialAudioSource], heartRate: Double, coherence: Double) async {
        // Update audio parameters based on bio-data
        for source in sources {
            // Passe Frequenz oder Volume an basierend auf Coherence
        }
    }
}

// MARK: - Eye Tracker

@MainActor
class EyeTracker {

    let dataPublisher = PassthroughSubject<VisionApp.EyeTrackingData, Never>()

    func requestAuthorization() async {
        log.info("👁️ Requesting eye tracking authorization", category: .system)
    }

    func startTracking() {
        log.info("👁️ Eye tracking started", category: .system)
        // Start sending updates via dataPublisher
    }

    func stopTracking() {
        log.info("👁️ Eye tracking stopped", category: .system)
    }
}

// MARK: - Hand Tracker

@MainActor
class HandTracker {

    let dataPublisher = PassthroughSubject<VisionApp.HandTrackingData, Never>()

    func requestAuthorization() async {
        log.info("👋 Requesting hand tracking authorization", category: .system)
    }

    func startTracking() {
        log.info("👋 Hand tracking started", category: .system)
        // Start sending updates via dataPublisher
    }

    func stopTracking() {
        log.info("👋 Hand tracking stopped", category: .system)
    }
}

// MARK: - Immersion Controller

@MainActor
class ImmersionController {

    func transitionTo(_ level: VisionApp.ImmersionLevel) async {
        log.info("🌐 Transitioning to immersion level: \(level.rawValue)", category: .system)

        switch level {
        case .windowed:
            // Standard window mode
            break
        case .mixed:
            // Open immersive space with passthrough
            break
        case .full:
            // Full immersion, no passthrough
            break
        }
    }
}

#endif

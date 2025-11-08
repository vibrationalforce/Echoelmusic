import SwiftUI
import RealityKit
#if os(visionOS)
import CompositorServices
#endif

/// Spatial UI Manager for Vision Pro
///
/// Features:
/// - 3D visualization windows
/// - Spatial audio visualization
/// - Immersive environments
/// - Hand tracking integration
/// - Eye tracking for parameter control
/// - Spatial recording/playback
@MainActor
class SpatialUIManager: ObservableObject {

    // MARK: - Published State

    /// Whether spatial UI is active
    @Published var isActive: Bool = false

    /// Current immersion style
    @Published var immersionStyle: ImmersionStyle = .mixed

    /// Spatial windows
    @Published var spatialWindows: [SpatialWindow] = []

    /// Hand tracking enabled
    @Published var handTrackingEnabled: Bool = false

    /// Eye tracking enabled
    @Published var eyeTrackingEnabled: Bool = false

    // MARK: - Configuration

    enum ImmersionStyle {
        case windowed       // Standard 3D windows
        case mixed          // Mixed reality with passthrough
        case immersive      // Full immersion
    }

    struct SpatialWindow: Identifiable {
        let id = UUID()
        var title: String
        var position: SIMD3<Float>
        var size: SIMD2<Float>
        var content: WindowContent

        enum WindowContent {
            case waveform
            case spectrum
            case spatialField
            case biometrics
            case controls
        }
    }

    // MARK: - RealityKit Components

    #if os(visionOS)
    private var rootEntity: Entity?
    private var spatialAudioVisualization: Entity?
    private var bioVisualization: Entity?
    #endif

    // MARK: - Dependencies

    private var spatialAudioEngine: SpatialAudioEngine?
    private var healthKitManager: HealthKitManager?

    // MARK: - Initialization

    init() {
        print("👓 SpatialUIManager initialized")
    }

    // MARK: - Public API

    /// Start spatial UI
    func start() {
        guard !isActive else { return }

        #if os(visionOS)
        setupSpatialEnvironment()
        setupDefaultWindows()
        #endif

        isActive = true
        print("👓 Spatial UI started")
    }

    /// Stop spatial UI
    func stop() {
        isActive = false
        spatialWindows.removeAll()

        #if os(visionOS)
        rootEntity?.removeFromParent()
        rootEntity = nil
        #endif

        print("👓 Spatial UI stopped")
    }

    /// Set immersion style
    func setImmersionStyle(_ style: ImmersionStyle) {
        immersionStyle = style
        print("👓 Immersion style: \(style)")

        #if os(visionOS)
        updateImmersionEnvironment()
        #endif
    }

    /// Add spatial window
    func addWindow(_ window: SpatialWindow) {
        spatialWindows.append(window)
        print("👓 Added spatial window: \(window.title)")
    }

    /// Remove spatial window
    func removeWindow(id: UUID) {
        spatialWindows.removeAll { $0.id == id }
    }

    /// Enable hand tracking
    func enableHandTracking() {
        handTrackingEnabled = true
        #if os(visionOS)
        setupHandTracking()
        #endif
    }

    /// Enable eye tracking
    func enableEyeTracking() {
        eyeTrackingEnabled = true
        #if os(visionOS)
        setupEyeTracking()
        #endif
    }

    /// Update spatial audio visualization
    func updateSpatialVisualization(sources: [SpatialSource]) {
        #if os(visionOS)
        updateSpatialAudioEntities(sources: sources)
        #endif
    }

    /// Update biometric visualization
    func updateBiometricVisualization(hrv: Double, heartRate: Double, coherence: Double) {
        #if os(visionOS)
        updateBioVisualizationEntity(hrv: hrv, heartRate: heartRate, coherence: coherence)
        #endif
    }

    // MARK: - Private Methods

    #if os(visionOS)

    private func setupSpatialEnvironment() {
        // Create root entity
        rootEntity = Entity()

        // Setup lighting
        let lightEntity = Entity()
        let light = PointLight()
        light.light.intensity = 5000
        lightEntity.components.set(light)
        lightEntity.position = SIMD3<Float>(0, 2, 0)
        rootEntity?.addChild(lightEntity)

        print("👓 Spatial environment setup complete")
    }

    private func setupDefaultWindows() {
        // Waveform window (front-left)
        addWindow(SpatialWindow(
            title: "Waveform",
            position: SIMD3<Float>(-0.5, 0, -1.5),
            size: SIMD2<Float>(0.8, 0.6),
            content: .waveform
        ))

        // Spectrum window (front-right)
        addWindow(SpatialWindow(
            title: "Spectrum",
            position: SIMD3<Float>(0.5, 0, -1.5),
            size: SIMD2<Float>(0.8, 0.6),
            content: .spectrum
        ))

        // Spatial field window (center, elevated)
        addWindow(SpatialWindow(
            title: "Spatial Audio Field",
            position: SIMD3<Float>(0, 0.5, -2.0),
            size: SIMD2<Float>(1.2, 1.2),
            content: .spatialField
        ))

        // Biometrics window (bottom-center)
        addWindow(SpatialWindow(
            title: "Biometrics",
            position: SIMD3<Float>(0, -0.3, -1.0),
            size: SIMD2<Float>(0.6, 0.3),
            content: .biometrics
        ))
    }

    private func updateImmersionEnvironment() {
        switch immersionStyle {
        case .windowed:
            // Keep windows at comfortable viewing distance
            break

        case .mixed:
            // Position windows around user
            for i in 0..<spatialWindows.count {
                let angle = (Float(i) / Float(spatialWindows.count)) * 2 * .pi
                spatialWindows[i].position = SIMD3<Float>(
                    cos(angle) * 1.5,
                    0,
                    sin(angle) * 1.5
                )
            }

        case .immersive:
            // Create full 360° environment
            createImmersiveEnvironment()
        }
    }

    private func createImmersiveEnvironment() {
        guard let root = rootEntity else { return }

        // Create particle field for full immersion
        let particleCount = 1000
        for i in 0..<particleCount {
            let angle = Float.random(in: 0...(2 * .pi))
            let elevation = Float.random(in: -.pi/2...(.pi/2))
            let radius = Float.random(in: 5...20)

            let x = cos(elevation) * cos(angle) * radius
            let y = sin(elevation) * radius
            let z = cos(elevation) * sin(angle) * radius

            let particle = createParticleEntity(at: SIMD3<Float>(x, y, z))
            root.addChild(particle)
        }
    }

    private func createParticleEntity(at position: SIMD3<Float>) -> Entity {
        let entity = Entity()

        // Create sphere mesh
        let mesh = MeshResource.generateSphere(radius: 0.02)
        var material = UnlitMaterial()
        material.color = .init(tint: .blue.withAlphaComponent(0.6))

        entity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        entity.position = position

        return entity
    }

    private func updateSpatialAudioEntities(sources: [SpatialSource]) {
        guard let root = rootEntity else { return }

        // Remove old visualization
        spatialAudioVisualization?.removeFromParent()

        // Create new visualization
        let visualization = Entity()

        for source in sources {
            let sphere = Entity()
            let mesh = MeshResource.generateSphere(radius: 0.05)

            var material = UnlitMaterial()
            let hue = Float(source.hue) / 360.0
            material.color = .init(tint: UIColor(hue: CGFloat(hue), saturation: 1.0, brightness: 1.0, alpha: 0.8))

            sphere.components.set(ModelComponent(mesh: mesh, materials: [material]))
            sphere.position = source.position

            visualization.addChild(sphere)
        }

        root.addChild(visualization)
        spatialAudioVisualization = visualization
    }

    private func updateBioVisualizationEntity(hrv: Double, heartRate: Double, coherence: Double) {
        guard let root = rootEntity else { return }

        // Remove old bio visualization
        bioVisualization?.removeFromParent()

        // Create new bio visualization (e.g., pulsing sphere based on heart rate)
        let bioEntity = Entity()

        let mesh = MeshResource.generateSphere(radius: 0.1)
        var material = UnlitMaterial()

        // Color based on coherence (red -> green)
        let hue = coherence / 100.0
        material.color = .init(tint: UIColor(hue: CGFloat(hue) * 0.33, saturation: 1.0, brightness: 1.0, alpha: 0.7))

        bioEntity.components.set(ModelComponent(mesh: mesh, materials: [material]))
        bioEntity.position = SIMD3<Float>(0, 1.5, -1.0)

        // TODO: Add pulsing animation based on heart rate

        root.addChild(bioEntity)
        bioVisualization = bioEntity
    }

    private func setupHandTracking() {
        // TODO: Integrate HandTrackingProvider from ARKit
        print("👓 Hand tracking setup")
    }

    private func setupEyeTracking() {
        // TODO: Integrate ARKitSession with eye tracking
        print("👓 Eye tracking setup")
    }

    #endif

    // MARK: - Gesture Handlers

    func handlePinch(scale: Float, at position: SIMD3<Float>) {
        // Scale spatial windows or controls
        print("👓 Pinch gesture: scale \(scale)")
    }

    func handleRotation(angle: Float, at position: SIMD3<Float>) {
        // Rotate 3D visualizations
        print("👓 Rotation gesture: \(angle)°")
    }

    func handleTap(at position: SIMD3<Float>) {
        // Select controls or trigger actions
        print("👓 Tap gesture at \(position)")
    }

    // MARK: - Supporting Types

    struct SpatialSource {
        let id: UUID
        let position: SIMD3<Float>
        let amplitude: Float
        let hue: Float  // 0-360
    }
}

// MARK: - SwiftUI Integration

#if os(visionOS)
struct SpatialUIView: View {
    @StateObject private var manager = SpatialUIManager()

    var body: some View {
        ZStack {
            // RealityView for 3D content
            RealityView { content in
                // Setup immersive content
                manager.start()
            }

            // 2D overlay controls
            VStack {
                Spacer()

                HStack {
                    Button("Windowed") {
                        manager.setImmersionStyle(.windowed)
                    }

                    Button("Mixed") {
                        manager.setImmersionStyle(.mixed)
                    }

                    Button("Immersive") {
                        manager.setImmersionStyle(.immersive)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding()
            }
        }
    }
}
#endif

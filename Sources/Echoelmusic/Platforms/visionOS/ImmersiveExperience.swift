import SwiftUI
import RealityKit
import AVFoundation
import Combine

#if os(visionOS)

// MARK: - Immersive Experience Manager

/// Manages immersive experiences for Apple Vision Pro, VR headsets, and AR glasses
/// Bio-reactive 360° environments that respond to heart rate, HRV, and coherence
@MainActor
@Observable
final class ImmersiveExperienceManager {

    // MARK: - Singleton

    static let shared = ImmersiveExperienceManager()

    // MARK: - State

    /// Current immersive mode
    var currentMode: ImmersiveMode = .passthrough

    /// Active experience
    var activeExperience: ImmersiveExperience?

    /// Is currently in immersive space
    var isImmersive: Bool = false

    /// Bio-reactive intensity (0-1)
    var bioIntensity: Double = 0.5

    /// Current coherence level driving visuals
    var coherenceLevel: Double = 0.5

    /// Current heart rate for pulsing effects
    var heartRate: Double = 60

    /// User preference for motion comfort
    var motionComfort: MotionComfort = .standard

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    // MARK: - Initialization

    private init() {
        setupBioDataListener()
    }

    private func setupBioDataListener() {
        // Listen to bio data from HealthKit
        NotificationCenter.default.publisher(for: .bioDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let data = notification.userInfo as? [String: Any] {
                    self?.updateBioData(data)
                }
            }
            .store(in: &cancellables)
    }

    private func updateBioData(_ data: [String: Any]) {
        if let hr = data["heartRate"] as? Double {
            heartRate = hr
        }
        if let coherence = data["coherence"] as? Double {
            coherenceLevel = coherence / 100.0
        }
    }

    // MARK: - Experience Control

    func startExperience(_ experience: ImmersiveExperience) async throws {
        print("🥽 Starting immersive experience: \(experience.name)")

        activeExperience = experience
        isImmersive = true

        // Start update loop for bio-reactive animations
        startUpdateLoop()
    }

    func stopExperience() async {
        print("🥽 Stopping immersive experience")

        stopUpdateLoop()
        activeExperience = nil
        isImmersive = false
    }

    func setMode(_ mode: ImmersiveMode) async {
        print("🥽 Setting immersive mode: \(mode.rawValue)")
        currentMode = mode
    }

    private func startUpdateLoop() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateExperience()
            }
        }
    }

    private func stopUpdateLoop() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateExperience() {
        // Update active experience with bio data
        guard let experience = activeExperience else { return }

        // Calculate pulse phase based on heart rate
        let pulsePhase = sin(Date().timeIntervalSince1970 * heartRate / 60.0 * 2.0 * .pi)

        // Update intensity based on coherence
        bioIntensity = coherenceLevel * (0.5 + 0.5 * pulsePhase)
    }

    // MARK: - Motion Comfort

    enum MotionComfort: String, CaseIterable {
        case minimal = "Minimal"
        case standard = "Standard"
        case immersive = "Immersive"

        var description: String {
            switch self {
            case .minimal:
                return "Reduced motion, fixed horizon, comfort vignette"
            case .standard:
                return "Balanced comfort with moderate motion"
            case .immersive:
                return "Full motion effects for experienced users"
            }
        }

        var motionScale: Float {
            switch self {
            case .minimal: return 0.3
            case .standard: return 0.7
            case .immersive: return 1.0
            }
        }

        var useVignette: Bool {
            self == .minimal
        }
    }
}

// MARK: - Immersive Mode

enum ImmersiveMode: String, CaseIterable {
    case passthrough = "Passthrough"
    case mixed = "Mixed Reality"
    case full = "Full Immersion"
    case spatial = "Spatial Window"

    var description: String {
        switch self {
        case .passthrough:
            return "See your environment with floating UI"
        case .mixed:
            return "3D content blended with reality"
        case .full:
            return "Complete 360° immersive environment"
        case .spatial:
            return "Volumetric windows in your space"
        }
    }

    var systemImage: String {
        switch self {
        case .passthrough: return "eye"
        case .mixed: return "cube.transparent"
        case .full: return "visionpro"
        case .spatial: return "square.3.layers.3d"
        }
    }
}

// MARK: - Immersive Experience

struct ImmersiveExperience: Identifiable {
    let id = UUID()
    let name: String
    let type: ExperienceType
    let environment: EnvironmentType
    let bioReactivity: BioReactivity
    let duration: TimeInterval?
    let preview: PreviewConfig

    enum ExperienceType: String, CaseIterable {
        case meditation = "Meditation"
        case focus = "Deep Focus"
        case creativity = "Creative Flow"
        case healing = "Healing"
        case performance = "Live Performance"
        case visualization = "Visualization"

        var defaultDuration: TimeInterval {
            switch self {
            case .meditation: return 600  // 10 min
            case .focus: return 1800      // 30 min
            case .creativity: return 3600 // 60 min
            case .healing: return 1200    // 20 min
            case .performance: return 0   // Unlimited
            case .visualization: return 0 // Unlimited
            }
        }
    }

    enum EnvironmentType: String, CaseIterable {
        case cosmos = "Cosmos"
        case nature = "Nature"
        case abstract = "Abstract"
        case sacred = "Sacred Geometry"
        case quantum = "Quantum Field"
        case void = "Void"
        case ocean = "Ocean"
        case forest = "Forest"
        case mountain = "Mountain"
        case aurora = "Aurora"

        var skyboxName: String {
            "\(rawValue.lowercased())_skybox"
        }

        var ambientSoundName: String {
            "\(rawValue.lowercased())_ambient"
        }
    }

    struct BioReactivity {
        var heartRateAffectsScale: Bool = true
        var coherenceAffectsColor: Bool = true
        var hrvAffectsComplexity: Bool = true
        var breathingAffectsMovement: Bool = true
        var intensity: Float = 1.0
    }

    struct PreviewConfig {
        var thumbnailName: String
        var description: String
        var tags: [String]
    }
}

// MARK: - Bio-Reactive Environment Entity

class BioReactiveEnvironment: Entity {

    // MARK: - Properties

    private var bioIntensity: Float = 0.5
    private var coherenceColor: SIMD3<Float> = SIMD3(0.2, 1.0, 0.8)
    private var pulsePhase: Float = 0

    private var particleSystems: [Entity] = []
    private var geometricEntities: [Entity] = []
    private var lightEntities: [Entity] = []

    // MARK: - Initialization

    required init() {
        super.init()
        setupEnvironment()
    }

    private func setupEnvironment() {
        // Create central bio-reactive sphere
        let sphere = createBioReactiveSphere()
        addChild(sphere)

        // Create particle field
        let particles = createParticleField()
        addChild(particles)

        // Create sacred geometry
        let geometry = createSacredGeometry()
        addChild(geometry)
    }

    private func createBioReactiveSphere() -> Entity {
        let entity = Entity()

        // Main sphere
        let sphereMesh = MeshResource.generateSphere(radius: 2.0)
        let material = SimpleMaterial(color: .cyan.withAlphaComponent(0.6), isMetallic: false)
        let modelComponent = ModelComponent(mesh: sphereMesh, materials: [material])

        entity.components.set(modelComponent)
        geometricEntities.append(entity)

        return entity
    }

    private func createParticleField() -> Entity {
        let container = Entity()

        // Create particle positions in fibonacci spiral
        let particleCount = 1000
        let goldenRatio: Float = (1.0 + sqrt(5.0)) / 2.0

        for i in 0..<particleCount {
            let t = Float(i) / Float(particleCount)
            let theta = 2.0 * .pi * Float(i) / goldenRatio
            let phi = acos(1.0 - 2.0 * t)
            let radius: Float = 5.0 + t * 3.0

            let x = radius * sin(phi) * cos(theta)
            let y = radius * sin(phi) * sin(theta)
            let z = radius * cos(phi)

            let particle = ModelEntity(
                mesh: .generateSphere(radius: 0.02),
                materials: [SimpleMaterial(color: .white, isMetallic: true)]
            )
            particle.position = SIMD3(x, y, z)

            container.addChild(particle)
            particleSystems.append(particle)
        }

        return container
    }

    private func createSacredGeometry() -> Entity {
        let container = Entity()

        // Flower of Life pattern
        let circleCount = 19  // Standard Flower of Life
        let radius: Float = 0.5
        let spacing: Float = 1.0

        // Center circle
        let center = createCircleEntity(radius: radius, color: .cyan)
        container.addChild(center)

        // First ring (6 circles)
        for i in 0..<6 {
            let angle = Float(i) * (.pi / 3.0)
            let x = cos(angle) * spacing
            let z = sin(angle) * spacing

            let circle = createCircleEntity(radius: radius, color: .cyan)
            circle.position = SIMD3(x, 0, z)
            container.addChild(circle)
        }

        // Second ring (12 circles)
        for i in 0..<12 {
            let angle = Float(i) * (.pi / 6.0)
            let r = spacing * sqrt(3.0)
            let x = cos(angle) * r
            let z = sin(angle) * r

            let circle = createCircleEntity(radius: radius, color: .purple)
            circle.position = SIMD3(x, 0, z)
            container.addChild(circle)
        }

        container.position = SIMD3(0, 0, -8)
        geometricEntities.append(container)

        return container
    }

    private func createCircleEntity(radius: Float, color: UIColor) -> Entity {
        let entity = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [SimpleMaterial(color: color.withAlphaComponent(0.3), isMetallic: false)]
        )
        return entity
    }

    // MARK: - Bio Updates

    func updateWithBioData(heartRate: Double, coherence: Double, hrv: Double) {
        // Calculate pulse effect from heart rate
        let time = Date().timeIntervalSince1970
        pulsePhase = Float(sin(time * heartRate / 60.0 * 2.0 * .pi))

        // Update coherence color (red -> yellow -> green)
        if coherence < 40 {
            coherenceColor = SIMD3(1.0, 0.3, 0.3)  // Red
        } else if coherence < 60 {
            coherenceColor = SIMD3(1.0, 0.8, 0.2)  // Yellow
        } else {
            coherenceColor = SIMD3(0.2, 1.0, 0.8)  // Green/Cyan
        }

        // Update bioIntensity based on HRV
        bioIntensity = Float(hrv / 100.0).clamped(to: 0.3...1.0)

        // Apply to entities
        updateGeometry()
        updateParticles()
    }

    private func updateGeometry() {
        let baseScale = 1.0 + bioIntensity * 0.3 * (0.5 + 0.5 * pulsePhase)

        for entity in geometricEntities {
            entity.scale = SIMD3(repeating: baseScale)
        }
    }

    private func updateParticles() {
        let time = Float(Date().timeIntervalSince1970)

        for (index, particle) in particleSystems.enumerated() {
            let offset = Float(index) * 0.01

            // Breathing motion
            let breathScale = 1.0 + 0.1 * sin(time * 0.5 + offset)

            // Pulse motion
            let pulseScale = 1.0 + bioIntensity * 0.2 * sin(time * 2.0 + offset)

            particle.scale = SIMD3(repeating: breathScale * pulseScale)
        }
    }
}

// MARK: - Extensions

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return max(range.lowerBound, min(range.upperBound, self))
    }
}

extension Notification.Name {
    static let bioDataUpdated = Notification.Name("bioDataUpdated")
}

// MARK: - Immersive Experience Library

struct ImmersiveExperienceLibrary {

    static let experiences: [ImmersiveExperience] = [

        // Meditation Experiences
        ImmersiveExperience(
            name: "Cosmic Meditation",
            type: .meditation,
            environment: .cosmos,
            bioReactivity: .init(intensity: 0.8),
            duration: 600,
            preview: .init(
                thumbnailName: "cosmic_meditation",
                description: "Float through galaxies as your coherence guides the stars",
                tags: ["meditation", "space", "relaxation"]
            )
        ),

        ImmersiveExperience(
            name: "Sacred Geometry Flow",
            type: .meditation,
            environment: .sacred,
            bioReactivity: .init(hrvAffectsComplexity: true, intensity: 1.0),
            duration: 900,
            preview: .init(
                thumbnailName: "sacred_geometry",
                description: "Flower of Life pulsates with your heartbeat",
                tags: ["sacred", "geometry", "spiritual"]
            )
        ),

        ImmersiveExperience(
            name: "Ocean Depths",
            type: .healing,
            environment: .ocean,
            bioReactivity: .init(breathingAffectsMovement: true, intensity: 0.7),
            duration: 1200,
            preview: .init(
                thumbnailName: "ocean_depths",
                description: "Submerge into peaceful waters, breath guides the currents",
                tags: ["ocean", "water", "calming"]
            )
        ),

        ImmersiveExperience(
            name: "Aurora Dreams",
            type: .creativity,
            environment: .aurora,
            bioReactivity: .init(coherenceAffectsColor: true, intensity: 0.9),
            duration: nil,
            preview: .init(
                thumbnailName: "aurora_dreams",
                description: "Northern lights dance to your creative energy",
                tags: ["aurora", "creative", "colorful"]
            )
        ),

        ImmersiveExperience(
            name: "Quantum Field",
            type: .focus,
            environment: .quantum,
            bioReactivity: .init(intensity: 1.0),
            duration: 1800,
            preview: .init(
                thumbnailName: "quantum_field",
                description: "Particles respond to your focus state",
                tags: ["quantum", "focus", "science"]
            )
        ),

        ImmersiveExperience(
            name: "Forest Sanctuary",
            type: .healing,
            environment: .forest,
            bioReactivity: .init(coherenceAffectsColor: true, breathingAffectsMovement: true, intensity: 0.6),
            duration: 1200,
            preview: .init(
                thumbnailName: "forest_sanctuary",
                description: "Peaceful forest glade with bio-reactive nature",
                tags: ["forest", "nature", "healing"]
            )
        ),

        ImmersiveExperience(
            name: "Abstract Pulse",
            type: .performance,
            environment: .abstract,
            bioReactivity: .init(heartRateAffectsScale: true, coherenceAffectsColor: true, intensity: 1.0),
            duration: nil,
            preview: .init(
                thumbnailName: "abstract_pulse",
                description: "Live performance visuals driven by your bio-data",
                tags: ["performance", "abstract", "live"]
            )
        ),

        ImmersiveExperience(
            name: "Mountain Peak",
            type: .focus,
            environment: .mountain,
            bioReactivity: .init(intensity: 0.5),
            duration: 2700,
            preview: .init(
                thumbnailName: "mountain_peak",
                description: "Breathtaking mountain views for deep concentration",
                tags: ["mountain", "focus", "nature"]
            )
        ),

        ImmersiveExperience(
            name: "Void Meditation",
            type: .meditation,
            environment: .void,
            bioReactivity: .init(intensity: 0.4),
            duration: 1800,
            preview: .init(
                thumbnailName: "void_meditation",
                description: "Pure emptiness for advanced meditation practice",
                tags: ["void", "advanced", "minimal"]
            )
        )
    ]

    static func experiencesByType(_ type: ImmersiveExperience.ExperienceType) -> [ImmersiveExperience] {
        experiences.filter { $0.type == type }
    }

    static func experiencesByEnvironment(_ environment: ImmersiveExperience.EnvironmentType) -> [ImmersiveExperience] {
        experiences.filter { $0.environment == environment }
    }
}

#endif

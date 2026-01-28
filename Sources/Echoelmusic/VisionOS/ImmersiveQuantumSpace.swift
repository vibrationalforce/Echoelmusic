//
//  ImmersiveQuantumSpace.swift
//  Echoelmusic
//
//  visionOS Immersive Space for Quantum Light Experience
//  Full 360° bio-reactive quantum visualization
//
//  Created: 2026-01-05
//

#if os(visionOS)
import SwiftUI
import RealityKit
import RealityKitContent

// MARK: - Immersive Quantum Space

@available(visionOS 1.0, *)
public struct ImmersiveQuantumSpace: View {

    @ObservedObject var emulator: QuantumLightEmulator
    @State private var photonEntities: [Entity] = []
    @State private var lightFieldEntity: Entity?
    @State private var isImmersed: Bool = false

    public init(emulator: QuantumLightEmulator) {
        self.emulator = emulator
    }

    public var body: some View {
        RealityView { content, attachments in
            // Create the immersive quantum environment
            let anchor = AnchorEntity(world: .zero)

            // Add quantum light field sphere
            let sphereEntity = createQuantumSphere()
            anchor.addChild(sphereEntity)
            lightFieldEntity = sphereEntity

            // Add floating photon particles
            let photons = createPhotonParticles()
            for photon in photons {
                anchor.addChild(photon)
            }
            photonEntities = photons

            // Add bio-coherence indicator attachment
            if let coherencePanel = attachments.entity(for: "coherencePanel") {
                coherencePanel.position = SIMD3<Float>(0, 1.5, -1)
                anchor.addChild(coherencePanel)
            }

            content.add(anchor)

        } update: { content, attachments in
            // Update visualization based on quantum state
            updateQuantumVisualization()

        } attachments: {
            Attachment(id: "coherencePanel") {
                CoherencePanel(emulator: emulator)
            }
        }
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleSpatialTap(value)
                }
        )
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    handleDrag(value)
                }
        )
        .onAppear {
            emulator.start()
            isImmersed = true
        }
        .onDisappear {
            isImmersed = false
        }
    }

    // MARK: - Entity Creation

    private func createQuantumSphere() -> Entity {
        let sphere = Entity()

        // Create mesh for quantum field visualization
        let mesh = MeshResource.generateSphere(radius: 3.0)

        // Quantum shader material (would use custom Metal shader in production)
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .cyan.withAlphaComponent(0.3))
        material.emissiveColor = .init(color: .cyan)
        material.emissiveIntensity = 0.5
        material.blending = .transparent(opacity: 0.3)

        let modelComponent = ModelComponent(mesh: mesh, materials: [material])
        sphere.components.set(modelComponent)

        // Add pulsing animation synced to heart rate
        let animation = createHeartSyncAnimation()
        sphere.components.set(animation)

        return sphere
    }

    private func createPhotonParticles() -> [Entity] {
        var particles: [Entity] = []

        guard let field = emulator.currentLightField else {
            // Create default particles
            for i in 0..<64 {
                let particle = createSinglePhoton(index: i, wavelength: 550)
                particles.append(particle)
            }
            return particles
        }

        for (index, photon) in field.photons.prefix(64).enumerated() {
            let particle = createSinglePhoton(
                index: index,
                wavelength: photon.wavelength,
                position: photon.position,
                intensity: photon.intensity
            )
            particles.append(particle)
        }

        return particles
    }

    private func createSinglePhoton(
        index: Int,
        wavelength: Float,
        position: SIMD3<Float> = .zero,
        intensity: Float = 1.0
    ) -> Entity {
        let photon = Entity()

        // Small glowing sphere for each photon
        let mesh = MeshResource.generateSphere(radius: 0.02)

        // Color based on wavelength
        let color = wavelengthToColor(wavelength)

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.emissiveColor = .init(color: color)
        material.emissiveIntensity = intensity * 2

        photon.components.set(ModelComponent(mesh: mesh, materials: [material]))

        // Position in Fibonacci spiral
        let goldenAngle = Float.pi * (3 - sqrt(5))
        let angle = Float(index) * goldenAngle
        let radius = sqrt(Float(index) / 64.0) * 2.5

        photon.position = [
            cos(angle) * radius + position.x,
            sin(Float(index) * 0.1) * 0.5 + position.y,
            sin(angle) * radius + position.z
        ]

        // Add floating animation
        let floatAnimation = createFloatingAnimation(index: index)
        photon.components.set(floatAnimation)

        return photon
    }

    private func wavelengthToColor(_ wavelength: Float) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0

        if wavelength >= 380 && wavelength < 440 {
            r = CGFloat(-(wavelength - 440) / (440 - 380))
            b = 1
        } else if wavelength >= 440 && wavelength < 490 {
            g = CGFloat((wavelength - 440) / (490 - 440))
            b = 1
        } else if wavelength >= 490 && wavelength < 510 {
            g = 1
            b = CGFloat(-(wavelength - 510) / (510 - 490))
        } else if wavelength >= 510 && wavelength < 580 {
            r = CGFloat((wavelength - 510) / (580 - 510))
            g = 1
        } else if wavelength >= 580 && wavelength < 645 {
            r = 1
            g = CGFloat(-(wavelength - 645) / (645 - 580))
        } else if wavelength >= 645 && wavelength <= 780 {
            r = 1
        }

        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }

    // MARK: - Animations

    private func createHeartSyncAnimation() -> AnimationPlaybackController {
        // Create pulsing animation synced to heart rate
        // In production, this would use actual animation resources
        return AnimationPlaybackController()
    }

    private func createFloatingAnimation(index: Int) -> AnimationPlaybackController {
        // Create floating/orbiting animation for photons
        return AnimationPlaybackController()
    }

    // MARK: - Updates

    private func updateQuantumVisualization() {
        guard isImmersed else { return }

        let coherence = emulator.coherenceLevel

        // Update sphere opacity and emission based on coherence
        if let sphere = lightFieldEntity {
            // Higher coherence = more visible and emissive
            // Would update material properties here
        }

        // Update photon positions based on light field
        if let field = emulator.currentLightField {
            for (index, entity) in photonEntities.enumerated() {
                guard index < field.photons.count else { continue }

                let photon = field.photons[index]
                let scaledPosition: SIMD3<Float> = [
                    photon.position.x * 2.5,
                    photon.position.y * 2.5 + 1.0,
                    photon.position.z * 2.5 - 1.5
                ]

                entity.position = scaledPosition
            }
        }
    }

    // MARK: - Gestures

    private func handleSpatialTap(_ value: EntityTargetValue<SpatialTapGesture.Value>) {
        // Collapse quantum state on tap - creative decision trigger
        let options = ["harmonize", "expand", "contract", "spiral", "pulse"]
        if let decision = emulator.collapseToDecision(options: options) {
            triggerVisualEffect(decision)
        }
    }

    private func handleDrag(_ value: EntityTargetValue<DragGesture.Value>) {
        // Drag to rotate the quantum field
        // Would implement rotation here
    }

    private func triggerVisualEffect(_ effect: String) {
        let goldenAngle = Float.pi * (3.0 - sqrt(5.0))

        switch effect {
        case "harmonize":
            // Align all photons to Fibonacci spiral arrangement
            for (index, entity) in photonEntities.enumerated() {
                let t = Float(index) / Float(photonEntities.count)
                let radius = t * 2.0
                let angle = Float(index) * goldenAngle
                let height = sin(t * Float.pi) * 0.5

                let newPosition = SIMD3<Float>(
                    cos(angle) * radius,
                    height + 1.0,
                    sin(angle) * radius - 1.5
                )
                entity.position = newPosition
            }
        case "expand":
            // Expand the light field outward
            for entity in photonEntities {
                entity.position = entity.position * 1.5
            }
        case "contract":
            // Contract the light field inward
            for entity in photonEntities {
                let center = SIMD3<Float>(0, 1.0, -1.5)
                let direction = entity.position - center
                entity.position = center + direction * 0.6
            }
        case "spiral":
            // Trigger spiral animation by rotating photons
            for (index, entity) in photonEntities.enumerated() {
                let currentAngle = atan2(entity.position.z + 1.5, entity.position.x)
                let radius = length(SIMD2<Float>(entity.position.x, entity.position.z + 1.5))
                let newAngle = currentAngle + Float.pi / 6.0

                entity.position.x = cos(newAngle) * radius
                entity.position.z = sin(newAngle) * radius - 1.5
            }
        case "pulse":
            // Emit pulse wave by temporarily scaling entities
            for entity in photonEntities {
                entity.scale = SIMD3<Float>(repeating: 1.5)
                // Scale would animate back in production
            }
        default:
            break
        }
    }
}

// MARK: - Coherence Panel (Attachment)

@available(visionOS 1.0, *)
struct CoherencePanel: View {
    @ObservedObject var emulator: QuantumLightEmulator

    var body: some View {
        VStack(spacing: 16) {
            Text("Quantum Coherence")
                .font(.headline)
                .foregroundColor(.white)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: CGFloat(emulator.coherenceLevel))
                    .stroke(coherenceColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(emulator.coherenceLevel * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Text(emulator.emulationMode.rawValue)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            // Entanglement indicator
            if !emulator.entanglementNetwork.isEmpty {
                HStack {
                    Image(systemName: "link")
                    Text("\(emulator.entanglementNetwork.count) entangled")
                }
                .font(.caption)
                .foregroundColor(.cyan)
            }
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .glassBackgroundEffect()
    }

    private var coherenceColor: Color {
        let coherence = Double(emulator.coherenceLevel)
        if coherence > 0.7 {
            return .green
        } else if coherence > 0.4 {
            return .yellow
        } else {
            return .orange
        }
    }
}

// MARK: - Immersive Space App Extension

@available(visionOS 1.0, *)
public extension View {
    /// Opens the quantum immersive space
    func openQuantumSpace(emulator: QuantumLightEmulator) -> some View {
        self.modifier(QuantumSpaceModifier(emulator: emulator))
    }
}

@available(visionOS 1.0, *)
struct QuantumSpaceModifier: ViewModifier {
    let emulator: QuantumLightEmulator
    @State private var showImmersive = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem {
                    Button(action: { showImmersive.toggle() }) {
                        Label("Quantum Space", systemImage: "visionpro")
                    }
                }
            }
            .fullScreenCover(isPresented: $showImmersive) {
                ImmersiveQuantumSpace(emulator: emulator)
            }
    }
}

#endif

// MARK: - Cross-Platform Stub

#if !os(visionOS)
// Stub for non-visionOS platforms
public struct ImmersiveQuantumSpace: View {
    let emulator: QuantumLightEmulator

    public init(emulator: QuantumLightEmulator) {
        self.emulator = emulator
    }

    public var body: some View {
        VStack {
            Image(systemName: "visionpro")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Immersive Quantum Space")
                .font(.headline)

            Text("Available on Apple Vision Pro")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
#endif

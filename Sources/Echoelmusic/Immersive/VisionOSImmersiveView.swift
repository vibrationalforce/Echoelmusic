import SwiftUI
import Combine
import simd

#if os(visionOS)
import RealityKit
import RealityKitContent
import Spatial
#endif

/// visionOS Immersive Space View for Echoelmusic
/// Full immersive experience with AIV + APAC integration
/// Bio-reactive visuals synchronized with spatial audio
struct VisionOSImmersiveView: View {

    // MARK: - Environment

    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    // MARK: - State

    @State private var aivEngine = AIVMetadataEngine()
    @State private var apacEngine = APACSpatialAudioEngine()
    @State private var playbackController: ImmersivePlaybackController?

    @State private var isFullyImmersive: Bool = false
    @State private var showingControls: Bool = true
    @State private var controlsOpacity: Double = 1.0

    // Bio-data
    @State private var currentHRV: Float = 50.0
    @State private var currentCoherence: Float = 0.5

    // Visualization
    @State private var visualizationIntensity: Float = 1.0
    @State private var particleCount: Int = 8192
    @State private var colorScheme: ColorScheme = .bioReactive

    enum ColorScheme: String, CaseIterable {
        case bioReactive = "Bio-Reactive"
        case vaporwave = "Vaporwave"
        case aurora = "Aurora"
        case cosmic = "Cosmic"
        case minimal = "Minimal"
    }

    var body: some View {
        ZStack {
            // Main immersive content
            #if os(visionOS)
            RealityView { content, attachments in
                await setupImmersiveContent(content: content, attachments: attachments)
            } update: { content, attachments in
                updateImmersiveContent(content: content, attachments: attachments)
            } attachments: {
                // Floating control panel
                Attachment(id: "controls") {
                    ImmersiveControlsView(
                        aivEngine: aivEngine,
                        apacEngine: apacEngine,
                        playbackController: playbackController,
                        isFullyImmersive: $isFullyImmersive,
                        showingControls: $showingControls,
                        colorScheme: $colorScheme,
                        onDismiss: {
                            Task {
                                await dismissImmersiveSpace()
                            }
                        }
                    )
                    .opacity(controlsOpacity)
                }

                // Comfort indicator
                Attachment(id: "comfort") {
                    ComfortIndicatorView(
                        comfortScore: aivEngine.motionComfortLevel,
                        warnings: aivEngine.comfortWarnings
                    )
                }

                // Bio-data HUD
                Attachment(id: "bioHUD") {
                    BioDataHUDView(
                        hrv: currentHRV,
                        coherence: currentCoherence
                    )
                }
            }
            #else
            // Fallback for non-visionOS
            Text("Immersive View requires visionOS")
                .font(.largeTitle)
            #endif
        }
        .onAppear {
            setupPlaybackController()
            startSpatialAudio()
        }
        .onDisappear {
            cleanup()
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingControls.toggle()
                        controlsOpacity = showingControls ? 1.0 : 0.0
                    }
                }
        )
    }

    // MARK: - Setup

    private func setupPlaybackController() {
        playbackController = ImmersivePlaybackController(
            aivEngine: aivEngine,
            apacEngine: apacEngine
        )
    }

    private func startSpatialAudio() {
        Task {
            try? await apacEngine.start()
        }
    }

    #if os(visionOS)
    private func setupImmersiveContent(content: RealityViewContent, attachments: RealityViewAttachments) async {
        // Create immersive environment
        let environment = await createImmersiveEnvironment()
        content.add(environment)

        // Add particle system
        let particleSystem = await createBioReactiveParticles()
        content.add(particleSystem)

        // Position attachments
        if let controlsEntity = attachments.entity(for: "controls") {
            controlsEntity.position = SIMD3<Float>(0, 1.0, -1.5)
            controlsEntity.look(at: .zero, from: controlsEntity.position, relativeTo: nil)
            content.add(controlsEntity)
        }

        if let comfortEntity = attachments.entity(for: "comfort") {
            comfortEntity.position = SIMD3<Float>(-1.5, 0.5, -1.0)
            content.add(comfortEntity)
        }

        if let bioHUDEntity = attachments.entity(for: "bioHUD") {
            bioHUDEntity.position = SIMD3<Float>(1.5, 0.5, -1.0)
            content.add(bioHUDEntity)
        }

        // Create spatial audio sources
        await setupSpatialAudioSources()

        // Start AIV session
        aivEngine.startImmersiveSession()
    }

    private func updateImmersiveContent(content: RealityViewContent, attachments: RealityViewAttachments) {
        // Update bio-reactive visuals based on bio-data
        updateBioReactiveVisuals(content: content)

        // Update spatial audio positions
        updateSpatialAudioPositions()

        // Update comfort adjustments
        applyComfortVisuals(content: content)
    }

    private func createImmersiveEnvironment() async -> Entity {
        let environment = Entity()
        environment.name = "ImmersiveEnvironment"

        // Create skybox/dome based on color scheme
        let skybox = await createSkybox()
        environment.addChild(skybox)

        // Create ground plane with bio-reactive shader
        let ground = await createGroundPlane()
        environment.addChild(ground)

        // Create ambient lighting
        let lighting = createAmbientLighting()
        environment.addChild(lighting)

        return environment
    }

    private func createSkybox() async -> Entity {
        let skybox = Entity()

        // Create large sphere for skybox
        let mesh = MeshResource.generateSphere(radius: 50)
        var material = UnlitMaterial()

        // Set color based on scheme
        switch colorScheme {
        case .bioReactive:
            let color = coherenceToColor(currentCoherence)
            material.color = .init(tint: color)
        case .vaporwave:
            material.color = .init(tint: .init(red: 0.2, green: 0.1, blue: 0.3, alpha: 1))
        case .aurora:
            material.color = .init(tint: .init(red: 0.0, green: 0.3, blue: 0.2, alpha: 1))
        case .cosmic:
            material.color = .init(tint: .init(red: 0.05, green: 0.05, blue: 0.1, alpha: 1))
        case .minimal:
            material.color = .init(tint: .init(red: 0.1, green: 0.1, blue: 0.1, alpha: 1))
        }

        skybox.components.set(ModelComponent(mesh: mesh, materials: [material]))

        // Invert normals for inside view
        skybox.scale = SIMD3<Float>(-1, 1, 1)

        return skybox
    }

    private func createGroundPlane() async -> Entity {
        let ground = Entity()

        let mesh = MeshResource.generatePlane(width: 20, depth: 20)
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .init(white: 0.2, alpha: 1))
        material.roughness = 0.8
        material.metallic = 0.1

        ground.components.set(ModelComponent(mesh: mesh, materials: [material]))
        ground.position.y = -1.5

        return ground
    }

    private func createAmbientLighting() -> Entity {
        let lighting = Entity()

        // Create point light that responds to bio-data
        let light = PointLightComponent(
            color: coherenceToColor(currentCoherence),
            intensity: 1000 + currentCoherence * 2000,
            attenuationRadius: 10
        )

        lighting.components.set(light)
        lighting.position = SIMD3<Float>(0, 3, 0)

        return lighting
    }

    private func createBioReactiveParticles() async -> Entity {
        let particleEntity = Entity()
        particleEntity.name = "BioParticles"

        // Configure particle emitter
        var emitter = ParticleEmitterComponent.Presets.magic

        emitter.birthRate = Float(particleCount) / 10
        emitter.speed = 0.1 + currentCoherence * 0.5
        emitter.speedVariation = 0.2

        // Color based on coherence
        let particleColor = coherenceToColor(currentCoherence)
        emitter.mainEmitter.color = .constant(.single(particleColor))

        emitter.mainEmitter.size = 0.02 + currentHRV / 1000
        emitter.mainEmitter.lifeSpan = 3.0

        particleEntity.components.set(emitter)
        particleEntity.position = SIMD3<Float>(0, 0, 0)

        return particleEntity
    }

    private func setupSpatialAudioSources() async {
        // Create surround audio sources for immersive sound field
        let positions: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0, -3),      // Front
            SIMD3<Float>(3, 0, 0),       // Right
            SIMD3<Float>(0, 0, 3),       // Back
            SIMD3<Float>(-3, 0, 0),      // Left
            SIMD3<Float>(0, 2, 0),       // Top
            SIMD3<Float>(0, -1, 0),      // Bottom
            SIMD3<Float>(2, 1, -2),      // Front-Right-Top
            SIMD3<Float>(-2, 1, -2)      // Front-Left-Top
        ]

        for (index, position) in positions.enumerated() {
            _ = try? await apacEngine.createSource(
                name: "Ambient \(index + 1)",
                position: position,
                type: .pointSource
            )
        }
    }

    private func updateBioReactiveVisuals(content: RealityViewContent) {
        // Update particle system based on bio-data
        for entity in content.entities {
            if entity.name == "BioParticles",
               var emitter = entity.components[ParticleEmitterComponent.self] {

                // Adjust particle behavior based on coherence
                emitter.speed = 0.1 + currentCoherence * 0.5
                emitter.birthRate = Float(particleCount) / 10 * (0.5 + currentCoherence * 0.5)

                let color = coherenceToColor(currentCoherence)
                emitter.mainEmitter.color = .constant(.single(color))

                entity.components.set(emitter)
            }

            // Update lighting
            if var light = entity.components[PointLightComponent.self] {
                light.color = coherenceToColor(currentCoherence)
                light.intensity = 1000 + currentCoherence * 2000
                entity.components.set(light)
            }
        }
    }

    private func updateSpatialAudioPositions() {
        // Update audio sources based on visualization
        let time = CACurrentMediaTime()

        for (index, source) in apacEngine.activeSources.enumerated() {
            let angle = Float(index) / Float(apacEngine.activeSources.count) * 2 * .pi
            let radius: Float = 3.0 + sin(Float(time) * 0.5) * 0.5

            // Add bio-reactive movement
            let coherenceOffset = currentCoherence * 0.5

            let position = SIMD3<Float>(
                cos(angle + Float(time) * 0.1) * radius,
                sin(Float(time) * 0.2 + Float(index)) * coherenceOffset,
                sin(angle + Float(time) * 0.1) * radius
            )

            apacEngine.updateSourcePosition(source.id, position: position)
        }
    }

    private func applyComfortVisuals(content: RealityViewContent) {
        let adjustments = aivEngine.getComfortAdjustmentsForFrame()

        // Apply vignette effect (would use shader in production)
        if adjustments.vignetteRadius < 1.0 {
            // Darken peripheral vision
        }

        // Apply stabilization
        if adjustments.stabilizationStrength > 0 {
            // Smooth camera movement
        }
    }
    #endif

    // MARK: - Helpers

    private func coherenceToColor(_ coherence: Float) -> UIColor {
        // Map coherence to color spectrum
        // Low coherence = red/orange, High coherence = green/blue

        let hue = 0.0 + Double(coherence) * 0.4  // 0 (red) to 0.4 (green/cyan)
        let saturation = 0.7 + Double(coherence) * 0.3
        let brightness = 0.6 + Double(coherence) * 0.4

        return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
    }

    private func cleanup() {
        playbackController?.cleanup()
        apacEngine.stop()
        aivEngine.endImmersiveSession()
    }
}

// MARK: - Immersive Controls View

struct ImmersiveControlsView: View {
    let aivEngine: AIVMetadataEngine
    let apacEngine: APACSpatialAudioEngine
    let playbackController: ImmersivePlaybackController?

    @Binding var isFullyImmersive: Bool
    @Binding var showingControls: Bool
    @Binding var colorScheme: VisionOSImmersiveView.ColorScheme

    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Echoelmusic Immersive")
                .font(.title)
                .foregroundStyle(.white)

            // Playback controls
            HStack(spacing: 30) {
                Button(action: { playbackController?.play() }) {
                    Image(systemName: "play.fill")
                        .font(.title)
                }

                Button(action: { playbackController?.pause() }) {
                    Image(systemName: "pause.fill")
                        .font(.title)
                }

                Button(action: { playbackController?.stop() }) {
                    Image(systemName: "stop.fill")
                        .font(.title)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)

            Divider()

            // Color scheme picker
            Picker("Color Scheme", selection: $colorScheme) {
                ForEach(VisionOSImmersiveView.ColorScheme.allCases, id: \.self) { scheme in
                    Text(scheme.rawValue).tag(scheme)
                }
            }
            .pickerStyle(.segmented)

            // Comfort preset
            HStack {
                Text("Comfort:")
                    .foregroundStyle(.white)

                Button("Comfortable") {
                    aivEngine.applyComfortPreset(.comfortable)
                }

                Button("Moderate") {
                    aivEngine.applyComfortPreset(.moderate)
                }

                Button("Intense") {
                    aivEngine.applyComfortPreset(.intense)
                }
            }
            .buttonStyle(.bordered)

            Divider()

            // Exit button
            Button("Exit Immersive") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(30)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .frame(width: 400)
    }
}

// MARK: - Comfort Indicator View

struct ComfortIndicatorView: View {
    let comfortScore: Float
    let warnings: [AIVMetadataEngine.ComfortWarning]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Comfort gauge
            HStack {
                Text("Comfort")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Text("\(Int(comfortScore * 100))%")
                    .font(.title2)
                    .foregroundStyle(comfortColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))

                    Rectangle()
                        .fill(comfortColor)
                        .frame(width: geometry.size.width * CGFloat(comfortScore))
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            // Warnings
            if !warnings.isEmpty {
                ForEach(warnings.suffix(3)) { warning in
                    HStack {
                        Image(systemName: warningIcon(warning.severity))
                            .foregroundStyle(warningColor(warning.severity))

                        Text(warning.message)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 200)
    }

    private var comfortColor: Color {
        if comfortScore > 0.7 {
            return .green
        } else if comfortScore > 0.4 {
            return .yellow
        } else {
            return .red
        }
    }

    private func warningIcon(_ severity: AIVMetadataEngine.ComfortWarning.Severity) -> String {
        switch severity {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.octagon"
        case .critical: return "xmark.octagon.fill"
        }
    }

    private func warningColor(_ severity: AIVMetadataEngine.ComfortWarning.Severity) -> Color {
        switch severity {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Bio-Data HUD View

struct BioDataHUDView: View {
    let hrv: Float
    let coherence: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bio-Metrics")
                .font(.headline)
                .foregroundStyle(.white)

            // HRV
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.cyan)

                Text("HRV")
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text("\(Int(hrv)) ms")
                    .font(.title3)
                    .foregroundStyle(.cyan)
            }

            // Coherence
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(coherenceColor)

                Text("Coherence")
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text("\(Int(coherence * 100))%")
                    .font(.title3)
                    .foregroundStyle(coherenceColor)
            }

            // Coherence bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))

                    Rectangle()
                        .fill(coherenceColor)
                        .frame(width: geometry.size.width * CGFloat(coherence))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 180)
    }

    private var coherenceColor: Color {
        if coherence > 0.7 {
            return .green
        } else if coherence > 0.4 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    VisionOSImmersiveView()
}

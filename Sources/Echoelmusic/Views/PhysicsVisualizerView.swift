import SwiftUI

// MARK: - Physics Visualizer View
// Interactive controls for the Physics/Antigravity Visual Engine

public struct PhysicsVisualizerView: View {
    @StateObject private var physicsEngine = PhysicsVisualEngine.shared

    @State private var selectedPreset: PhysicsPreset = .cosmic
    @State private var showForceEditor = false
    @State private var showParticleSettings = false

    public var body: some View {
        NavigationStack {
            ZStack {
                // Physics visualization
                PhysicsMetalView(engine: physicsEngine)
                    .ignoresSafeArea()

                // Overlay controls
                VStack {
                    // Top bar
                    topControlBar

                    Spacer()

                    // Bottom controls
                    bottomControlPanel
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Physics Visualizer")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showForceEditor) {
                ForceEditorView(engine: physicsEngine)
            }
            .sheet(isPresented: $showParticleSettings) {
                ParticleSettingsView(engine: physicsEngine)
            }
        }
    }

    // MARK: - Top Control Bar

    private var topControlBar: some View {
        HStack {
            // Preset selector
            Menu {
                ForEach(PhysicsPreset.allCases, id: \.self) { preset in
                    Button(preset.rawValue) {
                        selectedPreset = preset
                        applyPreset(preset)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(selectedPreset.rawValue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }

            Spacer()

            // Stats
            HStack(spacing: 16) {
                StatBadge(label: "Particles", value: "\(physicsEngine.particleCount)")
                StatBadge(label: "FPS", value: "\(Int(physicsEngine.fps))")
            }

            Spacer()

            // Settings buttons
            HStack(spacing: 8) {
                Button(action: { showForceEditor = true }) {
                    Image(systemName: "atom")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Button(action: { showParticleSettings = true }) {
                    Image(systemName: "circle.hexagongrid")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .foregroundStyle(.white)
        .padding()
    }

    // MARK: - Bottom Control Panel

    private var bottomControlPanel: some View {
        VStack(spacing: 16) {
            // Force sliders
            HStack(spacing: 24) {
                ForceSlider(
                    label: "Gravity",
                    value: $physicsEngine.gravity,
                    range: -10...10,
                    color: .blue
                )

                ForceSlider(
                    label: "Turbulence",
                    value: $physicsEngine.turbulence,
                    range: 0...5,
                    color: .purple
                )

                ForceSlider(
                    label: "Attraction",
                    value: $physicsEngine.attraction,
                    range: -5...5,
                    color: .orange
                )
            }

            // Quick actions
            HStack(spacing: 12) {
                QuickToggle(label: "Audio Reactive", isOn: $physicsEngine.audioReactive)
                QuickToggle(label: "Bloom", isOn: $physicsEngine.bloomEnabled)
                QuickToggle(label: "Trails", isOn: $physicsEngine.trailsEnabled)
                QuickToggle(label: "Motion Blur", isOn: $physicsEngine.motionBlurEnabled)

                Spacer()

                Button(action: { physicsEngine.reset() }) {
                    Image(systemName: "arrow.counterclockwise")
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Button(action: { physicsEngine.togglePause() }) {
                    Image(systemName: physicsEngine.isPaused ? "play.fill" : "pause.fill")
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
    }

    private func applyPreset(_ preset: PhysicsPreset) {
        physicsEngine.applyPreset(preset)
    }
}

// MARK: - Supporting Views

struct PhysicsMetalView: View {
    @ObservedObject var engine: PhysicsVisualEngine

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Render particles
                for particle in engine.particles.prefix(1000) {
                    let rect = CGRect(
                        x: Double(particle.position.x) * size.width,
                        y: Double(particle.position.y) * size.height,
                        width: Double(particle.size),
                        height: Double(particle.size)
                    )

                    context.fill(
                        Circle().path(in: rect),
                        with: .color(particle.color.opacity(Double(particle.alpha)))
                    )
                }
            }
        }
        .background(Color.black)
    }
}

struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ForceSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Slider(value: $value, in: range)
                    .tint(color)

                Text(String(format: "%.1f", value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 35)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isOn ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isOn ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ForceEditorView: View {
    @ObservedObject var engine: PhysicsVisualEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Global Forces") {
                    SliderRow(label: "Gravity X", value: $engine.gravityX, range: -10...10)
                    SliderRow(label: "Gravity Y", value: $engine.gravityY, range: -10...10)
                    SliderRow(label: "Wind", value: $engine.wind, range: -5...5)
                    SliderRow(label: "Friction", value: $engine.friction, range: 0...1)
                }

                Section("Force Fields") {
                    ForEach(engine.forceFields.indices, id: \.self) { index in
                        ForceFieldRow(field: $engine.forceFields[index])
                    }

                    Button("Add Force Field") {
                        engine.addForceField()
                    }
                }

                Section("Vortex") {
                    Toggle("Enable Vortex", isOn: $engine.vortexEnabled)
                    SliderRow(label: "Strength", value: $engine.vortexStrength, range: 0...10)
                    SliderRow(label: "Radius", value: $engine.vortexRadius, range: 0.1...1)
                }

                Section("Attractor") {
                    Toggle("Enable Attractor", isOn: $engine.attractorEnabled)
                    SliderRow(label: "Mass", value: $engine.attractorMass, range: 0...100)
                    SliderRow(label: "Falloff", value: $engine.attractorFalloff, range: 0.1...3)
                }
            }
            .navigationTitle("Force Editor")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.2f", value))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
        }
    }
}

struct ForceFieldRow: View {
    @Binding var field: ForceField

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(field.type.rawValue)
                    .font(.headline)
                Spacer()
                Toggle("", isOn: $field.enabled)
                    .labelsHidden()
            }

            SliderRow(label: "Strength", value: $field.strength, range: -10...10)
            SliderRow(label: "Radius", value: $field.radius, range: 0.01...0.5)
        }
        .padding(.vertical, 4)
    }
}

struct ParticleSettingsView: View {
    @ObservedObject var engine: PhysicsVisualEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Particle Count") {
                    Picker("Count", selection: $engine.targetParticleCount) {
                        Text("10K").tag(10000)
                        Text("25K").tag(25000)
                        Text("50K").tag(50000)
                        Text("100K").tag(100000)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Appearance") {
                    SliderRow(label: "Size", value: $engine.particleSize, range: 1...10)
                    SliderRow(label: "Life", value: $engine.particleLife, range: 0.5...10)
                    SliderRow(label: "Fade", value: $engine.particleFade, range: 0...1)

                    Picker("Shape", selection: $engine.particleShape) {
                        Text("Circle").tag(ParticleShape.circle)
                        Text("Square").tag(ParticleShape.square)
                        Text("Star").tag(ParticleShape.star)
                        Text("Custom").tag(ParticleShape.custom)
                    }
                }

                Section("Color") {
                    ColorPicker("Start Color", selection: $engine.startColor)
                    ColorPicker("End Color", selection: $engine.endColor)

                    Toggle("Rainbow Mode", isOn: $engine.rainbowMode)
                    Toggle("Audio Color", isOn: $engine.audioColor)
                }

                Section("Emission") {
                    Picker("Pattern", selection: $engine.emissionPattern) {
                        Text("Point").tag(EmissionPattern.point)
                        Text("Line").tag(EmissionPattern.line)
                        Text("Circle").tag(EmissionPattern.circle)
                        Text("Sphere").tag(EmissionPattern.sphere)
                        Text("Audio").tag(EmissionPattern.audio)
                    }

                    SliderRow(label: "Rate", value: $engine.emissionRate, range: 100...10000)
                    SliderRow(label: "Spread", value: $engine.emissionSpread, range: 0...360)
                }

                Section("Physics") {
                    SliderRow(label: "Mass", value: $engine.particleMass, range: 0.1...10)
                    SliderRow(label: "Bounce", value: $engine.particleBounce, range: 0...1)
                    Toggle("Collision", isOn: $engine.collisionEnabled)
                }
            }
            .navigationTitle("Particle Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Types

enum PhysicsPreset: String, CaseIterable {
    case cosmic = "Cosmic"
    case nebula = "Nebula"
    case aurora = "Aurora"
    case fire = "Fire"
    case water = "Water"
    case electric = "Electric"
    case organic = "Organic"
    case geometric = "Geometric"
    case chaos = "Chaos"
    case zen = "Zen"
}

enum ParticleShape {
    case circle, square, star, custom
}

enum EmissionPattern {
    case point, line, circle, sphere, audio
}

struct ForceField {
    var type: ForceFieldType
    var enabled: Bool = true
    var strength: Float = 1.0
    var radius: Float = 0.1
    var position: SIMD2<Float> = .zero
}

enum ForceFieldType: String {
    case attractor = "Attractor"
    case repulsor = "Repulsor"
    case vortex = "Vortex"
    case turbulence = "Turbulence"
    case directional = "Directional"
}

struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var size: Float
    var alpha: Float
    var color: Color
}

// MARK: - Mock Engine

class PhysicsVisualEngine: ObservableObject {
    static let shared = PhysicsVisualEngine()

    // Stats
    @Published var particleCount: Int = 50000
    @Published var fps: Float = 60
    @Published var isPaused: Bool = false

    // Global forces
    @Published var gravity: Float = 0
    @Published var gravityX: Float = 0
    @Published var gravityY: Float = -1
    @Published var turbulence: Float = 0.5
    @Published var attraction: Float = 0
    @Published var wind: Float = 0
    @Published var friction: Float = 0.02

    // Force fields
    @Published var forceFields: [ForceField] = []

    // Vortex
    @Published var vortexEnabled: Bool = false
    @Published var vortexStrength: Float = 2
    @Published var vortexRadius: Float = 0.3

    // Attractor
    @Published var attractorEnabled: Bool = false
    @Published var attractorMass: Float = 50
    @Published var attractorFalloff: Float = 2

    // Toggles
    @Published var audioReactive: Bool = true
    @Published var bloomEnabled: Bool = true
    @Published var trailsEnabled: Bool = false
    @Published var motionBlurEnabled: Bool = false

    // Particle settings
    @Published var targetParticleCount: Int = 50000
    @Published var particleSize: Float = 2
    @Published var particleLife: Float = 5
    @Published var particleFade: Float = 0.5
    @Published var particleShape: ParticleShape = .circle
    @Published var particleMass: Float = 1
    @Published var particleBounce: Float = 0.5
    @Published var collisionEnabled: Bool = false

    // Color
    @Published var startColor: Color = .white
    @Published var endColor: Color = .blue
    @Published var rainbowMode: Bool = false
    @Published var audioColor: Bool = true

    // Emission
    @Published var emissionPattern: EmissionPattern = .point
    @Published var emissionRate: Float = 1000
    @Published var emissionSpread: Float = 360

    // Particles
    @Published var particles: [Particle] = []

    func reset() {
        particles.removeAll()
    }

    func togglePause() {
        isPaused.toggle()
    }

    func addForceField() {
        forceFields.append(ForceField(type: .attractor))
    }

    func applyPreset(_ preset: PhysicsPreset) {
        switch preset {
        case .cosmic:
            gravity = -0.5
            turbulence = 0.3
            bloomEnabled = true
            startColor = .white
            endColor = .purple
        case .fire:
            gravity = -2
            turbulence = 1
            startColor = .yellow
            endColor = .red
        case .water:
            gravity = 1
            friction = 0.1
            startColor = .cyan
            endColor = .blue
        default:
            break
        }
    }
}

#Preview {
    PhysicsVisualizerView()
}

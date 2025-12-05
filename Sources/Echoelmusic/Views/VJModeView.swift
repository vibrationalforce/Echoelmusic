import SwiftUI

// MARK: - VJ Mode View
// Full-screen VJ performance interface with visual controls

public struct VJModeView: View {
    @StateObject private var vjEngine = VJModeEngine.shared

    @State private var showLayerEditor = false
    @State private var showEffectChain = false
    @State private var showMIDIMapping = false
    @State private var selectedLayerIndex = 0

    public var body: some View {
        ZStack {
            // Visual output
            VJOutputView(engine: vjEngine)
                .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top bar
                topBar

                Spacer()

                // Layer previews
                layerPreviews

                // Control surface
                controlSurface
            }
        }
        .sheet(isPresented: $showLayerEditor) {
            LayerEditorView(engine: vjEngine, layerIndex: selectedLayerIndex)
        }
        .sheet(isPresented: $showEffectChain) {
            EffectChainView(engine: vjEngine)
        }
        .sheet(isPresented: $showMIDIMapping) {
            MIDIMappingView()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // BPM
            VStack(alignment: .leading, spacing: 2) {
                Text("BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(Int(vjEngine.bpm))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            // Performance stats
            HStack(spacing: 16) {
                StatPill(label: "FPS", value: "\(Int(vjEngine.fps))")
                StatPill(label: "GPU", value: "\(Int(vjEngine.gpuUsage))%")
                StatPill(label: "Audio", value: vjEngine.audioConnected ? "OK" : "—")
            }

            Spacer()

            // Mode buttons
            HStack(spacing: 8) {
                Button(action: { showMIDIMapping = true }) {
                    Image(systemName: "pianokeys")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Button(action: { vjEngine.toggleFullscreen() }) {
                    Image(systemName: vjEngine.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
        }
        .foregroundStyle(.white)
        .padding()
    }

    // MARK: - Layer Previews

    private var layerPreviews: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(vjEngine.layers.indices, id: \.self) { index in
                    LayerPreviewCard(
                        layer: vjEngine.layers[index],
                        index: index,
                        isSelected: selectedLayerIndex == index
                    ) {
                        selectedLayerIndex = index
                        showLayerEditor = true
                    }
                }

                // Add layer button
                Button(action: { vjEngine.addLayer() }) {
                    VStack {
                        Image(systemName: "plus")
                            .font(.title2)
                        Text("Add Layer")
                            .font(.caption)
                    }
                    .frame(width: 100, height: 80)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Control Surface

    private var controlSurface: some View {
        VStack(spacing: 16) {
            // XY Pad
            HStack(spacing: 16) {
                XYPadView(
                    x: $vjEngine.padX,
                    y: $vjEngine.padY,
                    label: "Position"
                )

                XYPadView(
                    x: $vjEngine.rotationX,
                    y: $vjEngine.rotationY,
                    label: "Rotation"
                )

                // Faders
                VStack(spacing: 8) {
                    FaderView(value: $vjEngine.masterOpacity, label: "Master")
                    FaderView(value: $vjEngine.effectMix, label: "FX Mix")
                    FaderView(value: $vjEngine.speed, label: "Speed")
                }
            }

            // Trigger buttons
            HStack(spacing: 12) {
                ForEach(0..<8) { index in
                    TriggerButton(
                        index: index,
                        isActive: vjEngine.activeButtons.contains(index)
                    ) {
                        vjEngine.triggerButton(index)
                    }
                }

                Spacer()

                // Effect toggles
                EffectToggle(name: "Bloom", isOn: $vjEngine.bloomEnabled, color: .purple)
                EffectToggle(name: "Mirror", isOn: $vjEngine.mirrorEnabled, color: .blue)
                EffectToggle(name: "Kaleid", isOn: $vjEngine.kaleidoscopeEnabled, color: .pink)
                EffectToggle(name: "Glitch", isOn: $vjEngine.glitchEnabled, color: .red)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
    }
}

// MARK: - Supporting Views

struct VJOutputView: View {
    @ObservedObject var engine: VJModeEngine

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                LinearGradient(
                    colors: [.black, engine.backgroundColor],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Layers
                ForEach(engine.layers.indices, id: \.self) { index in
                    LayerRenderView(layer: engine.layers[index])
                        .opacity(Double(engine.layers[index].opacity))
                        .blendMode(engine.layers[index].blendMode)
                }
            }
        }
    }
}

struct LayerRenderView: View {
    let layer: VJLayer

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(layer.color.gradient)
                .scaleEffect(CGFloat(layer.scale))
                .rotationEffect(.degrees(Double(layer.rotation)))
                .offset(
                    x: CGFloat(layer.position.x) * geometry.size.width / 2,
                    y: CGFloat(layer.position.y) * geometry.size.height / 2
                )
        }
    }
}

struct LayerPreviewCard: View {
    let layer: VJLayer
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Preview
                RoundedRectangle(cornerRadius: 8)
                    .fill(layer.color.gradient)
                    .frame(width: 100, height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                // Label
                Text("Layer \(index + 1)")
                    .font(.caption)
                    .foregroundStyle(.white)

                // Opacity indicator
                Text("\(Int(layer.opacity * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

struct XYPadView: View {
    @Binding var x: Float
    @Binding var y: Float
    let label: String

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))

                    // Crosshairs
                    Path { path in
                        path.move(to: CGPoint(x: geometry.size.width / 2, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height))
                        path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                    }
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)

                    // Position indicator
                    Circle()
                        .fill(isDragging ? Color.accentColor : Color.white)
                        .frame(width: 20, height: 20)
                        .position(
                            x: CGFloat((x + 1) / 2) * geometry.size.width,
                            y: CGFloat((1 - (y + 1) / 2)) * geometry.size.height
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            x = Float(value.location.x / geometry.size.width) * 2 - 1
                            y = Float(1 - value.location.y / geometry.size.height) * 2 - 1
                            x = max(-1, min(1, x))
                            y = max(-1, min(1, y))
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(width: 120, height: 120)
        }
    }
}

struct FaderView: View {
    @Binding var value: Float
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 45, alignment: .leading)

            Slider(value: $value, in: 0...1)
                .tint(.accentColor)

            Text("\(Int(value * 100))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 25)
        }
    }
}

struct TriggerButton: View {
    let index: Int
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(index + 1)")
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(isActive ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct EffectToggle: View {
    let name: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Text(name)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isOn ? color : Color(.systemGray5))
                .foregroundStyle(isOn ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct LayerEditorView: View {
    @ObservedObject var engine: VJModeEngine
    let layerIndex: Int
    @Environment(\.dismiss) private var dismiss

    var layer: VJLayer {
        engine.layers[layerIndex]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    Picker("Type", selection: .constant(layer.sourceType)) {
                        Text("Color").tag(LayerSourceType.color)
                        Text("Image").tag(LayerSourceType.image)
                        Text("Video").tag(LayerSourceType.video)
                        Text("Generator").tag(LayerSourceType.generator)
                        Text("Camera").tag(LayerSourceType.camera)
                    }

                    ColorPicker("Color", selection: .constant(layer.color))
                }

                Section("Transform") {
                    SliderRow(label: "Scale", value: .constant(layer.scale), range: 0.1...3)
                    SliderRow(label: "Rotation", value: .constant(layer.rotation), range: 0...360)
                    SliderRow(label: "Opacity", value: .constant(layer.opacity), range: 0...1)
                }

                Section("Blend Mode") {
                    Picker("Mode", selection: .constant(layer.blendMode)) {
                        Text("Normal").tag(BlendMode.normal)
                        Text("Screen").tag(BlendMode.screen)
                        Text("Multiply").tag(BlendMode.multiply)
                        Text("Overlay").tag(BlendMode.overlay)
                        Text("Difference").tag(BlendMode.difference)
                    }
                }

                Section("Audio Reactivity") {
                    Toggle("Enable", isOn: .constant(layer.audioReactive))
                    Picker("Target", selection: .constant(layer.audioTarget)) {
                        Text("Scale").tag(AudioTarget.scale)
                        Text("Rotation").tag(AudioTarget.rotation)
                        Text("Opacity").tag(AudioTarget.opacity)
                        Text("Color").tag(AudioTarget.color)
                    }
                    SliderRow(label: "Sensitivity", value: .constant(layer.audioSensitivity), range: 0...2)
                }
            }
            .navigationTitle("Layer \(layerIndex + 1)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct EffectChainView: View {
    @ObservedObject var engine: VJModeEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(engine.effectChain.indices, id: \.self) { index in
                    EffectRow(effect: engine.effectChain[index])
                }
                .onMove { from, to in
                    engine.effectChain.move(fromOffsets: from, toOffset: to)
                }
            }
            .navigationTitle("Effect Chain")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
    }
}

struct EffectRow: View {
    let effect: VJEffect

    var body: some View {
        HStack {
            Image(systemName: effect.icon)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(effect.name)
                    .font(.headline)
                Text("Mix: \(Int(effect.mix * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: .constant(effect.enabled))
                .labelsHidden()
        }
    }
}

struct MIDIMappingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Faders") {
                    MIDIMapRow(parameter: "Master Opacity", mapping: "CC 1")
                    MIDIMapRow(parameter: "FX Mix", mapping: "CC 2")
                    MIDIMapRow(parameter: "Speed", mapping: "CC 3")
                }

                Section("XY Pads") {
                    MIDIMapRow(parameter: "Position X", mapping: "CC 10")
                    MIDIMapRow(parameter: "Position Y", mapping: "CC 11")
                    MIDIMapRow(parameter: "Rotation X", mapping: "CC 12")
                    MIDIMapRow(parameter: "Rotation Y", mapping: "CC 13")
                }

                Section("Buttons") {
                    ForEach(1...8, id: \.self) { i in
                        MIDIMapRow(parameter: "Trigger \(i)", mapping: "Note \(35 + i)")
                    }
                }
            }
            .navigationTitle("MIDI Mapping")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct MIDIMapRow: View {
    let parameter: String
    let mapping: String

    var body: some View {
        HStack {
            Text(parameter)
            Spacer()
            Text(mapping)
                .foregroundStyle(.secondary)
            Button(action: {}) {
                Text("Learn")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Types

class VJModeEngine: ObservableObject {
    static let shared = VJModeEngine()

    @Published var bpm: Float = 120
    @Published var fps: Float = 60
    @Published var gpuUsage: Float = 45
    @Published var audioConnected: Bool = true
    @Published var isFullscreen: Bool = false

    @Published var layers: [VJLayer] = [
        VJLayer(color: .purple),
        VJLayer(color: .blue),
        VJLayer(color: .cyan)
    ]

    @Published var padX: Float = 0
    @Published var padY: Float = 0
    @Published var rotationX: Float = 0
    @Published var rotationY: Float = 0
    @Published var masterOpacity: Float = 1
    @Published var effectMix: Float = 0.5
    @Published var speed: Float = 1

    @Published var activeButtons: Set<Int> = []
    @Published var bloomEnabled = true
    @Published var mirrorEnabled = false
    @Published var kaleidoscopeEnabled = false
    @Published var glitchEnabled = false

    @Published var backgroundColor: Color = .black

    @Published var effectChain: [VJEffect] = [
        VJEffect(name: "Bloom", icon: "sun.max"),
        VJEffect(name: "Color Correction", icon: "paintpalette"),
        VJEffect(name: "Mirror", icon: "rectangle.split.2x1"),
        VJEffect(name: "Kaleidoscope", icon: "star.square"),
    ]

    func addLayer() {
        layers.append(VJLayer(color: .random))
    }

    func toggleFullscreen() {
        isFullscreen.toggle()
    }

    func triggerButton(_ index: Int) {
        if activeButtons.contains(index) {
            activeButtons.remove(index)
        } else {
            activeButtons.insert(index)
        }
    }
}

struct VJLayer {
    var color: Color
    var sourceType: LayerSourceType = .color
    var scale: Float = 1
    var rotation: Float = 0
    var opacity: Float = 1
    var position: SIMD2<Float> = .zero
    var blendMode: BlendMode = .normal
    var audioReactive: Bool = false
    var audioTarget: AudioTarget = .scale
    var audioSensitivity: Float = 1
}

enum LayerSourceType {
    case color, image, video, generator, camera
}

enum AudioTarget {
    case scale, rotation, opacity, color
}

struct VJEffect {
    var name: String
    var icon: String
    var enabled: Bool = true
    var mix: Float = 1
}

extension Color {
    static var random: Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
}

#Preview {
    VJModeView()
}

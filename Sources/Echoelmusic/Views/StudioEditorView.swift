import SwiftUI

/// Studio Editor View - Node-Based Audio/Visual Editor
/// Provides professional-grade editing capabilities for Echoelmusic sessions
struct StudioEditorView: View {

    // MARK: - Environment Objects

    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var recordingEngine: RecordingEngine

    // MARK: - State

    @State private var selectedEditor: EditorMode = .audioChain
    @State private var showPresetLibrary = false
    @State private var selectedPreset: Preset?
    @State private var nodes: [AudioNode] = []

    // MARK: - Editor Mode

    enum EditorMode: String, CaseIterable {
        case audioChain = "Audio Chain"
        case spatialMixer = "Spatial Mixer"
        case visualEditor = "Visual Editor"
        case automation = "Automation"

        var icon: String {
            switch self {
            case .audioChain: return "waveform.path"
            case .spatialMixer: return "cube.fill"
            case .visualEditor: return "paintpalette.fill"
            case .automation: return "point.3.connected.trianglepath.dotted"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Header
                header

                // MARK: - Editor Mode Picker
                editorModePicker

                // MARK: - Main Editor Area
                editorContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // MARK: - Bottom Toolbar
                bottomToolbar
            }
        }
        .sheet(isPresented: $showPresetLibrary) {
            presetLibrarySheet
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Studio")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button(action: { showPresetLibrary.toggle() }) {
                Label("Presets", systemImage: "folder.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.3))
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 20)
    }

    // MARK: - Editor Mode Picker

    private var editorModePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(EditorMode.allCases, id: \.self) { mode in
                    Button(action: { selectedEditor = mode }) {
                        VStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20))

                            Text(mode.rawValue)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(selectedEditor == mode ? .white : .white.opacity(0.5))
                        .frame(width: 100, height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedEditor == mode ? Color.cyan.opacity(0.3) : Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selectedEditor == mode ? Color.cyan : Color.clear, lineWidth: 2)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Editor Content

    @ViewBuilder
    private var editorContent: some View {
        switch selectedEditor {
        case .audioChain:
            audioChainEditor
        case .spatialMixer:
            spatialMixerEditor
        case .visualEditor:
            visualEditorView
        case .automation:
            automationEditor
        }
    }

    // MARK: - Audio Chain Editor

    private var audioChainEditor: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Audio Effects Chain")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                // Effect Nodes
                VStack(spacing: 16) {
                    effectNodeCard(
                        name: "Reverb",
                        icon: "waveform.circle.fill",
                        color: .purple,
                        parameters: [
                            ("Room Size", 0.6),
                            ("Damping", 0.5),
                            ("Wet/Dry", 0.3)
                        ]
                    )

                    effectNodeCard(
                        name: "Delay",
                        icon: "arrow.left.arrow.right.circle.fill",
                        color: .blue,
                        parameters: [
                            ("Time", 0.4),
                            ("Feedback", 0.5),
                            ("Mix", 0.4)
                        ]
                    )

                    effectNodeCard(
                        name: "Binaural Beats",
                        icon: "brain.head.profile",
                        color: .cyan,
                        parameters: [
                            ("Frequency", 0.3),
                            ("Amplitude", 0.5)
                        ]
                    )

                    effectNodeCard(
                        name: "Spatial 3D",
                        icon: "cube.fill",
                        color: .green,
                        parameters: [
                            ("Azimuth", 0.5),
                            ("Elevation", 0.5),
                            ("Distance", 0.7)
                        ]
                    )

                    // Add Effect Button
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Effect")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.cyan.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.cyan, lineWidth: 2, antialiased: true)
                                        .blendMode(.overlay)
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 100)
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Spatial Mixer Editor

    private var spatialMixerEditor: some View {
        VStack(spacing: 30) {
            Text("Dolby Atmos 7.1.4 Spatial Mixer")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            // 3D Spatial Visualizer (Placeholder)
            ZStack {
                // Background grid
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        GeometryReader { geometry in
                            Path { path in
                                // Vertical lines
                                for i in 0...8 {
                                    let x = geometry.size.width * CGFloat(i) / 8
                                    path.move(to: CGPoint(x: x, y: 0))
                                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                                }
                                // Horizontal lines
                                for i in 0...8 {
                                    let y = geometry.size.height * CGFloat(i) / 8
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                                }
                            }
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        }
                    )

                // Audio source indicators
                VStack {
                    Text("Drag audio sources to position")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))

                    Spacer()

                    // Sample audio source
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.white)
                        )
                        .shadow(color: .cyan, radius: 10)

                    Spacer()
                }
            }
            .frame(height: 300)
            .padding(.horizontal, 20)

            // Spatial Controls
            VStack(spacing: 16) {
                parameterSlider(label: "Azimuth", value: .constant(0.5), color: .cyan)
                parameterSlider(label: "Elevation", value: .constant(0.5), color: .purple)
                parameterSlider(label: "Distance", value: .constant(0.7), color: .blue)
                parameterSlider(label: "Spread", value: .constant(0.3), color: .green)
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.top, 20)
    }

    // MARK: - Visual Editor

    private var visualEditorView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Visual Effects & Overlays")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                // Visual Modes Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    visualModeCard(
                        name: "Particles",
                        icon: "sparkles",
                        color: .cyan,
                        isActive: true
                    )

                    visualModeCard(
                        name: "Cymatics",
                        icon: "waveform.circle.fill",
                        color: .purple,
                        isActive: false
                    )

                    visualModeCard(
                        name: "Mandala",
                        icon: "circle.hexagongrid.fill",
                        color: .pink,
                        isActive: false
                    )

                    visualModeCard(
                        name: "Spectral",
                        icon: "chart.bar.fill",
                        color: .green,
                        isActive: false
                    )

                    visualModeCard(
                        name: "Fractals",
                        icon: "triangle.fill",
                        color: .orange,
                        isActive: false
                    )

                    visualModeCard(
                        name: "Neural",
                        icon: "brain",
                        color: .blue,
                        isActive: false
                    )
                }
                .padding(.horizontal, 20)

                // Color Mapping
                VStack(spacing: 16) {
                    Text("Biometric Color Mapping")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    colorMappingRow(label: "Heart Rate → Hue", color: .red)
                    colorMappingRow(label: "HRV → Saturation", color: .green)
                    colorMappingRow(label: "Coherence → Brightness", color: .cyan)
                    colorMappingRow(label: "Audio Level → Intensity", color: .yellow)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 100)
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Automation Editor

    private var automationEditor: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Parameter Automation")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                // Automation Lanes
                VStack(spacing: 16) {
                    automationLane(
                        parameter: "Reverb Mix",
                        source: "HRV Coherence",
                        color: .purple
                    )

                    automationLane(
                        parameter: "Spatial Distance",
                        source: "Heart Rate",
                        color: .red
                    )

                    automationLane(
                        parameter: "Visual Intensity",
                        source: "Audio Level",
                        color: .cyan
                    )

                    automationLane(
                        parameter: "Particle Count",
                        source: "Breathing Rate",
                        color: .green
                    )

                    // Add Automation Button
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Automation")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.cyan.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.cyan, lineWidth: 2)
                                )
                        )
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 100)
            }
            .padding(.vertical, 20)
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            Button(action: {}) {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button(action: {}) {
                Label("Clear All", systemImage: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.8))
            }

            Spacer()

            Button(action: {}) {
                Label("Save", systemImage: "square.and.arrow.down.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.cyan)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.8))
        )
    }

    // MARK: - Preset Library Sheet

    private var presetLibrarySheet: some View {
        NavigationView {
            List {
                Section("System Presets") {
                    presetRow(name: "Meditation Flow", icon: "brain", color: .purple)
                    presetRow(name: "High Energy", icon: "bolt.fill", color: .orange)
                    presetRow(name: "Deep Focus", icon: "eye.fill", color: .blue)
                    presetRow(name: "Creative Mode", icon: "paintbrush.fill", color: .pink)
                }

                Section("My Presets") {
                    presetRow(name: "Morning Routine", icon: "sunrise.fill", color: .yellow)
                    presetRow(name: "Night Session", icon: "moon.fill", color: .indigo)
                }
            }
            .navigationTitle("Preset Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showPresetLibrary = false
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private func effectNodeCard(name: String, icon: String, color: Color, parameters: [(String, Double)]) -> some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)

                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {}) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Parameters
            VStack(spacing: 10) {
                ForEach(parameters, id: \.0) { param in
                    parameterSlider(label: param.0, value: .constant(param.1), color: color)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    private func parameterSlider(label: String, value: Binding<Double>, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }

            Slider(value: value, in: 0...1)
                .tint(color)
        }
    }

    private func visualModeCard(name: String, icon: String, color: Color, isActive: Bool) -> some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isActive ? color.opacity(0.3) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isActive ? color : Color.clear, lineWidth: 2)
                    )

                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(isActive ? color : .white.opacity(0.5))

                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isActive ? .white : .white.opacity(0.5))
                }
            }
            .frame(height: 120)
        }
    }

    private func colorMappingRow(label: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func automationLane(parameter: String, source: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(parameter)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: {}) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            HStack {
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(color)

                Text(source)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()
            }

            // Mini automation curve visualization
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 40)

                // Simulated automation curve
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 30))
                    path.addQuadCurve(
                        to: CGPoint(x: 100, y: 10),
                        control: CGPoint(x: 50, y: 35)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: 200, y: 25),
                        control: CGPoint(x: 150, y: 5)
                    )
                }
                .stroke(color, lineWidth: 2)
                .frame(height: 40)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func presetRow(name: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)

            Text(name)

            Spacer()
        }
    }
}

// MARK: - Audio Node Model

struct AudioNode: Identifiable {
    let id = UUID()
    var type: String
    var x: CGFloat
    var y: CGFloat
    var parameters: [String: Double]
}

// MARK: - Preset Model

struct Preset: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
    var color: Color
    var effects: [String]
}

// MARK: - Preview

#Preview {
    StudioEditorView()
        .environmentObject(AudioEngine(microphoneManager: MicrophoneManager()))
        .environmentObject(RecordingEngine())
}

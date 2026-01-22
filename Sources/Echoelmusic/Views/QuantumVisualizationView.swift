//
//  QuantumVisualizationView.swift
//  Echoelmusic
//
//  SwiftUI view for quantum photonics visualization
//  A+++ level UI with full accessibility support
//
//  Created: 2026-01-05
//

import SwiftUI
import Combine

#if canImport(MetalKit)
import MetalKit
#endif

// MARK: - Quantum Visualization View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct QuantumVisualizationView: View {

    @ObservedObject var emulator: QuantumLightEmulator
    @State private var selectedVisualization: PhotonicsVisualizationEngine.VisualizationType = .interferencePattern
    @State private var selectedMode: QuantumLightEmulator.EmulationMode = .bioCoherent
    @State private var showSettings: Bool = false
    @State private var isFullscreen: Bool = false

    public init(emulator: QuantumLightEmulator) {
        self.emulator = emulator
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient based on coherence
                coherenceGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with controls
                    if !isFullscreen {
                        headerView
                            .padding()
                    }

                    // Main visualization area
                    // LAMBDA LOOP: Explicit animation value for smart recalculation
                    visualizationCanvas(size: geometry.size)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isFullscreen.toggle()
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: isFullscreen)

                    // Bottom controls
                    if !isFullscreen {
                        bottomControls
                            .padding()
                    }
                }

                // Floating coherence indicator
                coherenceIndicator
                    .position(x: geometry.size.width - 60, y: 60)

                // Settings sheet
                if showSettings {
                    settingsOverlay
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quantum Light Visualization")
        .accessibilityHint("Double tap to toggle fullscreen mode")
    }

    // MARK: - Subviews (LAMBDA LOOP: @ViewBuilder for optimized rendering)

    @ViewBuilder
    private var coherenceGradient: some View {
        let coherence = Double(emulator.coherenceLevel)
        let topColor = Color(
            hue: 0.55 + coherence * 0.15, // Blue to cyan
            saturation: 0.6,
            brightness: 0.15
        )
        let bottomColor = Color(
            hue: 0.7 + coherence * 0.1, // Purple to violet
            saturation: 0.5,
            brightness: 0.1
        )

        return LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Quantum Light Field")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(emulator.emulationMode.rawValue)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Mode selector
            Menu {
                ForEach(QuantumLightEmulator.EmulationMode.allCases, id: \.self) { mode in
                    Button(mode.rawValue) {
                        selectedMode = mode
                        emulator.setMode(mode)
                    }
                }
            } label: {
                Label("Mode", systemImage: "waveform.circle")
                    .foregroundColor(.white)
            }
            .accessibilityLabel("Select emulation mode")

            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.white)
                    .font(.title2)
            }
            .accessibilityLabel("Settings")
        }
    }

    private func visualizationCanvas(size: CGSize) -> some View {
        ZStack {
            // Visualization content
            QuantumCanvasView(emulator: emulator, visualizationType: selectedVisualization)
                .clipShape(RoundedRectangle(cornerRadius: isFullscreen ? 0 : 20))
                .shadow(color: .black.opacity(0.3), radius: 10)

            // Overlay info
            if !isFullscreen {
                VStack {
                    Spacer()
                    HStack {
                        visualizationLabel
                        Spacer()
                        photonCounter
                    }
                    .padding()
                }
            }
        }
        .frame(height: isFullscreen ? size.height : size.height * 0.6)
        .animation(.spring(), value: isFullscreen)
    }

    private var visualizationLabel: some View {
        Text(selectedVisualization.rawValue)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    private var photonCounter: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
            Text("\(emulator.currentLightField?.photons.count ?? 0)")
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .accessibilityLabel("\(emulator.currentLightField?.photons.count ?? 0) photons active")
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Visualization type picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PhotonicsVisualizationEngine.VisualizationType.allCases, id: \.self) { type in
                        VisualizationButton(
                            type: type,
                            isSelected: selectedVisualization == type
                        ) {
                            withAnimation(.spring()) {
                                selectedVisualization = type
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Control buttons
            HStack(spacing: 20) {
                // Play/Pause
                Button(action: {
                    if emulator.isActive {
                        emulator.stop()
                    } else {
                        emulator.start()
                    }
                }) {
                    Image(systemName: emulator.isActive ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                }
                .accessibilityLabel(emulator.isActive ? "Pause visualization" : "Play visualization")

                // Coherence slider
                VStack(spacing: 4) {
                    Text("Bio-Coherence")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))

                    CoherenceBar(value: Double(emulator.coherenceLevel))
                        .frame(width: 150, height: 8)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Bio coherence level: \(Int(emulator.coherenceLevel * 100)) percent")
            }
        }
    }

    private var coherenceIndicator: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            coherenceColor.opacity(0.8),
                            coherenceColor.opacity(0.2)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)

            Text("\(Int(emulator.coherenceLevel * 100))")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .accessibilityHidden(true) // Already announced in bottom controls
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

    private var settingsOverlay: some View {
        Color.black.opacity(0.5)
            .ignoresSafeArea()
            .onTapGesture { showSettings = false }
            .overlay {
                QuantumSettingsPanel(emulator: emulator, isPresented: $showSettings)
                    .frame(maxWidth: 400)
                    .padding()
            }
    }
}

// MARK: - Visualization Button

struct VisualizationButton: View {
    let type: PhotonicsVisualizationEngine.VisualizationType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconForType(type))
                    .font(.title2)

                Text(shortName(type))
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 70, height: 70)
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.1))
            )
        }
        .accessibilityLabel("\(type.rawValue) visualization")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func iconForType(_ type: PhotonicsVisualizationEngine.VisualizationType) -> String {
        switch type {
        case .interferencePattern: return "wave.3.right"
        case .waveFunction: return "waveform"
        case .coherenceField: return "circle.hexagongrid"
        case .photonFlow: return "sparkles"
        case .sacredGeometry: return "seal"
        case .quantumTunnel: return "circle.dashed"
        case .biophotonAura: return "person.wave.2"
        case .lightMandala: return "sun.max"
        case .holographicDisplay: return "cube.transparent"
        case .cosmicWeb: return "network"
        }
    }

    private func shortName(_ type: PhotonicsVisualizationEngine.VisualizationType) -> String {
        switch type {
        case .interferencePattern: return "Interference"
        case .waveFunction: return "Wave Fn"
        case .coherenceField: return "Coherence"
        case .photonFlow: return "Photons"
        case .sacredGeometry: return "Sacred"
        case .quantumTunnel: return "Tunnel"
        case .biophotonAura: return "Aura"
        case .lightMandala: return "Mandala"
        case .holographicDisplay: return "Hologram"
        case .cosmicWeb: return "Cosmic"
        }
    }
}

// MARK: - Coherence Bar

struct CoherenceBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.red, .yellow, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(value))
            }
        }
    }
}

// MARK: - Quantum Canvas View (Metal-backed)

struct QuantumCanvasView: View {
    @ObservedObject var emulator: QuantumLightEmulator
    let visualizationType: PhotonicsVisualizationEngine.VisualizationType

    @State private var frameData: [[SIMD3<Float>]] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, size in
                let visualization = emulator.generateLightFieldVisualization(
                    width: Int(size.width / 4),
                    height: Int(size.height / 4)
                )

                // Render pixels
                let pixelWidth = size.width / CGFloat(max(1, visualization.first?.count ?? 1))
                let pixelHeight = size.height / CGFloat(max(1, visualization.count))

                for (y, row) in visualization.enumerated() {
                    for (x, color) in row.enumerated() {
                        let rect = CGRect(
                            x: CGFloat(x) * pixelWidth,
                            y: CGFloat(y) * pixelHeight,
                            width: pixelWidth + 1,
                            height: pixelHeight + 1
                        )

                        let swiftColor = Color(
                            red: Double(color.x),
                            green: Double(color.y),
                            blue: Double(color.z)
                        )

                        context.fill(Path(rect), with: .color(swiftColor))
                    }
                }
            }
        }
        .background(Color.black)
    }
}

// MARK: - Settings Panel

struct QuantumSettingsPanel: View {
    @ObservedObject var emulator: QuantumLightEmulator
    @Binding var isPresented: Bool

    @State private var qubitCount: Double = 8
    @State private var photonCount: Double = 64
    @State private var coherenceThreshold: Double = 0.7
    @State private var glowIntensity: Double = 0.5

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Quantum Settings")
                    .font(.headline)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                }
            }

            Divider()

            Group {
                SettingSlider(
                    title: "Qubits",
                    value: $qubitCount,
                    range: 2...32,
                    icon: "atom"
                )

                SettingSlider(
                    title: "Photons",
                    value: $photonCount,
                    range: 8...256,
                    icon: "sparkle"
                )

                SettingSlider(
                    title: "Coherence Threshold",
                    value: $coherenceThreshold,
                    range: 0...1,
                    icon: "waveform.path.ecg"
                )

                SettingSlider(
                    title: "Glow Intensity",
                    value: $glowIntensity,
                    range: 0...1,
                    icon: "sun.max"
                )
            }

            Divider()

            // Entanglement Network
            VStack(alignment: .leading, spacing: 8) {
                Text("Entanglement Network")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if emulator.entanglementNetwork.isEmpty {
                    Text("No entangled devices")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(emulator.entanglementNetwork.keys), id: \.self) { device in
                        HStack {
                            Image(systemName: "link")
                            Text(device)
                            Spacer()
                            Text("\(Int((emulator.entanglementNetwork[device] ?? 0) * 100))%")
                        }
                        .font(.caption)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Slider(value: $value, in: range)
                .tint(.blue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(String(format: "%.1f", value))")
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 10
            switch direction {
            case .increment:
                value = min(range.upperBound, value + step)
            case .decrement:
                value = max(range.lowerBound, value - step)
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
struct QuantumVisualizationView_Previews: PreviewProvider {
    static var previews: some View {
        QuantumVisualizationView(emulator: QuantumLightEmulator())
            .preferredColorScheme(.dark)
    }
}
#endif

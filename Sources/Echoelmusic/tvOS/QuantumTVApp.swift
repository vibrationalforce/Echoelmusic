//
//  QuantumTVApp.swift
//  Echoelmusic
//
//  tvOS App for Quantum Light Experience on Apple TV
//  Big screen immersive visualization for living rooms
//
//  Created: 2026-01-05
//

#if os(tvOS)
import SwiftUI
import TVUIKit

// MARK: - Main tvOS App View

@available(tvOS 16.0, *)
public struct QuantumTVMainView: View {

    @StateObject private var viewModel = QuantumTVViewModel()
    @FocusState private var focusedSection: TVSection?

    public enum TVSection: Hashable {
        case visualization
        case presets
        case modes
        case settings
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen visualization background
                QuantumTVVisualizationView(viewModel: viewModel)
                    .ignoresSafeArea()

                // Overlay UI
                VStack {
                    // Top bar with coherence
                    HStack {
                        QuantumCoherencePill(coherence: viewModel.coherenceLevel)

                        Spacer()

                        if viewModel.isSessionActive {
                            SessionTimerView(duration: viewModel.sessionDuration)
                        }

                        Spacer()

                        ModeIndicator(mode: viewModel.currentMode)
                    }
                    .padding(.horizontal, 60)
                    .padding(.top, 40)

                    Spacer()

                    // Bottom navigation shelf
                    TVNavigationShelf(viewModel: viewModel, focusedSection: $focusedSection)
                        .padding(.bottom, 40)
                }
            }
            .onAppear {
                viewModel.startSession()
            }
            .onDisappear {
                viewModel.stopSession()
            }
            .onPlayPauseCommand {
                viewModel.togglePlayPause()
            }
            .onMoveCommand { direction in
                handleRemoteNavigation(direction)
            }
        }
    }

    private func handleRemoteNavigation(_ direction: MoveCommandDirection) {
        switch direction {
        case .up:
            viewModel.increaseCoherence()
        case .down:
            viewModel.decreaseCoherence()
        case .left:
            viewModel.previousVisualization()
        case .right:
            viewModel.nextVisualization()
        @unknown default:
            break
        }
    }
}

// MARK: - TV View Model

@available(tvOS 15.0, *)
@MainActor
public class QuantumTVViewModel: ObservableObject {

    @Published public var coherenceLevel: Float = 0.5
    @Published public var currentMode: QuantumLightEmulator.EmulationMode = .bioCoherent
    @Published public var currentVisualization: PhotonicsVisualizationEngine.VisualizationType = .coherenceField
    @Published public var isSessionActive: Bool = false
    @Published public var sessionDuration: TimeInterval = 0

    private var emulator: QuantumLightEmulator?
    private var visualizationEngine: PhotonicsVisualizationEngine?
    private var displayLink: CADisplayLink?
    private var sessionStartTime: Date?

    public init() {
        setupEmulator()
    }

    private func setupEmulator() {
        emulator = QuantumLightEmulator()
        emulator?.setMode(currentMode)

        visualizationEngine = PhotonicsVisualizationEngine()
        visualizationEngine?.setVisualizationType(currentVisualization)
    }

    public func startSession() {
        isSessionActive = true
        sessionStartTime = Date()
        emulator?.start()

        displayLink = CADisplayLink(target: self, selector: #selector(updateLoop))
        displayLink?.add(to: .main, forMode: .common)
    }

    public func stopSession() {
        isSessionActive = false
        displayLink?.invalidate()
        displayLink = nil
        emulator?.stop()
    }

    @objc private func updateLoop() {
        if let startTime = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(startTime)
        }

        if let emulator = emulator {
            coherenceLevel = emulator.coherenceLevel
        }
    }

    public func togglePlayPause() {
        if isSessionActive {
            stopSession()
        } else {
            startSession()
        }
    }

    public func increaseCoherence() {
        coherenceLevel = min(1.0, coherenceLevel + 0.1)
    }

    public func decreaseCoherence() {
        coherenceLevel = max(0.0, coherenceLevel - 0.1)
    }

    public func nextVisualization() {
        let allTypes = PhotonicsVisualizationEngine.VisualizationType.allCases
        if let currentIndex = allTypes.firstIndex(of: currentVisualization) {
            let nextIndex = (currentIndex + 1) % allTypes.count
            currentVisualization = allTypes[nextIndex]
            visualizationEngine?.setVisualizationType(currentVisualization)
        }
    }

    public func previousVisualization() {
        let allTypes = PhotonicsVisualizationEngine.VisualizationType.allCases
        if let currentIndex = allTypes.firstIndex(of: currentVisualization) {
            let prevIndex = (currentIndex - 1 + allTypes.count) % allTypes.count
            currentVisualization = allTypes[prevIndex]
            visualizationEngine?.setVisualizationType(currentVisualization)
        }
    }

    public func setMode(_ mode: QuantumLightEmulator.EmulationMode) {
        currentMode = mode
        emulator?.setMode(mode)
    }

    public func selectPreset(_ preset: QuantumPreset) {
        if let mode = QuantumLightEmulator.EmulationMode(rawValue: preset.emulationMode) {
            setMode(mode)
        }
        if let vizType = PhotonicsVisualizationEngine.VisualizationType.allCases.first(where: { $0.rawValue == preset.visualizationType }) {
            currentVisualization = vizType
            visualizationEngine?.setVisualizationType(vizType)
        }
    }
}

// MARK: - TV Visualization View

@available(tvOS 15.0, *)
struct QuantumTVVisualizationView: View {
    @ObservedObject var viewModel: QuantumTVViewModel

    var body: some View {
        Canvas { context, size in
            // Draw visualization based on current type
            drawVisualization(context: context, size: size)
        }
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var gradientColors: [Color] {
        let coherence = Double(viewModel.coherenceLevel)
        if coherence > 0.7 {
            return [.purple.opacity(0.8), .cyan.opacity(0.6), .blue.opacity(0.4)]
        } else if coherence > 0.4 {
            return [.blue.opacity(0.8), .teal.opacity(0.6), .green.opacity(0.4)]
        } else {
            return [.orange.opacity(0.8), .red.opacity(0.6), .purple.opacity(0.4)]
        }
    }

    private func drawVisualization(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let coherence = CGFloat(viewModel.coherenceLevel)

        switch viewModel.currentVisualization {
        case .interferencePattern:
            drawInterferencePattern(context: context, size: size, coherence: coherence)
        case .waveFunction:
            drawWaveFunction(context: context, center: center, coherence: coherence)
        case .coherenceField:
            drawCoherenceField(context: context, size: size, coherence: coherence)
        case .photonFlow:
            drawPhotonFlow(context: context, size: size, coherence: coherence)
        case .sacredGeometry:
            drawSacredGeometry(context: context, center: center, size: size, coherence: coherence)
        case .quantumTunnel:
            drawQuantumTunnel(context: context, center: center, coherence: coherence)
        case .biophotonAura:
            drawBiophotonAura(context: context, center: center, coherence: coherence)
        case .lightMandala:
            drawLightMandala(context: context, center: center, coherence: coherence)
        case .holographicDisplay:
            drawHolographic(context: context, size: size, coherence: coherence)
        case .cosmicWeb:
            drawCosmicWeb(context: context, size: size, coherence: coherence)
        }
    }

    // MARK: - Visualization Renderers

    private func drawInterferencePattern(context: GraphicsContext, size: CGSize, coherence: CGFloat) {
        for i in 0..<50 {
            let y = CGFloat(i) * (size.height / 50)
            let amplitude = sin(CGFloat(i) * 0.3 * coherence) * 20

            var path = Path()
            path.move(to: CGPoint(x: 0, y: y + amplitude))

            for x in stride(from: 0, to: size.width, by: 10) {
                let wave = sin(x * 0.02 + CGFloat(i) * 0.1) * amplitude
                path.addLine(to: CGPoint(x: x, y: y + wave))
            }

            context.stroke(
                path,
                with: .color(.white.opacity(0.3 + Double(coherence) * 0.3)),
                lineWidth: 1
            )
        }
    }

    private func drawWaveFunction(context: GraphicsContext, center: CGPoint, coherence: CGFloat) {
        let rings = Int(10 + coherence * 20)
        for i in 0..<rings {
            let radius = CGFloat(i) * 40 * (1 + coherence * 0.5)
            let opacity = 1.0 - Double(i) / Double(rings)

            let circle = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            context.stroke(
                circle,
                with: .color(.cyan.opacity(opacity * 0.5)),
                lineWidth: 2 + coherence * 2
            )
        }
    }

    private func drawCoherenceField(context: GraphicsContext, size: CGSize, coherence: CGFloat) {
        let gridSize = 20
        let cellWidth = size.width / CGFloat(gridSize)
        let cellHeight = size.height / CGFloat(gridSize)

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = CGFloat(col) * cellWidth
                let y = CGFloat(row) * cellHeight

                let noise = sin(CGFloat(row + col) * coherence * 0.5)
                let brightness = 0.2 + abs(noise) * 0.6

                let rect = CGRect(x: x, y: y, width: cellWidth - 2, height: cellHeight - 2)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 4),
                    with: .color(.purple.opacity(brightness))
                )
            }
        }
    }

    private func drawPhotonFlow(context: GraphicsContext, size: CGSize, coherence: CGFloat) {
        let photonCount = Int(50 + coherence * 100)
        for i in 0..<photonCount {
            let progress = CGFloat(i) / CGFloat(photonCount)
            let x = size.width * progress
            let y = size.height / 2 + sin(progress * .pi * 4) * 100 * coherence

            let photonSize = 4 + coherence * 8

            context.fill(
                Path(ellipseIn: CGRect(x: x - photonSize/2, y: y - photonSize/2, width: photonSize, height: photonSize)),
                with: .color(.white.opacity(0.6 + Double(coherence) * 0.4))
            )
        }
    }

    private func drawSacredGeometry(context: GraphicsContext, center: CGPoint, size: CGSize, coherence: CGFloat) {
        let petals = 6
        let radius = min(size.width, size.height) * 0.3

        for layer in 0..<Int(3 + coherence * 4) {
            let layerRadius = radius * CGFloat(layer + 1) / 4

            for petal in 0..<petals {
                let angle = CGFloat(petal) * .pi * 2 / CGFloat(petals)
                let petalCenter = CGPoint(
                    x: center.x + cos(angle) * layerRadius,
                    y: center.y + sin(angle) * layerRadius
                )

                let circle = Path(ellipseIn: CGRect(
                    x: petalCenter.x - layerRadius,
                    y: petalCenter.y - layerRadius,
                    width: layerRadius * 2,
                    height: layerRadius * 2
                ))

                context.stroke(
                    circle,
                    with: .color(.yellow.opacity(0.4)),
                    lineWidth: 1.5
                )
            }
        }
    }

    private func drawQuantumTunnel(context: GraphicsContext, center: CGPoint, coherence: CGFloat) {
        let rings = 30
        for i in 0..<rings {
            let progress = CGFloat(i) / CGFloat(rings)
            let radius = 50 + progress * 400 * (1 + coherence)
            let opacity = 1.0 - progress

            let ellipse = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius * 0.5,
                width: radius * 2,
                height: radius
            ))

            let hue = progress * 0.3 + Double(coherence) * 0.5
            context.stroke(
                ellipse,
                with: .color(Color(hue: hue, saturation: 0.8, brightness: 0.9).opacity(opacity)),
                lineWidth: 2
            )
        }
    }

    private func drawBiophotonAura(context: GraphicsContext, center: CGPoint, coherence: CGFloat) {
        let auraLayers: [(Color, CGFloat)] = [
            (.red, 100),
            (.orange, 150),
            (.yellow, 200),
            (.green, 250),
            (.cyan, 300),
            (.blue, 350),
            (.purple, 400)
        ]

        for (color, baseRadius) in auraLayers {
            let radius = baseRadius * (0.8 + coherence * 0.4)

            var aura = Path()
            for angle in stride(from: 0, to: CGFloat.pi * 2, by: 0.1) {
                let noise = sin(angle * 6) * 20 * coherence
                let r = radius + noise
                let point = CGPoint(
                    x: center.x + cos(angle) * r,
                    y: center.y + sin(angle) * r
                )
                if angle == 0 {
                    aura.move(to: point)
                } else {
                    aura.addLine(to: point)
                }
            }
            aura.closeSubpath()

            context.fill(
                aura,
                with: .color(color.opacity(0.15))
            )
            context.stroke(
                aura,
                with: .color(color.opacity(0.5)),
                lineWidth: 2
            )
        }
    }

    private func drawLightMandala(context: GraphicsContext, center: CGPoint, coherence: CGFloat) {
        let arms = Int(6 + coherence * 12)
        let rings = 5

        for ring in 0..<rings {
            let ringRadius = CGFloat(ring + 1) * 80

            for arm in 0..<arms {
                let angle = CGFloat(arm) * .pi * 2 / CGFloat(arms)
                let endPoint = CGPoint(
                    x: center.x + cos(angle) * ringRadius,
                    y: center.y + sin(angle) * ringRadius
                )

                var line = Path()
                line.move(to: center)
                line.addLine(to: endPoint)

                let hue = Double(arm) / Double(arms)
                context.stroke(
                    line,
                    with: .color(Color(hue: hue, saturation: 0.7, brightness: 0.9).opacity(0.6)),
                    lineWidth: 2
                )
            }
        }
    }

    private func drawHolographic(context: GraphicsContext, size: CGSize, coherence: CGFloat) {
        let lineCount = Int(30 + coherence * 50)

        for i in 0..<lineCount {
            let progress = CGFloat(i) / CGFloat(lineCount)
            let x = progress * size.width

            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))

            for y in stride(from: 0, to: size.height, by: 5) {
                let wave = sin(CGFloat(y) * 0.02 + progress * .pi * 2) * 20 * coherence
                line.addLine(to: CGPoint(x: x + wave, y: y))
            }

            let hue = Double(progress) * 0.3
            context.stroke(
                line,
                with: .color(Color(hue: hue, saturation: 0.6, brightness: 0.8).opacity(0.4)),
                lineWidth: 1
            )
        }
    }

    private func drawCosmicWeb(context: GraphicsContext, size: CGSize, coherence: CGFloat) {
        let nodeCount = Int(20 + coherence * 30)
        var nodes: [CGPoint] = []

        // Generate nodes
        for _ in 0..<nodeCount {
            nodes.append(CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            ))
        }

        // Draw connections
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let distance = hypot(nodes[i].x - nodes[j].x, nodes[i].y - nodes[j].y)
                let maxDistance = 200 * (1 + coherence)

                if distance < maxDistance {
                    var line = Path()
                    line.move(to: nodes[i])
                    line.addLine(to: nodes[j])

                    let opacity = 1.0 - Double(distance / maxDistance)
                    context.stroke(
                        line,
                        with: .color(.cyan.opacity(opacity * 0.5)),
                        lineWidth: 1
                    )
                }
            }
        }

        // Draw nodes
        for node in nodes {
            context.fill(
                Path(ellipseIn: CGRect(x: node.x - 4, y: node.y - 4, width: 8, height: 8)),
                with: .color(.white.opacity(0.8))
            )
        }
    }
}

// MARK: - TV UI Components

@available(tvOS 15.0, *)
struct QuantumCoherencePill: View {
    let coherence: Float

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundColor(coherenceColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("COHERENCE")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(Int(coherence * 100))%")
                    .font(.title3.bold())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var coherenceColor: Color {
        if coherence > 0.7 { return .green }
        if coherence > 0.4 { return .yellow }
        return .orange
    }
}

@available(tvOS 15.0, *)
struct SessionTimerView: View {
    let duration: TimeInterval

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .foregroundColor(.cyan)

            Text(formatDuration(duration))
                .font(.title3.monospacedDigit())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

@available(tvOS 15.0, *)
struct ModeIndicator: View {
    let mode: QuantumLightEmulator.EmulationMode

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "atom")
                .foregroundColor(.purple)

            Text(mode.rawValue.uppercased())
                .font(.caption.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

@available(tvOS 15.0, *)
struct TVNavigationShelf: View {
    @ObservedObject var viewModel: QuantumTVViewModel
    @FocusState.Binding var focusedSection: QuantumTVMainView.TVSection?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 30) {
                // Visualization selector
                TVShelfButton(
                    icon: "sparkles",
                    title: "Visualization",
                    subtitle: viewModel.currentVisualization.rawValue,
                    isSelected: focusedSection == .visualization
                ) {
                    viewModel.nextVisualization()
                }
                .focused($focusedSection, equals: .visualization)

                // Preset selector
                NavigationLink {
                    TVPresetPickerView(viewModel: viewModel)
                } label: {
                    TVShelfButtonContent(
                        icon: "list.star",
                        title: "Presets",
                        subtitle: "15 experiences",
                        isSelected: focusedSection == .presets
                    )
                }
                .buttonStyle(.card)
                .focused($focusedSection, equals: .presets)

                // Mode selector
                TVShelfButton(
                    icon: "slider.horizontal.3",
                    title: "Mode",
                    subtitle: viewModel.currentMode.rawValue,
                    isSelected: focusedSection == .modes
                ) {
                    let modes = QuantumLightEmulator.EmulationMode.allCases
                    if let index = modes.firstIndex(of: viewModel.currentMode) {
                        let nextIndex = (index + 1) % modes.count
                        viewModel.setMode(modes[nextIndex])
                    }
                }
                .focused($focusedSection, equals: .modes)

                // Settings
                NavigationLink {
                    TVSettingsView()
                } label: {
                    TVShelfButtonContent(
                        icon: "gearshape",
                        title: "Settings",
                        subtitle: "Configure",
                        isSelected: focusedSection == .settings
                    )
                }
                .buttonStyle(.card)
                .focused($focusedSection, equals: .settings)
            }
            .padding(.horizontal, 60)
        }
    }
}

@available(tvOS 15.0, *)
struct TVShelfButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TVShelfButtonContent(
                icon: icon,
                title: title,
                subtitle: subtitle,
                isSelected: isSelected
            )
        }
        .buttonStyle(.card)
    }
}

@available(tvOS 15.0, *)
struct TVShelfButtonContent: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(isSelected ? .cyan : .white)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 200, height: 150)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - TV Preset Picker

@available(tvOS 15.0, *)
struct TVPresetPickerView: View {
    @ObservedObject var viewModel: QuantumTVViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 30) {
                ForEach(PresetManager.shared.allPresets) { preset in
                    Button {
                        viewModel.selectPreset(preset)
                        dismiss()
                    } label: {
                        TVPresetCard(preset: preset)
                    }
                    .buttonStyle(.card)
                }
            }
            .padding(60)
        }
        .navigationTitle("Quantum Presets")
    }
}

@available(tvOS 15.0, *)
struct TVPresetCard: View {
    let preset: QuantumPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(preset.icon)
                    .font(.largeTitle)

                Spacer()

                Text(preset.category.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }

            Text(preset.name)
                .font(.title3.bold())

            Text(preset.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Label("\(Int(preset.sessionDuration / 60))m", systemImage: "clock")
                Spacer()
                Label(preset.emulationMode, systemImage: "atom")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(width: 300, height: 180)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - TV Settings View

@available(tvOS 15.0, *)
struct TVSettingsView: View {
    @AppStorage("tv_auto_dim") private var autoDim = true
    @AppStorage("tv_ambient_mode") private var ambientMode = true
    @AppStorage("tv_sound_enabled") private var soundEnabled = true

    var body: some View {
        List {
            Section("Display") {
                Toggle("Auto-Dim Room Lights", isOn: $autoDim)
                Toggle("Ambient Mode", isOn: $ambientMode)
            }

            Section("Audio") {
                Toggle("Quantum Sounds", isOn: $soundEnabled)
            }

            Section("About") {
                LabeledContent("Version", value: "1.0.0")
                LabeledContent("Quantum Engine", value: "Phase 4")
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Top Shelf Provider

@available(tvOS 15.0, *)
public struct QuantumTopShelfProvider {

    public static func topShelfItems() -> [TVTopShelfItem] {
        let presets = PresetManager.shared.allPresets.prefix(5)

        return presets.map { preset in
            let item = TVTopShelfItem(identifier: preset.id)
            if let presetURL = URL(string: "echoelmusic://preset/\(preset.id)") {
                item.displayAction = TVTopShelfAction(url: presetURL)
            }
            return item
        }
    }
}

#endif

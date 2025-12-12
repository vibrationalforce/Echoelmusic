import SwiftUI
import Combine

// MARK: - Instrument Mode View
// Intuitive interface that feels like an instrument
// Simple to complex pieces - just play and explore

/// InstrumentModeView - Das Instrument zum Anfassen
///
/// **Philosophie:**
/// - Fühlt sich an wie ein echtes Instrument
/// - Einfache bis komplexe Stücke möglich
/// - Leichtes Wechseln zwischen Modi
/// - Übersichtlich für alle Zielgruppen
///
/// **Zielgruppen:**
/// - Anfänger: Simplified Mode mit Führung
/// - Fortgeschrittene: Standard Mode mit allen Optionen
/// - Profis: Expert Mode mit maximaler Kontrolle
/// - Therapeuten: Clinical Mode mit Protokollen
/// - Forscher: Research Mode mit Datenexport
@MainActor
public struct InstrumentModeView: View {

    // MARK: - State

    @StateObject private var controller = InstrumentController()
    @State private var showModeSelector = false
    @State private var showSettings = false

    public init() {}

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                instrumentBackground

                // Main content based on complexity
                VStack(spacing: 0) {
                    // Top bar (minimal when playing)
                    topBar
                        .opacity(controller.isPlaying ? 0.6 : 1.0)

                    // Main instrument area
                    instrumentArea(geometry: geometry)

                    // Bottom controls
                    bottomControls
                }

                // Mode selector overlay
                if showModeSelector {
                    modeSelectorOverlay
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            controller.setup()
        }
    }

    // MARK: - Background

    private var instrumentBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    controller.currentMode.backgroundColor.opacity(0.3),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Bio-reactive glow
            if controller.bioReactiveEnabled {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                controller.coherenceColor.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 400
                        )
                    )
                    .scaleEffect(1.0 + controller.breathingPhase * 0.1)
                    .animation(.easeInOut(duration: 4), value: controller.breathingPhase)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Mode button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    showModeSelector.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: controller.currentMode.icon)
                        .font(.title3)

                    if !controller.isPlaying {
                        Text(controller.currentMode.displayName)
                            .font(.headline)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(controller.currentMode.accentColor.opacity(0.2))
                .cornerRadius(20)
            }
            .foregroundColor(controller.currentMode.accentColor)

            Spacer()

            // Bio metrics (when active)
            if controller.bioReactiveEnabled {
                bioMetricsCompact
            }

            // Settings
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var bioMetricsCompact: some View {
        HStack(spacing: 12) {
            // Heart rate
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .scaleEffect(controller.heartbeatScale)

                Text(controller.formattedBPM)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
            }

            // Coherence
            HStack(spacing: 4) {
                Circle()
                    .fill(controller.coherenceColor)
                    .frame(width: 10, height: 10)

                Text("\(Int(controller.coherence))%")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }

    // MARK: - Instrument Area

    private func instrumentArea(geometry: GeometryProxy) -> some View {
        Group {
            switch controller.currentMode.complexity {
            case .simple:
                simpleInstrument(geometry: geometry)
            case .standard:
                standardInstrument(geometry: geometry)
            case .advanced:
                advancedInstrument(geometry: geometry)
            case .expert:
                expertInstrument(geometry: geometry)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Simple Mode (Beginners)

    private func simpleInstrument(geometry: GeometryProxy) -> some View {
        VStack(spacing: 30) {
            Spacer()

            // One big play area
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                controller.currentMode.accentColor,
                                controller.currentMode.accentColor.opacity(0.3)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .scaleEffect(controller.isPlaying ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: controller.isPlaying)

                VStack {
                    Image(systemName: controller.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 60))

                    Text(controller.isPlaying ? "Pause" : "Play")
                        .font(.title2)
                }
                .foregroundColor(.white)
            }
            .onTapGesture {
                controller.togglePlayPause()
            }

            // Simple info
            Text(controller.currentMode.description)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            // Intensity slider only
            VStack(spacing: 8) {
                Text("Intensität")
                    .font(.caption)
                    .foregroundColor(.gray)

                Slider(value: $controller.intensity, in: 0...1)
                    .accentColor(controller.currentMode.accentColor)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: Standard Mode

    private func standardInstrument(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            // XY Pad
            xyPad(size: min(geometry.size.width - 40, 300))

            // Parameter controls
            HStack(spacing: 20) {
                parameterKnob(label: "Tempo", value: $controller.tempo, range: 40...180)
                parameterKnob(label: "Harmonie", value: $controller.harmony, range: 0...1)
                parameterKnob(label: "Raum", value: $controller.space, range: 0...1)
            }
            .padding(.horizontal)
        }
    }

    // MARK: Advanced Mode

    private func advancedInstrument(geometry: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            // Multi-touch area
            multiTouchArea(geometry: geometry)

            // Parameter matrix
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(controller.parameters) { param in
                    parameterCell(param)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Expert Mode

    private func expertInstrument(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left: Sequencer
            VStack {
                Text("Sequencer")
                    .font(.caption)
                    .foregroundColor(.gray)

                sequencerView
            }
            .frame(width: geometry.size.width * 0.4)

            Divider()
                .background(Color.gray.opacity(0.3))

            // Right: Mixer + Effects
            VStack {
                // Mixer
                mixerView
                    .frame(height: geometry.size.height * 0.4)

                Divider()

                // Effects
                effectsView
            }
            .frame(width: geometry.size.width * 0.6)
        }
    }

    // MARK: - Components

    private func xyPad(size: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack {
                // Grid
                Canvas { context, canvasSize in
                    let gridCount = 8
                    let step = canvasSize.width / CGFloat(gridCount)

                    for i in 0...gridCount {
                        let pos = CGFloat(i) * step

                        // Vertical
                        var vPath = Path()
                        vPath.move(to: CGPoint(x: pos, y: 0))
                        vPath.addLine(to: CGPoint(x: pos, y: canvasSize.height))
                        context.stroke(vPath, with: .color(.white.opacity(0.1)), lineWidth: 1)

                        // Horizontal
                        var hPath = Path()
                        hPath.move(to: CGPoint(x: 0, y: pos))
                        hPath.addLine(to: CGPoint(x: canvasSize.width, y: pos))
                        context.stroke(hPath, with: .color(.white.opacity(0.1)), lineWidth: 1)
                    }
                }

                // Touch point
                Circle()
                    .fill(controller.currentMode.accentColor)
                    .frame(width: 40, height: 40)
                    .position(
                        x: controller.xyPosition.x * geo.size.width,
                        y: controller.xyPosition.y * geo.size.height
                    )
                    .shadow(color: controller.currentMode.accentColor, radius: 10)
            }
            .background(Color.black.opacity(0.3))
            .cornerRadius(12)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        controller.xyPosition = CGPoint(
                            x: max(0, min(1, value.location.x / geo.size.width)),
                            y: max(0, min(1, value.location.y / geo.size.height))
                        )
                    }
            )
        }
        .frame(width: size, height: size)
    }

    private func parameterKnob(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: (value.wrappedValue - range.lowerBound) / (range.upperBound - range.lowerBound))
                    .stroke(controller.currentMode.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text(String(format: "%.0f", value.wrappedValue))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(width: 60, height: 60)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let delta = -gesture.translation.height / 100
                        let newValue = value.wrappedValue + delta * (range.upperBound - range.lowerBound)
                        value.wrappedValue = max(range.lowerBound, min(range.upperBound, newValue))
                    }
            )

            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    private func multiTouchArea(geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            // Draw active touches
            for touch in controller.activeTouches {
                let center = CGPoint(
                    x: touch.position.x * size.width,
                    y: touch.position.y * size.height
                )

                // Glow
                context.fill(
                    Circle().path(in: CGRect(
                        x: center.x - 30,
                        y: center.y - 30,
                        width: 60,
                        height: 60
                    )),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(hue: touch.hue, saturation: 0.8, brightness: 1.0),
                            .clear
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: 30 * touch.pressure
                    )
                )
            }
        }
        .frame(height: geometry.size.height * 0.4)
        .background(Color.black.opacity(0.2))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func parameterCell(_ param: InstrumentController.Parameter) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.2f", param.value))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)

            Text(param.name)
                .font(.caption2)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(controller.currentMode.accentColor.opacity(param.value * 0.3))
        .cornerRadius(8)
    }

    private var sequencerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(0..<16, id: \.self) { step in
                    VStack(spacing: 2) {
                        ForEach(0..<8, id: \.self) { note in
                            Rectangle()
                                .fill(controller.sequencerGrid[step][note] ?
                                      controller.currentMode.accentColor :
                                      Color.gray.opacity(0.2))
                                .frame(width: 30, height: 20)
                                .onTapGesture {
                                    controller.toggleSequencerStep(step: step, note: note)
                                }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.black.opacity(0.2))
    }

    private var mixerView: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { channel in
                VStack {
                    // Fader
                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))

                            Rectangle()
                                .fill(controller.currentMode.accentColor)
                                .frame(height: geo.size.height * controller.mixerLevels[channel])
                        }
                    }
                    .frame(width: 40)
                    .cornerRadius(4)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Update fader
                            }
                    )

                    Text("Ch \(channel + 1)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
    }

    private var effectsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                effectButton(name: "Reverb", icon: "waveform.path", active: true)
                effectButton(name: "Delay", icon: "repeat", active: false)
                effectButton(name: "Filter", icon: "line.horizontal.3.decrease", active: true)
                effectButton(name: "Comp", icon: "arrow.down.right.and.arrow.up.left", active: false)
            }
            .padding()
        }
    }

    private func effectButton(name: String, icon: String, active: Bool) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(active ? controller.currentMode.accentColor : .gray)

            Text(name)
                .font(.caption2)
                .foregroundColor(active ? .white : .gray)
        }
        .frame(width: 60, height: 60)
        .background(active ? controller.currentMode.accentColor.opacity(0.2) : Color.black.opacity(0.2))
        .cornerRadius(8)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        HStack(spacing: 30) {
            // Record
            Button {
                controller.toggleRecord()
            } label: {
                Circle()
                    .fill(controller.isRecording ? Color.red : Color.red.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color.red, lineWidth: 2)
                    )
            }

            // Play/Pause
            Button {
                controller.togglePlayPause()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(controller.currentMode.accentColor)
            }

            // Stop
            Button {
                controller.stop()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Mode Selector

    private var modeSelectorOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showModeSelector = false
                    }
                }

            VStack(spacing: 20) {
                Text("Wähle deinen Modus")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                // Complexity selector
                HStack(spacing: 12) {
                    ForEach(InstrumentMode.Complexity.allCases, id: \.self) { complexity in
                        Button {
                            controller.setComplexity(complexity)
                        } label: {
                            VStack {
                                Image(systemName: complexity.icon)
                                    .font(.title)
                                Text(complexity.displayName)
                                    .font(.caption)
                            }
                            .frame(width: 80, height: 70)
                            .background(
                                controller.currentMode.complexity == complexity ?
                                    Color.blue.opacity(0.3) : Color.white.opacity(0.1)
                            )
                            .cornerRadius(12)
                        }
                        .foregroundColor(.white)
                    }
                }

                Divider()
                    .background(Color.gray)
                    .padding(.horizontal, 40)

                // Mode grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(InstrumentMode.allCases, id: \.self) { mode in
                        modeCard(mode)
                    }
                }
                .padding(.horizontal)

                Button("Schließen") {
                    withAnimation {
                        showModeSelector = false
                    }
                }
                .foregroundColor(.gray)
                .padding(.top)
            }
            .padding()
        }
    }

    private func modeCard(_ mode: InstrumentMode) -> some View {
        Button {
            controller.setMode(mode)
            withAnimation {
                showModeSelector = false
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.title)
                    .foregroundColor(mode.accentColor)

                Text(mode.displayName)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(mode.shortDescription)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                controller.currentMode == mode ?
                    mode.accentColor.opacity(0.2) : Color.white.opacity(0.05)
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        controller.currentMode == mode ? mode.accentColor : Color.clear,
                        lineWidth: 2
                    )
            )
        }
    }
}

// MARK: - Instrument Controller

@MainActor
final class InstrumentController: ObservableObject {

    @Published var currentMode: InstrumentMode = .relaxation
    @Published var isPlaying: Bool = false
    @Published var isRecording: Bool = false
    @Published var bioReactiveEnabled: Bool = true

    // Bio data
    @Published var bpm: Double = 72.0
    @Published var coherence: Double = 50.0
    @Published var breathingPhase: Double = 0
    @Published var heartbeatScale: Double = 1.0

    // Parameters
    @Published var intensity: Double = 0.5
    @Published var tempo: Double = 80
    @Published var harmony: Double = 0.5
    @Published var space: Double = 0.3
    @Published var xyPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)

    @Published var parameters: [Parameter] = []
    @Published var activeTouches: [TouchPoint] = []
    @Published var sequencerGrid: [[Bool]] = Array(repeating: Array(repeating: false, count: 8), count: 16)
    @Published var mixerLevels: [Double] = [0.7, 0.5, 0.6, 0.4]

    private var cancellables = Set<AnyCancellable>()

    var formattedBPM: String {
        String(format: "%.1f", bpm)
    }

    var coherenceColor: Color {
        let hue = coherence / 100.0 * 0.33  // Red to green
        return Color(hue: hue, saturation: 0.8, brightness: 0.9)
    }

    struct Parameter: Identifiable {
        let id = UUID()
        let name: String
        var value: Double
    }

    struct TouchPoint: Identifiable {
        let id = UUID()
        var position: CGPoint
        var pressure: Double
        var hue: Double
    }

    func setup() {
        // Initialize parameters based on mode
        updateParametersForMode()

        // Simulate bio data updates
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateBioData()
            }
            .store(in: &cancellables)
    }

    func setMode(_ mode: InstrumentMode) {
        currentMode = mode
        updateParametersForMode()
    }

    func setComplexity(_ complexity: InstrumentMode.Complexity) {
        // Find mode with same base but different complexity
        // For now, just update current mode's complexity
        currentMode = InstrumentMode.allCases.first { $0.complexity == complexity } ?? currentMode
        updateParametersForMode()
    }

    private func updateParametersForMode() {
        switch currentMode.complexity {
        case .simple:
            parameters = []
        case .standard:
            parameters = [
                Parameter(name: "Cutoff", value: 0.5),
                Parameter(name: "Resonance", value: 0.3),
                Parameter(name: "Attack", value: 0.2),
                Parameter(name: "Release", value: 0.5)
            ]
        case .advanced:
            parameters = [
                Parameter(name: "Osc1", value: 0.7),
                Parameter(name: "Osc2", value: 0.5),
                Parameter(name: "Filter", value: 0.6),
                Parameter(name: "Env", value: 0.4),
                Parameter(name: "LFO", value: 0.3),
                Parameter(name: "Mod", value: 0.5),
                Parameter(name: "FX1", value: 0.6),
                Parameter(name: "FX2", value: 0.4)
            ]
        case .expert:
            parameters = (0..<16).map { Parameter(name: "P\($0+1)", value: Double.random(in: 0...1)) }
        }
    }

    private func updateBioData() {
        // Simulate heart rate variation
        bpm += Double.random(in: -0.5...0.5)
        bpm = max(50, min(120, bpm))

        // Simulate coherence
        coherence += Double.random(in: -2...2)
        coherence = max(0, min(100, coherence))

        // Breathing phase
        breathingPhase += 0.02
        if breathingPhase > 1 { breathingPhase = 0 }

        // Heartbeat animation
        let beatPhase = (Date().timeIntervalSince1970 * (bpm / 60)).truncatingRemainder(dividingBy: 1)
        heartbeatScale = 1.0 + (beatPhase < 0.1 ? 0.1 : 0)
    }

    func togglePlayPause() {
        isPlaying.toggle()
    }

    func toggleRecord() {
        isRecording.toggle()
    }

    func stop() {
        isPlaying = false
        isRecording = false
    }

    func toggleSequencerStep(step: Int, note: Int) {
        sequencerGrid[step][note].toggle()
    }
}

// MARK: - Instrument Mode

public enum InstrumentMode: CaseIterable {
    case relaxation
    case meditation
    case focus
    case creativity
    case healing
    case performance
    case freeplay
    case therapy
    case research

    public enum Complexity: String, CaseIterable {
        case simple = "simple"
        case standard = "standard"
        case advanced = "advanced"
        case expert = "expert"

        var displayName: String {
            switch self {
            case .simple: return "Einfach"
            case .standard: return "Standard"
            case .advanced: return "Fortgeschritten"
            case .expert: return "Experte"
            }
        }

        var icon: String {
            switch self {
            case .simple: return "1.circle"
            case .standard: return "2.circle"
            case .advanced: return "3.circle"
            case .expert: return "star.circle"
            }
        }
    }

    var displayName: String {
        switch self {
        case .relaxation: return "Entspannung"
        case .meditation: return "Meditation"
        case .focus: return "Fokus"
        case .creativity: return "Kreativität"
        case .healing: return "Heilung"
        case .performance: return "Performance"
        case .freeplay: return "Frei Spielen"
        case .therapy: return "Therapie"
        case .research: return "Forschung"
        }
    }

    var shortDescription: String {
        switch self {
        case .relaxation: return "Stress abbauen"
        case .meditation: return "Innere Ruhe"
        case .focus: return "Konzentration"
        case .creativity: return "Inspiriert werden"
        case .healing: return "Ganzheitlich"
        case .performance: return "Live spielen"
        case .freeplay: return "Ohne Grenzen"
        case .therapy: return "Klinische Protokolle"
        case .research: return "Daten & Analyse"
        }
    }

    var description: String {
        switch self {
        case .relaxation: return "Tippe zum Starten. Die Musik reagiert auf deine Atmung und deinen Herzschlag."
        case .meditation: return "Lass dich von den Klängen in tiefe Entspannung führen."
        case .focus: return "Steigere deine Konzentration mit optimierten Frequenzen."
        case .creativity: return "Erkunde neue Klangwelten und lass deiner Kreativität freien Lauf."
        case .healing: return "Wissenschaftlich fundierte Protokolle für dein Wohlbefinden."
        case .performance: return "Spiele live und teile deine Musik mit der Welt."
        case .freeplay: return "Volle Kontrolle. Alle Parameter. Keine Grenzen."
        case .therapy: return "Klinische HRV-Biofeedback-Protokolle für Therapeuten."
        case .research: return "Vollständiger Datenexport für wissenschaftliche Analyse."
        }
    }

    var icon: String {
        switch self {
        case .relaxation: return "leaf.fill"
        case .meditation: return "figure.mind.and.body"
        case .focus: return "target"
        case .creativity: return "paintpalette.fill"
        case .healing: return "heart.fill"
        case .performance: return "music.mic"
        case .freeplay: return "waveform"
        case .therapy: return "cross.case.fill"
        case .research: return "chart.bar.doc.horizontal"
        }
    }

    var accentColor: Color {
        switch self {
        case .relaxation: return .green
        case .meditation: return .purple
        case .focus: return .orange
        case .creativity: return .pink
        case .healing: return .cyan
        case .performance: return .red
        case .freeplay: return .yellow
        case .therapy: return .blue
        case .research: return .gray
        }
    }

    var backgroundColor: Color {
        switch self {
        case .relaxation: return .green
        case .meditation: return .purple
        case .focus: return .orange
        case .creativity: return .pink
        case .healing: return .cyan
        case .performance: return .red
        case .freeplay: return .yellow
        case .therapy: return .blue
        case .research: return .gray
        }
    }

    var complexity: Complexity {
        switch self {
        case .relaxation, .meditation: return .simple
        case .focus, .creativity, .healing: return .standard
        case .performance, .freeplay: return .advanced
        case .therapy, .research: return .expert
        }
    }
}

// MARK: - Preview

#Preview {
    InstrumentModeView()
}

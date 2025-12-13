import SwiftUI
import simd

/// Body Resonance Visualizer Mode
///
/// Visualizes "How would my body resonate if I could see the vibrations"
/// Shows standing wave patterns, resonance nodes, and the coupling
/// between cardiac and respiratory rhythms.
///
/// Based on:
/// - Wave mechanics on bounded domains
/// - Cardiac-respiratory coupling (Respiratory Sinus Arrhythmia)
/// - Resonance mode shapes from physics
struct BodyResonanceVisualizerMode: View {
    @ObservedObject var bioSyncMode: BioSyncMode

    // Animation state
    @State private var phase: Double = 0
    @State private var heartbeatPhase: Double = 0
    @State private var breathPhase: Double = 0

    // Display settings
    @State private var showNodes: Bool = true
    @State private var showWaveMotion: Bool = true
    @State private var showCoupling: Bool = true

    let timer = Timer.publish(every: 1/60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                // Body outline with resonance
                BodyResonanceShape(
                    bioSyncMode: bioSyncMode,
                    phase: phase,
                    heartbeatPhase: heartbeatPhase,
                    breathPhase: breathPhase,
                    showNodes: showNodes
                )
                .stroke(
                    LinearGradient(
                        colors: [resonanceColor, resonanceColor.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .frame(width: geometry.size.width * 0.6, height: geometry.size.height * 0.8)

                // Standing wave visualization inside body
                if showWaveMotion {
                    StandingWaveOverlay(
                        bioSyncMode: bioSyncMode,
                        phase: phase
                    )
                    .frame(width: geometry.size.width * 0.5, height: geometry.size.height * 0.7)
                }

                // Cardiac-respiratory coupling indicator
                if showCoupling {
                    CouplingIndicator(bioSyncMode: bioSyncMode)
                        .frame(width: 150, height: 150)
                        .position(x: geometry.size.width - 100, y: 100)
                }

                // Resonance parameters display
                VStack(alignment: .leading, spacing: 8) {
                    ParameterDisplay(
                        label: "Tempo",
                        value: String(format: "%.3f BPM", bioSyncMode.tempo)
                    )
                    ParameterDisplay(
                        label: "Frequency",
                        value: String(format: "%.4f Hz", bioSyncMode.baseFrequency)
                    )
                    ParameterDisplay(
                        label: "Tuning",
                        value: String(format: "%+.2f cents", bioSyncMode.tuningCents)
                    )
                    ParameterDisplay(
                        label: "Q-Factor",
                        value: String(format: "%.1f", bioSyncMode.resonanceQ)
                    )
                    ParameterDisplay(
                        label: "Coherence",
                        value: String(format: "%.1f%%", bioSyncMode.bodyResonance.overallCoherence * 100)
                    )
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
                .position(x: 120, y: geometry.size.height - 120)
            }
        }
        .onReceive(timer) { _ in
            updateAnimation()
        }
    }

    private var resonanceColor: Color {
        // Color based on coherence level
        let coherence = bioSyncMode.bodyResonance.overallCoherence
        if coherence > 0.7 {
            return Color(red: 0.2, green: 0.8, blue: 0.4)  // High coherence - green
        } else if coherence > 0.4 {
            return Color(red: 0.3, green: 0.6, blue: 0.9)  // Medium - blue
        } else {
            return Color(red: 0.9, green: 0.5, blue: 0.3)  // Low - orange
        }
    }

    private func updateAnimation() {
        let dt = 1.0 / 60.0

        // Main phase advances with base frequency
        phase += dt * bioSyncMode.tempoFrequency * 2.0 * .pi

        // Heartbeat phase
        heartbeatPhase += dt * bioSyncMode.bodyResonance.cardiacFrequency * 2.0 * .pi

        // Breath phase
        breathPhase += dt * bioSyncMode.bodyResonance.respiratoryFrequency * 2.0 * .pi

        // Wrap phases
        if phase > 2.0 * .pi { phase -= 2.0 * .pi }
        if heartbeatPhase > 2.0 * .pi { heartbeatPhase -= 2.0 * .pi }
        if breathPhase > 2.0 * .pi { breathPhase -= 2.0 * .pi }
    }
}

// MARK: - Body Shape with Resonance Deformation

struct BodyResonanceShape: Shape {
    let bioSyncMode: BioSyncMode
    let phase: Double
    let heartbeatPhase: Double
    let breathPhase: Double
    let showNodes: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let centerX = rect.midX
        let width = rect.width
        let height = rect.height

        // Simplified body outline with resonance deformation
        let points = generateBodyOutline(
            centerX: centerX,
            width: width,
            height: height
        )

        guard let first = points.first else { return path }
        path.move(to: first)

        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()

        return path
    }

    private func generateBodyOutline(centerX: CGFloat, width: CGFloat, height: CGFloat) -> [CGPoint] {
        var points: [CGPoint] = []
        let segments = 100

        // Generate body shape with resonance deformation
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let angle = t * 2.0 * .pi

            // Base body shape (simplified ellipse with modifications)
            var baseRadius: CGFloat
            var yOffset: CGFloat = 0

            // Create body-like shape
            let section = t * 4.0  // 0-4 sections around body

            if section < 1.0 {
                // Right side torso
                baseRadius = width * 0.25 * (1.0 + 0.3 * sin(angle * 2))
            } else if section < 2.0 {
                // Lower body
                baseRadius = width * 0.3 * (1.0 + 0.2 * sin(angle * 3))
            } else if section < 3.0 {
                // Left side torso
                baseRadius = width * 0.25 * (1.0 + 0.3 * sin(angle * 2))
            } else {
                // Upper body/shoulders
                baseRadius = width * 0.35 * (1.0 + 0.15 * sin(angle * 2))
            }

            // Apply resonance deformation
            let resonanceDeform = calculateResonanceDeformation(
                angle: Double(angle),
                baseRadius: Double(baseRadius)
            )

            let finalRadius = baseRadius + CGFloat(resonanceDeform)
            let x = centerX + finalRadius * cos(angle - .pi / 2)
            let y = height * 0.5 + finalRadius * sin(angle - .pi / 2) * 1.3

            points.append(CGPoint(x: x, y: y))
        }

        return points
    }

    private func calculateResonanceDeformation(angle: Double, baseRadius: Double) -> Double {
        // Combine multiple resonance modes

        // Mode 1: Breathing (whole body expansion/contraction)
        let breathingMode = sin(breathPhase) * baseRadius * 0.05

        // Mode 2: Cardiac pulse (radial pulse from center)
        let cardiacMode = sin(heartbeatPhase) * baseRadius * 0.02

        // Mode 3: Standing wave pattern (based on resonance Q)
        let modeNumber = max(1, Int(bioSyncMode.resonanceQ / 10))
        let standingWave = sin(Double(modeNumber) * angle + phase) * baseRadius * 0.03

        // Mode 4: HRV modulation (slow variation)
        let hrvMod = sin(bioSyncMode.bodyResonance.hrvModulationFrequency * phase * 0.1) * baseRadius * 0.01

        return breathingMode + cardiacMode + standingWave + hrvMod
    }
}

// MARK: - Standing Wave Overlay

struct StandingWaveOverlay: View {
    let bioSyncMode: BioSyncMode
    let phase: Double

    var body: some View {
        Canvas { context, size in
            // Draw standing wave lines inside body
            let lineCount = max(3, Int(bioSyncMode.resonanceQ / 5))

            for i in 0..<lineCount {
                let y = size.height * CGFloat(i + 1) / CGFloat(lineCount + 1)

                var path = Path()
                let segmentCount = 50

                for j in 0...segmentCount {
                    let x = size.width * CGFloat(j) / CGFloat(segmentCount)
                    let normalizedX = Double(j) / Double(segmentCount)

                    // Standing wave: sin(n*pi*x) * cos(omega*t)
                    let modeNumber = Double(i + 1)
                    let spatialPart = sin(modeNumber * .pi * normalizedX)
                    let temporalPart = cos(phase * modeNumber * 0.5)
                    let amplitude = spatialPart * temporalPart * Double(size.height) * 0.03

                    let point = CGPoint(x: x, y: y + CGFloat(amplitude))

                    if j == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }

                // Color based on mode number
                let hue = Double(i) / Double(lineCount) * 0.3 + 0.5  // Blue to cyan range
                let opacity = 0.3 + 0.4 * (1.0 - Double(i) / Double(lineCount))

                context.stroke(
                    path,
                    with: .color(Color(hue: hue, saturation: 0.7, brightness: 0.9).opacity(opacity)),
                    lineWidth: 1.5
                )
            }

            // Draw nodes (points of minimal motion)
            drawNodes(context: context, size: size, lineCount: lineCount)
        }
    }

    private func drawNodes(context: GraphicsContext, size: CGSize, lineCount: Int) {
        // Nodes occur where standing waves have zero amplitude
        for i in 0..<lineCount {
            let y = size.height * CGFloat(i + 1) / CGFloat(lineCount + 1)
            let modeNumber = i + 1

            // Nodes at x = k/(n+1) for k = 1...n
            for k in 1...modeNumber {
                let x = size.width * CGFloat(k) / CGFloat(modeNumber + 1)

                let nodePath = Path(ellipseIn: CGRect(
                    x: x - 4,
                    y: y - 4,
                    width: 8,
                    height: 8
                ))

                context.fill(nodePath, with: .color(.white.opacity(0.6)))
            }
        }
    }
}

// MARK: - Cardiac-Respiratory Coupling Indicator

struct CouplingIndicator: View {
    let bioSyncMode: BioSyncMode
    @State private var heartPhase: Double = 0
    @State private var breathPhase: Double = 0

    let timer = Timer.publish(every: 1/30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 10) {
            Text("Heart-Breath Coupling")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            ZStack {
                // Breathing circle (outer)
                Circle()
                    .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                    .scaleEffect(1.0 + 0.2 * CGFloat(sin(breathPhase)))

                // Heart circle (inner)
                Circle()
                    .fill(Color.red.opacity(0.6))
                    .scaleEffect(0.3 + 0.1 * CGFloat(sin(heartPhase)))

                // Coupling strength indicator
                Circle()
                    .stroke(couplingColor, lineWidth: 3)
                    .scaleEffect(0.6)
            }

            Text(String(format: "%.0f%%", bioSyncMode.bodyResonance.couplingStrength * 100))
                .font(.caption2)
                .foregroundColor(couplingColor)
        }
        .onReceive(timer) { _ in
            heartPhase += bioSyncMode.bodyResonance.cardiacFrequency * 2.0 * .pi / 30.0
            breathPhase += bioSyncMode.bodyResonance.respiratoryFrequency * 2.0 * .pi / 30.0

            if heartPhase > 2.0 * .pi { heartPhase -= 2.0 * .pi }
            if breathPhase > 2.0 * .pi { breathPhase -= 2.0 * .pi }
        }
    }

    private var couplingColor: Color {
        let coupling = bioSyncMode.bodyResonance.couplingStrength
        if coupling > 0.7 {
            return .green
        } else if coupling > 0.4 {
            return .yellow
        } else {
            return .orange
        }
    }
}

// MARK: - Parameter Display

struct ParameterDisplay: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Resonance Mode Selector

struct ResonanceModeSelector: View {
    @Binding var selectedMode: ResonanceMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resonance Mode")
                .font(.caption)
                .foregroundColor(.gray)

            ForEach(ResonanceMode.allCases, id: \.self) { mode in
                Button(action: { selectedMode = mode }) {
                    HStack {
                        Image(systemName: selectedMode == mode ? "circle.fill" : "circle")
                            .foregroundColor(selectedMode == mode ? .blue : .gray)
                        VStack(alignment: .leading) {
                            Text(mode.rawValue)
                                .font(.caption)
                                .foregroundColor(.white)
                            Text(mode.description)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
    }
}

// MARK: - Preview

#Preview {
    BodyResonanceVisualizerMode(bioSyncMode: BioSyncMode())
}

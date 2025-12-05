import SwiftUI
import Accelerate

/// Brainwave Visualizer Mode
/// EEG-style 8-channel display showing Alpha/Beta/Theta/Delta waves
/// Integrates with real-time FFT data and binaural beat states
struct BrainwaveVisualizerMode: View {

    /// Audio level (0.0 - 1.0)
    var audioLevel: Float

    /// Dominant frequency (Hz)
    var frequency: Float

    /// HRV Coherence (0-100)
    var hrvCoherence: Double

    /// Heart rate (BPM)
    var heartRate: Double

    /// FFT magnitude data (if available)
    var fftData: [Float]?

    /// Current binaural beat state
    var binauralState: BrainwaveState = .alpha

    /// Simulated brainwave data for each channel
    @State private var channelData: [[Float]] = Array(repeating: Array(repeating: 0, count: 200), count: 8)

    /// Animation time
    @State private var time: Double = 0

    enum BrainwaveState: String, CaseIterable {
        case delta = "Delta"      // 0.5-4 Hz - Deep sleep
        case theta = "Theta"      // 4-8 Hz - Meditation, drowsiness
        case alpha = "Alpha"      // 8-12 Hz - Relaxed, calm
        case lowBeta = "Low Beta" // 12-15 Hz - Relaxed focus
        case beta = "Beta"        // 15-30 Hz - Active thinking
        case highBeta = "High Beta" // 30-40 Hz - Anxiety, stress
        case gamma = "Gamma"      // 40-100 Hz - Peak concentration
        case mixed = "Mixed"      // Combination

        var frequencyRange: ClosedRange<Float> {
            switch self {
            case .delta: return 0.5...4
            case .theta: return 4...8
            case .alpha: return 8...12
            case .lowBeta: return 12...15
            case .beta: return 15...30
            case .highBeta: return 30...40
            case .gamma: return 40...100
            case .mixed: return 0.5...100
            }
        }

        var color: Color {
            switch self {
            case .delta: return .purple
            case .theta: return .indigo
            case .alpha: return .blue
            case .lowBeta: return .cyan
            case .beta: return .green
            case .highBeta: return .yellow
            case .gamma: return .orange
            case .mixed: return .white
            }
        }

        var description: String {
            switch self {
            case .delta: return "Deep Sleep"
            case .theta: return "Meditation"
            case .alpha: return "Relaxed"
            case .lowBeta: return "Calm Focus"
            case .beta: return "Active"
            case .highBeta: return "Alert"
            case .gamma: return "Peak Focus"
            case .mixed: return "Combined"
            }
        }
    }

    // Channel labels (brain regions)
    private let channelLabels = ["Fp1", "Fp2", "F3", "F4", "C3", "C4", "O1", "O2"]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with state indicator
                headerView

                // Main visualization
                TimelineView(.animation(minimumInterval: 1.0/60.0)) { timeline in
                    Canvas { context, size in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        updateChannelData(time: time)

                        // Draw channel waveforms
                        drawChannels(context: context, size: size, time: time)

                        // Draw frequency bands indicator
                        drawFrequencyBands(context: context, size: size)

                        // Draw coherence indicator
                        drawCoherenceIndicator(context: context, size: size)
                    }
                }

                // Bottom status bar
                statusBar
            }
        }
        .background(Color.black)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            // State indicator
            VStack(alignment: .leading, spacing: 2) {
                Text("BRAINWAVE STATE")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)

                HStack(spacing: 8) {
                    Circle()
                        .fill(binauralState.color)
                        .frame(width: 8, height: 8)

                    Text(binauralState.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(binauralState.color)

                    Text(binauralState.description)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Frequency display
            VStack(alignment: .trailing, spacing: 2) {
                Text("FREQUENCY")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)

                Text("\(String(format: "%.1f", frequency)) Hz")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 20) {
            // Heart rate
            statusItem(label: "HR", value: "\(Int(heartRate))", unit: "BPM", color: .red)

            // Coherence
            statusItem(label: "COH", value: "\(Int(hrvCoherence))", unit: "%", color: .green)

            // Audio level
            statusItem(label: "LEVEL", value: "\(Int(audioLevel * 100))", unit: "%", color: .blue)

            Spacer()

            // Band activity indicators
            ForEach(BrainwaveState.allCases.prefix(5), id: \.rawValue) { state in
                bandIndicator(state: state)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.8))
    }

    private func statusItem(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)

            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(color)

                Text(unit)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
    }

    private func bandIndicator(state: BrainwaveState) -> some View {
        let isActive = state == binauralState
        return VStack(spacing: 2) {
            Text(state.rawValue.prefix(1))
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isActive ? state.color : .gray)

            Rectangle()
                .fill(isActive ? state.color : state.color.opacity(0.3))
                .frame(width: 16, height: isActive ? 8 : 4)
                .animation(.easeInOut(duration: 0.3), value: isActive)
        }
    }

    // MARK: - Channel Data Generation

    private func updateChannelData(time: Double) {
        // Generate simulated EEG-like data for each channel
        // In production, this would come from actual EEG hardware or binaural beat analysis

        var newData: [[Float]] = []

        for channelIndex in 0..<8 {
            var channel: [Float] = []

            for sampleIndex in 0..<200 {
                let t = time + Double(sampleIndex) * 0.01

                // Base wave frequencies for each brain region
                let baseFreq = binauralState.frequencyRange.lowerBound + Float(channelIndex) * 0.5

                // Mix of different frequency components
                var sample: Float = 0

                // Delta component
                sample += sin(Float(t) * 2 * .pi * 2) * 0.2

                // Theta component
                sample += sin(Float(t) * 2 * .pi * 6) * 0.3

                // Alpha component (strongest in relaxed state)
                sample += sin(Float(t) * 2 * .pi * 10) * (binauralState == .alpha ? 0.6 : 0.3)

                // Beta component
                sample += sin(Float(t) * 2 * .pi * 20) * 0.2

                // Gamma component
                sample += sin(Float(t) * 2 * .pi * 40) * 0.1

                // Add channel-specific variation
                sample += sin(Float(t) * 2 * .pi * baseFreq + Float(channelIndex)) * 0.3

                // Modulate by audio level
                sample *= (0.5 + audioLevel * 0.5)

                // Add some noise based on coherence (lower coherence = more noise)
                let noise = Float.random(in: -1...1) * Float(1 - hrvCoherence / 100) * 0.2
                sample += noise

                channel.append(sample)
            }

            newData.append(channel)
        }

        channelData = newData
    }

    // MARK: - Drawing Functions

    private func drawChannels(context: GraphicsContext, size: CGSize, time: Double) {
        let channelHeight = size.height / CGFloat(channelData.count + 1)
        let leftMargin: CGFloat = 50
        let rightMargin: CGFloat = 20
        let availableWidth = size.width - leftMargin - rightMargin

        for (channelIndex, channel) in channelData.enumerated() {
            let yCenter = channelHeight * (CGFloat(channelIndex) + 1)

            // Draw channel label
            let labelText = Text(channelLabels[channelIndex])
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)

            context.draw(labelText, at: CGPoint(x: 25, y: yCenter))

            // Draw channel baseline
            var baselinePath = Path()
            baselinePath.move(to: CGPoint(x: leftMargin, y: yCenter))
            baselinePath.addLine(to: CGPoint(x: size.width - rightMargin, y: yCenter))

            context.stroke(
                baselinePath,
                with: .color(Color.gray.opacity(0.2)),
                style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])
            )

            // Draw waveform
            var waveformPath = Path()
            let amplitude = channelHeight * 0.35

            for (sampleIndex, sample) in channel.enumerated() {
                let x = leftMargin + (CGFloat(sampleIndex) / CGFloat(channel.count)) * availableWidth
                let y = yCenter - CGFloat(sample) * amplitude

                if sampleIndex == 0 {
                    waveformPath.move(to: CGPoint(x: x, y: y))
                } else {
                    waveformPath.addLine(to: CGPoint(x: x, y: y))
                }
            }

            // Color based on dominant frequency content
            let channelColor = colorForChannel(channelIndex)

            context.stroke(
                waveformPath,
                with: .color(channelColor),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
            )

            // Draw glow effect for high amplitude sections
            context.stroke(
                waveformPath,
                with: .color(channelColor.opacity(0.3)),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func colorForChannel(_ index: Int) -> Color {
        // Map channels to brain regions with appropriate colors
        let hue = Double(index) / 8.0 * 0.6 + hrvCoherence / 100.0 * 0.2
        return Color(hue: hue, saturation: 0.7, brightness: 0.9)
    }

    private func drawFrequencyBands(context: GraphicsContext, size: CGSize) {
        // Draw frequency band legend at the bottom
        let bandHeight: CGFloat = 20
        let y = size.height - bandHeight - 40

        let bands: [(String, ClosedRange<Float>, Color)] = [
            ("δ", 0.5...4, .purple),
            ("θ", 4...8, .indigo),
            ("α", 8...12, .blue),
            ("β", 12...30, .green),
            ("γ", 30...100, .orange)
        ]

        let totalWidth = size.width - 100
        let startX: CGFloat = 50

        for (index, band) in bands.enumerated() {
            let bandWidth = totalWidth / CGFloat(bands.count)
            let x = startX + CGFloat(index) * bandWidth

            // Band background
            let isActive = binauralState.frequencyRange.overlaps(band.1)
            let alpha = isActive ? 0.5 : 0.2

            var bandRect = Path()
            bandRect.addRoundedRect(
                in: CGRect(x: x + 2, y: y, width: bandWidth - 4, height: bandHeight),
                cornerSize: CGSize(width: 4, height: 4)
            )

            context.fill(bandRect, with: .color(band.2.opacity(alpha)))

            // Band label
            let labelText = Text(band.0)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(isActive ? .white : .gray)

            context.draw(labelText, at: CGPoint(x: x + bandWidth/2, y: y + bandHeight/2))
        }
    }

    private func drawCoherenceIndicator(context: GraphicsContext, size: CGSize) {
        // Draw coherence as a circular indicator in the top-right
        let indicatorSize: CGFloat = 60
        let center = CGPoint(x: size.width - indicatorSize/2 - 20, y: indicatorSize/2 + 60)

        // Background circle
        context.fill(
            Path(ellipseIn: CGRect(
                x: center.x - indicatorSize/2,
                y: center.y - indicatorSize/2,
                width: indicatorSize,
                height: indicatorSize
            )),
            with: .color(Color.gray.opacity(0.2))
        )

        // Coherence arc
        let coherenceAngle = Angle(degrees: hrvCoherence / 100.0 * 360 - 90)
        var arcPath = Path()
        arcPath.addArc(
            center: center,
            radius: indicatorSize/2 - 5,
            startAngle: .degrees(-90),
            endAngle: coherenceAngle,
            clockwise: false
        )

        let coherenceColor = Color(
            hue: hrvCoherence / 100.0 * 0.3,
            saturation: 0.7,
            brightness: 0.9
        )

        context.stroke(
            arcPath,
            with: .color(coherenceColor),
            style: StrokeStyle(lineWidth: 6, lineCap: .round)
        )

        // Center text
        let valueText = Text("\(Int(hrvCoherence))")
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundColor(.white)

        context.draw(valueText, at: center)
    }
}


// MARK: - Preview

#Preview {
    BrainwaveVisualizerMode(
        audioLevel: 0.5,
        frequency: 10,
        hrvCoherence: 65,
        heartRate: 72,
        binauralState: .alpha
    )
}

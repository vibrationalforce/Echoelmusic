import SwiftUI

/// Brainwave Visualizer Mode
/// EEG-style 8-channel display showing different brainwave states
/// Each channel represents a binaural state: Delta, Theta, Alpha, Beta, Gamma
/// Real-time FFT integration for frequency analysis
struct BrainwaveVisualizerMode: View {
    /// Audio level (0.0 - 1.0)
    var audioLevel: Float

    /// Detected frequency (Hz)
    var frequency: Float

    /// HRV Coherence (0-100)
    var hrvCoherence: Double

    /// Heart Rate (BPM)
    var heartRate: Double

    /// Current binaural beat frequency (if active)
    var binauralBeatFrequency: Float = 10.0

    /// FFT data for frequency visualization (optional)
    var fftData: [Float]?

    @State private var wavePhases: [Double] = Array(repeating: 0, count: 8)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSince1970

                // Draw background grid
                drawGrid(context: context, size: size)

                // Draw brainwave channels
                drawBrainwaveChannels(context: context, size: size, time: time)

                // Draw frequency spectrum if FFT data available
                if let fftData = fftData {
                    drawFFTSpectrum(context: context, size: size, fftData: fftData)
                }

                // Draw coherence indicator
                drawCoherenceIndicator(context: context, size: size)

                // Draw channel labels
                drawChannelLabels(context: context, size: size)
            }
        }
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Brainwave Channel Definitions

    struct BrainwaveChannel {
        let name: String
        let frequencyRange: ClosedRange<Float>
        let color: Color
        let description: String

        var centerFrequency: Float {
            (frequencyRange.lowerBound + frequencyRange.upperBound) / 2
        }
    }

    private var channels: [BrainwaveChannel] {
        [
            BrainwaveChannel(name: "Delta", frequencyRange: 0.5...4, color: .purple, description: "Deep Sleep"),
            BrainwaveChannel(name: "Theta", frequencyRange: 4...8, color: .indigo, description: "Meditation"),
            BrainwaveChannel(name: "Alpha", frequencyRange: 8...12, color: .blue, description: "Relaxation"),
            BrainwaveChannel(name: "Low Beta", frequencyRange: 12...15, color: .cyan, description: "Calm Focus"),
            BrainwaveChannel(name: "Beta", frequencyRange: 15...20, color: .green, description: "Active Thinking"),
            BrainwaveChannel(name: "High Beta", frequencyRange: 20...30, color: .yellow, description: "Alertness"),
            BrainwaveChannel(name: "Gamma", frequencyRange: 30...50, color: .orange, description: "Peak Performance"),
            BrainwaveChannel(name: "High Gamma", frequencyRange: 50...100, color: .red, description: "Insight")
        ]
    }

    // MARK: - Drawing Functions

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridColor = Color.white.opacity(0.1)

        // Horizontal lines
        for i in 0...8 {
            let y = CGFloat(i) / 8 * size.height
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }

        // Vertical time markers (every 100px)
        let numVerticalLines = Int(size.width / 100)
        for i in 0...numVerticalLines {
            let x = CGFloat(i) * 100
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
    }

    private func drawBrainwaveChannels(context: GraphicsContext, size: CGSize, time: Double) {
        let channelHeight = size.height / CGFloat(channels.count)
        let leftMargin: CGFloat = 80

        for (index, channel) in channels.enumerated() {
            let yCenter = CGFloat(index) * channelHeight + channelHeight / 2

            // Calculate wave amplitude based on how close the binaural beat is to this channel
            let distanceFromBeat = abs(binauralBeatFrequency - channel.centerFrequency)
            let maxDistance: Float = 20
            let baseAmplitude = max(0, 1 - distanceFromBeat / maxDistance)

            // Modulate with audio level and HRV
            let hrvModulation = Float(hrvCoherence / 100.0)
            let amplitude = baseAmplitude * (0.3 + audioLevel * 0.7) * (0.5 + hrvModulation * 0.5)

            // Draw the waveform
            drawWaveform(
                context: context,
                yCenter: yCenter,
                width: size.width - leftMargin,
                height: channelHeight * 0.8,
                amplitude: CGFloat(amplitude),
                frequency: channel.centerFrequency,
                color: channel.color,
                time: time,
                startX: leftMargin
            )
        }
    }

    private func drawWaveform(
        context: GraphicsContext,
        yCenter: CGFloat,
        width: CGFloat,
        height: CGFloat,
        amplitude: CGFloat,
        frequency: Float,
        color: Color,
        time: Double,
        startX: CGFloat
    ) {
        var path = Path()
        let points = Int(width)

        for i in 0..<points {
            let x = startX + CGFloat(i)
            let phase = time * Double(frequency) * 0.5 + Double(i) / 50.0

            // Combine multiple harmonics for more realistic EEG appearance
            let y1 = sin(phase) * Double(amplitude)
            let y2 = sin(phase * 2.3 + 0.5) * Double(amplitude) * 0.3
            let y3 = sin(phase * 0.7 + 1.2) * Double(amplitude) * 0.5

            // Add some noise for realism
            let noise = Double.random(in: -0.05...0.05) * Double(amplitude)

            let y = yCenter + CGFloat(y1 + y2 + y3 + noise) * height / 2

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Draw glow effect for active channels
        if amplitude > 0.3 {
            context.stroke(path, with: .color(color.opacity(0.3)), lineWidth: 4)
        }

        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }

    private func drawFFTSpectrum(context: GraphicsContext, size: CGSize, fftData: [Float]) {
        let spectrumHeight: CGFloat = 60
        let spectrumY = size.height - spectrumHeight - 10
        let barWidth = size.width / CGFloat(fftData.count)

        for (index, value) in fftData.enumerated() {
            let x = CGFloat(index) * barWidth
            let barHeight = CGFloat(value) * spectrumHeight

            // Color based on frequency bin
            let hue = Double(index) / Double(fftData.count) * 0.7
            let color = Color(hue: hue, saturation: 0.8, brightness: 0.9)

            var barPath = Path()
            barPath.addRect(CGRect(
                x: x,
                y: spectrumY + spectrumHeight - barHeight,
                width: barWidth - 1,
                height: barHeight
            ))

            context.fill(barPath, with: .color(color.opacity(0.7)))
        }

        // Draw spectrum label
        let text = Text("Frequency Spectrum")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
        context.draw(text, at: CGPoint(x: 60, y: spectrumY - 10))
    }

    private func drawCoherenceIndicator(context: GraphicsContext, size: CGSize) {
        let indicatorSize: CGFloat = 100
        let x = size.width - indicatorSize - 20
        let y: CGFloat = 20

        // Background circle
        var bgPath = Path()
        bgPath.addEllipse(in: CGRect(x: x, y: y, width: indicatorSize, height: indicatorSize))
        context.fill(bgPath, with: .color(Color.black.opacity(0.5)))

        // Coherence arc
        let coherenceAngle = Angle.degrees(360 * hrvCoherence / 100.0)
        var arcPath = Path()
        arcPath.addArc(
            center: CGPoint(x: x + indicatorSize / 2, y: y + indicatorSize / 2),
            radius: indicatorSize / 2 - 5,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90) + coherenceAngle,
            clockwise: false
        )

        // Color based on coherence level
        let coherenceColor: Color
        if hrvCoherence >= 70 {
            coherenceColor = .green
        } else if hrvCoherence >= 40 {
            coherenceColor = .yellow
        } else {
            coherenceColor = .red
        }

        context.stroke(arcPath, with: .color(coherenceColor), lineWidth: 8)

        // Coherence text
        let coherenceText = Text("\(Int(hrvCoherence))%")
            .font(.system(size: 24, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
        context.draw(coherenceText, at: CGPoint(x: x + indicatorSize / 2, y: y + indicatorSize / 2))

        let labelText = Text("Coherence")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white.opacity(0.7))
        context.draw(labelText, at: CGPoint(x: x + indicatorSize / 2, y: y + indicatorSize + 15))
    }

    private func drawChannelLabels(context: GraphicsContext, size: CGSize) {
        let channelHeight = size.height / CGFloat(channels.count)

        for (index, channel) in channels.enumerated() {
            let yCenter = CGFloat(index) * channelHeight + channelHeight / 2

            // Channel name
            let nameText = Text(channel.name)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(channel.color)
            context.draw(nameText, at: CGPoint(x: 40, y: yCenter - 8))

            // Frequency range
            let freqText = Text("\(Int(channel.frequencyRange.lowerBound))-\(Int(channel.frequencyRange.upperBound))Hz")
                .font(.system(size: 8, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            context.draw(freqText, at: CGPoint(x: 40, y: yCenter + 8))
        }
    }
}

// MARK: - Brainwave State Detection

extension BrainwaveVisualizerMode {
    /// Determine dominant brainwave state based on binaural beat frequency
    var dominantState: String {
        for channel in channels {
            if channel.frequencyRange.contains(binauralBeatFrequency) {
                return channel.name
            }
        }
        return "Unknown"
    }

    /// Get description for current state
    var stateDescription: String {
        for channel in channels {
            if channel.frequencyRange.contains(binauralBeatFrequency) {
                return channel.description
            }
        }
        return "Neutral"
    }
}

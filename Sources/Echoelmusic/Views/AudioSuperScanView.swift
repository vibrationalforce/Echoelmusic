//
//  AudioSuperScanView.swift
//  Echoelmusic
//
//  Professional Audio Analysis & Visualization Interface
//  Created: 2025-11-20
//

import SwiftUI

@available(iOS 15.0, *)
struct AudioSuperScanView: View {
    @StateObject private var scanEngine = AudioSuperScanEngine()
    @State private var isScanning = false

    var body: some View {
        ZStack {
            // Background
            EchoelBranding.darkGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: EchoelBranding.Spacing.lg) {
                    // Header
                    headerView

                    // Scan Mode Selector
                    scanModePicker

                    // Main Visualization
                    mainVisualization

                    // Meters & Analysis
                    metersSection

                    // Info Cards
                    infoSection
                }
                .padding(EchoelBranding.Spacing.lg)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: EchoelBranding.Spacing.sm) {
            HStack {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 36))
                    .foregroundColor(EchoelBranding.accent)

                VStack(alignment: .leading) {
                    Text("Audio Super Scan")
                        .font(EchoelBranding.Typography.h2())
                        .foregroundColor(.white)

                    Text("Professional-Grade Analysis")
                        .font(EchoelBranding.Typography.bodySmall())
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Scan toggle
                Button(action: {
                    isScanning.toggle()
                }) {
                    Image(systemName: isScanning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(isScanning ? .red : EchoelBranding.accentGreen)
                }
            }
        }
    }

    // MARK: - Scan Mode Picker

    private var scanModePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EchoelBranding.Spacing.sm) {
                ForEach(AudioSuperScanEngine.ScanMode.allCases, id: \.self) { mode in
                    ScanModeButton(
                        mode: mode,
                        isSelected: scanEngine.currentMode == mode,
                        action: { scanEngine.currentMode = mode }
                    )
                }
            }
        }
    }

    // MARK: - Main Visualization

    @ViewBuilder
    private var mainVisualization: some View {
        ZStack {
            // Glass card background
            RoundedRectangle(cornerRadius: EchoelBranding.CornerRadius.xl)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: EchoelBranding.CornerRadius.xl)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )

            VStack {
                switch scanEngine.currentMode {
                case .spectrum:
                    SpectrumVisualization(data: scanEngine.spectrumData)
                case .spectrogram:
                    SpectrogramVisualization(data: scanEngine.spectrogramData)
                case .harmonic:
                    HarmonicVisualization(harmonics: scanEngine.harmonicContent, fundamental: scanEngine.dominantFrequency)
                case .phase:
                    PhaseCorrelationVisualization(correlation: scanEngine.phaseCorrelation)
                case .loudness:
                    LoudnessVisualization(lufs: scanEngine.lufsLevel)
                case .frequency:
                    FrequencyResponseVisualization(data: scanEngine.spectrumData)
                case .resonance:
                    ResonanceVisualization(data: scanEngine.spectrumData)
                }
            }
            .padding(EchoelBranding.Spacing.lg)
        }
        .frame(height: 350)
    }

    // MARK: - Meters Section

    private var metersSection: some View {
        VStack(spacing: EchoelBranding.Spacing.md) {
            // Peak & RMS Meters
            HStack(spacing: EchoelBranding.Spacing.md) {
                MeterCard(
                    title: "Peak",
                    value: scanEngine.peakLevel,
                    unit: "dB",
                    range: -60...0,
                    color: .green
                )

                MeterCard(
                    title: "RMS",
                    value: scanEngine.rmsLevel,
                    unit: "dB",
                    range: -60...0,
                    color: .yellow
                )
            }

            // LUFS & Dominant Frequency
            HStack(spacing: EchoelBranding.Spacing.md) {
                MeterCard(
                    title: "LUFS",
                    value: scanEngine.lufsLevel,
                    unit: "LUFS",
                    range: -60...0,
                    color: .blue
                )

                InfoCard(
                    title: "Dominant",
                    value: "\(Int(scanEngine.dominantFrequency)) Hz",
                    icon: "waveform",
                    color: EchoelBranding.accentPurple
                )
            }

            // Phase Correlation (if stereo)
            if scanEngine.phaseCorrelation != 1.0 {
                InfoCard(
                    title: "Phase Correlation",
                    value: String(format: "%.2f", scanEngine.phaseCorrelation),
                    subtitle: phaseCorrelationLabel(scanEngine.phaseCorrelation),
                    icon: "circle.lefthalf.filled.righthalf.striped.horizontal",
                    color: correlationColor(scanEngine.phaseCorrelation)
                )
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: EchoelBranding.Spacing.md) {
            Text("About This Mode")
                .font(EchoelBranding.Typography.h4())
                .foregroundColor(.white)

            Text(infoTextForMode(scanEngine.currentMode))
                .font(EchoelBranding.Typography.bodySmall())
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .echoelCard(style: .glass)
    }

    // MARK: - Helper Functions

    private func infoTextForMode(_ mode: AudioSuperScanEngine.ScanMode) -> String {
        switch mode {
        case .spectrum:
            return "Real-time FFT spectrum analyzer showing frequency content from 20 Hz to 20 kHz. Peak detection and frequency analysis with 8192-point resolution."
        case .spectrogram:
            return "Waterfall display showing frequency content over time. Useful for analyzing how sound evolves and detecting transients."
        case .harmonic:
            return "Harmonic analysis showing fundamental frequency and its harmonics (overtones). Useful for tuning and understanding timbre."
        case .phase:
            return "Phase correlation meter showing stereo width. +1.0 = perfect mono, 0.0 = wide stereo, -1.0 = out of phase."
        case .loudness:
            return "EBU R128 loudness measurement (LUFS - Loudness Units relative to Full Scale). Industry standard for broadcast."
        case .frequency:
            return "Frequency response analysis with smoothing. Shows the overall tonal balance of your audio."
        case .resonance:
            return "Resonance detection highlighting problematic frequencies and standing waves. Useful for room acoustics."
        }
    }

    private func phaseCorrelationLabel(_ correlation: Float) -> String {
        if correlation > 0.9 {
            return "Mono"
        } else if correlation > 0.5 {
            return "Narrow"
        } else if correlation > 0.0 {
            return "Wide"
        } else if correlation > -0.5 {
            return "Very Wide"
        } else {
            return "Phase Issues"
        }
    }

    private func correlationColor(_ correlation: Float) -> Color {
        if correlation < -0.3 {
            return .red  // Phase issues
        } else if correlation < 0.3 {
            return EchoelBranding.accentGreen  // Good stereo
        } else {
            return .yellow  // Narrow/mono
        }
    }
}

// MARK: - Supporting Views

struct ScanModeButton: View {
    let mode: AudioSuperScanEngine.ScanMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(mode.rawValue)
                .font(EchoelBranding.Typography.bodySmall(weight: isSelected ? .bold : .medium))
                .padding(.horizontal, EchoelBranding.Spacing.md)
                .padding(.vertical, EchoelBranding.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: EchoelBranding.CornerRadius.pill)
                        .fill(isSelected ? EchoelBranding.accent : Color.white.opacity(0.1))
                )
                .foregroundColor(.white)
        }
    }
}

// MARK: - Visualizations

struct SpectrumVisualization: View {
    let data: [Float]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid lines
                ForEach(0..<5) { i in
                    let y = geometry.size.height * CGFloat(i) / 4
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                }

                // Spectrum bars
                HStack(spacing: 1) {
                    ForEach(0..<min(data.count, 200), id: \.self) { index in
                        let value = data[index]
                        let normalizedValue = max(0, (value + 60) / 60)  // -60 dB to 0 dB range

                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        EchoelBranding.accentGreen,
                                        EchoelBranding.accentYellow,
                                        EchoelBranding.accent
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: geometry.size.height * CGFloat(normalizedValue))
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                }

                // Labels
                VStack {
                    HStack {
                        Text("0 dB")
                            .font(EchoelBranding.Typography.captionSmall())
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Text("-60 dB")
                            .font(EchoelBranding.Typography.captionSmall())
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    }
                }
            }
        }
    }
}

struct SpectrogramVisualization: View {
    let data: [[Float]]

    var body: some View {
        GeometryReader { geometry in
            if !data.isEmpty {
                VStack(spacing: 0) {
                    ForEach(data.indices.reversed(), id: \.self) { rowIndex in
                        HStack(spacing: 0) {
                            ForEach(0..<min(data[rowIndex].count, 200), id: \.self) { colIndex in
                                let value = data[rowIndex][colIndex]
                                let normalizedValue = max(0, min(1, (value + 60) / 60))

                                Rectangle()
                                    .fill(colorForValue(normalizedValue))
                            }
                        }
                        .frame(height: geometry.size.height / CGFloat(data.count))
                    }
                }
            } else {
                Text("Waiting for audio data...")
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private func colorForValue(_ value: Float) -> Color {
        if value < 0.2 {
            return Color.blue.opacity(0.3)
        } else if value < 0.4 {
            return Color.green.opacity(0.5)
        } else if value < 0.6 {
            return Color.yellow.opacity(0.7)
        } else if value < 0.8 {
            return Color.orange
        } else {
            return Color.red
        }
    }
}

struct HarmonicVisualization: View {
    let harmonics: [Float]
    let fundamental: Float

    var body: some View {
        VStack(spacing: EchoelBranding.Spacing.md) {
            Text("Fundamental: \(Int(fundamental)) Hz")
                .font(EchoelBranding.Typography.h3())
                .foregroundColor(.white)

            GeometryReader { geometry in
                HStack(spacing: 8) {
                    ForEach(harmonics.indices, id: \.self) { index in
                        VStack {
                            let value = harmonics[index]
                            let normalizedValue = max(0, (value + 60) / 60)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(EchoelBranding.accent)
                                .frame(height: geometry.size.height * 0.7 * CGFloat(normalizedValue))
                                .frame(maxHeight: .infinity, alignment: .bottom)

                            Text("\(index + 1)")
                                .font(EchoelBranding.Typography.captionSmall())
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
    }
}

struct PhaseCorrelationVisualization: View {
    let correlation: Float

    var body: some View {
        VStack(spacing: EchoelBranding.Spacing.xl) {
            Text("Phase Correlation")
                .font(EchoelBranding.Typography.h3())
                .foregroundColor(.white)

            // Goniometer-style display
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 200, height: 200)

                // Correlation indicator
                Circle()
                    .fill(correlationColor)
                    .frame(width: 30, height: 30)
                    .offset(x: CGFloat(correlation) * 85, y: 0)
            }

            HStack {
                Text("-1.0")
                    .font(EchoelBranding.Typography.caption())
                    .foregroundColor(.red)
                Spacer()
                Text("0.0")
                    .font(EchoelBranding.Typography.caption())
                    .foregroundColor(EchoelBranding.accentGreen)
                Spacer()
                Text("+1.0")
                    .font(EchoelBranding.Typography.caption())
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 40)

            Text(String(format: "%.3f", correlation))
                .font(EchoelBranding.Typography.display(size: 48))
                .foregroundColor(.white)
        }
    }

    private var correlationColor: Color {
        if correlation < -0.3 {
            return .red
        } else if correlation < 0.3 {
            return EchoelBranding.accentGreen
        } else {
            return .yellow
        }
    }
}

struct LoudnessVisualization: View {
    let lufs: Float

    var body: some View {
        VStack(spacing: EchoelBranding.Spacing.xl) {
            Text("Integrated Loudness")
                .font(EchoelBranding.Typography.h3())
                .foregroundColor(.white)

            Text(String(format: "%.1f LUFS", lufs))
                .font(EchoelBranding.Typography.display(size: 64))
                .foregroundColor(lufsColor)

            // Target reference
            VStack(spacing: 8) {
                Text("Common Targets:")
                    .font(EchoelBranding.Typography.bodySmall())
                    .foregroundColor(.white.opacity(0.7))

                HStack {
                    targetLabel(name: "Spotify", value: -14)
                    targetLabel(name: "YouTube", value: -14)
                    targetLabel(name: "Apple", value: -16)
                    targetLabel(name: "Broadcast", value: -23)
                }
            }

            // Meter
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(max(0, min(1, (lufs + 60) / 60))))
                }
            }
            .frame(height: 20)
        }
    }

    private var lufsColor: Color {
        if lufs > -10 {
            return .red  // Too loud
        } else if lufs > -23 {
            return .green  // Good range
        } else {
            return .yellow  // Quiet
        }
    }

    private func targetLabel(name: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(EchoelBranding.Typography.captionSmall())
            Text("\(value)")
                .font(EchoelBranding.Typography.caption(weight: .bold))
        }
        .foregroundColor(.white.opacity(0.6))
    }
}

struct FrequencyResponseVisualization: View {
    let data: [Float]

    var body: some View {
        SpectrumVisualization(data: data)  // Similar to spectrum but with smoothing
    }
}

struct ResonanceVisualization: View {
    let data: [Float]

    var body: some View {
        VStack {
            Text("Resonance Detection")
                .font(EchoelBranding.Typography.h3())
                .foregroundColor(.white)

            SpectrumVisualization(data: data)

            Text("Red peaks indicate potential resonances")
                .font(EchoelBranding.Typography.caption())
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

// MARK: - Meter & Info Cards

struct MeterCard: View {
    let title: String
    let value: Float
    let unit: String
    let range: ClosedRange<Float>
    let color: Color

    var body: some View {
        VStack(spacing: EchoelBranding.Spacing.sm) {
            Text(title)
                .font(EchoelBranding.Typography.bodySmall(weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Text(String(format: "%.1f", value))
                .font(EchoelBranding.Typography.h3())
                .foregroundColor(.white)

            Text(unit)
                .font(EchoelBranding.Typography.caption())
                .foregroundColor(.white.opacity(0.5))

            // Visual meter
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)))
                }
            }
            .frame(height: 8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .echoelCard(style: .glass)
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: EchoelBranding.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(EchoelBranding.Typography.bodySmall(weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Text(value)
                    .font(EchoelBranding.Typography.h4())
                    .foregroundColor(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(EchoelBranding.Typography.caption())
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .echoelCard(style: .glass)
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct AudioSuperScanView_Previews: PreviewProvider {
    static var previews: some View {
        AudioSuperScanView()
    }
}

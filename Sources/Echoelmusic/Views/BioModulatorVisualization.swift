// BioModulatorVisualization.swift
// Echoelmusic - Bio-Reactive Visual Feedback System
//
// Real-time visualization of biometric data and modulation
// Includes graphs, meters, waveforms, and laser/DMX preview
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import SwiftUI
import Combine

// MARK: - Main BioModulator Visualization View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct BioModulatorVisualizationView: View {
    @ObservedObject var bioModulator: BioModulator
    @State private var selectedTab = 0

    public init(bioModulator: BioModulator) {
        self.bioModulator = bioModulator
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with bio summary
            BioSummaryBar(bioData: bioModulator.currentBioData)
                .padding(.horizontal)
                .padding(.top, 8)

            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("Bio").tag(0)
                Text("Modulation").tag(1)
                Text("Laser/DMX").tag(2)
                Text("Waveform").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            TabView(selection: $selectedTab) {
                BioMetricsView(bioData: bioModulator.currentBioData)
                    .tag(0)

                ModulationMatrixView(bioModulator: bioModulator)
                    .tag(1)

                LaserDMXPreviewView(bioModulator: bioModulator)
                    .tag(2)

                BioWaveformView(bioModulator: bioModulator)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color.black.opacity(0.95))
    }
}

// MARK: - Bio Summary Bar

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct BioSummaryBar: View {
    let bioData: BiometricData

    var body: some View {
        HStack(spacing: 16) {
            // Heart Rate
            BioMiniMeter(
                icon: "heart.fill",
                value: bioData.heartRate,
                unit: "BPM",
                color: .red,
                range: 40...200
            )

            // HRV
            BioMiniMeter(
                icon: "waveform.path.ecg",
                value: bioData.hrvMs,
                unit: "ms",
                color: .orange,
                range: 10...150
            )

            // Coherence
            BioMiniMeter(
                icon: "brain.head.profile",
                value: bioData.coherence * 100,
                unit: "%",
                color: .purple,
                range: 0...100
            )

            // Breathing
            BioMiniMeter(
                icon: "lungs.fill",
                value: bioData.breathingRate,
                unit: "BR",
                color: .cyan,
                range: 4...30
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct BioMiniMeter: View {
    let icon: String
    let value: Double
    let unit: String
    let color: Color
    let range: ClosedRange<Double>

    var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))

            Text("\(Int(value))")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text(unit)
                .font(.system(size: 9))
                .foregroundColor(.gray)

            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))

                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(normalizedValue))
                }
            }
            .frame(height: 3)
        }
        .frame(width: 50)
    }
}

// MARK: - Bio Modulator Metrics View (renamed to avoid conflict with Components/BioMetricsView)

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct BioModulatorMetricsView: View {
    let bioData: BiometricData
    @State private var heartRateHistory: [Double] = Array(repeating: 70, count: 60)
    @State private var hrvHistory: [Double] = Array(repeating: 50, count: 60)
    @State private var coherenceHistory: [Double] = Array(repeating: 0.5, count: 60)
    @State private var breathHistory: [Double] = Array(repeating: 0.5, count: 60)

    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Heart Rate Graph
                BioGraphCard(
                    title: "Heart Rate",
                    icon: "heart.fill",
                    color: .red,
                    currentValue: bioData.heartRate,
                    unit: "BPM",
                    history: heartRateHistory,
                    range: 40...180
                )

                // HRV Graph
                BioGraphCard(
                    title: "Heart Rate Variability",
                    icon: "waveform.path.ecg",
                    color: .orange,
                    currentValue: bioData.hrvMs,
                    unit: "ms",
                    history: hrvHistory,
                    range: 10...150
                )

                // Coherence Graph
                BioGraphCard(
                    title: "Coherence",
                    icon: "brain.head.profile",
                    color: .purple,
                    currentValue: bioData.coherence * 100,
                    unit: "%",
                    history: coherenceHistory.map { $0 * 100 },
                    range: 0...100
                )

                // Breathing Phase
                BreathingVisualization(phase: bioData.breathPhase, rate: bioData.breathingRate)

                // Additional Metrics
                HStack(spacing: 16) {
                    BioMetricCard(
                        title: "GSR",
                        value: bioData.skinConductance,
                        icon: "hand.raised.fill",
                        color: .yellow
                    )

                    BioMetricCard(
                        title: "Temp",
                        value: bioData.bodyTemperature,
                        icon: "thermometer",
                        color: .green,
                        format: "%.1f°C"
                    )

                    BioMetricCard(
                        title: "SpO2",
                        value: bioData.oxygenSaturation,
                        icon: "drop.fill",
                        color: .blue,
                        format: "%.0f%%"
                    )
                }
            }
            .padding()
        }
        .onReceive(timer) { _ in
            updateHistory()
        }
    }

    func updateHistory() {
        heartRateHistory.removeFirst()
        heartRateHistory.append(bioData.heartRate)

        hrvHistory.removeFirst()
        hrvHistory.append(bioData.hrvMs)

        coherenceHistory.removeFirst()
        coherenceHistory.append(bioData.coherence)

        breathHistory.removeFirst()
        breathHistory.append(bioData.breathPhase)
    }
}

// MARK: - Bio Graph Card

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct BioGraphCard: View {
    let title: String
    let icon: String
    let color: Color
    let currentValue: Double
    let unit: String
    let history: [Double]
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(currentValue)) \(unit)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }

            // Graph
            GeometryReader { geo in
                Path { path in
                    let stepX = geo.size.width / CGFloat(history.count - 1)
                    let height = geo.size.height

                    for (index, value) in history.enumerated() {
                        let normalizedY = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                        let y = height - (CGFloat(normalizedY) * height)
                        let x = CGFloat(index) * stepX

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Current value indicator
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .position(
                        x: geo.size.width,
                        y: geo.size.height - (CGFloat((currentValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * geo.size.height)
                    )
            }
            .frame(height: 80)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Breathing Visualization

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct BreathingVisualization: View {
    let phase: Double
    let rate: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lungs.fill")
                    .foregroundColor(.cyan)
                Text("Breathing")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(rate)) BR/min")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            // Breathing circle
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.cyan.opacity(0.2), lineWidth: 8)

                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(phase))
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Inner breathing circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.cyan.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .scaleEffect(0.5 + CGFloat(phase) * 0.5)

                // Phase text
                VStack {
                    Text(phase < 0.5 ? "INHALE" : "EXHALE")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(Int(phase * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            }
            .frame(width: 120, height: 120)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - Bio Metric Card (renamed to avoid conflict with WatchAppView.MetricCard)

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct BioMetricCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    var format: String = "%.2f"

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)

            Text(String(format: format, value))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Modulation Matrix View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct ModulationMatrixView: View {
    @ObservedObject var bioModulator: BioModulator

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // BPM Section
                ModulationSection(
                    title: "BPM / Tempo",
                    icon: "metronome.fill",
                    color: .orange
                ) {
                    VStack(spacing: 12) {
                        // Current BPM
                        HStack {
                            Text("Modulated BPM")
                                .foregroundColor(.gray)
                            Spacer()
                            Text("\(Int(bioModulator.modulatedBPM))")
                                .font(.system(size: 36, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                        }

                        // BPM visualization
                        BPMVisualization(bpm: bioModulator.modulatedBPM)
                    }
                }

                // EFX Section
                ModulationSection(
                    title: "Effects Modulation",
                    icon: "slider.horizontal.3",
                    color: .purple
                ) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(bioModulator.efxModulations.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { target in
                            if let value = bioModulator.efxModulations[target] {
                                ModulationMeter(
                                    name: formatTargetName(target.rawValue),
                                    value: value,
                                    color: .purple
                                )
                            }
                        }
                    }
                }

                // Instrument Section
                ModulationSection(
                    title: "Instrument Modulation",
                    icon: "pianokeys",
                    color: .cyan
                ) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(bioModulator.instrumentModulations.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { target in
                            if let value = bioModulator.instrumentModulations[target] {
                                ModulationMeter(
                                    name: formatTargetName(target.rawValue),
                                    value: value,
                                    color: .cyan
                                )
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    func formatTargetName(_ name: String) -> String {
        // Convert camelCase to readable
        var result = ""
        for char in name {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result.capitalized
    }
}

// MARK: - Modulation Section

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct ModulationSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            content
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
}

// MARK: - BPM Visualization

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct BPMVisualization: View {
    let bpm: Double
    @State private var beatPhase: Double = 0

    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<16, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(beatBarColor(for: index))
                    .frame(height: beatBarHeight(for: index))
            }
        }
        .frame(height: 40)
        .onReceive(timer) { _ in
            let beatInterval = 60.0 / bpm
            beatPhase += 0.016 / beatInterval
            if beatPhase >= 1 {
                beatPhase = 0
            }
        }
    }

    func beatBarHeight(for index: Int) -> CGFloat {
        let position = Double(index) / 16.0
        let distance = abs(position - beatPhase)
        let normalized = 1.0 - min(distance, 1.0 - distance) * 4
        return CGFloat(max(0.2, normalized)) * 40
    }

    func beatBarColor(for index: Int) -> Color {
        let position = Double(index) / 16.0
        let distance = abs(position - beatPhase)
        let normalized = 1.0 - min(distance, 1.0 - distance) * 4
        return Color.orange.opacity(max(0.3, normalized))
    }
}

// MARK: - Modulation Meter

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct ModulationMeter: View {
    let name: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(1)

            HStack {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))

                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * CGFloat(value))
                    }
                }
                .frame(height: 8)

                Text("\(Int(value * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(color)
                    .frame(width: 35, alignment: .trailing)
            }
        }
    }
}

// MARK: - Laser/DMX Preview View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct LaserDMXPreviewView: View {
    @ObservedObject var bioModulator: BioModulator
    @State private var laserAngle: Double = 0

    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var laserColor: Color {
        let coherence = bioModulator.currentBioData.coherence
        // Map coherence to hue (0 = red, 0.33 = green, 0.66 = blue, 1 = back to red)
        return Color(hue: coherence, saturation: 1, brightness: 1)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Laser Preview
            ZStack {
                // Dark background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black)

                // Laser beams
                LaserBeamView(
                    color: laserColor,
                    intensity: bioModulator.currentBioData.heartRate / 150,
                    scanSpeed: bioModulator.currentBioData.breathPhase,
                    angle: laserAngle
                )

                // Overlay info
                VStack {
                    Spacer()
                    HStack {
                        LaserInfoBadge(title: "Intensity", value: "\(Int(bioModulator.currentBioData.heartRate / 1.5))%")
                        Spacer()
                        LaserInfoBadge(title: "Scan", value: "\(Int(bioModulator.currentBioData.breathPhase * 100))%")
                        Spacer()
                        LaserInfoBadge(title: "Color", value: "H:\(Int(bioModulator.currentBioData.coherence * 360))°")
                    }
                    .padding()
                }
            }
            .frame(height: 250)
            .cornerRadius(20)

            // DMX Channels
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "light.max")
                        .foregroundColor(.yellow)
                    Text("DMX Channels")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    DMXChannelView(channel: 1, name: "Master", value: bioModulator.currentBioData.coherence)
                    DMXChannelView(channel: 2, name: "Intensity", value: bioModulator.currentBioData.heartRate / 200)
                    DMXChannelView(channel: 3, name: "Red", value: 1 - bioModulator.currentBioData.coherence)
                    DMXChannelView(channel: 4, name: "Green", value: bioModulator.currentBioData.coherence)
                    DMXChannelView(channel: 5, name: "Blue", value: bioModulator.currentBioData.breathPhase)
                    DMXChannelView(channel: 6, name: "Strobe", value: bioModulator.currentBioData.skinConductance)
                    DMXChannelView(channel: 7, name: "Pattern", value: bioModulator.currentBioData.hrvMs / 150)
                    DMXChannelView(channel: 8, name: "Speed", value: bioModulator.currentBioData.breathPhase)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
        .padding()
        .onReceive(timer) { _ in
            laserAngle += bioModulator.currentBioData.breathPhase * 5
            if laserAngle >= 360 {
                laserAngle = 0
            }
        }
    }
}

// MARK: - Laser Beam View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct LaserBeamView: View {
    let color: Color
    let intensity: Double
    let scanSpeed: Double
    let angle: Double

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height)
            let beamCount = 5

            ForEach(0..<beamCount, id: \.self) { i in
                let beamAngle = angle + Double(i) * (360.0 / Double(beamCount))
                let radians = beamAngle * .pi / 180

                Path { path in
                    path.move(to: center)
                    let endX = center.x + cos(radians - .pi/2) * geo.size.height * 1.5
                    let endY = center.y + sin(radians - .pi/2) * geo.size.height * 1.5
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(
                    color.opacity(intensity * 0.8),
                    style: StrokeStyle(lineWidth: 2 + intensity * 3, lineCap: .round)
                )
                .blur(radius: 2)
            }

            // Center glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(intensity), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 60, height: 60)
                .position(center)
        }
    }
}

// MARK: - Laser Info Badge

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct LaserInfoBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }
}

// MARK: - DMX Channel View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct DMXChannelView: View {
    let channel: Int
    let name: String
    let value: Double

    var dmxValue: Int {
        Int(min(255, max(0, value * 255)))
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("CH\(channel)")
                .font(.system(size: 10))
                .foregroundColor(.gray)

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 60)

                // Value bar
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.yellow.opacity(0.8))
                        .frame(height: CGFloat(value) * 60)
                }
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                // Value text
                Text("\(dmxValue)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Text(name)
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
    }
}

// MARK: - Bio Waveform View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct BioWaveformView: View {
    @ObservedObject var bioModulator: BioModulator
    @State private var waveformData: [Double] = Array(repeating: 0, count: 256)
    @State private var phase: Double = 0

    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            // Main waveform
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                    Text("Bio-Reactive Waveform")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                WaveformCanvas(
                    data: waveformData,
                    color: .green,
                    bioData: bioModulator.currentBioData
                )
                .frame(height: 150)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)

            // Frequency spectrum
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                    Text("Bio Frequency Spectrum")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                SpectrumView(bioData: bioModulator.currentBioData)
                    .frame(height: 100)
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)

            // Coherence visualization
            CoherenceFieldView(coherence: bioModulator.currentBioData.coherence)
                .frame(height: 200)
        }
        .padding()
        .onReceive(timer) { _ in
            updateWaveform()
        }
    }

    func updateWaveform() {
        phase += 0.1

        for i in 0..<waveformData.count {
            let x = Double(i) / Double(waveformData.count) * .pi * 4

            // Heart rate wave
            let hrWave = sin(x + phase) * (bioModulator.currentBioData.heartRate / 200)

            // Breathing wave
            let breathWave = sin(x * 0.2 + phase * 0.3) * bioModulator.currentBioData.breathPhase

            // HRV noise
            let hrvNoise = Double.random(in: -0.1...0.1) * (bioModulator.currentBioData.hrvMs / 100)

            waveformData[i] = (hrWave + breathWave + hrvNoise) * bioModulator.currentBioData.coherence
        }
    }
}

// MARK: - Waveform Canvas

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct WaveformCanvas: View {
    let data: [Double]
    let color: Color
    let bioData: BiometricData

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let stepX = size.width / CGFloat(data.count)

            // Draw waveform
            var path = Path()
            for (index, value) in data.enumerated() {
                let x = CGFloat(index) * stepX
                let y = midY - CGFloat(value) * midY * 0.8

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )

            // Draw center line
            var centerLine = Path()
            centerLine.move(to: CGPoint(x: 0, y: midY))
            centerLine.addLine(to: CGPoint(x: size.width, y: midY))
            context.stroke(centerLine, with: .color(.white.opacity(0.2)), lineWidth: 1)
        }
    }
}

// MARK: - Spectrum View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct SpectrumView: View {
    let bioData: BiometricData
    @State private var bands: [Double] = Array(repeating: 0.3, count: 32)

    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { context, size in
            let bandWidth = size.width / CGFloat(bands.count)

            for (index, value) in bands.enumerated() {
                let x = CGFloat(index) * bandWidth
                let height = CGFloat(value) * size.height

                let rect = CGRect(
                    x: x + 1,
                    y: size.height - height,
                    width: bandWidth - 2,
                    height: height
                )

                let gradient = Gradient(colors: [.blue, .cyan, .green])
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 2),
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: 0, y: size.height),
                        endPoint: CGPoint(x: 0, y: 0)
                    )
                )
            }
        }
        .onReceive(timer) { _ in
            updateSpectrum()
        }
    }

    func updateSpectrum() {
        for i in 0..<bands.count {
            let baseValue = 0.2 + bioData.coherence * 0.3
            let hrInfluence = sin(Double(i) * 0.2 + bioData.heartRate / 30) * 0.2
            let breathInfluence = sin(Double(i) * 0.1) * bioData.breathPhase * 0.3
            let noise = Double.random(in: -0.1...0.1) * (1 - bioData.coherence)

            bands[i] = max(0.05, min(1, baseValue + hrInfluence + breathInfluence + noise))
        }
    }
}

// MARK: - Coherence Field View

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct CoherenceFieldView: View {
    let coherence: Double
    @State private var phase: Double = 0

    let timer = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("Coherence Field")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(coherence * 100))%")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
            }

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = min(size.width, size.height) / 2

                // Draw coherence rings
                for i in 0..<8 {
                    let ringPhase = phase + Double(i) * 0.5
                    let radius = CGFloat(i + 1) / 8 * maxRadius * CGFloat(0.5 + coherence * 0.5)

                    let opacity = (1 - Double(i) / 8) * coherence

                    var ringPath = Path()
                    ringPath.addEllipse(in: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))

                    context.stroke(
                        ringPath,
                        with: .color(.purple.opacity(opacity)),
                        lineWidth: 2 + CGFloat(coherence) * 2
                    )
                }

                // Draw particles
                let particleCount = Int(coherence * 30) + 5
                for i in 0..<particleCount {
                    let angle = (Double(i) / Double(particleCount)) * .pi * 2 + phase
                    let distance = maxRadius * CGFloat(0.3 + coherence * 0.6) * CGFloat(sin(angle * 3 + phase) * 0.2 + 0.8)

                    let particleX = center.x + cos(angle) * distance
                    let particleY = center.y + sin(angle) * distance

                    let particleSize = 3 + coherence * 4

                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: particleX - particleSize / 2,
                            y: particleY - particleSize / 2,
                            width: particleSize,
                            height: particleSize
                        )),
                        with: .color(.purple.opacity(0.6 + coherence * 0.4))
                    )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .onReceive(timer) { _ in
            phase += 0.02
        }
    }
}

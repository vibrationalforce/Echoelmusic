import SwiftUI
import Combine

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC ADAPTIVE UI COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Cross-Platform Self-Healing UI Components with Automatic Fallbacks
//
// Features:
// • Platform-Aware Component Rendering
// • Automatic Fallback to Simpler Variants
// • Accessibility-First Design
// • Performance-Adaptive Quality
// • Error Boundary Protection
// • Graceful Degradation
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Adaptive Container

/// A self-healing container that provides error boundaries and fallbacks
public struct AdaptiveContainer<Content: View, Fallback: View>: View {
    @StateObject private var uiEngine = SelfHealingUIEngine.shared
    @State private var hasError = false
    @State private var errorMessage: String?

    private let componentId: String
    private let componentType: ComponentType
    private let priority: ComponentPriority
    private let content: () -> Content
    private let fallback: () -> Fallback

    public init(
        id: String,
        type: ComponentType,
        priority: ComponentPriority = .normal,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder fallback: @escaping () -> Fallback
    ) {
        self.componentId = id
        self.componentType = type
        self.priority = priority
        self.content = content
        self.fallback = fallback
    }

    public var body: some View {
        Group {
            if hasError || shouldUseFallback {
                fallback()
                    .onAppear {
                        uiEngine.registerComponent(componentId, type: componentType, priority: priority)
                    }
            } else {
                content()
                    .onAppear {
                        uiEngine.registerComponent(componentId, type: componentType, priority: priority)
                    }
            }
        }
        .onChange(of: uiEngine.uiRecoveryMode) { mode in
            if mode == .emergency || mode == .fallback {
                withAnimation(.easeInOut(duration: 0.3)) {
                    hasError = true
                }
            } else if mode == .normal {
                withAnimation(.easeInOut(duration: 0.3)) {
                    hasError = false
                }
            }
        }
    }

    private var shouldUseFallback: Bool {
        // Check if this component should use fallback based on system state
        if uiEngine.uiHealth == .critical { return true }
        if uiEngine.uiHealth == .degraded && priority.rawValue < ComponentPriority.high.rawValue { return true }

        // Check component-specific state
        if let state = uiEngine.componentRegistry[componentId] {
            return state.usingFallback
        }

        return false
    }
}

// MARK: - Adaptive Waveform

/// Cross-platform waveform display with automatic fallback
public struct AdaptiveWaveform: View {
    @StateObject private var uiEngine = SelfHealingUIEngine.shared

    let samples: [Float]
    let color: Color
    let lineWidth: CGFloat

    @State private var useSimplified = false

    public init(samples: [Float], color: Color = .blue, lineWidth: CGFloat = 2) {
        self.samples = samples
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        AdaptiveContainer(
            id: "waveform-\(UUID().uuidString.prefix(8))",
            type: .waveform,
            priority: .normal
        ) {
            // Full quality waveform
            Canvas { context, size in
                drawWaveform(context: context, size: size, simplified: false)
            }
            .drawingGroup()  // GPU-accelerated
        } fallback: {
            // Simplified waveform
            Canvas { context, size in
                drawWaveform(context: context, size: size, simplified: true)
            }
        }
    }

    private func drawWaveform(context: GraphicsContext, size: CGSize, simplified: Bool) {
        let width = size.width
        let height = size.height
        let midY = height / 2

        // Reduce sample count for simplified version
        let displaySamples: [Float]
        if simplified {
            let step = max(1, samples.count / 50)
            displaySamples = stride(from: 0, to: samples.count, by: step).map { samples[$0] }
        } else {
            displaySamples = samples
        }

        guard !displaySamples.isEmpty else { return }

        var path = Path()
        let stepX = width / CGFloat(displaySamples.count - 1)

        path.move(to: CGPoint(x: 0, y: midY))

        for (index, sample) in displaySamples.enumerated() {
            let x = CGFloat(index) * stepX
            let y = midY - CGFloat(sample) * midY * 0.9

            if simplified {
                path.addLine(to: CGPoint(x: x, y: y))
            } else {
                // Smooth curve for full quality
                if index > 0 {
                    let prevX = CGFloat(index - 1) * stepX
                    let controlX = (prevX + x) / 2
                    path.addQuadCurve(
                        to: CGPoint(x: x, y: y),
                        control: CGPoint(x: controlX, y: path.currentPoint?.y ?? midY)
                    )
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }

        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }
}

// MARK: - Adaptive Spectrum Analyzer

/// Cross-platform spectrum analyzer with automatic fallback
public struct AdaptiveSpectrum: View {
    @StateObject private var uiEngine = SelfHealingUIEngine.shared

    let magnitudes: [Float]
    let barCount: Int
    let gradient: Gradient

    public init(magnitudes: [Float], barCount: Int = 32, gradient: Gradient? = nil) {
        self.magnitudes = magnitudes
        self.barCount = barCount
        self.gradient = gradient ?? Gradient(colors: [.green, .yellow, .orange, .red])
    }

    public var body: some View {
        AdaptiveContainer(
            id: "spectrum-\(UUID().uuidString.prefix(8))",
            type: .spectrum,
            priority: .normal
        ) {
            // Full quality spectrum
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(0..<barCount, id: \.self) { index in
                        SpectrumBar(
                            magnitude: getMagnitude(for: index),
                            gradient: gradient,
                            animated: true
                        )
                    }
                }
            }
        } fallback: {
            // Simplified spectrum
            GeometryReader { geometry in
                HStack(spacing: 4) {
                    ForEach(0..<min(16, barCount), id: \.self) { index in
                        SpectrumBar(
                            magnitude: getMagnitude(for: index * 2),
                            gradient: gradient,
                            animated: false
                        )
                    }
                }
            }
        }
    }

    private func getMagnitude(for index: Int) -> Float {
        guard !magnitudes.isEmpty else { return 0 }
        let mappedIndex = index * magnitudes.count / barCount
        return magnitudes[min(mappedIndex, magnitudes.count - 1)]
    }
}

struct SpectrumBar: View {
    let magnitude: Float
    let gradient: Gradient
    let animated: Bool

    @State private var displayMagnitude: Float = 0

    var body: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                Rectangle()
                    .fill(LinearGradient(gradient: gradient, startPoint: .bottom, endPoint: .top))
                    .frame(height: geometry.size.height * CGFloat(displayMagnitude))
                    .cornerRadius(animated ? 2 : 0)
            }
        }
        .onAppear {
            displayMagnitude = magnitude
        }
        .onChange(of: magnitude) { newValue in
            if animated {
                withAnimation(.easeOut(duration: 0.1)) {
                    displayMagnitude = newValue
                }
            } else {
                displayMagnitude = newValue
            }
        }
    }
}

// MARK: - Adaptive Knob Control

/// Cross-platform knob control with automatic fallback
public struct AdaptiveKnob: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    let color: Color

    @State private var isDragging = false
    @GestureState private var dragOffset: CGFloat = 0

    public init(
        value: Binding<Float>,
        range: ClosedRange<Float> = 0...1,
        label: String = "",
        color: Color = .accentColor
    ) {
        self._value = value
        self.range = range
        self.label = label
        self.color = color
    }

    public var body: some View {
        AdaptiveContainer(
            id: "knob-\(label)",
            type: .knob,
            priority: .high
        ) {
            // Full quality knob
            fullKnob
        } fallback: {
            // Fallback to slider
            fallbackSlider
        }
    }

    private var fullKnob: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)

                // Value arc
                Circle()
                    .trim(from: 0, to: CGFloat(normalizedValue) * 0.75)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(135))

                // Indicator line
                Rectangle()
                    .fill(color)
                    .frame(width: 2, height: 15)
                    .offset(y: -20)
                    .rotationEffect(.degrees(Double(normalizedValue) * 270 - 135))

                // Center circle
                Circle()
                    .fill(isDragging ? color.opacity(0.2) : Color.clear)
                    .frame(width: 30, height: 30)
            }
            .frame(width: 60, height: 60)
            .gesture(knobGesture)

            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(String(format: "%.1f", value))
                .font(.caption)
                .monospacedDigit()
        }
    }

    private var fallbackSlider: some View {
        VStack(spacing: 4) {
            #if os(macOS)
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Float($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound))
            .frame(width: 80)
            #else
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Float($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound))
            .tint(color)
            .frame(width: 80)
            #endif

            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var normalizedValue: Float {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var knobGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                isDragging = true
                let delta = Float(-gesture.translation.height / 100)
                let newValue = value + delta * (range.upperBound - range.lowerBound)
                value = min(max(newValue, range.lowerBound), range.upperBound)
            }
            .onEnded { _ in
                isDragging = false
            }
    }
}

// MARK: - Adaptive Transport Control

/// Cross-platform transport control with automatic fallback
public struct AdaptiveTransport: View {
    @Binding var isPlaying: Bool
    @Binding var isRecording: Bool
    let onStop: () -> Void
    let onRewind: () -> Void
    let onForward: () -> Void

    public init(
        isPlaying: Binding<Bool>,
        isRecording: Binding<Bool>,
        onStop: @escaping () -> Void,
        onRewind: @escaping () -> Void,
        onForward: @escaping () -> Void
    ) {
        self._isPlaying = isPlaying
        self._isRecording = isRecording
        self.onStop = onStop
        self.onRewind = onRewind
        self.onForward = onForward
    }

    public var body: some View {
        AdaptiveContainer(
            id: "transport",
            type: .transport,
            priority: .critical  // Transport is critical
        ) {
            // Full transport controls
            fullTransport
        } fallback: {
            // Minimal transport (only play/stop)
            minimalTransport
        }
    }

    private var fullTransport: some View {
        HStack(spacing: platformSpacing) {
            // Rewind
            TransportButton(systemName: "backward.fill", action: onRewind)

            // Stop
            TransportButton(systemName: "stop.fill", action: onStop)

            // Play/Pause
            TransportButton(
                systemName: isPlaying ? "pause.fill" : "play.fill",
                highlighted: isPlaying
            ) {
                isPlaying.toggle()
            }

            // Record
            TransportButton(
                systemName: isRecording ? "record.circle.fill" : "record.circle",
                color: .red,
                highlighted: isRecording
            ) {
                isRecording.toggle()
            }

            // Forward
            TransportButton(systemName: "forward.fill", action: onForward)
        }
        .padding(.horizontal)
    }

    private var minimalTransport: some View {
        HStack(spacing: 20) {
            // Stop
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(isPlaying ? .accentColor : .primary)
            }
            .buttonStyle(.plain)
        }
    }

    private var platformSpacing: CGFloat {
        #if os(tvOS)
        return 40
        #elseif os(watchOS)
        return 8
        #else
        return 16
        #endif
    }
}

struct TransportButton: View {
    let systemName: String
    var color: Color = .primary
    var highlighted: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2)
                .foregroundColor(highlighted ? color : .primary)
                .frame(width: buttonSize, height: buttonSize)
                .background(highlighted ? color.opacity(0.2) : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var buttonSize: CGFloat {
        #if os(tvOS)
        return 60
        #elseif os(watchOS)
        return 30
        #else
        return 44
        #endif
    }
}

// MARK: - Adaptive Visualizer

/// Cross-platform audio visualizer with automatic fallback
public struct AdaptiveVisualizer: View {
    @StateObject private var uiEngine = SelfHealingUIEngine.shared

    let audioLevel: Float
    let coherence: Float
    let style: VisualizerStyle

    public enum VisualizerStyle {
        case particle
        case wave
        case radial
        case simple
    }

    public init(audioLevel: Float, coherence: Float = 0.5, style: VisualizerStyle = .particle) {
        self.audioLevel = audioLevel
        self.coherence = coherence
        self.style = style
    }

    public var body: some View {
        AdaptiveContainer(
            id: "visualizer",
            type: .visualizer,
            priority: .low  // Visualizers are optional
        ) {
            // Full quality visualizer
            fullVisualizer
        } fallback: {
            // Simple color view
            simpleVisualizer
        }
    }

    @ViewBuilder
    private var fullVisualizer: some View {
        switch style {
        case .particle:
            ParticleVisualizerView(audioLevel: audioLevel, coherence: coherence)
        case .wave:
            WaveVisualizerView(audioLevel: audioLevel, coherence: coherence)
        case .radial:
            RadialVisualizerView(audioLevel: audioLevel, coherence: coherence)
        case .simple:
            simpleVisualizer
        }
    }

    private var simpleVisualizer: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: Double(coherence) * 0.3, saturation: 0.7, brightness: 0.8),
                        Color(hue: Double(coherence) * 0.3 + 0.1, saturation: 0.6, brightness: 0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .opacity(Double(0.5 + audioLevel * 0.5))
    }
}

// Particle Visualizer Implementation
struct ParticleVisualizerView: View {
    let audioLevel: Float
    let coherence: Float

    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGPoint
        var size: CGFloat
        var opacity: Double
        var hue: Double
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let rect = CGRect(
                        x: particle.position.x - particle.size/2,
                        y: particle.position.y - particle.size/2,
                        width: particle.size,
                        height: particle.size
                    )

                    context.fill(
                        Circle().path(in: rect),
                        with: .color(Color(hue: particle.hue, saturation: 0.8, brightness: 0.9).opacity(particle.opacity))
                    )
                }
            }
        }
        .onAppear {
            generateParticles(count: 50)
        }
        .onChange(of: audioLevel) { _ in
            updateParticles()
        }
    }

    private func generateParticles(count: Int) {
        particles = (0..<count).map { _ in
            Particle(
                position: CGPoint(x: CGFloat.random(in: 0...300), y: CGFloat.random(in: 0...300)),
                velocity: CGPoint(x: CGFloat.random(in: -2...2), y: CGFloat.random(in: -2...2)),
                size: CGFloat.random(in: 4...12),
                opacity: Double.random(in: 0.3...0.8),
                hue: Double(coherence) * 0.3
            )
        }
    }

    private func updateParticles() {
        for i in particles.indices {
            var p = particles[i]
            p.position.x += p.velocity.x * CGFloat(audioLevel * 2)
            p.position.y += p.velocity.y * CGFloat(audioLevel * 2)
            p.hue = Double(coherence) * 0.3
            particles[i] = p
        }
    }
}

// Wave Visualizer Implementation
struct WaveVisualizerView: View {
    let audioLevel: Float
    let coherence: Float

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let amplitude = size.height / 4 * CGFloat(audioLevel)

            var path = Path()
            path.move(to: CGPoint(x: 0, y: midY))

            for x in stride(from: 0, through: size.width, by: 2) {
                let normalizedX = x / size.width
                let y = midY + sin(normalizedX * .pi * 4 + Double(coherence * 10)) * amplitude
                path.addLine(to: CGPoint(x: x, y: y))
            }

            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [.blue, .purple, .pink]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 3
            )
        }
    }
}

// Radial Visualizer Implementation
struct RadialVisualizerView: View {
    let audioLevel: Float
    let coherence: Float

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2

            for i in 0..<8 {
                let angle = Double(i) * .pi / 4
                let radius = maxRadius * CGFloat(0.3 + audioLevel * 0.7)

                var path = Path()
                path.move(to: center)
                path.addLine(to: CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                ))

                context.stroke(
                    path,
                    with: .color(Color(hue: Double(coherence) * 0.3 + Double(i) * 0.05, saturation: 0.8, brightness: 0.9)),
                    lineWidth: 4
                )
            }

            // Center circle
            let circleRect = CGRect(
                x: center.x - 20,
                y: center.y - 20,
                width: 40,
                height: 40
            )
            context.fill(
                Circle().path(in: circleRect),
                with: .color(Color(hue: Double(coherence) * 0.3, saturation: 0.7, brightness: 0.9))
            )
        }
    }
}

// MARK: - Adaptive Bio Display

/// Cross-platform biometric display with automatic fallback
public struct AdaptiveBioDisplay: View {
    let heartRate: Int
    let coherence: Float
    let stress: Float

    public init(heartRate: Int, coherence: Float, stress: Float) {
        self.heartRate = heartRate
        self.coherence = coherence
        self.stress = stress
    }

    public var body: some View {
        AdaptiveContainer(
            id: "bio-display",
            type: .biofeedback,
            priority: .normal
        ) {
            // Full bio display
            fullBioDisplay
        } fallback: {
            // Simple numbers only
            simpleBioDisplay
        }
    }

    private var fullBioDisplay: some View {
        HStack(spacing: 20) {
            // Heart Rate
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)

                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .scaleEffect(1.0 + Float.random(in: 0...0.1))
                }

                Text("\(heartRate)")
                    .font(.headline)
                    .monospacedDigit()

                Text("BPM")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Coherence
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: CGFloat(coherence))
                        .stroke(coherenceColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(coherence * 100))")
                        .font(.caption)
                        .fontWeight(.bold)
                }

                Text("Coherence")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Stress
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: CGFloat(stress))
                        .stroke(stressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(stress * 100))")
                        .font(.caption)
                        .fontWeight(.bold)
                }

                Text("Stress")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var simpleBioDisplay: some View {
        HStack(spacing: 16) {
            Label("\(heartRate)", systemImage: "heart.fill")
                .foregroundColor(.red)

            Label("\(Int(coherence * 100))%", systemImage: "waveform.path.ecg")
                .foregroundColor(coherenceColor)
        }
        .font(.caption)
    }

    private var coherenceColor: Color {
        if coherence > 0.7 { return .green }
        if coherence > 0.4 { return .yellow }
        return .orange
    }

    private var stressColor: Color {
        if stress < 0.3 { return .green }
        if stress < 0.6 { return .yellow }
        return .red
    }
}

// MARK: - Platform-Specific Helpers

extension View {
    /// Apply platform-specific modifiers
    @ViewBuilder
    func platformOptimized() -> some View {
        #if os(watchOS)
        self.frame(maxWidth: .infinity)
        #elseif os(tvOS)
        self.focusable()
        #elseif os(visionOS)
        self.frame(depth: 10)
        #else
        self
        #endif
    }

    /// Apply self-healing error boundary
    func selfHealing(
        id: String,
        type: ComponentType,
        priority: ComponentPriority = .normal
    ) -> some View {
        AdaptiveContainer(
            id: id,
            type: type,
            priority: priority
        ) {
            self
        } fallback: {
            Color.gray.opacity(0.2)
                .overlay(
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                )
        }
    }
}

// MARK: - Accessibility Extensions

extension View {
    /// Add accessibility optimizations for self-healing components
    func accessibilityOptimized(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(Text(label))
            .accessibilityHint(hint.map { Text($0) } ?? Text(""))
            .accessibilityAddTraits(.updatesFrequently)
    }
}

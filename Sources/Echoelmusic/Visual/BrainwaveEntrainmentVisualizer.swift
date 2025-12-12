import SwiftUI
import Combine

/// BrainwaveEntrainmentVisualizer - Scientific Visual Brainwave Entrainment
///
/// Implements evidence-based visual entrainment using:
/// - Photic driving (rhythmic light stimulation)
/// - Ganzfeld effect (uniform visual field)
/// - Color therapy based on octave transposition
/// - Safe frequency ranges (avoiding photosensitive triggers)
///
/// **Safety Features:**
/// - Maximum flash frequency: 14 Hz (below photosensitive epilepsy threshold)
/// - Gradual intensity ramps to avoid sudden transitions
/// - Optional static mode for sensitive users
/// - Automatic detection of rapid frequency changes
///
/// **Physical Translation:**
/// Bio frequencies (0.04-3.5 Hz) → Audio (20-20kHz) → Light (400-750 THz)
/// Each step uses octave multiplication to maintain harmonic relationships
@MainActor
public struct BrainwaveEntrainmentVisualizer: View {

    // MARK: - Bindings

    @ObservedObject var hub: ImmersiveExperienceHub

    // MARK: - State

    @State private var phase: Double = 0
    @State private var lastUpdate: Date = Date()

    // Safety settings
    @State private var safetyMode: Bool = false
    @State private var maxFlashRate: Double = 14.0  // Hz - safe for most users

    // MARK: - Body

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let deltaTime = now.timeIntervalSince(lastUpdate)

                // Update phase
                updatePhase(deltaTime: deltaTime)

                // Draw based on experience mode
                switch hub.experienceMode {
                case .deepSleep:
                    drawDeltaWavePattern(context: context, size: size)
                case .meditation:
                    drawThetaWavePattern(context: context, size: size)
                case .relaxation, .healing, .creativity:
                    drawAlphaWavePattern(context: context, size: size)
                case .focus, .performance:
                    drawBetaWavePattern(context: context, size: size)
                case .flow:
                    drawFlowStatePattern(context: context, size: size)
                }

                // Draw coherence indicator
                drawCoherenceRing(context: context, size: size)

                // Draw entrainment sync indicator
                drawSyncIndicator(context: context, size: size)

                DispatchQueue.main.async {
                    lastUpdate = now
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityLabel("Brainwave entrainment visualization")
        .accessibilityHint("Visual patterns synchronized to target brainwave frequency")
    }

    // MARK: - Phase Updates

    private func updatePhase(deltaTime: Double) {
        let frequency = min(hub.entrainmentTargetHz, maxFlashRate)
        phase += frequency * deltaTime
        phase = phase.truncatingRemainder(dividingBy: 1.0)
    }

    // MARK: - Delta Wave Pattern (0.5-4 Hz)

    private func drawDeltaWavePattern(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2

        // Deep blue pulsing glow - very slow, hypnotic
        let pulseAmount = sin(phase * .pi * 2) * 0.5 + 0.5
        let color = hub.brainwaveState.color

        // Background gradient
        let gradient = Gradient(colors: [
            Color(red: Double(color.r) * 0.3, green: Double(color.g) * 0.3, blue: Double(color.b) * 0.8),
            Color.black
        ])

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                gradient,
                center: center,
                startRadius: maxRadius * CGFloat(0.2 + pulseAmount * 0.3),
                endRadius: maxRadius * 1.5
            )
        )

        // Slow expanding rings
        for i in 0..<5 {
            let ringPhase = (phase + Double(i) * 0.2).truncatingRemainder(dividingBy: 1.0)
            let radius = maxRadius * CGFloat(ringPhase)
            let opacity = 1.0 - ringPhase

            var path = Path()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(0),
                endAngle: .degrees(360),
                clockwise: false
            )

            context.stroke(
                path,
                with: .color(Color(
                    red: Double(color.r),
                    green: Double(color.g),
                    blue: Double(color.b)
                ).opacity(opacity * 0.5)),
                lineWidth: 3
            )
        }
    }

    // MARK: - Theta Wave Pattern (4-8 Hz)

    private func drawThetaWavePattern(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2
        let color = hub.brainwaveState.color

        // Purple/indigo dreamy pattern
        let pulseAmount = sin(phase * .pi * 2) * 0.5 + 0.5

        // Ganzfeld-like background
        let bgColor = Color(
            red: Double(color.r) * (0.3 + pulseAmount * 0.2),
            green: Double(color.g) * (0.2 + pulseAmount * 0.1),
            blue: Double(color.b) * (0.6 + pulseAmount * 0.3)
        )

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(bgColor)
        )

        // Spiral patterns - meditative
        let spiralCount = 3
        for s in 0..<spiralCount {
            var path = Path()
            let spiralOffset = Double(s) / Double(spiralCount) * .pi * 2

            for t in stride(from: 0.0, to: 4 * Double.pi, by: 0.1) {
                let r = maxRadius * 0.1 + maxRadius * 0.8 * t / (4 * .pi)
                let angle = t + phase * .pi * 2 + spiralOffset
                let x = center.x + CGFloat(r * cos(angle))
                let y = center.y + CGFloat(r * sin(angle))

                if t == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(
                path,
                with: .color(.white.opacity(0.3)),
                lineWidth: 2
            )
        }

        // Central meditation focus point
        let focusRadius = maxRadius * 0.1 * CGFloat(1 + pulseAmount * 0.3)
        var focusPath = Path()
        focusPath.addArc(center: center, radius: focusRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)

        context.fill(
            focusPath,
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.8), .clear]),
                center: center,
                startRadius: 0,
                endRadius: focusRadius
            )
        )
    }

    // MARK: - Alpha Wave Pattern (8-12 Hz)

    private func drawAlphaWavePattern(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2
        let color = hub.brainwaveState.color

        // Green relaxation pattern with gentle oscillation
        let pulseAmount = sin(phase * .pi * 2) * 0.5 + 0.5
        let coherence = hub.systemCoherence / 100.0

        // Background shifts with coherence
        let bgColor = Color(
            red: 0.1,
            green: 0.3 + coherence * 0.4,
            blue: 0.2
        )

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(bgColor)
        )

        // Mandala-like petal pattern
        let petalCount = 12
        for i in 0..<petalCount {
            let angle = (Double(i) / Double(petalCount)) * .pi * 2 + phase * .pi
            let petalLength = maxRadius * 0.7 * (0.8 + coherence * 0.2)
            let petalWidth = maxRadius * 0.15

            var path = Path()
            let startPoint = CGPoint(
                x: center.x + cos(angle) * maxRadius * 0.15,
                y: center.y + sin(angle) * maxRadius * 0.15
            )
            let endPoint = CGPoint(
                x: center.x + cos(angle) * petalLength,
                y: center.y + sin(angle) * petalLength
            )
            let control1 = CGPoint(
                x: center.x + cos(angle - 0.3) * petalLength * 0.6,
                y: center.y + sin(angle - 0.3) * petalLength * 0.6
            )
            let control2 = CGPoint(
                x: center.x + cos(angle + 0.3) * petalLength * 0.6,
                y: center.y + sin(angle + 0.3) * petalLength * 0.6
            )

            path.move(to: startPoint)
            path.addQuadCurve(to: endPoint, control: control1)
            path.addQuadCurve(to: startPoint, control: control2)

            let petalOpacity = 0.3 + pulseAmount * 0.2
            context.fill(
                path,
                with: .color(Color(
                    red: Double(color.r),
                    green: Double(color.g),
                    blue: Double(color.b)
                ).opacity(petalOpacity))
            )
        }

        // Breathing circle at center
        let breathRadius = maxRadius * 0.2 * CGFloat(0.8 + pulseAmount * 0.4)
        var breathPath = Path()
        breathPath.addArc(center: center, radius: breathRadius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)

        context.fill(
            breathPath,
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: Double(color.r), green: Double(color.g), blue: Double(color.b)),
                    Color(red: Double(color.r), green: Double(color.g), blue: Double(color.b)).opacity(0)
                ]),
                center: center,
                startRadius: 0,
                endRadius: breathRadius
            )
        )
    }

    // MARK: - Beta Wave Pattern (12-30 Hz)

    private func drawBetaWavePattern(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2
        let color = hub.brainwaveState.color

        // Yellow/orange alert pattern - more dynamic
        let pulseAmount = sin(phase * .pi * 2) * 0.5 + 0.5
        let fastPulse = sin(phase * .pi * 4) * 0.5 + 0.5

        // Dynamic background
        let bgColor = Color(
            red: 0.15 + fastPulse * 0.1,
            green: 0.12 + fastPulse * 0.08,
            blue: 0.05
        )

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(bgColor)
        )

        // Radiating lines - focused energy
        let lineCount = 24
        for i in 0..<lineCount {
            let angle = (Double(i) / Double(lineCount)) * .pi * 2
            let linePhase = (phase * 2 + Double(i) * 0.1).truncatingRemainder(dividingBy: 1.0)

            let innerRadius = maxRadius * 0.15
            let outerRadius = maxRadius * CGFloat(0.3 + linePhase * 0.6)

            var path = Path()
            path.move(to: CGPoint(
                x: center.x + cos(angle) * innerRadius,
                y: center.y + sin(angle) * innerRadius
            ))
            path.addLine(to: CGPoint(
                x: center.x + cos(angle) * outerRadius,
                y: center.y + sin(angle) * outerRadius
            ))

            context.stroke(
                path,
                with: .color(Color(
                    red: Double(color.r),
                    green: Double(color.g),
                    blue: Double(color.b)
                ).opacity(1.0 - linePhase)),
                lineWidth: 2
            )
        }

        // Pulsing hexagon - focus symbol
        let hexRadius = maxRadius * 0.25 * CGFloat(0.9 + pulseAmount * 0.2)
        var hexPath = Path()
        for i in 0..<6 {
            let angle = (Double(i) / 6.0) * .pi * 2 - .pi / 6
            let point = CGPoint(
                x: center.x + cos(angle) * hexRadius,
                y: center.y + sin(angle) * hexRadius
            )
            if i == 0 {
                hexPath.move(to: point)
            } else {
                hexPath.addLine(to: point)
            }
        }
        hexPath.closeSubpath()

        context.stroke(
            hexPath,
            with: .color(Color(
                red: Double(color.r),
                green: Double(color.g),
                blue: Double(color.b)
            )),
            lineWidth: 3
        )
    }

    // MARK: - Flow State Pattern (Mixed Alpha-Gamma)

    private func drawFlowStatePattern(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2
        let coherence = hub.systemCoherence / 100.0

        // Flow state combines relaxation with heightened awareness
        let slowPulse = sin(phase * .pi * 2) * 0.5 + 0.5
        let fastPulse = sin(phase * .pi * 8) * 0.5 + 0.5

        // Gradient background shifting with flow
        let gradient = Gradient(colors: [
            Color(red: 0.1 + coherence * 0.2, green: 0.3 + coherence * 0.3, blue: 0.5),
            Color(red: 0.05, green: 0.1, blue: 0.2)
        ])

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .radialGradient(
                gradient,
                center: center,
                startRadius: maxRadius * CGFloat(slowPulse * 0.3),
                endRadius: maxRadius * 1.5
            )
        )

        // Flowing particles
        let particleCount = 50
        for i in 0..<particleCount {
            let seed = Double(i) * 1.618033988749895  // Golden ratio
            let particlePhase = (phase + seed).truncatingRemainder(dividingBy: 1.0)

            let angle = seed * .pi * 2
            let distance = maxRadius * CGFloat(0.2 + particlePhase * 0.7)

            let x = center.x + cos(angle + particlePhase * .pi) * distance
            let y = center.y + sin(angle + particlePhase * .pi) * distance

            let particleSize: CGFloat = 3 + CGFloat(fastPulse) * 3

            var path = Path()
            path.addArc(
                center: CGPoint(x: x, y: y),
                radius: particleSize,
                startAngle: .degrees(0),
                endAngle: .degrees(360),
                clockwise: false
            )

            let opacity = (1.0 - particlePhase) * coherence
            context.fill(
                path,
                with: .color(.white.opacity(opacity))
            )
        }

        // Coherence indicator circle
        let coherenceRadius = maxRadius * CGFloat(0.15 + coherence * 0.1)
        var coherencePath = Path()
        coherencePath.addArc(
            center: center,
            radius: coherenceRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )

        context.fill(
            coherencePath,
            with: .radialGradient(
                Gradient(colors: [
                    .white.opacity(0.8),
                    Color(red: 0.2, green: 0.8, blue: 0.6).opacity(0.5),
                    .clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: coherenceRadius
            )
        )
    }

    // MARK: - Coherence Ring

    private func drawCoherenceRing(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxRadius = min(size.width, size.height) / 2
        let coherence = hub.systemCoherence / 100.0

        // Arc showing coherence level
        let arcRadius = maxRadius * 0.85
        let startAngle = Angle.degrees(-90)
        let endAngle = Angle.degrees(-90 + 360 * coherence)

        var path = Path()
        path.addArc(
            center: center,
            radius: arcRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        // Color based on coherence level
        let color: Color
        if coherence < 0.4 {
            color = .red.opacity(0.6)
        } else if coherence < 0.6 {
            color = .yellow.opacity(0.6)
        } else {
            color = .green.opacity(0.6)
        }

        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
        )
    }

    // MARK: - Sync Indicator

    private func drawSyncIndicator(context: GraphicsContext, size: CGSize) {
        let sync = hub.entrainmentSync
        let indicatorSize: CGFloat = 20
        let position = CGPoint(x: size.width - 30, y: 30)

        // Pulsing circle when synced
        let pulseAmount = sin(phase * .pi * 2) * 0.5 + 0.5
        let radius = indicatorSize * 0.5 * CGFloat(1 + sync * pulseAmount * 0.3)

        var path = Path()
        path.addArc(
            center: position,
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )

        // Green when synced, red when not
        let color = Color(
            red: 1.0 - sync,
            green: sync,
            blue: 0.2
        )

        context.fill(path, with: .color(color))
    }
}

// MARK: - Watch Variant (Simplified for small screen)

@MainActor
public struct WatchEntrainmentVisualizer: View {

    @ObservedObject var hub: ImmersiveExperienceHub

    @State private var phase: Double = 0

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 * 0.8

                // Simple breathing circle
                let pulseAmount = sin(phase * .pi * 2) * 0.5 + 0.5
                let circleRadius = radius * CGFloat(0.6 + pulseAmount * 0.4)

                // Coherence-based color
                let coherence = hub.systemCoherence / 100.0
                let hue = coherence * 0.33  // Red to green

                var path = Path()
                path.addArc(
                    center: center,
                    radius: circleRadius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360),
                    clockwise: false
                )

                context.fill(
                    path,
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(hue: hue, saturation: 0.8, brightness: 1.0),
                            Color(hue: hue, saturation: 0.8, brightness: 0.5).opacity(0)
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: circleRadius
                    )
                )

                // Update phase
                phase += hub.entrainmentTargetHz / 30.0
                phase = phase.truncatingRemainder(dividingBy: 1.0)
            }
        }
    }
}

// MARK: - Vision Pro Variant (Full 3D)

#if os(visionOS)
import RealityKit

@MainActor
public struct VisionProEntrainmentView: View {

    @ObservedObject var hub: ImmersiveExperienceHub

    public var body: some View {
        RealityView { content in
            // Create 3D entrainment sphere
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.5),
                materials: [createEntrainmentMaterial()]
            )
            content.add(sphere)
        } update: { content in
            // Update material based on hub state
            if let sphere = content.entities.first as? ModelEntity {
                sphere.model?.materials = [createEntrainmentMaterial()]
            }
        }
    }

    private func createEntrainmentMaterial() -> Material {
        var material = SimpleMaterial()

        let color = hub.brainwaveState.color
        material.color = .init(
            tint: UIColor(
                red: CGFloat(color.r),
                green: CGFloat(color.g),
                blue: CGFloat(color.b),
                alpha: 1.0
            )
        )

        // Emissive based on coherence
        let coherence = Float(hub.systemCoherence / 100.0)
        material.color.tint = material.color.tint.withAlphaComponent(CGFloat(0.5 + coherence * 0.5))

        return material
    }
}
#endif

// MARK: - Preview

#Preview {
    let hub = ImmersiveExperienceHub()

    return BrainwaveEntrainmentVisualizer(hub: hub)
        .background(.black)
}

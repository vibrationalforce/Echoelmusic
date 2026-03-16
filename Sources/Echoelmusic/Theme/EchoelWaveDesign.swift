#if canImport(SwiftUI)
import SwiftUI

// MARK: - Echoelmusic Wave Design System
// Brand visual identity: EKG waveform mark, echo rings, heart pulse dot.
// Derived from echoelmusic.com SVG mark — monochrome, science-first.
//
// Usage:
//   EchoelWaveformMark()                           — standalone brand mark
//   EchoelWaveformMark(bioCoherence: 0.8)          — bio-reactive color
//   WaveDivider()                                   — section separator
//   EchoRingsView(pulsePhase: phase)               — animated rings
//   AmbientGlowBackground()                        — subtle radial glow

// MARK: - Waveform Shape (Brand Mark)

/// The Echoelmusic waveform — EKG-like heartbeat path from brand SVG.
/// Renders the signature waveform that appears in the logo and OG image.
/// Path normalized to unit rect (0...1), scaled to any size.
public struct EchoelWaveformShape: Shape {

    public func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let midY = h * 0.5

        // Scale factors from SVG viewBox 0-200 to rect
        func x(_ v: CGFloat) -> CGFloat { (v / 200.0) * w }
        func y(_ v: CGFloat) -> CGFloat { (v / 200.0) * h }

        var path = Path()

        // Flatline entry
        path.move(to: CGPoint(x: x(15), y: midY))
        path.addLine(to: CGPoint(x: x(48), y: midY))

        // QRS complex (the sharp heartbeat spike)
        path.addLine(to: CGPoint(x: x(60), y: y(62)))   // R-wave up
        path.addLine(to: CGPoint(x: x(72), y: y(136)))   // S-wave down
        path.addLine(to: CGPoint(x: x(82), y: y(76)))    // Recovery

        // ST segment + T-wave (smooth curve back to baseline)
        path.addCurve(
            to: CGPoint(x: x(100), y: midY),
            control1: CGPoint(x: x(86), y: y(88)),
            control2: CGPoint(x: x(92), y: midY)
        )

        // Secondary undulation
        path.addLine(to: CGPoint(x: x(110), y: midY))
        path.addCurve(
            to: CGPoint(x: x(130), y: y(78)),
            control1: CGPoint(x: x(116), y: midY),
            control2: CGPoint(x: x(122), y: y(78))
        )
        path.addCurve(
            to: CGPoint(x: x(148), y: midY),
            control1: CGPoint(x: x(138), y: y(78)),
            control2: CGPoint(x: x(142), y: midY)
        )

        // Trailing ripple
        path.addCurve(
            to: CGPoint(x: x(164), y: y(120)),
            control1: CGPoint(x: x(154), y: midY),
            control2: CGPoint(x: x(158), y: y(120))
        )
        path.addCurve(
            to: CGPoint(x: x(185), y: midY),
            control1: CGPoint(x: x(168), y: y(120)),
            control2: CGPoint(x: x(172), y: y(104))
        )

        return path
    }
}

// MARK: - Waveform Mark (Composite Brand View)

/// Complete Echoelmusic brand mark: waveform + echo rings + heart pulse dot.
/// Bio-reactive: coherence level modulates color warmth and glow intensity.
public struct EchoelWaveformMark: View {

    /// Bio-coherence level (0-1). Nil = static monochrome.
    public var bioCoherence: Float?

    /// Whether to show the concentric echo rings behind the waveform
    public var showEchoRings: Bool

    /// Whether to animate the pulse dot
    public var animated: Bool

    @State private var pulseScale: CGFloat = 1.0

    public init(
        bioCoherence: Float? = nil,
        showEchoRings: Bool = true,
        animated: Bool = true
    ) {
        self.bioCoherence = bioCoherence
        self.showEchoRings = showEchoRings
        self.animated = animated
    }

    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                // Echo rings (concentric circles, decreasing opacity)
                if showEchoRings {
                    echoRings(size: size)
                }

                // Glow layer (soft blur behind waveform)
                EchoelWaveformShape()
                    .stroke(
                        waveformColor.opacity(0.3),
                        style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round, lineJoin: .round)
                    )
                    .blur(radius: size * 0.02)

                // Main waveform stroke
                EchoelWaveformShape()
                    .stroke(
                        waveformGradient,
                        style: StrokeStyle(lineWidth: size * 0.015, lineCap: .round, lineJoin: .round)
                    )

                // Crisp top layer
                EchoelWaveformShape()
                    .stroke(
                        waveformColor,
                        style: StrokeStyle(lineWidth: size * 0.01, lineCap: .round, lineJoin: .round)
                    )

                // Heart pulse dot at R-wave peak
                Circle()
                    .fill(waveformColor.opacity(0.9))
                    .frame(width: size * 0.04, height: size * 0.04)
                    .scaleEffect(pulseScale)
                    .position(
                        x: (60.0 / 200.0) * geo.size.width,
                        y: (62.0 / 200.0) * geo.size.height
                    )

                // Outer pulse ring
                Circle()
                    .fill(waveformColor.opacity(0.4))
                    .frame(width: size * 0.06, height: size * 0.06)
                    .scaleEffect(pulseScale * 1.2)
                    .position(
                        x: (60.0 / 200.0) * geo.size.width,
                        y: (62.0 / 200.0) * geo.size.height
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.3
            }
        }
    }

    // MARK: - Echo Rings

    private func echoRings(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(Color(white: 0.878).opacity(0.08), lineWidth: 0.5)
                .frame(width: size * 0.30, height: size * 0.30)

            Circle()
                .stroke(Color(white: 0.878).opacity(0.06), lineWidth: 0.4)
                .frame(width: size * 0.55, height: size * 0.55)

            Circle()
                .stroke(Color(white: 0.878).opacity(0.04), lineWidth: 0.3)
                .frame(width: size * 0.82, height: size * 0.82)
        }
        // Offset to center on waveform heart (not geometric center)
        .offset(x: -size * 0.04, y: 0)
    }

    // MARK: - Color Computation

    private var waveformColor: Color {
        guard let coherence = bioCoherence else {
            return Color(white: 0.878) // #E0E0E0 monochrome default
        }
        let c = CGFloat(max(0, min(1, coherence)))
        // Low coherence: cool gray → High coherence: warm white
        return Color(
            red: 0.878 + c * 0.122,      // → 1.0 at full coherence
            green: 0.878 + c * 0.05,      // slight warm shift
            blue: 0.878 - c * 0.1         // reduce blue for warmth
        )
    }

    private var waveformGradient: LinearGradient {
        LinearGradient(
            colors: [
                waveformColor.opacity(0.6),
                waveformColor,
                waveformColor.opacity(0.8),
                waveformColor.opacity(0.6)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Wave Divider

/// A subtle wave-shaped section divider.
/// Replaces flat Divider() with organic waveform rhythm.
public struct WaveDivider: View {

    public var amplitude: CGFloat
    public var frequency: CGFloat
    public var color: Color

    public init(
        amplitude: CGFloat = 3,
        frequency: CGFloat = 2,
        color: Color = Color(white: 0.878).opacity(0.08)
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.color = color
    }

    public var body: some View {
        WaveDividerShape(amplitude: amplitude, frequency: frequency)
            .stroke(color, lineWidth: 1)
            .frame(height: amplitude * 2 + 2)
    }
}

/// Shape for wave divider — sine wave path
private struct WaveDividerShape: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let step: CGFloat = 1.0

        path.move(to: CGPoint(x: 0, y: midY))

        var x: CGFloat = 0
        while x <= rect.width {
            let progress = x / rect.width
            let y = midY + sin(progress * .pi * 2 * frequency) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }

        return path
    }
}

// MARK: - Echo Rings View (Standalone)

/// Animated concentric echo rings — pulsing outward from center.
/// Bio-reactive: pulse rate follows heart rate when provided.
public struct EchoRingsView: View {

    /// Current pulse phase (0-1), typically driven by heart rate
    public var pulsePhase: CGFloat

    /// Number of rings
    public var ringCount: Int

    /// Base color
    public var color: Color

    @State private var animatedPhase: CGFloat = 0

    public init(
        pulsePhase: CGFloat = 0,
        ringCount: Int = 4,
        color: Color = Color(white: 0.878)
    ) {
        self.pulsePhase = pulsePhase
        self.ringCount = ringCount
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)

            ZStack {
                ForEach(0..<ringCount, id: \.self) { i in
                    let ringProgress = CGFloat(i) / CGFloat(ringCount)
                    let scale = 0.2 + ringProgress * 0.8 + animatedPhase * 0.1
                    let opacity = max(0, 0.12 - ringProgress * 0.03)

                    Circle()
                        .stroke(color.opacity(opacity), lineWidth: max(0.3, 1.0 - ringProgress * 0.2))
                        .frame(width: size * scale, height: size * scale)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: pulsePhase) { _, newPhase in
            withAnimation(.easeOut(duration: 0.3)) {
                animatedPhase = newPhase
            }
        }
    }
}

// MARK: - Ambient Glow Background

/// Subtle radial glow — matches echoelmusic.com ambient1/ambient2 divs.
/// Two soft white radial gradients at opposing corners, barely visible.
public struct AmbientGlowBackground: View {

    /// Intensity multiplier (0-1). Higher = more visible glow.
    public var intensity: CGFloat

    /// Bio-coherence for warm/cool tinting
    public var bioCoherence: Float?

    public init(intensity: CGFloat = 1.0, bioCoherence: Float? = nil) {
        self.intensity = intensity
        self.bioCoherence = bioCoherence
    }

    public var body: some View {
        ZStack {
            // Top-left ambient (website: ambient1)
            RadialGradient(
                colors: [
                    glowColor.opacity(0.03 * intensity),
                    Color.clear
                ],
                center: UnitPoint(x: -0.05, y: -0.1),
                startRadius: 0,
                endRadius: 400
            )

            // Bottom-right ambient (website: ambient2)
            RadialGradient(
                colors: [
                    glowColor.opacity(0.02 * intensity),
                    Color.clear
                ],
                center: UnitPoint(x: 1.05, y: 1.1),
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var glowColor: Color {
        guard let c = bioCoherence else {
            return .white
        }
        let coherence = CGFloat(max(0, min(1, c)))
        // Subtle warm shift at high coherence
        return Color(
            red: 1.0,
            green: 1.0 - coherence * 0.05,
            blue: 1.0 - coherence * 0.15
        )
    }
}

// MARK: - Wave Background Pattern

/// Repeating sine wave pattern for section backgrounds.
/// Extremely subtle — barely visible rhythm in the background.
public struct WaveBackgroundPattern: View {

    public var lineCount: Int
    public var color: Color
    public var animated: Bool

    @State private var phase: CGFloat = 0

    public init(
        lineCount: Int = 5,
        color: Color = Color(white: 0.878).opacity(0.03),
        animated: Bool = false
    ) {
        self.lineCount = lineCount
        self.color = color
        self.animated = animated
    }

    public var body: some View {
        Canvas { context, size in
            for i in 0..<lineCount {
                let yOffset = size.height * CGFloat(i + 1) / CGFloat(lineCount + 1)
                let amplitude: CGFloat = 4 + CGFloat(i) * 1.5
                let frequency: CGFloat = 1.5 + CGFloat(i) * 0.3

                var path = Path()
                path.move(to: CGPoint(x: 0, y: yOffset))

                var x: CGFloat = 0
                while x <= size.width {
                    let progress = x / size.width
                    let y = yOffset + sin((progress + phase) * .pi * 2 * frequency) * amplitude
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 2
                }

                context.stroke(path, with: .color(color), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard animated else { return }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
        }
    }
}

// MARK: - View Modifiers

/// Adds ambient glow background behind any view
public struct AmbientGlowModifier: ViewModifier {
    let intensity: CGFloat
    let bioCoherence: Float?

    public func body(content: Content) -> some View {
        content
            .background(AmbientGlowBackground(intensity: intensity, bioCoherence: bioCoherence))
    }
}

public extension View {
    /// Adds the Echoelmusic ambient glow background
    func echoelAmbientGlow(intensity: CGFloat = 1.0, bioCoherence: Float? = nil) -> some View {
        modifier(AmbientGlowModifier(intensity: intensity, bioCoherence: bioCoherence))
    }

    /// Adds subtle wave background pattern
    func echoelWaveBackground(
        lineCount: Int = 5,
        color: Color = Color(white: 0.878).opacity(0.03),
        animated: Bool = false
    ) -> some View {
        background(WaveBackgroundPattern(lineCount: lineCount, color: color, animated: animated))
    }
}
#endif

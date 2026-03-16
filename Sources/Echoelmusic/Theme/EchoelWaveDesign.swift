#if canImport(SwiftUI)
import SwiftUI

// MARK: - Echoelmusic Wave Design System
// Brand visual identity: "E" letter + 3 sine wave curves underneath.
// Derived from docs/app-icon.svg — monochrome, science-first.
//
// Usage:
//   EchoelWaveformMark()                           — standalone brand mark
//   EchoelWaveformMark(bioCoherence: 0.8)          — bio-reactive color
//   WaveDivider()                                   — section separator
//   EchoRingsView(pulsePhase: phase)               — animated rings
//   AmbientGlowBackground()                        — subtle radial glow

// MARK: - Brand Wave Shape

/// Three sine wave curves — the Echoelmusic brand mark waves.
/// Matches the 3 S-curves from docs/app-icon.svg (1024x1024 viewBox).
/// Each wave is a triple cubic bezier with ~55px amplitude.
public struct EchoelBrandWaveShape: Shape {

    /// Which wave index (0, 1, 2) — controls vertical position
    public var waveIndex: Int

    public init(waveIndex: Int = 0) {
        self.waveIndex = waveIndex
    }

    public func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height

        // SVG viewBox is 1024x1024
        // Waves span x: 245-779, y centers: 610, 710, 810
        // Normalize to rect
        func x(_ v: CGFloat) -> CGFloat { (v / 1024.0) * w }
        func y(_ v: CGFloat) -> CGFloat { (v / 1024.0) * h }

        // Y-center for this wave (610, 710, 810 in SVG space)
        let centerY: CGFloat = 610.0 + CGFloat(waveIndex) * 100.0

        var path = Path()

        // Triple S-curve matching SVG cubic beziers
        // M 245,centerY
        path.move(to: CGPoint(x: x(245), y: y(centerY)))

        // C 295,centerY-55  375,centerY-55  425,centerY
        path.addCurve(
            to: CGPoint(x: x(425), y: y(centerY)),
            control1: CGPoint(x: x(295), y: y(centerY - 55)),
            control2: CGPoint(x: x(375), y: y(centerY - 55))
        )

        // C 475,centerY+55  549,centerY+55  599,centerY
        path.addCurve(
            to: CGPoint(x: x(599), y: y(centerY)),
            control1: CGPoint(x: x(475), y: y(centerY + 55)),
            control2: CGPoint(x: x(549), y: y(centerY + 55))
        )

        // C 649,centerY-55  729,centerY-55  779,centerY
        path.addCurve(
            to: CGPoint(x: x(779), y: y(centerY)),
            control1: CGPoint(x: x(649), y: y(centerY - 55)),
            control2: CGPoint(x: x(729), y: y(centerY - 55))
        )

        return path
    }
}

// MARK: - Brand Mark (Composite View)

/// Complete Echoelmusic brand mark: "E" letter + 3 sine wave curves.
/// Matches docs/app-icon.svg. Bio-reactive: coherence modulates color warmth.
public struct EchoelWaveformMark: View {

    /// Bio-coherence level (0-1). Nil = static monochrome (#E0E0E0).
    public var bioCoherence: Float?

    /// Whether to animate wave glow
    public var animated: Bool

    /// Wave opacities matching SVG: 0.8, 0.4, 0.2
    private let waveOpacities: [CGFloat] = [0.8, 0.4, 0.2]

    @State private var glowPhase: CGFloat = 0

    public init(
        bioCoherence: Float? = nil,
        animated: Bool = true
    ) {
        self.bioCoherence = bioCoherence
        self.animated = animated
    }

    public var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let strokeWidth = max(2, size * 0.03)

            ZStack {
                // "E" letter — positioned in upper portion (matching SVG y=470/1024)
                Text("E")
                    .font(.system(size: size * 0.52, weight: .bold, design: .default))
                    .foregroundColor(brandColor)
                    .position(
                        x: geo.size.width * 0.5,
                        y: geo.size.height * 0.40
                    )

                // Three sine wave curves underneath
                ForEach(0..<3, id: \.self) { i in
                    // Soft layer (wider, lower opacity — no blur)
                    EchoelBrandWaveShape(waveIndex: i)
                        .stroke(
                            brandColor.opacity(waveOpacities[i] * 0.2),
                            style: StrokeStyle(lineWidth: strokeWidth * 1.5, lineCap: .round)
                        )

                    // Main stroke
                    EchoelBrandWaveShape(waveIndex: i)
                        .stroke(
                            brandColor.opacity(waveOpacities[i]),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowPhase = 1.0
            }
        }
    }

    // MARK: - Color Computation

    private var brandColor: Color {
        guard let coherence = bioCoherence else {
            return Color(white: 0.878) // #E0E0E0 monochrome default
        }
        let c = CGFloat(max(0, min(1, coherence)))
        // Low coherence: cool gray → High coherence: warm white
        return Color(
            red: 0.878 + c * 0.122,
            green: 0.878 + c * 0.05,
            blue: 0.878 - c * 0.1
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

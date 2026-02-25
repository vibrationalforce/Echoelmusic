import SwiftUI

// MARK: - Launch Screen — E + Wellen Animation

/// Animated launch screen: The letter "E" draws on stroke-by-stroke,
/// then wave rings pulse outward from center. Monochrome brand identity.
struct LaunchScreen: View {

    // Animation phases
    @State private var eStroke: CGFloat = 0       // 0→1: E letter draws on
    @State private var waveStroke: CGFloat = 0    // 0→1: waveform draws on
    @State private var ringScale: CGFloat = 0.3   // wave rings expand
    @State private var ringOpacity: Double = 0    // wave rings fade in then out
    @State private var textOpacity: Double = 0    // app name fades in
    @State private var dotsActive = false         // loading dots pulse
    @State private var breatheScale: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Background — true black
            EchoelBrand.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // E + Waves animation area
                ZStack {
                    // Expanding wave rings (behind the E)
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                EchoelBrand.primary.opacity(ringOpacity * (1.0 - Double(i) * 0.3)),
                                lineWidth: 1.5
                            )
                            .frame(
                                width: 140 + CGFloat(i) * 50,
                                height: 140 + CGFloat(i) * 50
                            )
                            .scaleEffect(ringScale)
                    }

                    // Animated "E" letter
                    ELetterShape()
                        .trim(from: 0, to: eStroke)
                        .stroke(
                            EchoelBrand.primary,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 60, height: 80)
                        .scaleEffect(breatheScale)

                    // Waveform extending from the E
                    LaunchWaveformShape()
                        .trim(from: 0, to: waveStroke)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    EchoelBrand.primary,
                                    EchoelBrand.primary.opacity(0.6),
                                    EchoelBrand.primary.opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 200, height: 60)
                        .offset(x: 60)
                        .scaleEffect(breatheScale)
                }
                .frame(height: 200)

                // App name — monochrome
                VStack(spacing: EchoelSpacing.sm) {
                    Text("ECHOELMUSIC")
                        .font(EchoelBrandFont.sectionTitle())
                        .tracking(6)
                        .foregroundColor(EchoelBrand.textPrimary)

                    Text("Create from Within")
                        .font(EchoelBrandFont.caption())
                        .tracking(2)
                        .foregroundColor(EchoelBrand.textSecondary)
                }
                .opacity(textOpacity)
                .padding(.top, EchoelSpacing.lg)

                Spacer()

                // Loading indicator — monochrome dots
                HStack(spacing: EchoelSpacing.sm) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(EchoelBrand.primary)
                            .frame(width: 6, height: 6)
                            .scaleEffect(dotsActive ? 1.0 : 0.5)
                            .opacity(dotsActive ? 1.0 : 0.3)
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: dotsActive
                            )
                    }
                }
                .padding(.bottom, EchoelSpacing.xxl)

                // Version
                Text("v1.0")
                    .font(EchoelBrandFont.label())
                    .foregroundColor(EchoelBrand.textDisabled)
                    .padding(.bottom, EchoelSpacing.lg)
            }
        }
        .onAppear {
            if reduceMotion {
                // Skip animations — show everything immediately
                eStroke = 1.0
                waveStroke = 1.0
                ringScale = 1.0
                ringOpacity = 0.15
                textOpacity = 1.0
                dotsActive = true
            } else {
                runAnimation()
            }
        }
    }

    private func runAnimation() {
        // Phase 1: E letter draws on (0.0s → 0.8s)
        withAnimation(.easeOut(duration: 0.8)) {
            eStroke = 1.0
        }

        // Phase 2: Wave rings expand from center (0.4s → 1.2s)
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            ringScale = 1.0
            ringOpacity = 0.25
        }

        // Phase 3: Waveform draws on from E (0.6s → 1.4s)
        withAnimation(.easeOut(duration: 0.8).delay(0.6)) {
            waveStroke = 1.0
        }

        // Phase 4: Rings fade to subtle glow (1.2s → 2.0s)
        withAnimation(.easeInOut(duration: 0.8).delay(1.2)) {
            ringOpacity = 0.08
        }

        // Phase 5: Text fades in (1.0s → 1.6s)
        withAnimation(.easeOut(duration: 0.6).delay(1.0)) {
            textOpacity = 1.0
        }

        // Phase 6: Loading dots start (1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dotsActive = true
        }

        // Phase 7: Subtle breathing loop on E + wave (1.5s onwards)
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(1.5)) {
            breatheScale = 1.02
        }
    }
}

// MARK: - E Letter Shape

/// The letter "E" drawn as a single continuous stroke path.
/// Designed to animate with .trim(from:to:) for a drawing-on effect.
struct ELetterShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        // Draw the E as one continuous stroke:
        // Start at top-right of top bar, go left, down the spine,
        // kick out for middle bar, back to spine, down, then bottom bar

        // Top bar: right → left
        path.move(to: CGPoint(x: w * 0.95, y: h * 0.0))
        path.addLine(to: CGPoint(x: w * 0.0, y: h * 0.0))

        // Spine: top → middle
        path.addLine(to: CGPoint(x: w * 0.0, y: h * 0.5))

        // Middle bar: left → right and back
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.0, y: h * 0.5))

        // Spine: middle → bottom
        path.addLine(to: CGPoint(x: w * 0.0, y: h * 1.0))

        // Bottom bar: left → right
        path.addLine(to: CGPoint(x: w * 0.95, y: h * 1.0))

        return path
    }
}

// MARK: - Launch Waveform Shape

/// Sine wave emanating rightward — represents audio waves flowing from the "E".
/// Single continuous path for .trim() animation.
struct LaunchWaveformShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let cy = h * 0.5
        var path = Path()

        path.move(to: CGPoint(x: 0, y: cy))

        // 3 sine wave cycles with decreasing amplitude (waves dissipating)
        let cycles = 3
        let segmentsPerCycle = 20
        let totalSegments = cycles * segmentsPerCycle

        for i in 0...totalSegments {
            let progress = CGFloat(i) / CGFloat(totalSegments)
            let x = progress * w

            // Amplitude decreases as waves travel outward
            let amplitude = h * 0.35 * (1.0 - progress * 0.7)
            let y = cy + sin(progress * CGFloat(cycles) * 2 * .pi) * amplitude

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

#if DEBUG
#Preview {
    LaunchScreen()
}
#endif

import SwiftUI

// MARK: - Launch Screen — E + Wellen Animation

/// Animated launch screen: The letter "E" draws on stroke-by-stroke,
/// then wave rings pulse outward from center. Monochrome brand identity.
///
/// All animations use `.task` (auto-cancelled on view unmount) instead of
/// DispatchQueue.main.asyncAfter to prevent state mutation after deallocation.
struct LaunchScreen: View {

    /// Initialization phase description from EchoelmusicApp
    var phase: String = ""
    /// Initialization progress 0.0-1.0 from EchoelmusicApp
    var progress: Double = 0

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

                // Initialization progress bar + phase label
                VStack(spacing: EchoelSpacing.sm) {
                    if !phase.isEmpty {
                        Text(phase)
                            .font(EchoelBrandFont.caption())
                            .foregroundColor(EchoelBrand.textSecondary)
                            .transition(.opacity)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(cornerRadius: 2)
                                .fill(EchoelBrand.textDisabled.opacity(0.2))
                                .frame(height: 3)

                            // Fill
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [EchoelBrand.primary, EchoelBrand.primary.opacity(0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(progress), height: 3)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 60)
                }
                .padding(.bottom, EchoelSpacing.md)

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
        // Use .task instead of .onAppear — auto-cancels when view unmounts,
        // preventing state mutation on deallocated view.
        .task {
            if reduceMotion {
                eStroke = 1.0
                waveStroke = 1.0
                ringScale = 1.0
                ringOpacity = 0.15
                textOpacity = 1.0
                dotsActive = true
            } else {
                await runAnimation()
            }
        }
    }

    /// Phased animation using Task.sleep for delays.
    /// Task is automatically cancelled when LaunchScreen unmounts
    /// (when coreSystemsReady becomes true), so no state mutation
    /// fires on a deallocated view.
    @MainActor
    private func runAnimation() async {
        // Phase 1: E letter draws on (0.0s → 0.8s)
        withAnimation(.easeOut(duration: 0.8)) {
            eStroke = 1.0
        }

        // Phase 2: Wave rings expand from center (0.4s delay)
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.8)) {
            ringScale = 1.0
            ringOpacity = 0.25
        }

        // Phase 3: Waveform draws on from E (0.2s after rings)
        try? await Task.sleep(nanoseconds: 200_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.8)) {
            waveStroke = 1.0
        }

        // Phase 4: Text fades in (0.4s after waveform)
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.6)) {
            textOpacity = 1.0
        }

        // Phase 5: Loading dots start + rings fade to subtle glow
        try? await Task.sleep(nanoseconds: 200_000_000)
        guard !Task.isCancelled else { return }
        dotsActive = true
        withAnimation(.easeInOut(duration: 0.8)) {
            ringOpacity = 0.08
        }

        // Phase 6: Subtle breathing loop on E + wave
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
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
        // Top bar right → left, spine down, middle bar out and back, spine down, bottom bar
        path.move(to: CGPoint(x: w * 0.95, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.5))
        path.addLine(to: CGPoint(x: 0, y: h * 0.5))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w * 0.95, y: h))

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

        // 3 sine wave cycles with decreasing amplitude (waves dissipating)
        let cycles = 3
        let segmentsPerCycle = 20
        let totalSegments = cycles * segmentsPerCycle

        for i in 0...totalSegments {
            let progress = CGFloat(i) / CGFloat(totalSegments)
            let x = progress * w
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

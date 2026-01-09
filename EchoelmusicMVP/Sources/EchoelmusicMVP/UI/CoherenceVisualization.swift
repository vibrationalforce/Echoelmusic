// CoherenceVisualization - Bio-Reactive Visual Display
// Animated visualization driven by heart coherence

import SwiftUI

// MARK: - Coherence Visualization

public struct CoherenceVisualization: View {
    let coherence: Double
    let heartRate: Double
    let isActive: Bool

    @State private var animationPhase: Double = 0
    @State private var pulseScale: Double = 1.0
    @State private var rotationAngle: Double = 0

    public init(coherence: Double, heartRate: Double, isActive: Bool) {
        self.coherence = coherence
        self.heartRate = heartRate
        self.isActive = isActive
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Outer glow rings
                ForEach(0..<3, id: \.self) { ring in
                    glowRing(index: ring, size: size)
                }

                // Main coherence circle
                mainCircle(size: size)

                // Inner particle ring
                particleRing(size: size)

                // Center coherence indicator
                centerIndicator(size: size)
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startAnimations()
            }
        }
    }

    // MARK: - Glow Rings

    private func glowRing(index: Int, size: CGFloat) -> some View {
        let ringSize = size * (0.6 + Double(index) * 0.15)
        let opacity = (0.3 - Double(index) * 0.08) * coherence
        let delay = Double(index) * 0.3

        return Circle()
            .stroke(
                coherenceGradient,
                lineWidth: 2
            )
            .frame(width: ringSize, height: ringSize)
            .opacity(opacity)
            .scaleEffect(pulseScale + Double(index) * 0.05)
            .animation(
                isActive
                    ? .easeInOut(duration: pulseDuration)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                    : .default,
                value: pulseScale
            )
    }

    // MARK: - Main Circle

    private func mainCircle(size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        coherenceColor.opacity(0.8),
                        coherenceColor.opacity(0.3),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.3
                )
            )
            .frame(width: size * 0.5, height: size * 0.5)
            .scaleEffect(pulseScale)
            .animation(
                isActive
                    ? .easeInOut(duration: pulseDuration)
                        .repeatForever(autoreverses: true)
                    : .default,
                value: pulseScale
            )
    }

    // MARK: - Particle Ring

    private func particleRing(size: CGFloat) -> some View {
        let particleCount = 12
        let ringRadius = size * 0.25

        return ZStack {
            ForEach(0..<particleCount, id: \.self) { i in
                let angle = (Double(i) / Double(particleCount)) * 2 * .pi + rotationAngle
                let x = cos(angle) * ringRadius
                let y = sin(angle) * ringRadius
                let particleSize = 4.0 + sin(animationPhase + Double(i)) * 2.0

                Circle()
                    .fill(coherenceColor)
                    .frame(width: particleSize, height: particleSize)
                    .offset(x: x, y: y)
                    .opacity(0.6 + sin(animationPhase + Double(i) * 0.5) * 0.4)
            }
        }
        .rotationEffect(.radians(rotationAngle))
        .animation(
            isActive
                ? .linear(duration: 10.0 / max(coherence, 0.3))
                    .repeatForever(autoreverses: false)
                : .default,
            value: rotationAngle
        )
    }

    // MARK: - Center Indicator

    private func centerIndicator(size: CGFloat) -> some View {
        VStack(spacing: 4) {
            // Coherence percentage
            Text("\(Int(coherence * 100))")
                .font(.system(size: size * 0.12, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Coherence label
            Text("COHERENCE")
                .font(.system(size: size * 0.03, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .tracking(2)
        }
    }

    // MARK: - Computed Properties

    private var coherenceColor: Color {
        if coherence > 0.7 {
            return Color(red: 0.2, green: 0.8, blue: 0.4) // Green
        } else if coherence > 0.4 {
            return Color(red: 0.3, green: 0.5, blue: 0.9) // Blue
        } else {
            return Color(red: 0.6, green: 0.3, blue: 0.8) // Purple
        }
    }

    private var coherenceGradient: LinearGradient {
        LinearGradient(
            colors: [
                coherenceColor,
                coherenceColor.opacity(0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var pulseDuration: Double {
        // Pulse synced to heart rate
        // 60 BPM = 1 second per beat
        60.0 / max(heartRate, 40)
    }

    // MARK: - Animations

    private func startAnimations() {
        guard isActive else { return }

        // Pulse animation (synced to heart rate)
        withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }

        // Rotation animation (speed based on coherence)
        withAnimation(.linear(duration: 10.0 / max(coherence, 0.3)).repeatForever(autoreverses: false)) {
            rotationAngle = .pi * 2
        }

        // Phase animation for particles
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if !isActive {
                timer.invalidate()
                return
            }
            animationPhase += 0.1
        }
    }
}

// MARK: - Breathing Guide Overlay

public struct BreathingGuideOverlay: View {
    @State private var breathPhase: Double = 0
    @State private var isInhaling: Bool = true

    let inhaleSeconds: Double = 4.0
    let holdSeconds: Double = 2.0
    let exhaleSeconds: Double = 6.0

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Breathing circle
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                .frame(width: 150, height: 150)
                .overlay(
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .scaleEffect(breathPhase)
                )

            // Instruction text
            Text(breathInstruction)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
        }
        .onAppear {
            startBreathingCycle()
        }
    }

    private var breathInstruction: String {
        if breathPhase < 0.5 {
            return "Breathe In..."
        } else if breathPhase > 0.9 {
            return "Hold..."
        } else {
            return "Breathe Out..."
        }
    }

    private func startBreathingCycle() {
        // Inhale
        withAnimation(.easeInOut(duration: inhaleSeconds)) {
            breathPhase = 1.0
        }

        // Hold, then exhale
        DispatchQueue.main.asyncAfter(deadline: .now() + inhaleSeconds + holdSeconds) {
            withAnimation(.easeInOut(duration: exhaleSeconds)) {
                breathPhase = 0.3
            }

            // Repeat cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + exhaleSeconds) {
                startBreathingCycle()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CoherenceVisualization_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                CoherenceVisualization(
                    coherence: 0.85,
                    heartRate: 65,
                    isActive: true
                )
                .frame(height: 300)

                CoherenceVisualization(
                    coherence: 0.45,
                    heartRate: 80,
                    isActive: true
                )
                .frame(height: 200)
            }
        }
    }
}
#endif

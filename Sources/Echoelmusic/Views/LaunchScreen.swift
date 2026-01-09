import SwiftUI

/// Launch Screen for Echoelmusic
/// Bio-reactive audio-visual platform
struct LaunchScreen: View {

    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5

    var body: some View {
        ZStack {
            // Background gradient
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: VaporwaveSpacing.xl) {
                Spacer()

                // Logo/Icon area
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    VaporwaveColors.neonCyan.opacity(glowOpacity),
                                    VaporwaveColors.neonPink.opacity(glowOpacity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale)

                    // Inner circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    VaporwaveColors.neonCyan.opacity(0.3),
                                    VaporwaveColors.neonPink.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    // Icon
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [VaporwaveColors.neonCyan, VaporwaveColors.neonPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                }

                // App name
                VStack(spacing: VaporwaveSpacing.sm) {
                    Text("ECHOELMUSIC")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .tracking(6)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [VaporwaveColors.neonCyan, VaporwaveColors.neonPink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Bio-Reactive Audio-Visual")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(2)
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                Spacer()

                // Loading indicator
                HStack(spacing: VaporwaveSpacing.sm) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(VaporwaveColors.neonCyan)
                            .frame(width: 8, height: 8)
                            .scaleEffect(isAnimating ? 1.0 : 0.5)
                            .opacity(isAnimating ? 1.0 : 0.3)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: isAnimating
                            )
                    }
                }
                .padding(.bottom, VaporwaveSpacing.xxl)

                // Version
                Text("v1.0")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(VaporwaveColors.textTertiary.opacity(0.5))
                    .padding(.bottom, VaporwaveSpacing.lg)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
                pulseScale = 1.1
                glowOpacity = 0.8
            }
        }
    }
}

#if DEBUG
#Preview {
    LaunchScreen()
}
#endif

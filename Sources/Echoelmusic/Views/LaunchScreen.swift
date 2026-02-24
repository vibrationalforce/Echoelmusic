import SwiftUI

/// Launch Screen for Echoelmusic — Monochrome Corporate Identity
/// True black + gray, Atkinson Hyperlegible, E + Waves logo
struct LaunchScreen: View {

    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var logoOpacity: Double = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Background — true black
            EchoelBrand.bgDeep
                .ignoresSafeArea()

            VStack(spacing: EchoelSpacing.xl) {
                Spacer()

                // Logo — scaled-down AppIconView (E + Waves)
                AppIconView(size: 140)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .opacity(logoOpacity)
                    .scaleEffect(pulseScale)

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
                .opacity(logoOpacity)

                Spacer()

                // Loading indicator — monochrome dots
                HStack(spacing: EchoelSpacing.sm) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(EchoelBrand.primary)
                            .frame(width: 6, height: 6)
                            .scaleEffect(isAnimating ? 1.0 : 0.5)
                            .opacity(isAnimating ? 1.0 : 0.3)
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                                value: isAnimating
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
                isAnimating = true
                pulseScale = 1.0
                logoOpacity = 1.0
            } else {
                // Fade in logo
                withAnimation(.easeOut(duration: 0.8)) {
                    logoOpacity = 1.0
                }
                // Subtle pulse
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isAnimating = true
                    pulseScale = 1.02
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    LaunchScreen()
}
#endif

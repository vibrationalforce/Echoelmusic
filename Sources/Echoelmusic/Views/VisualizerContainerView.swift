import SwiftUI

// MARK: - Visualizer Container View
// Integration der Unified Visual Engine in die VaporwavePalace UI
// "Flüssiges Licht für deine Musik"

struct VisualizerContainerView: View {

    // MARK: - Environment

    @ObservedObject var visualEngine: UnifiedVisualSoundEngine
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var audioEngine: AudioEngine

    // MARK: - State

    @State private var showModeSelector = false
    @State private var isFullscreen = false
    @Binding var isActive: Bool

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Main Visualizer
                UnifiedVisualizer(engine: visualEngine)
                    .ignoresSafeArea(isFullscreen ? .all : [])

                // Overlay UI (hidden in fullscreen)
                if !isFullscreen {
                    overlayUI(size: geo.size)
                }

                // Mode Selector Sheet
                if showModeSelector {
                    modeSelectorOverlay
                }
            }
            .onTapGesture(count: 2) {
                withAnimation(VaporwaveAnimation.smooth) {
                    isFullscreen.toggle()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            // Horizontal swipe - change mode
                            let modes = UnifiedVisualSoundEngine.VisualMode.allCases
                            if let currentIndex = modes.firstIndex(of: visualEngine.currentMode) {
                                let newIndex = value.translation.width > 0
                                    ? (currentIndex - 1 + modes.count) % modes.count
                                    : (currentIndex + 1) % modes.count
                                withAnimation(VaporwaveAnimation.smooth) {
                                    visualEngine.currentMode = modes[newIndex]
                                }
                                impactFeedback(.light)
                            }
                        }
                    }
            )
        }
        .onAppear {
            connectEngines()
        }
    }

    // MARK: - Overlay UI

    @ViewBuilder
    private func overlayUI(size: CGSize) -> some View {
        VStack {
            // Top bar
            HStack {
                // Mode indicator
                Button(action: {
                    withAnimation(VaporwaveAnimation.smooth) {
                        showModeSelector.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: visualEngine.currentMode.icon)
                            .font(.system(size: 16))

                        Text(visualEngine.currentMode.rawValue.uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .tracking(2)
                    }
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.5))
                    )
                    .overlay(
                        Capsule()
                            .stroke(VaporwaveColors.neonCyan.opacity(0.3), lineWidth: 1)
                    )
                }

                Spacer()

                // Fullscreen toggle
                Button(action: {
                    withAnimation(VaporwaveAnimation.smooth) {
                        isFullscreen = true
                    }
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 16))
                        .foregroundColor(VaporwaveColors.textSecondary)
                        .padding(12)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
            }
            .padding(.horizontal, VaporwaveSpacing.lg)
            .padding(.top, VaporwaveSpacing.lg)

            Spacer()

            // Bottom info bar
            HStack(spacing: VaporwaveSpacing.lg) {
                // Audio level
                VStack(spacing: 4) {
                    LevelMeter(level: CGFloat(visualEngine.visualParams.audioLevel))
                        .frame(width: 6, height: 40)

                    Text("AUDIO")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                // Bass
                VStack(spacing: 4) {
                    LevelMeter(level: CGFloat(visualEngine.visualParams.bassLevel), color: VaporwaveColors.neonPink)
                        .frame(width: 6, height: 40)

                    Text("BASS")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                // Mid
                VStack(spacing: 4) {
                    LevelMeter(level: CGFloat(visualEngine.visualParams.midLevel), color: VaporwaveColors.neonPurple)
                        .frame(width: 6, height: 40)

                    Text("MID")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                // High
                VStack(spacing: 4) {
                    LevelMeter(level: CGFloat(visualEngine.visualParams.highLevel), color: VaporwaveColors.neonCyan)
                        .frame(width: 6, height: 40)

                    Text("HIGH")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                Spacer()

                // Coherence indicator
                VStack(spacing: 4) {
                    CoherenceRing(coherence: CGFloat(visualEngine.visualParams.coherence))
                        .frame(width: 40, height: 40)

                    Text("FLOW")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                // Beat indicator
                Circle()
                    .fill(visualEngine.beatDetected ? VaporwaveColors.neonPink : Color.white.opacity(0.2))
                    .frame(width: 12, height: 12)
                    .neonGlow(color: visualEngine.beatDetected ? VaporwaveColors.neonPink : .clear, radius: 10)
                    .animation(.easeOut(duration: 0.1), value: visualEngine.beatDetected)
            }
            .padding(.horizontal, VaporwaveSpacing.lg)
            .padding(.vertical, VaporwaveSpacing.md)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    // MARK: - Mode Selector Overlay

    private var modeSelectorOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(VaporwaveAnimation.smooth) {
                        showModeSelector = false
                    }
                }

            VStack(spacing: VaporwaveSpacing.lg) {
                // Title
                Text("VISUALIZATION MODE")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .tracking(4)

                // Mode grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: VaporwaveSpacing.md) {
                    ForEach(UnifiedVisualSoundEngine.VisualMode.allCases) { mode in
                        ModeButton(
                            mode: mode,
                            isSelected: visualEngine.currentMode == mode
                        ) {
                            withAnimation(VaporwaveAnimation.smooth) {
                                visualEngine.currentMode = mode
                                showModeSelector = false
                            }
                            impactFeedback(.medium)
                        }
                    }
                }
                .padding(.horizontal, VaporwaveSpacing.lg)

                // Close button
                Button(action: {
                    withAnimation(VaporwaveAnimation.smooth) {
                        showModeSelector = false
                    }
                }) {
                    Text("CLOSE")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VaporwaveColors.textSecondary)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .padding(.top, VaporwaveSpacing.md)
            }
            .padding(VaporwaveSpacing.xl)
        }
        .transition(.opacity)
    }

    // MARK: - Engine Connection

    private func connectEngines() {
        // WICHTIG: Route bio data durch UniversalCore - verteilt automatisch an ALLE Systeme
        // (VisualEngine, SelfHealingEngine, MultiPlatformBridge, VideoAIHub, etc.)
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            EchoelUniversalCore.shared.receiveBioData(
                heartRate: healthKitManager.heartRate,
                hrv: healthKitManager.hrvRMSSD,
                coherence: healthKitManager.hrvCoherence
            )
        }
    }

    // MARK: - Haptic Feedback

    private func impactFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()
    }
}

// MARK: - Mode Button

struct ModeButton: View {
    let mode: UnifiedVisualSoundEngine.VisualMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: mode.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? VaporwaveColors.neonCyan : VaporwaveColors.textSecondary)

                Text(mode.rawValue.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)
                    .tracking(1)

                Text(mode.description)
                    .font(.system(size: 8))
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(VaporwaveSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? VaporwaveColors.neonCyan.opacity(0.15) : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? VaporwaveColors.neonCyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .neonGlow(color: isSelected ? VaporwaveColors.neonCyan : .clear, radius: 10)
    }
}

// MARK: - Level Meter

struct LevelMeter: View {
    let level: CGFloat
    var color: Color = VaporwaveColors.neonCyan

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.1))

                // Level fill
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.5),
                                color
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: geo.size.height * min(level, 1.0))
            }
        }
    }
}

// MARK: - Coherence Ring

struct CoherenceRing: View {
    let coherence: CGFloat

    private var ringColor: Color {
        if coherence < 0.4 {
            return VaporwaveColors.coherenceLow
        } else if coherence < 0.6 {
            return VaporwaveColors.coherenceMedium
        } else {
            return VaporwaveColors.coherenceHigh
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 3)

            // Progress ring
            Circle()
                .trim(from: 0, to: coherence)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .neonGlow(color: ringColor, radius: 5)

            // Center value
            Text("\(Int(coherence * 100))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(ringColor)
        }
    }
}

// MARK: - Preview

#Preview {
    VisualizerContainerView(
        visualEngine: UnifiedVisualSoundEngine(),
        isActive: .constant(true)
    )
    .environmentObject(HealthKitManager())
    .environmentObject(AudioEngine())
}

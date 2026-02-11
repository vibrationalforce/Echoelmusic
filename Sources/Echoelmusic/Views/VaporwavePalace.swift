import SwiftUI

// MARK: - Vaporwave Palace
// Das Mutterschiff - Die Hauptansicht für Echoelmusic
// "Flüssiges Licht für deine Musik"

@MainActor
struct VaporwavePalace: View {

    // MARK: - Environment

    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var microphoneManager: MicrophoneManager

    // MARK: - State

    @State private var selectedMode: PalaceMode = .focus
    @State private var isActive = false
    @State private var showSettings = false
    @State private var showVisualizer = false
    @State private var pulseAnimation = false
    @State private var glowIntensity: CGFloat = 0.5

    // MARK: - Central Systems (VERBUNDEN MIT UNIVERSAL CORE)

    /// Verwendet die zentrale Visual Engine vom UniversalCore (nicht eigene Instanz!)
    @ObservedObject private var visualEngine = EchoelUniversalCore.shared.visualEngine

    /// System Status für UI-Anzeige
    @State private var systemStatus: EchoelUniversalCore.SystemStatus?

    /// Timer für Bio-Daten Updates (wird in onDisappear invalidiert)
    @State private var bioDataTimer: Timer?

    // MARK: - Modes

    enum PalaceMode: String, CaseIterable {
        case focus = "FOCUS"
        case create = "CREATE"
        case heal = "HEAL"
        case live = "LIVE"

        var icon: String {
            switch self {
            case .focus: return "brain.head.profile"
            case .create: return "waveform.circle"
            case .heal: return "heart.circle"
            case .live: return "dot.radiowaves.left.and.right"
            }
        }

        var color: Color {
            switch self {
            case .focus: return VaporwaveColors.neonCyan
            case .create: return VaporwaveColors.neonPurple
            case .heal: return VaporwaveColors.coherenceHigh
            case .live: return VaporwaveColors.neonPink
            }
        }

        var description: String {
            switch self {
            case .focus: return "Deep concentration with bio-synced audio"
            case .create: return "Music creation powered by your body"
            case .heal: return "Therapeutic frequencies for wellness"
            case .live: return "Performance mode with visual output"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            backgroundLayer

            // Content
            VStack(spacing: 0) {
                // Header
                headerSection

                Spacer()

                // Bio Metrics Circle
                bioMetricsCircle

                Spacer()

                // Mode Selector
                modeSelector

                // Main Action Button
                mainActionButton

                // Status Bar
                statusBar
            }
            .padding(.horizontal, VaporwaveSpacing.lg)
        }
        .onAppear {
            startAnimations()
        }
        .sheet(isPresented: $showSettings) {
            VaporwaveSettings()
        }
        .fullScreenCover(isPresented: $showVisualizer) {
            VisualizerContainerView(
                visualEngine: visualEngine,
                isActive: $isActive
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        ZStack {
            // Base gradient
            VaporwaveGradients.background
                .ignoresSafeArea()

            // Animated grid (Vaporwave aesthetic)
            GeometryReader { geo in
                VaporwaveGrid()
                    .opacity(0.3)
            }

            // Glow orb (responds to coherence)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            selectedMode.color.opacity(glowIntensity * 0.5),
                            selectedMode.color.opacity(0)
                        ]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .blur(radius: 50)
                .offset(y: -100)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: VaporwaveSpacing.xs) {
            HStack {
                // Logo
                Text("ECHOELMUSIC")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .neonGlow(color: selectedMode.color, radius: pulseAnimation ? 20 : 10)

                Spacer()

                // Settings button
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(VaporwaveColors.textSecondary)
                }
            }

            // Tagline
            Text("Flüssiges Licht")
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textTertiary)
                .tracking(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, VaporwaveSpacing.xl)
    }

    // MARK: - Bio Metrics Circle

    private var bioMetricsCircle: some View {
        ZStack {
            // Outer ring (coherence indicator)
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            coherenceColor.opacity(0.1),
                            coherenceColor,
                            coherenceColor.opacity(0.1)
                        ]),
                        center: .center
                    ),
                    lineWidth: 4
                )
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(pulseAnimation ? 360 : 0))
                .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: pulseAnimation)

            // Middle ring (HRV)
            Circle()
                .stroke(VaporwaveColors.hrv.opacity(0.3), lineWidth: 2)
                .frame(width: 240, height: 240)

            // Inner content - Mini visualizer when active, bio data when inactive
            if isActive {
                // Mini visualizer preview
                Circle()
                    .fill(Color.black)
                    .frame(width: 200, height: 200)
                    .overlay(
                        UnifiedVisualizer(engine: visualEngine)
                            .clipShape(Circle())
                    )
                    .overlay(
                        Circle()
                            .stroke(selectedMode.color.opacity(0.5), lineWidth: 2)
                    )
                    .neonGlow(color: selectedMode.color, radius: 15)
                    .onTapGesture {
                        showVisualizer = true
                    }
                    .overlay(
                        VStack {
                            Spacer()
                            Text("TAP TO EXPAND")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(VaporwaveColors.textTertiary)
                                .tracking(2)
                                .padding(.bottom, 20)
                        }
                    )
            } else {
                // Inner glow
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                selectedMode.color.opacity(0.3),
                                selectedMode.color.opacity(0.1),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                    .animation(VaporwaveAnimation.breathing, value: pulseAnimation)

                // Bio data display
                VStack(spacing: VaporwaveSpacing.md) {
                    // Heart Rate
                    VStack(spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(healthKitManager.heartRate))")
                                .font(VaporwaveTypography.data())
                                .foregroundColor(VaporwaveColors.heartRate)
                                .neonGlow(color: VaporwaveColors.heartRate, radius: 8)

                            Image(systemName: "heart.fill")
                                .font(.system(size: 16))
                                .foregroundColor(VaporwaveColors.heartRate)
                                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                                .animation(VaporwaveAnimation.pulse, value: pulseAnimation)
                        }

                        Text("BPM")
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }

                    // Coherence Score
                    VStack(spacing: 2) {
                        Text("\(Int(healthKitManager.hrvCoherence))")
                            .font(.system(size: 56, weight: .ultraLight, design: .rounded))
                            .foregroundColor(coherenceColor)
                            .neonGlow(color: coherenceColor, radius: 15)

                        Text(coherenceLabel)
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(coherenceColor)
                            .tracking(2)
                    }

                    // HRV
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", healthKitManager.hrvRMSSD))
                            .font(VaporwaveTypography.dataSmall())
                            .foregroundColor(VaporwaveColors.hrv)

                        Text("HRV ms")
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Mode buttons
            HStack(spacing: VaporwaveSpacing.sm) {
                ForEach(PalaceMode.allCases, id: \.self) { mode in
                    Button(action: { withAnimation(VaporwaveAnimation.smooth) { selectedMode = mode } }) {
                        VStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 24))

                            Text(mode.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, VaporwaveSpacing.md)
                        .foregroundColor(selectedMode == mode ? mode.color : VaporwaveColors.textTertiary)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMode == mode ? mode.color.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMode == mode ? mode.color.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    }
                    .neonGlow(color: selectedMode == mode ? mode.color : .clear, radius: 10)
                }
            }

            // Mode description
            Text(selectedMode.description)
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, VaporwaveSpacing.xs)
        }
        .padding(.horizontal, VaporwaveSpacing.sm)
    }

    // MARK: - Main Action Button

    private var mainActionButton: some View {
        Button(action: toggleActive) {
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(selectedMode.color.opacity(isActive ? 0.5 : 0.2), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(isActive ? 1.2 : 1.0)
                    .animation(isActive ? VaporwaveAnimation.pulse : .default, value: isActive)

                // Main button
                Circle()
                    .fill(isActive ? selectedMode.color : VaporwaveColors.deepBlack)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(selectedMode.color, lineWidth: 2)
                    )

                // Icon
                Image(systemName: isActive ? "stop.fill" : "play.fill")
                    .font(.system(size: 36))
                    .foregroundColor(isActive ? VaporwaveColors.deepBlack : selectedMode.color)
            }
            .neonGlow(color: isActive ? selectedMode.color : .clear, radius: 25)
        }
        .padding(.vertical, VaporwaveSpacing.xl)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(healthKitManager.isAuthorized ? VaporwaveColors.success : VaporwaveColors.warning)
                    .frame(width: 8, height: 8)

                Text(healthKitManager.isAuthorized ? "Watch Connected" : "Connect Watch")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            Spacer()

            // Mode indicator
            Text(selectedMode.rawValue)
                .font(VaporwaveTypography.label())
                .foregroundColor(selectedMode.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(selectedMode.color.opacity(0.15))
                )
        }
        .padding(.bottom, VaporwaveSpacing.xl)
    }

    // MARK: - Computed Properties

    private var coherenceColor: Color {
        let score = healthKitManager.hrvCoherence
        if score < 40 {
            return VaporwaveColors.coherenceLow
        } else if score < 60 {
            return VaporwaveColors.coherenceMedium
        } else {
            return VaporwaveColors.coherenceHigh
        }
    }

    private var coherenceLabel: String {
        let score = healthKitManager.hrvCoherence
        if score < 40 {
            return "FINDING FLOW"
        } else if score < 60 {
            return "BUILDING"
        } else {
            return "IN THE ZONE"
        }
    }

    // MARK: - Actions

    private func toggleActive() {
        withAnimation(VaporwaveAnimation.smooth) {
            isActive.toggle()
        }

        if isActive {
            audioEngine.start()
            if healthKitManager.isAuthorized {
                healthKitManager.startMonitoring()
            }

            // Set initial visualization mode based on palace mode
            visualEngine.currentMode = mapPalaceModeToVisualMode(selectedMode)
        } else {
            audioEngine.stop()
            healthKitManager.stopMonitoring()
        }

        // Haptic feedback
        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: isActive ? .heavy : .medium)
        impact.impactOccurred()
        #endif
    }

    private func startAnimations() {
        pulseAnimation = true

        // Invalidiere vorherigen Timer falls vorhanden (Memory Leak Prevention)
        bioDataTimer?.invalidate()

        // Update glow and feed bio data through UNIVERSAL CORE (not directly to visualEngine!)
        // Timer wird gespeichert für sauberes Cleanup in stopAnimations()
        bioDataTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak healthKitManager] _ in
            guard let hkManager = healthKitManager else { return }

            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.5)) {
                    glowIntensity = CGFloat(hkManager.hrvCoherence / 100.0)
                }

                // Route Bio-Daten durch UniversalCore - verteilt automatisch an ALLE Systeme
                EchoelUniversalCore.shared.receiveBioData(
                    heartRate: hkManager.heartRate,
                    hrv: hkManager.hrvRMSSD,
                    coherence: hkManager.hrvCoherence
                )

                // Update System Status für UI
                systemStatus = EchoelUniversalCore.shared.getSystemStatus()
            }
        }
    }

    private func stopAnimations() {
        pulseAnimation = false
        bioDataTimer?.invalidate()
        bioDataTimer = nil
    }

    // MARK: - Mode Mapping

    /// Maps Palace mode to default visualization mode
    private func mapPalaceModeToVisualMode(_ palaceMode: PalaceMode) -> UnifiedVisualSoundEngine.VisualMode {
        switch palaceMode {
        case .focus:
            return .liquidLight
        case .create:
            return .vaporwave
        case .heal:
            return .mandala
        case .live:
            return .spectrum
        }
    }
}

// MARK: - Vaporwave Grid (Aesthetic Background)

struct VaporwaveGrid: View {
    @State private var offset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let gridSpacing: CGFloat = 40
                let lineWidth: CGFloat = 0.5

                // Horizontal lines with perspective
                for i in 0..<Int(size.height / gridSpacing) + 10 {
                    let y = CGFloat(i) * gridSpacing + offset.truncatingRemainder(dividingBy: gridSpacing)
                    let opacity = 1.0 - (y / size.height)

                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))

                    context.stroke(
                        path,
                        with: .color(VaporwaveColors.neonPink.opacity(opacity * 0.3)),
                        lineWidth: lineWidth
                    )
                }

                // Vertical lines
                let centerX = size.width / 2
                for i in -10..<11 {
                    let x = centerX + CGFloat(i) * gridSpacing
                    let opacity = 1.0 - abs(CGFloat(i)) / 10.0

                    var path = Path()
                    path.move(to: CGPoint(x: x, y: size.height * 0.5))
                    path.addLine(to: CGPoint(x: centerX + CGFloat(i) * gridSpacing * 3, y: size.height))

                    context.stroke(
                        path,
                        with: .color(VaporwaveColors.neonCyan.opacity(opacity * 0.2)),
                        lineWidth: lineWidth
                    )
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                offset = 40
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VaporwavePalace()
        .environmentObject(HealthKitManager())
        .environmentObject(AudioEngine())
        .environmentObject(MicrophoneManager())
}
#endif

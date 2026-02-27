import SwiftUI

// MARK: - Echoel Palace
// Das Mutterschiff - Die Hauptansicht für Echoelmusic
// "Create from Within" — E + Wellen, Schwarz mit Grautönen

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
    @State private var wavePhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Central Systems

    /// Visual Engine — accessed lazily via onAppear to avoid triggering
    /// a heavyweight singleton cascade during view init (which blocks MainActor).
    @State private var visualEngine: UnifiedVisualSoundEngine?

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
            case .focus: return EchoelBrand.sky
            case .create: return EchoelBrand.primary
            case .heal: return EchoelBrand.emerald
            case .live: return EchoelBrand.accent
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
            // Background — true black
            backgroundLayer

            // Content
            VStack(spacing: 0) {
                // Header
                headerSection

                Spacer()

                // Bio Metrics Circle with E motif
                bioMetricsCircle

                Spacer()

                // Mode Selector
                modeSelector

                // Main Action Button
                mainActionButton

                // Status Bar
                statusBar
            }
            .padding(.horizontal, EchoelSpacing.lg)
        }
        .onAppear {
            // Lazy-init: attach visual engine only when view appears on screen
            if visualEngine == nil {
                visualEngine = EchoelUniversalCore.shared.visualEngine
            }
            startAnimations()
        }
        .sheet(isPresented: $showSettings) {
            VaporwaveSettings()
        }
        .fullScreenCover(isPresented: $showVisualizer) {
            if let engine = visualEngine {
                VisualizerContainerView(
                    visualEngine: engine,
                    isActive: $isActive
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        ZStack {
            // True black base
            EchoelBrand.bgDeep
                .ignoresSafeArea()

            // Subtle wave pattern (monochrome)
            GeometryReader { geo in
                Canvas { context, size in
                    let lineCount = 5
                    for i in 0..<lineCount {
                        let progress = CGFloat(i) / CGFloat(lineCount - 1)
                        let y = size.height * (0.3 + progress * 0.4)
                        let opacity = 0.03 + (1.0 - abs(progress - 0.5) * 2) * 0.04

                        var path = Path()
                        let segments = 60
                        for seg in 0...segments {
                            let x = CGFloat(seg) / CGFloat(segments) * size.width
                            let wave = sin((x / size.width) * .pi * 3 + wavePhase + CGFloat(i) * 0.8) * 15 * (1.0 - progress * 0.5)
                            let point = CGPoint(x: x, y: y + wave)
                            if seg == 0 {
                                path.move(to: point)
                            } else {
                                path.addLine(to: point)
                            }
                        }

                        context.stroke(
                            path,
                            with: .color(EchoelBrand.primary.opacity(opacity)),
                            lineWidth: 0.8
                        )
                    }
                }
            }

            // Subtle coherence glow orb (monochrome)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            EchoelBrand.primary.opacity(glowIntensity * 0.08),
                            EchoelBrand.primary.opacity(0)
                        ]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .blur(radius: 60)
                .offset(y: -100)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: EchoelSpacing.xs) {
            HStack {
                // E + Waveform Logo (inline)
                HStack(spacing: EchoelSpacing.sm) {
                    // Small E letter
                    ELetterShape()
                        .stroke(
                            EchoelBrand.primary,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 18, height: 24)

                    Text("ECHOELMUSIC")
                        .font(EchoelBrandFont.sectionTitle())
                        .foregroundColor(EchoelBrand.textPrimary)
                        .tracking(4)
                }

                Spacer()

                // Settings button
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundColor(EchoelBrand.textSecondary)
                }
            }

            // Tagline
            Text("Create from Within")
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textTertiary)
                .tracking(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, EchoelSpacing.xl)
    }

    // MARK: - Bio Metrics Circle

    private var bioMetricsCircle: some View {
        ZStack {
            // Outer ring (coherence indicator) — monochrome with functional color
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            coherenceColor.opacity(0.05),
                            coherenceColor.opacity(0.4),
                            coherenceColor.opacity(0.05)
                        ]),
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(pulseAnimation && !reduceMotion ? 360 : 0))
                .animation(reduceMotion ? nil : .linear(duration: 12).repeatForever(autoreverses: false), value: pulseAnimation)

            // Middle ring (HRV) — subtle gray
            Circle()
                .stroke(EchoelBrand.primary.opacity(0.1), lineWidth: 1)
                .frame(width: 240, height: 240)

            // Wave rings emanating from center (E motif)
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        EchoelBrand.primary.opacity(pulseAnimation ? 0.03 : 0.06),
                        lineWidth: 0.5
                    )
                    .frame(
                        width: 160 + CGFloat(i) * 40,
                        height: 160 + CGFloat(i) * 40
                    )
                    .scaleEffect(pulseAnimation ? 1.05 : 0.95)
                    .animation(
                        reduceMotion ? nil :
                            .easeInOut(duration: 3.0 + Double(i) * 0.5)
                            .repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
            }

            // Inner content
            if isActive, let engine = visualEngine {
                // Mini visualizer preview
                Circle()
                    .fill(EchoelBrand.bgDeep)
                    .frame(width: 200, height: 200)
                    .overlay(
                        UnifiedVisualizer(engine: engine)
                            .clipShape(Circle())
                    )
                    .overlay(
                        Circle()
                            .stroke(EchoelBrand.primary.opacity(0.2), lineWidth: 1)
                    )
                    .echoelGlow(EchoelBrand.primary, radius: 8, intensity: 0.15)
                    .onTapGesture {
                        showVisualizer = true
                    }
                    .overlay(
                        VStack {
                            Spacer()
                            Text("TAP TO EXPAND")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(EchoelBrand.textTertiary)
                                .tracking(2)
                                .padding(.bottom, 20)
                        }
                    )
            } else {
                // E letter in center (brand motif)
                ELetterShape()
                    .stroke(
                        EchoelBrand.primary.opacity(0.08),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 40, height: 54)
                    .scaleEffect(pulseAnimation ? 1.02 : 0.98)
                    .animation(
                        reduceMotion ? nil :
                            .easeInOut(duration: 4.0).repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )

                // Bio data display
                VStack(spacing: EchoelSpacing.md) {
                    // Heart Rate
                    VStack(spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(healthKitManager.heartRate))")
                                .font(EchoelBrandFont.data())
                                .foregroundColor(EchoelBrand.rose)

                            Image(systemName: "heart.fill")
                                .font(.system(size: 14))
                                .foregroundColor(EchoelBrand.rose)
                                .scaleEffect(pulseAnimation ? 1.15 : 1.0)
                                .animation(
                                    reduceMotion ? nil :
                                        .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                    value: pulseAnimation
                                )
                        }

                        Text("BPM")
                            .font(EchoelBrandFont.label())
                            .foregroundColor(EchoelBrand.textTertiary)
                    }

                    // Coherence Score
                    VStack(spacing: 2) {
                        Text("\(Int(healthKitManager.hrvCoherence))")
                            .font(.system(size: 52, weight: .ultraLight, design: .rounded))
                            .foregroundColor(coherenceColor)

                        Text(coherenceLabel)
                            .font(EchoelBrandFont.caption())
                            .foregroundColor(coherenceColor.opacity(0.8))
                            .tracking(3)
                    }

                    // HRV
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f", healthKitManager.hrvRMSSD))
                            .font(EchoelBrandFont.dataSmall())
                            .foregroundColor(EchoelBrand.emerald)

                        Text("HRV ms")
                            .font(EchoelBrandFont.label())
                            .foregroundColor(EchoelBrand.textTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(spacing: EchoelSpacing.sm) {
            // Mode buttons
            HStack(spacing: EchoelSpacing.sm) {
                ForEach(PalaceMode.allCases, id: \.self) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
                            selectedMode = mode
                        }
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 22))

                            Text(mode.rawValue)
                                .font(.system(size: 9, weight: .medium))
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, EchoelSpacing.md)
                        .foregroundColor(selectedMode == mode ? EchoelBrand.textPrimary : EchoelBrand.textTertiary)
                        .background(
                            RoundedRectangle(cornerRadius: EchoelRadius.md)
                                .fill(selectedMode == mode ? EchoelBrand.bgElevated : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoelRadius.md)
                                .stroke(
                                    selectedMode == mode ? EchoelBrand.borderActive : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }

            // Mode description
            Text(selectedMode.description)
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, EchoelSpacing.xs)
        }
        .padding(.horizontal, EchoelSpacing.sm)
    }

    // MARK: - Main Action Button

    private var mainActionButton: some View {
        Button(action: toggleActive) {
            ZStack {
                // Outer ring — subtle
                Circle()
                    .stroke(
                        EchoelBrand.primary.opacity(isActive ? 0.3 : 0.1),
                        lineWidth: 1.5
                    )
                    .frame(width: 110, height: 110)
                    .scaleEffect(isActive ? 1.15 : 1.0)
                    .animation(
                        isActive ?
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
                            : .default,
                        value: isActive
                    )

                // Main button
                Circle()
                    .fill(isActive ? EchoelBrand.primary : EchoelBrand.bgSurface)
                    .frame(width: 90, height: 90)
                    .overlay(
                        Circle()
                            .stroke(EchoelBrand.primary.opacity(0.4), lineWidth: 1.5)
                    )

                // Icon
                Image(systemName: isActive ? "stop.fill" : "play.fill")
                    .font(.system(size: 32))
                    .foregroundColor(isActive ? EchoelBrand.bgDeep : EchoelBrand.primary)
            }
            .echoelGlow(EchoelBrand.primary, radius: isActive ? 15 : 0, intensity: isActive ? 0.2 : 0)
        }
        .padding(.vertical, EchoelSpacing.xl)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(healthKitManager.isAuthorized ? EchoelBrand.success : EchoelBrand.warning)
                    .frame(width: 6, height: 6)

                Text(healthKitManager.isAuthorized ? "Watch Connected" : "Connect Watch")
                    .font(EchoelBrandFont.label())
                    .foregroundColor(EchoelBrand.textTertiary)
            }

            Spacer()

            // Mode indicator
            Text(selectedMode.rawValue)
                .font(EchoelBrandFont.label())
                .foregroundColor(EchoelBrand.textSecondary)
                .tracking(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(EchoelBrand.bgElevated)
                        .overlay(
                            Capsule()
                                .stroke(EchoelBrand.border, lineWidth: 1)
                        )
                )
        }
        .padding(.bottom, EchoelSpacing.xl)
    }

    // MARK: - Computed Properties

    private var coherenceColor: Color {
        let score = healthKitManager.hrvCoherence
        if score < 40 {
            return EchoelBrand.coherenceLow
        } else if score < 60 {
            return EchoelBrand.coherenceMedium
        } else {
            return EchoelBrand.coherenceHigh
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
        withAnimation(.easeInOut(duration: EchoelAnimation.smooth)) {
            isActive.toggle()
        }

        if isActive {
            audioEngine.start()
            healthKitManager.startMonitoring()

            // Set initial visualization mode based on palace mode
            visualEngine?.currentMode = mapPalaceModeToVisualMode(selectedMode)
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

        // Subtle wave animation
        if !reduceMotion {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }

        // Update glow and feed bio data through UNIVERSAL CORE
        bioDataTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak healthKitManager] _ in
            guard let hkManager = healthKitManager else { return }

            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.5)) {
                    glowIntensity = CGFloat(hkManager.hrvCoherence / 100.0)
                }

                // Route Bio-Daten durch UniversalCore
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

// MARK: - Preview

#if DEBUG
#Preview {
    VaporwavePalace()
        .environmentObject(HealthKitManager())
        .environmentObject(AudioEngine())
        .environmentObject(MicrophoneManager())
}
#endif

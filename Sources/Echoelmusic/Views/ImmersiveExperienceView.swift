import SwiftUI
import Combine

/// ImmersiveExperienceView - Unified UI for All Apple Devices
///
/// Provides an adaptive, device-optimized interface for the immersive experience
/// that combines biofeedback, touch, gesture, face tracking, and visual entrainment.
///
/// **Device Adaptations:**
/// - Apple Watch: Minimal UI, focus on haptic feedback and breathing guidance
/// - iPhone: Touch keyboard, face tracking, full biofeedback visuals
/// - iPad: Expanded canvas, split-view controls, Apple Pencil support
/// - Vision Pro: Full 3D immersive environment with hand/eye tracking
/// - Mac: Multi-window layout with external display support
@MainActor
public struct ImmersiveExperienceView: View {

    @StateObject private var hub = ImmersiveExperienceHub()

    @State private var showControls: Bool = true
    @State private var selectedMode: ImmersiveExperienceHub.ExperienceMode = .meditation
    @State private var isStarted: Bool = false
    @State private var showModeSelector: Bool = false
    @State private var showSettings: Bool = false

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background entrainment visualization
                if isStarted {
                    entrainmentVisualization
                } else {
                    startScreen
                }

                // Overlay controls
                if showControls && isStarted {
                    controlOverlay(geometry: geometry)
                }
            }
            .ignoresSafeArea()
            .onTapGesture {
                if isStarted {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls.toggle()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Start Screen

    private var startScreen: some View {
        VStack(spacing: 30) {
            Spacer()

            // Logo/Title
            VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Immersive Experience")
                    .font(.title.bold())
                    .foregroundColor(.white)

                Text("Brainwave Entrainment & Biofeedback")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            // Mode selector
            VStack(spacing: 16) {
                Text("Select Experience Mode")
                    .font(.headline)
                    .foregroundColor(.white)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(ImmersiveExperienceHub.ExperienceMode.allCases, id: \.self) { mode in
                        modeButton(mode)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Start button
            Button {
                startExperience()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Begin Session")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }

            // Device info
            deviceCapabilitiesInfo

            Spacer()
        }
        .background(Color.black)
    }

    private func modeButton(_ mode: ImmersiveExperienceHub.ExperienceMode) -> some View {
        Button {
            selectedMode = mode
        } label: {
            VStack(spacing: 8) {
                Image(systemName: modeIcon(mode))
                    .font(.title2)

                Text(mode.rawValue)
                    .font(.caption)
                    .lineLimit(1)

                Text("\(mode.targetFrequency, specifier: "%.1f") Hz")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedMode == mode ? Color.blue.opacity(0.3) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedMode == mode ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .foregroundColor(.white)
    }

    private func modeIcon(_ mode: ImmersiveExperienceHub.ExperienceMode) -> String {
        switch mode {
        case .deepSleep: return "moon.zzz.fill"
        case .meditation: return "figure.mind.and.body"
        case .relaxation: return "leaf.fill"
        case .focus: return "target"
        case .performance: return "bolt.fill"
        case .creativity: return "paintpalette.fill"
        case .healing: return "heart.fill"
        case .flow: return "wind"
        }
    }

    private var deviceCapabilitiesInfo: some View {
        HStack(spacing: 20) {
            capabilityIcon(
                icon: "hand.tap.fill",
                active: hub.deviceCapabilities.hasTouch,
                label: "Touch"
            )
            capabilityIcon(
                icon: "face.smiling.fill",
                active: hub.deviceCapabilities.hasFaceTracking,
                label: "Face"
            )
            capabilityIcon(
                icon: "hand.raised.fill",
                active: hub.deviceCapabilities.hasHandTracking,
                label: "Hand"
            )
            capabilityIcon(
                icon: "heart.fill",
                active: hub.deviceCapabilities.hasBiofeedback,
                label: "Bio"
            )
            capabilityIcon(
                icon: "hifispeaker.2.fill",
                active: hub.deviceCapabilities.hasSpatialAudio,
                label: "Spatial"
            )
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func capabilityIcon(icon: String, active: Bool, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(active ? .green : .gray)

            Text(label)
                .font(.caption2)
                .foregroundColor(active ? .white : .gray)
        }
    }

    // MARK: - Entrainment Visualization

    @ViewBuilder
    private var entrainmentVisualization: some View {
        #if os(watchOS)
        WatchEntrainmentVisualizer(hub: hub)
        #elseif os(visionOS)
        VisionProEntrainmentView(hub: hub)
        #else
        BrainwaveEntrainmentVisualizer(hub: hub)
        #endif
    }

    // MARK: - Control Overlay

    private func controlOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            // Top bar
            HStack {
                // Back/Stop button
                Button {
                    stopExperience()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                // Current mode
                VStack(alignment: .trailing, spacing: 2) {
                    Text(hub.experienceMode.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("\(hub.entrainmentTargetHz, specifier: "%.1f") Hz")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Mode selector
                Button {
                    showModeSelector.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.8), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Spacer()

            // Bottom metrics
            metricsBar
                .padding()
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .sheet(isPresented: $showModeSelector) {
            modeSelectorSheet
        }
    }

    private var metricsBar: some View {
        HStack(spacing: 20) {
            // Coherence
            metricView(
                icon: "waveform.path.ecg",
                value: "\(Int(hub.systemCoherence))%",
                label: "Coherence",
                color: coherenceColor
            )

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.3))

            // Brainwave state
            metricView(
                icon: "brain",
                value: hub.brainwaveState.rawValue,
                label: "State",
                color: brainwaveColor
            )

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.3))

            // Sync
            metricView(
                icon: "link",
                value: "\(Int(hub.entrainmentSync * 100))%",
                label: "Sync",
                color: syncColor
            )
        }
        .padding(.horizontal)
    }

    private func metricView(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(color)

                Text(value)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }

    private var coherenceColor: Color {
        let coherence = hub.systemCoherence
        if coherence < 40 {
            return .red
        } else if coherence < 60 {
            return .yellow
        } else {
            return .green
        }
    }

    private var brainwaveColor: Color {
        let color = hub.brainwaveState.color
        return Color(red: Double(color.r), green: Double(color.g), blue: Double(color.b))
    }

    private var syncColor: Color {
        let sync = hub.entrainmentSync
        if sync < 0.3 {
            return .red
        } else if sync < 0.6 {
            return .yellow
        } else {
            return .green
        }
    }

    // MARK: - Mode Selector Sheet

    private var modeSelectorSheet: some View {
        NavigationView {
            List {
                ForEach(ImmersiveExperienceHub.ExperienceMode.allCases, id: \.self) { mode in
                    Button {
                        hub.switchMode(to: mode)
                        showModeSelector = false
                    } label: {
                        HStack {
                            Image(systemName: modeIcon(mode))
                                .foregroundColor(.blue)
                                .frame(width: 30)

                            VStack(alignment: .leading) {
                                Text(mode.rawValue)
                                    .foregroundColor(.primary)

                                Text("\(mode.targetFrequency, specifier: "%.1f") Hz - \(mode.targetBrainwaveState.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if hub.experienceMode == mode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                Section("Manual Frequency") {
                    VStack {
                        Text("\(hub.entrainmentTargetHz, specifier: "%.1f") Hz")
                            .font(.title2)
                            .bold()

                        Slider(
                            value: Binding(
                                get: { hub.entrainmentTargetHz },
                                set: { hub.setEntrainmentTarget(frequency: $0) }
                            ),
                            in: 0.5...40,
                            step: 0.5
                        )

                        HStack {
                            Text("Delta")
                                .font(.caption2)
                            Spacer()
                            Text("Gamma")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Experience Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showModeSelector = false
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func startExperience() {
        Task {
            do {
                try await hub.start(mode: selectedMode)
                withAnimation {
                    isStarted = true
                }
            } catch {
                EchoelLogger.error("[ImmersiveView] Failed to start: \(error.localizedDescription)", category: EchoelLogger.system)
            }
        }
    }

    private func stopExperience() {
        hub.stop()
        withAnimation {
            isStarted = false
            showControls = true
        }
    }
}

// MARK: - Watch-Specific View

#if os(watchOS)
@MainActor
public struct WatchImmersiveExperienceView: View {

    @StateObject private var hub = ImmersiveExperienceHub()
    @State private var isStarted: Bool = false

    public var body: some View {
        ZStack {
            if isStarted {
                WatchEntrainmentVisualizer(hub: hub)

                VStack {
                    Spacer()

                    // Minimal metrics
                    HStack {
                        VStack {
                            Text("\(Int(hub.systemCoherence))")
                                .font(.title2.bold())
                            Text("Coherence")
                                .font(.caption2)
                        }

                        Spacer()

                        Button {
                            hub.stop()
                            isStarted = false
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                    }
                    .padding(.horizontal)
                }
            } else {
                // Start button
                VStack(spacing: 16) {
                    Image(systemName: "brain")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)

                    Button {
                        Task {
                            try? await hub.start(mode: .relaxation)
                            isStarted = true
                        }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    ImmersiveExperienceView()
}

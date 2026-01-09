import SwiftUI
import Combine

/// Streaming Dashboard View
/// Native iOS/macOS streaming to Twitch, YouTube, Facebook with bio-reactive overlays
struct StreamingView: View {

    // MARK: - Environment

    @EnvironmentObject var healthKitManager: HealthKitManager

    // MARK: - State

    @State private var selectedDestinations: Set<StreamEngine.StreamDestination> = []
    @State private var streamKeys: [StreamEngine.StreamDestination: String] = [:]
    @State private var selectedResolution: StreamEngine.Resolution = .hd1920x1080
    @State private var frameRate: Int = 60
    @State private var bitrate: Int = 6000
    @State private var adaptiveBitrateEnabled: Bool = true
    @State private var bioReactiveEnabled: Bool = true
    @State private var showingKeyInput: StreamEngine.StreamDestination?
    @State private var isStreaming: Bool = false
    @State private var showingScenePicker: Bool = false
    @State private var showingAnalytics: Bool = false
    @State private var currentScene: Scene?
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: VaporwaveSpacing.xl) {

                // Header
                headerSection

                // Status Section
                statusSection

                // Destinations
                destinationsSection

                // Settings
                settingsSection

                // Bio-Reactive Controls
                if isStreaming {
                    bioMetricsSection
                        .transition(.opacity.combined(with: .scale))
                }

                // Control Buttons
                controlsSection

                // Analytics Summary
                if showingAnalytics && isStreaming {
                    analyticsSection
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding()
        }
        .background(VaporwaveGradients.background.ignoresSafeArea())
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(item: $showingKeyInput) { destination in
            StreamKeyInputSheet(
                destination: destination,
                streamKey: Binding(
                    get: { streamKeys[destination] ?? "" },
                    set: { streamKeys[destination] = $0 }
                )
            )
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 28))
                    .foregroundColor(isStreaming ? VaporwaveColors.recordingActive : VaporwaveColors.neonCyan)
                    .neonGlow(color: isStreaming ? VaporwaveColors.recordingActive : VaporwaveColors.neonCyan, radius: 10)

                Text("STREAM STUDIO")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)
            }

            Text("Bio-Reactive Live Streaming")
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textTertiary)
                .tracking(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stream Studio, Bio-Reactive Live Streaming")
    }

    // MARK: - Status Section

    private var statusSection: some View {
        HStack(spacing: VaporwaveSpacing.lg) {
            // Streaming status
            VStack(spacing: VaporwaveSpacing.xs) {
                Circle()
                    .fill(isStreaming ? VaporwaveColors.recordingActive : VaporwaveColors.textTertiary)
                    .frame(width: 12, height: 12)
                    .shadow(color: isStreaming ? VaporwaveColors.recordingActive : .clear, radius: 5)

                Text(isStreaming ? "LIVE" : "OFFLINE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isStreaming ? VaporwaveColors.recordingActive : VaporwaveColors.textTertiary)
            }
            .accessibilityLabel(isStreaming ? "Status: Live" : "Status: Offline")

            Divider()
                .frame(height: 40)

            // Resolution & FPS
            VStack(spacing: VaporwaveSpacing.xs) {
                Text(selectedResolution.rawValue)
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text("\(frameRate) FPS")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .accessibilityLabel("Resolution: \(selectedResolution.rawValue) at \(frameRate) frames per second")

            Divider()
                .frame(height: 40)

            // Bitrate
            VStack(spacing: VaporwaveSpacing.xs) {
                Text("\(bitrate)")
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(VaporwaveColors.neonCyan)

                Text("kbps")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .accessibilityLabel("Bitrate: \(bitrate) kilobits per second")

            Divider()
                .frame(height: 40)

            // Destinations count
            VStack(spacing: VaporwaveSpacing.xs) {
                Text("\(selectedDestinations.count)")
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(VaporwaveColors.neonPink)

                Text("streams")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .accessibilityLabel("\(selectedDestinations.count) streaming destinations selected")
        }
        .padding(VaporwaveSpacing.lg)
        .glassCard()
    }

    // MARK: - Destinations Section

    private var destinationsSection: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            VaporwaveSectionHeader("Streaming Destinations", icon: "antenna.radiowaves.left.and.right")

            ForEach(StreamEngine.StreamDestination.allCases) { destination in
                destinationRow(destination)
            }
        }
    }

    private func destinationRow(_ destination: StreamEngine.StreamDestination) -> some View {
        let isSelected = selectedDestinations.contains(destination)
        let hasKey = streamKeys[destination]?.isEmpty == false

        return HStack {
            // Selection toggle
            Button(action: {
                if isSelected {
                    selectedDestinations.remove(destination)
                } else {
                    selectedDestinations.insert(destination)
                }
            }) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? VaporwaveColors.success : VaporwaveColors.textTertiary)
            }
            .disabled(isStreaming)

            // Platform icon and name
            Image(systemName: iconForDestination(destination))
                .font(.system(size: 20))
                .foregroundColor(colorForDestination(destination))
                .frame(width: 30)

            Text(destination.rawValue)
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textPrimary)

            Spacer()

            // Stream key status
            if hasKey {
                Text("Key Set")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.success)
            }

            // Configure key button
            Button(action: {
                showingKeyInput = destination
            }) {
                Image(systemName: "key.fill")
                    .font(.system(size: 16))
                    .foregroundColor(hasKey ? VaporwaveColors.neonCyan : VaporwaveColors.warning)
            }
            .disabled(isStreaming)
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(destination.rawValue), \(isSelected ? "selected" : "not selected"), stream key \(hasKey ? "configured" : "not set")")
        .accessibilityHint("Double tap to toggle selection")
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            VaporwaveSectionHeader("Stream Settings", icon: "gearshape")

            // Resolution Picker
            HStack {
                Text("Resolution")
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Spacer()

                Picker("Resolution", selection: $selectedResolution) {
                    ForEach(StreamEngine.Resolution.allCases, id: \.self) { res in
                        Text(res.rawValue).tag(res)
                    }
                }
                .pickerStyle(.menu)
                .tint(VaporwaveColors.neonCyan)
                .disabled(isStreaming)
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()

            // Frame Rate
            HStack {
                Text("Frame Rate")
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Spacer()

                Picker("FPS", selection: $frameRate) {
                    Text("30 FPS").tag(30)
                    Text("60 FPS").tag(60)
                    Text("120 FPS").tag(120)
                }
                .pickerStyle(.segmented)
                .disabled(isStreaming)
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()

            // Bitrate Slider
            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                HStack {
                    Text("Bitrate")
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Spacer()

                    Text("\(bitrate) kbps")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(VaporwaveColors.neonCyan)
                }

                Slider(value: Binding(
                    get: { Double(bitrate) },
                    set: { bitrate = Int($0) }
                ), in: 1000...15000, step: 500)
                .tint(VaporwaveColors.neonCyan)
                .disabled(isStreaming)
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()

            // Adaptive Bitrate Toggle
            VaporwaveToggleRow(
                title: "Adaptive Bitrate",
                subtitle: "Automatically adjust based on network",
                isOn: $adaptiveBitrateEnabled,
                tintColor: VaporwaveColors.neonCyan
            )

            // Bio-Reactive Toggle
            VaporwaveToggleRow(
                title: "Bio-Reactive Mode",
                subtitle: "Switch scenes based on coherence",
                isOn: $bioReactiveEnabled,
                tintColor: VaporwaveColors.neonPink
            )
        }
    }

    // MARK: - Bio Metrics Section

    private var bioMetricsSection: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            VaporwaveSectionHeader("Bio-Data Overlay", icon: "waveform.path.ecg")

            HStack(spacing: VaporwaveSpacing.xl) {
                // Heart Rate
                VStack(spacing: VaporwaveSpacing.xs) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24))
                        .foregroundColor(VaporwaveColors.heartRate)

                    Text("\(Int(healthKitManager.heartRate))")
                        .font(VaporwaveTypography.dataSmall())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text("BPM")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
                .accessibilityLabel("Heart rate: \(Int(healthKitManager.heartRate)) BPM")

                // Coherence
                VStack(spacing: VaporwaveSpacing.xs) {
                    VaporwaveProgressRing(
                        progress: healthKitManager.hrvCoherence / 100.0,
                        color: coherenceColor,
                        lineWidth: 4,
                        size: 50
                    )
                    .overlay {
                        Text("\(Int(healthKitManager.hrvCoherence))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(coherenceColor)
                    }

                    Text("Flow")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
                .accessibilityLabel("Coherence: \(Int(healthKitManager.hrvCoherence)) percent")

                // HRV
                VStack(spacing: VaporwaveSpacing.xs) {
                    Image(systemName: "waveform")
                        .font(.system(size: 24))
                        .foregroundColor(VaporwaveColors.hrv)

                    Text(String(format: "%.0f", healthKitManager.hrvRMSSD))
                        .font(VaporwaveTypography.dataSmall())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text("HRV")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
                .accessibilityLabel("HRV: \(Int(healthKitManager.hrvRMSSD)) milliseconds")

                Spacer()

                // Bio status
                VStack(spacing: VaporwaveSpacing.xs) {
                    Text(bioReactiveEnabled ? "ACTIVE" : "OFF")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(bioReactiveEnabled ? VaporwaveColors.success : VaporwaveColors.textTertiary)

                    Text("Bio Mode")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
            }
            .padding(VaporwaveSpacing.lg)
            .glassCard()
        }
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        HStack(spacing: VaporwaveSpacing.lg) {
            // Scene picker
            VaporwaveControlButton(
                icon: "rectangle.stack",
                label: "Scenes",
                isActive: showingScenePicker,
                color: VaporwaveColors.neonPurple
            ) {
                showingScenePicker.toggle()
            }

            // Main stream button
            Button(action: toggleStreaming) {
                ZStack {
                    Circle()
                        .fill(isStreaming ? VaporwaveColors.recordingActive : VaporwaveColors.neonCyan)
                        .frame(width: 100, height: 100)

                    Image(systemName: isStreaming ? "stop.fill" : "play.fill")
                        .font(.system(size: 40))
                        .foregroundColor(VaporwaveColors.deepBlack)
                }
                .neonGlow(color: isStreaming ? VaporwaveColors.recordingActive : VaporwaveColors.neonCyan, radius: 20)
            }
            .disabled(selectedDestinations.isEmpty || !allKeysConfigured)
            .accessibilityLabel(isStreaming ? "Stop streaming" : "Start streaming")
            .accessibilityHint(selectedDestinations.isEmpty ? "Select at least one destination first" :
                              !allKeysConfigured ? "Configure stream keys first" : "")

            // Analytics
            VaporwaveControlButton(
                icon: "chart.bar",
                label: "Stats",
                isActive: showingAnalytics,
                color: VaporwaveColors.neonCyan
            ) {
                showingAnalytics.toggle()
            }
        }
    }

    // MARK: - Analytics Section

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            VaporwaveSectionHeader("Stream Analytics", icon: "chart.xyaxis.line")

            HStack(spacing: VaporwaveSpacing.xl) {
                VStack(spacing: VaporwaveSpacing.xs) {
                    Text("0")
                        .font(VaporwaveTypography.data())
                        .foregroundColor(VaporwaveColors.neonCyan)
                    Text("Viewers")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                VStack(spacing: VaporwaveSpacing.xs) {
                    Text("0")
                        .font(VaporwaveTypography.data())
                        .foregroundColor(VaporwaveColors.neonPink)
                    Text("Peak")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                VStack(spacing: VaporwaveSpacing.xs) {
                    Text("0")
                        .font(VaporwaveTypography.data())
                        .foregroundColor(VaporwaveColors.success)
                    Text("Frames")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                VStack(spacing: VaporwaveSpacing.xs) {
                    Text("0")
                        .font(VaporwaveTypography.data())
                        .foregroundColor(VaporwaveColors.warning)
                    Text("Dropped")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
            }
            .padding(VaporwaveSpacing.lg)
            .glassCard()
        }
    }

    // MARK: - Helpers

    private var coherenceColor: Color {
        if healthKitManager.hrvCoherence < 40 {
            return VaporwaveColors.coherenceLow
        } else if healthKitManager.hrvCoherence < 60 {
            return VaporwaveColors.coherenceMedium
        } else {
            return VaporwaveColors.coherenceHigh
        }
    }

    private var allKeysConfigured: Bool {
        selectedDestinations.allSatisfy { destination in
            streamKeys[destination]?.isEmpty == false
        }
    }

    private func iconForDestination(_ destination: StreamEngine.StreamDestination) -> String {
        switch destination {
        case .twitch: return "gamecontroller"
        case .youtube: return "play.rectangle"
        case .facebook: return "person.2"
        case .custom1, .custom2: return "server.rack"
        }
    }

    private func colorForDestination(_ destination: StreamEngine.StreamDestination) -> Color {
        switch destination {
        case .twitch: return .purple
        case .youtube: return .red
        case .facebook: return .blue
        case .custom1, .custom2: return VaporwaveColors.neonCyan
        }
    }

    private func toggleStreaming() {
        withAnimation(VaporwaveAnimation.smooth) {
            isStreaming.toggle()
        }

        if isStreaming {
            log.streaming("▶️ StreamingView: Starting stream to \(selectedDestinations.count) destination(s)")
        } else {
            log.streaming("⏹️ StreamingView: Stopping stream")
        }
    }
}

// MARK: - Stream Key Input Sheet

struct StreamKeyInputSheet: View {
    let destination: StreamEngine.StreamDestination
    @Binding var streamKey: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: VaporwaveSpacing.xl) {
                Image(systemName: "key.fill")
                    .font(.system(size: 50))
                    .foregroundColor(VaporwaveColors.neonCyan)
                    .neonGlow(color: VaporwaveColors.neonCyan, radius: 15)

                Text("Enter Stream Key")
                    .font(VaporwaveTypography.sectionTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text(destination.rawValue)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)

                SecureField("Stream Key", text: $streamKey)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Text("Your stream key can be found in your \(destination.rawValue) dashboard settings.")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding()
            .background(VaporwaveGradients.background.ignoresSafeArea())
            .navigationTitle("Configure \(destination.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { dismiss() }
                        .disabled(streamKey.isEmpty)
                }
            }
        }
    }
}

// MARK: - StreamDestination Identifiable Extension

extension StreamEngine.StreamDestination: @retroactive Identifiable {
    public var id: String { rawValue }
}

// MARK: - Preview

#Preview {
    StreamingView()
        .environmentObject(HealthKitManager())
}

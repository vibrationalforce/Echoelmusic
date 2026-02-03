import SwiftUI

/// UI Controls for Spatial Audio
/// Shows spatial audio toggle, mode selector, and status
/// Uses VaporwaveTheme for consistent styling
struct SpatialAudioControlsView: View {

    @ObservedObject var audioEngine: AudioEngine
    @ObservedObject var deviceCapabilities: DeviceCapabilities
    @ObservedObject var headTrackingManager: HeadTrackingManager
    @ObservedObject var spatialAudioEngine: SpatialAudioEngine

    @State private var showDetails = false

    var body: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            // Header
            HStack {
                Image(systemName: "airpodspro")
                    .font(.system(size: 20))
                    .foregroundColor(VaporwaveColors.neonCyan)
                    .neonGlow(color: VaporwaveColors.neonCyan, radius: 5)

                Text("Spatial Audio")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(VaporwaveColors.textPrimary)

                Spacer()

                // Status indicator
                VaporwaveStatusIndicator(
                    isActive: spatialAudioEngine.isActive && audioEngine.spatialAudioEnabled,
                    activeColor: VaporwaveColors.coherenceHigh,
                    inactiveColor: VaporwaveColors.textTertiary
                )

                // Expand button
                Button(action: { withAnimation(VaporwaveAnimation.smooth) { showDetails.toggle() } }) {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(VaporwaveColors.textSecondary)
                }
                .accessibilityLabel(showDetails ? "Collapse details" : "Expand details")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Spatial Audio, \(spatialStatusText)")

            // Main Toggle
            Toggle(isOn: $audioEngine.spatialAudioEnabled) {
                HStack {
                    Text(spatialStatusText)
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(VaporwaveColors.textSecondary)

                    if !deviceCapabilities.canUseSpatialAudio {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 12))
                            .foregroundColor(VaporwaveColors.warning)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: VaporwaveColors.neonCyan))
            .disabled(!spatialAudioEngine.isAvailable)
            .accessibilityLabel("Spatial audio toggle")
            .accessibilityValue(audioEngine.spatialAudioEnabled ? "Enabled" : "Disabled")

            // Expanded Details
            if showDetails {
                VStack(spacing: VaporwaveSpacing.md) {
                    Divider()
                        .background(VaporwaveColors.textTertiary)

                    // Spatial Mode Picker
                    if audioEngine.spatialAudioEnabled {
                        VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                            Text("Mode")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(VaporwaveColors.textTertiary)

                            Picker("Spatial Mode", selection: $spatialAudioEngine.currentMode) {
                                ForEach(SpatialMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .accessibilityLabel("Spatial mode: \(spatialAudioEngine.currentMode.rawValue)")
                        }
                    }

                    // Head Tracking Status
                    HStack {
                        Image(systemName: headTrackingManager.isTracking ? "gyroscope" : "gyroscope.slash")
                            .font(.system(size: 14))
                            .foregroundColor(headTrackingManager.isTracking ? VaporwaveColors.coherenceHigh : VaporwaveColors.textTertiary)

                        Text(headTrackingManager.statusDescription)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(VaporwaveColors.textSecondary)

                        Spacer()

                        if headTrackingManager.isTracking {
                            Text(headTrackingManager.getDirectionArrow())
                                .font(.system(size: 20))
                                .foregroundColor(VaporwaveColors.neonCyan)
                        }
                    }
                    .accessibilityLabel("Head tracking \(headTrackingManager.isTracking ? "active" : "inactive")")

                    // Device Info
                    VStack(spacing: VaporwaveSpacing.xs) {
                        deviceInfoRow(
                            icon: "iphone",
                            label: "Device",
                            value: deviceCapabilities.deviceModel
                        )

                        if deviceCapabilities.hasAirPodsConnected {
                            deviceInfoRow(
                                icon: "airpodspro",
                                label: "Audio",
                                value: deviceCapabilities.airPodsModel ?? "Unknown"
                            )
                        }

                        deviceInfoRow(
                            icon: deviceCapabilities.supportsASAF ? "checkmark.circle.fill" : "xmark.circle",
                            label: "ASAF",
                            value: deviceCapabilities.supportsASAF ? "Supported" : "Not Available",
                            color: deviceCapabilities.supportsASAF ? VaporwaveColors.coherenceHigh : VaporwaveColors.coherenceLow
                        )
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
        .neonGlow(color: audioEngine.spatialAudioEnabled ? VaporwaveColors.neonCyan : .clear, radius: 10)
    }

    // MARK: - Helper Views

    private func deviceInfoRow(icon: String, label: String, value: String, color: Color = VaporwaveColors.textSecondary) -> some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 11, weight: .light))
                .foregroundColor(VaporwaveColors.textTertiary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(color)

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        if !spatialAudioEngine.isAvailable {
            return VaporwaveColors.textTertiary
        } else if audioEngine.spatialAudioEnabled && spatialAudioEngine.isActive {
            return VaporwaveColors.coherenceHigh
        } else {
            return VaporwaveColors.coherenceMedium
        }
    }

    private var spatialStatusText: String {
        if !spatialAudioEngine.isAvailable {
            return "Not Available"
        } else if audioEngine.spatialAudioEnabled {
            return "Active"
        } else {
            return "Ready"
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.1, green: 0.05, blue: 0.2)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        let micManager = MicrophoneManager()
        let audioEngine = AudioEngine(microphoneManager: micManager)
        let capabilities = DeviceCapabilities()
        let headTracking = HeadTrackingManager()
        let spatial = SpatialAudioEngine()  // New API: self-contained

        SpatialAudioControlsView(
            audioEngine: audioEngine,
            deviceCapabilities: capabilities,
            headTrackingManager: headTracking,
            spatialAudioEngine: spatial
        )
        .padding()
    }
}

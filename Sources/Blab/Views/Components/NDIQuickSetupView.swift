import SwiftUI

/// NDI Quick Setup - One-tap setup wizard for beginners
///
/// Features:
/// - 3-step guided setup
/// - Automatic configuration
/// - Network quality check
/// - Device compatibility check
/// - Clear instructions with visuals
///
/// Usage:
/// ```swift
/// .sheet(isPresented: $showingSetup) {
///     NDIQuickSetupView(controlHub: hub)
/// }
/// ```
@available(iOS 15.0, *)
struct NDIQuickSetupView: View {

    @ObservedObject var controlHub: UnifiedControlHub
    @Environment(\.dismiss) var dismiss

    @State private var currentStep: SetupStep = .welcome
    @State private var isConfiguring: Bool = false
    @State private var setupComplete: Bool = false
    @State private var errorMessage: String?

    private let smartConfig = NDISmartConfiguration.shared
    private let networkMonitor = NDINetworkMonitor.shared

    enum SetupStep {
        case welcome
        case networkCheck
        case deviceCheck
        case configure
        case complete
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: stepProgress, total: 1.0)
                    .padding()

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        stepContent
                    }
                    .padding()
                }

                // Navigation
                HStack(spacing: 16) {
                    if currentStep != .welcome {
                        Button("Back") {
                            previousStep()
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button(nextButtonTitle) {
                        nextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isConfiguring)
                }
                .padding()
            }
            .navigationTitle("NDI Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if currentStep != .complete {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            // Start network monitoring
            networkMonitor.start()
            // Detect device & network
            smartConfig.detectDeviceCapability()
            smartConfig.detectNetworkQuality()
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .welcome:
            welcomeStep
        case .networkCheck:
            networkCheckStep
        case .deviceCheck:
            deviceCheckStep
        case .configure:
            configureStep
        case .complete:
            completeStep
        }
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Welcome to NDI Audio!")
                .font(.title.bold())

            Text("Stream BLAB audio to your DAW, OBS, or any NDI-compatible device")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "wifi", title: "Network Streaming", description: "Works over WiFi or Ethernet")
                FeatureRow(icon: "bolt.fill", title: "Ultra-Low Latency", description: "< 5ms on local network")
                FeatureRow(icon: "gearshape.2.fill", title: "Auto-Configuration", description: "We'll optimize everything for you")
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            Text("This will take about 30 seconds")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private struct FeatureRow: View {
        let icon: String
        let title: String
        let description: String

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Network Check

    private var networkCheckStep: some View {
        VStack(spacing: 24) {
            Image(systemName: networkQualityIcon)
                .font(.system(size: 80))
                .foregroundColor(networkQualityColor)

            Text("Checking Network")
                .font(.title2.bold())

            let networkQuality = smartConfig.networkQuality
            let healthScore = networkMonitor.getHealthScore()

            VStack(spacing: 16) {
                InfoCard(
                    title: "Network Quality",
                    value: networkQuality.rawValue,
                    icon: "wifi",
                    color: networkQualityColor
                )

                InfoCard(
                    title: "Health Score",
                    value: "\(healthScore)/100",
                    icon: "heart.fill",
                    color: healthScore > 80 ? .green : healthScore > 60 ? .orange : .red
                )

                InfoCard(
                    title: "Estimated Latency",
                    value: String(format: "%.1fms", smartConfig.estimateLatency()),
                    icon: "timer",
                    color: .blue
                )
            }

            if healthScore < 60 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("⚠️ Network Quality Tips:")
                        .font(.subheadline.bold())

                    ForEach(networkMonitor.getTroubleshootingTips(), id: \.self) { tip in
                        Text("• \(tip)")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("✅ Your network is ready for NDI streaming!")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
    }

    private var networkQualityIcon: String {
        switch smartConfig.networkQuality {
        case .excellent: return "wifi"
        case .good: return "wifi"
        case .fair: return "wifi"
        case .poor: return "wifi.slash"
        case .unknown: return "wifi.exclamationmark"
        }
    }

    private var networkQualityColor: Color {
        switch smartConfig.networkQuality {
        case .excellent: return .green
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }

    // MARK: - Device Check

    private var deviceCheckStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("Checking Device")
                .font(.title2.bold())

            let deviceCapability = smartConfig.deviceCapability

            VStack(spacing: 16) {
                InfoCard(
                    title: "Device Type",
                    value: deviceCapability.rawValue,
                    icon: "iphone",
                    color: .blue
                )

                InfoCard(
                    title: "Max Sample Rate",
                    value: "\(Int(deviceCapability.maxSampleRate / 1000)) kHz",
                    icon: "waveform",
                    color: .purple
                )

                InfoCard(
                    title: "Recommended Buffer",
                    value: "\(deviceCapability.recommendedBufferSize) frames",
                    icon: "speedometer",
                    color: .orange
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("💡 Optimization Tips:")
                    .font(.subheadline.bold())

                ForEach(smartConfig.getOptimizationTips(), id: \.self) { tip in
                    Text("• \(tip)")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Configure

    private var configureStep: some View {
        VStack(spacing: 24) {
            if isConfiguring {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()

                Text("Configuring NDI...")
                    .font(.headline)

                Text("Optimizing settings for your device and network")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

            } else if let error = errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)

                Text("Setup Error")
                    .font(.title2.bold())

                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Button("Try Again") {
                    errorMessage = nil
                    configureNDI()
                }
                .buttonStyle(.borderedProminent)

            } else {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Ready to Configure")
                    .font(.title2.bold())

                Text("We'll automatically optimize NDI for:")
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    ConfigItem(label: "Device", value: smartConfig.deviceCapability.rawValue)
                    ConfigItem(label: "Network", value: smartConfig.networkQuality.rawValue)
                    ConfigItem(label: "Quality Profile", value: smartConfig.currentProfile.rawValue)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Text("This will take a few seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if !isConfiguring && errorMessage == nil && !setupComplete {
                configureNDI()
            }
        }
    }

    private struct ConfigItem: View {
        let label: String
        let value: String

        var body: some View {
            HStack {
                Text(label)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .bold()
            }
            .font(.caption)
        }
    }

    // MARK: - Complete

    private var completeStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Setup Complete!")
                .font(.title.bold())

            Text("NDI is now streaming audio to your network")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ResultRow(label: "Source Name", value: NDIConfiguration.shared.sourceName)
                ResultRow(label: "Quality", value: smartConfig.currentProfile.rawValue)
                ResultRow(label: "Sample Rate", value: "\(Int(NDIConfiguration.shared.sampleRate / 1000)) kHz")
                ResultRow(label: "Latency", value: String(format: "~%.1fms", smartConfig.estimateLatency()))
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 12) {
                Text("Next Steps:")
                    .font(.subheadline.bold())

                NextStep(number: 1, text: "Open your DAW or streaming app")
                NextStep(number: 2, text: "Look for '\(NDIConfiguration.shared.sourceName)' in NDI sources")
                NextStep(number: 3, text: "Start recording or streaming!")
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)

            Text("💡 Tip: Check NDI settings anytime in the app")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private struct ResultRow: View {
        let label: String
        let value: String

        var body: some View {
            HStack {
                Text(label)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .bold()
            }
            .font(.subheadline)
        }
    }

    private struct NextStep: View {
        let number: Int
        let text: String

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                Text("\(number)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.blue)
                    .clipShape(Circle())

                Text(text)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Navigation

    private var stepProgress: Double {
        switch currentStep {
        case .welcome: return 0.0
        case .networkCheck: return 0.25
        case .deviceCheck: return 0.5
        case .configure: return 0.75
        case .complete: return 1.0
        }
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case .welcome: return "Get Started"
        case .networkCheck, .deviceCheck: return "Continue"
        case .configure: return isConfiguring ? "Please Wait..." : "Configure"
        case .complete: return "Done"
        }
    }

    private func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .networkCheck
        case .networkCheck:
            currentStep = .deviceCheck
        case .deviceCheck:
            currentStep = .configure
        case .configure:
            if setupComplete {
                currentStep = .complete
            }
        case .complete:
            dismiss()
        }
    }

    private func previousStep() {
        switch currentStep {
        case .welcome:
            break
        case .networkCheck:
            currentStep = .welcome
        case .deviceCheck:
            currentStep = .networkCheck
        case .configure:
            currentStep = .deviceCheck
        case .complete:
            break
        }
    }

    // MARK: - Configuration

    private func configureNDI() {
        isConfiguring = true

        Task {
            do {
                // Apply optimal settings
                smartConfig.applyOptimalSettings()

                // Wait a bit for visual effect
                try await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5s

                // Enable NDI
                try controlHub.enableNDI()

                // Wait for confirmation
                try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s

                await MainActor.run {
                    isConfiguring = false
                    setupComplete = true
                    currentStep = .complete
                }

            } catch {
                await MainActor.run {
                    isConfiguring = false
                    errorMessage = "Failed to configure NDI: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Info Card

@available(iOS 15.0, *)
private struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.headline)
            }

            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct NDIQuickSetupView_Previews: PreviewProvider {
    static var previews: some View {
        NDIQuickSetupView(controlHub: UnifiedControlHub())
    }
}

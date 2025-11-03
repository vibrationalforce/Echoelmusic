import SwiftUI

/// NDI Simple View - User-friendly main interface
///
/// Features:
/// - One-button enable/disable
/// - Visual health indicators
/// - Connection status
/// - Quick troubleshooting tips
/// - Auto-recovery status
///
/// Usage:
/// ```swift
/// NDISimpleView(controlHub: hub)
/// ```
@available(iOS 15.0, *)
struct NDISimpleView: View {

    @ObservedObject var controlHub: UnifiedControlHub

    @StateObject private var networkMonitor = NDINetworkMonitor.shared
    @StateObject private var smartConfig = NDISmartConfiguration.shared
    @StateObject private var autoRecovery: NDIAutoRecovery

    @State private var showingQuickSetup = false
    @State private var showingAdvancedSettings = false
    @State private var showingHelp = false

    init(controlHub: UnifiedControlHub) {
        self.controlHub = controlHub
        self._autoRecovery = StateObject(wrappedValue: NDIAutoRecovery(controlHub: controlHub))
    }

    var body: some View {
        Form {
            // MARK: - Main Control
            Section {
                mainControlCard
            }

            // MARK: - Status
            if controlHub.isNDIEnabled {
                Section {
                    statusSection
                }

                // MARK: - Health Indicators
                Section("Connection Health") {
                    healthIndicators
                }

                // MARK: - Auto-Recovery
                if autoRecovery.currentError != nil {
                    Section {
                        autoRecoverySection
                    } header: {
                        Text("Auto-Recovery")
                    }
                }
            }

            // MARK: - Quick Actions
            Section {
                quickActionsSection
            }

            // MARK: - Help
            Section {
                helpSection
            }
        }
        .navigationTitle("NDI Audio")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingQuickSetup) {
            NDIQuickSetupView(controlHub: controlHub)
        }
        .sheet(isPresented: $showingAdvancedSettings) {
            NDISettingsView(controlHub: controlHub)
        }
        .sheet(isPresented: $showingHelp) {
            NDIHelpView()
        }
        .onAppear {
            // Start monitoring
            networkMonitor.start()

            // Enable auto-recovery if NDI is enabled
            if controlHub.isNDIEnabled {
                autoRecovery.enable()
            }
        }
    }

    // MARK: - Main Control Card

    private var mainControlCard: some View {
        VStack(spacing: 16) {
            // Icon & Title
            HStack {
                Image(systemName: controlHub.isNDIEnabled ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 50))
                    .foregroundColor(controlHub.isNDIEnabled ? .green : .gray)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(controlHub.isNDIEnabled ? "Streaming" : "Stopped")
                        .font(.title2.bold())

                    if controlHub.isNDIEnabled {
                        Text("\(controlHub.ndiConnectionCount) receiver\(controlHub.ndiConnectionCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Ready to stream")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Main Toggle
            Button {
                toggleNDI()
            } label: {
                Text(controlHub.isNDIEnabled ? "Stop Streaming" : "Start Streaming")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(controlHub.isNDIEnabled ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Quick Setup Button (if not streaming)
            if !controlHub.isNDIEnabled {
                Button {
                    showingQuickSetup = true
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Quick Setup Wizard")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatusRow(
                icon: "wifi",
                label: "Network",
                value: networkMonitor.networkStatus.quality.rawValue,
                color: networkStatusColor
            )

            StatusRow(
                icon: "speedometer",
                label: "Latency",
                value: String(format: "~%.1fms", smartConfig.estimateLatency()),
                color: latencyColor
            )

            StatusRow(
                icon: "checkmark.shield",
                label: "Health Score",
                value: "\(networkMonitor.getHealthScore())/100",
                color: healthScoreColor
            )

            if let stats = controlHub.ndiStatistics {
                StatusRow(
                    icon: "arrow.up.circle",
                    label: "Data Sent",
                    value: stats.bytesSent.formatted(.byteCount(style: .memory)),
                    color: .blue
                )

                if stats.droppedFrames > 0 {
                    StatusRow(
                        icon: "exclamationmark.triangle",
                        label: "Dropped Frames",
                        value: "\(stats.droppedFrames)",
                        color: .orange
                    )
                }
            }
        }
    }

    // MARK: - Health Indicators

    private var healthIndicators: some View {
        VStack(spacing: 12) {
            // Network Health Bar
            HealthBar(
                label: "Network Quality",
                score: Double(networkMonitor.getHealthScore()),
                color: healthScoreColor
            )

            // Quick Recommendation
            Text(networkMonitor.getStatusMessage())
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
        }
    }

    // MARK: - Auto-Recovery Section

    private var autoRecoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = autoRecovery.currentError {
                // Error Display
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.title)
                            .font(.subheadline.bold())
                        Text(error.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)

                // Suggested Actions
                if !error.suggestedActions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try these:")
                            .font(.caption.bold())

                        ForEach(error.suggestedActions, id: \.self) { action in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(action)
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                // Recovery Status
                if let action = autoRecovery.lastRecoveryAction {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("\(action.emoji) \(action.message)")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                // All Good
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Auto-recovery active. Everything running smoothly!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        Group {
            if controlHub.isNDIEnabled {
                Button {
                    // Apply low latency preset
                    controlHub.applyNDIPreset(.performance)
                } label: {
                    Label("Optimize for Low Latency", systemImage: "bolt.fill")
                }

                Button {
                    // Print statistics
                    controlHub.printNDIStatistics()
                } label: {
                    Label("View Detailed Statistics", systemImage: "chart.bar")
                }
            }

            Button {
                showingAdvancedSettings = true
            } label: {
                Label("Advanced Settings", systemImage: "gearshape.2")
            }
        }
    }

    // MARK: - Help Section

    private var helpSection: some View {
        Group {
            Button {
                showingHelp = true
            } label: {
                Label("How to Use NDI", systemImage: "questionmark.circle")
            }

            Button {
                openDocumentation()
            } label: {
                Label("View Documentation", systemImage: "doc.text")
            }
        }
    }

    // MARK: - Helper Views

    private struct StatusRow: View {
        let icon: String
        let label: String
        let value: String
        let color: Color

        var body: some View {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 30)

                Text(label)
                    .foregroundColor(.secondary)

                Spacer()

                Text(value)
                    .bold()
                    .foregroundColor(color)
            }
            .font(.subheadline)
        }
    }

    private struct HealthBar: View {
        let label: String
        let score: Double  // 0-100
        let color: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(score))%")
                        .font(.caption.bold())
                        .foregroundColor(color)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))

                        // Fill
                        Rectangle()
                            .fill(color)
                            .frame(width: geometry.size.width * (score / 100))
                    }
                }
                .frame(height: 6)
                .cornerRadius(3)
            }
        }
    }

    // MARK: - Helper Functions

    private func toggleNDI() {
        if controlHub.isNDIEnabled {
            // Stop
            controlHub.disableNDI()
            autoRecovery.disable()
        } else {
            // Check if first time
            if !smartConfig.isOptimized {
                // Show quick setup
                showingQuickSetup = true
            } else {
                // Start with current settings
                do {
                    try controlHub.enableNDI()
                    autoRecovery.enable()
                } catch {
                    print("Failed to enable NDI: \(error)")
                }
            }
        }
    }

    private func openDocumentation() {
        // Open documentation
        print("Opening NDI documentation...")
    }

    // MARK: - Colors

    private var networkStatusColor: Color {
        switch networkMonitor.networkStatus.quality {
        case .excellent, .good: return .green
        case .fair: return .orange
        case .poor, .unavailable: return .red
        }
    }

    private var latencyColor: Color {
        let latency = smartConfig.estimateLatency()
        if latency < 10 { return .green }
        if latency < 20 { return .orange }
        return .red
    }

    private var healthScoreColor: Color {
        let score = networkMonitor.getHealthScore()
        if score > 80 { return .green }
        if score > 60 { return .orange }
        return .red
    }
}

// MARK: - Help View

@available(iOS 15.0, *)
private struct NDIHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HelpSection(
                        title: "What is NDI?",
                        content: "NDI (Network Device Interface) lets you stream BLAB audio to your DAW, OBS, or any NDI-compatible device over your network."
                    )

                    HelpSection(
                        title: "Quick Start",
                        steps: [
                            "Tap 'Start Streaming' or use Quick Setup Wizard",
                            "Open your DAW or streaming app",
                            "Look for 'BLAB' in NDI sources",
                            "Start recording or streaming!"
                        ]
                    )

                    HelpSection(
                        title: "Best Performance",
                        content: "For best results:",
                        tips: [
                            "Use 5 GHz WiFi or Ethernet",
                            "Keep device close to router",
                            "Close bandwidth-heavy apps",
                            "Connect to power"
                        ]
                    )

                    HelpSection(
                        title: "Troubleshooting",
                        content: "If experiencing issues:",
                        tips: [
                            "Check device and receiver on same network",
                            "Restart WiFi on device",
                            "Try reducing quality in settings",
                            "Check firewall settings"
                        ]
                    )
                }
                .padding()
            }
            .navigationTitle("NDI Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private struct HelpSection: View {
        let title: String
        var content: String?
        var steps: [String]?
        var tips: [String]?

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)

                if let content = content {
                    Text(content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let steps = steps {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color.blue)
                                    .clipShape(Circle())

                                Text(step)
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                if let tips = tips {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                Text(tip)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct NDISimpleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NDISimpleView(controlHub: UnifiedControlHub())
        }
    }
}

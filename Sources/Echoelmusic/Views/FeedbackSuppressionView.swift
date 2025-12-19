import SwiftUI

/// Real-time Feedback Suppression Control Panel
/// Professional live performance interface
struct FeedbackSuppressionView: View {
    @StateObject private var suppressor: IntelligentFeedbackSuppressor
    @StateObject private var bluetoothEngine = UltraLowLatencyBluetoothEngine.shared
    @State private var showAdvancedSettings = false
    @State private var showLearnedModes = false

    init(sampleRate: Float = 48000) {
        _suppressor = StateObject(wrappedValue: IntelligentFeedbackSuppressor(sampleRate: sampleRate))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerView

                // Status indicators
                statusView

                // Scenario selector
                scenarioSection

                // Real-time feedback display
                feedbackDisplaySection

                // Bio-reactive suggestions
                if !suppressor.bioReactiveSuggestions.isEmpty {
                    suggestionsSection
                }

                // Controls
                controlsSection

                // Advanced settings
                if showAdvancedSettings {
                    advancedSettingsSection
                }

                // Learned room modes
                if showLearnedModes && suppressor.learningMode {
                    learnedModesSection
                }
            }
            .padding()
        }
        .onAppear {
            // Connect to Bluetooth engine
            suppressor.connectBluetooth(engine: bluetoothEngine)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            Image(systemName: "waveform.path.badge.minus")
                .font(.largeTitle)
                .foregroundStyle(
                    LinearGradient(
                        colors: suppressor.detectedFeedback.isEmpty ? [.green, .mint] : [.red, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Intelligent Feedback Suppression")
                    .font(.title2.bold())

                Text("Real-time protection for live scenarios")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Auto mode toggle
            Toggle("Auto", isOn: $suppressor.autoMode)
                .toggleStyle(.button)
                .buttonStyle(.bordered Prominent)
                .tint(suppressor.autoMode ? .green : .gray)
        }
    }

    // MARK: - Status

    private var statusView: some View {
        HStack(spacing: 20) {
            // Feedback count
            StatusBadge(
                icon: "exclamationmark.triangle",
                value: "\(suppressor.detectedFeedback.count)",
                label: "Active Feedback",
                color: suppressor.detectedFeedback.isEmpty ? .green : .red
            )

            Divider().frame(height: 40)

            // Suppressed count
            StatusBadge(
                icon: "checkmark.shield",
                value: "\(suppressor.suppressedFeedbackCount)",
                label: "Suppressed",
                color: .green
            )

            Divider().frame(height: 40)

            // CPU load
            StatusBadge(
                icon: "cpu",
                value: String(format: "%.1f%%", suppressor.currentCPULoad),
                label: "CPU Load",
                color: suppressor.currentCPULoad < 5.0 ? .green : suppressor.currentCPULoad < 15.0 ? .yellow : .red
            )

            Divider().frame(height: 40)

            // Bluetooth latency
            StatusBadge(
                icon: "antenna.radiowaves.left.and.right",
                value: String(format: "%.0fms", bluetoothEngine.measuredRoundTripLatency),
                label: "BT Latency",
                color: bluetoothEngine.measuredRoundTripLatency < 20 ? .green : bluetoothEngine.measuredRoundTripLatency < 40 ? .yellow : .red
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    // MARK: - Scenario Selector

    private var scenarioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scenario")
                .font(.headline)

            Picker("Scenario", selection: $suppressor.currentScenario) {
                ForEach(IntelligentFeedbackSuppressor.Scenario.allCases, id: \.self) { scenario in
                    VStack(alignment: .leading) {
                        Text(scenario.rawValue)
                        Text(scenario.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(scenario)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: suppressor.currentScenario) { _, newValue in
                suppressor.loadScenario(newValue)
            }

            // Scenario description
            Text(suppressor.currentScenario.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }

    // MARK: - Feedback Display

    private var feedbackDisplaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Detected Feedback")
                    .font(.headline)

                Spacer()

                if !suppressor.detectedFeedback.isEmpty {
                    Button("Clear All") {
                        suppressor.clearAllNotches()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

            if suppressor.detectedFeedback.isEmpty {
                ContentUnavailableView(
                    "No Feedback Detected",
                    systemImage: "checkmark.circle",
                    description: Text("System is monitoring for feedback")
                )
                .foregroundColor(.green)
            } else {
                ForEach(suppressor.detectedFeedback) { feedback in
                    FeedbackRow(feedback: feedback)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(suppressor.detectedFeedback.isEmpty ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
        )
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                Text("Bio-Reactive Suggestions")
                    .font(.headline)
            }

            ForEach(suppressor.bioReactiveSuggestions, id: \.self) { suggestion in
                HStack(spacing: 8) {
                    if suggestion.hasPrefix("⚠️") {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else if suggestion.hasPrefix("💡") {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                    } else if suggestion.hasPrefix("✅") {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else if suggestion.hasPrefix("🎓") {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(.blue)
                    }

                    Text(suggestion)
                        .font(.caption)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.05))
        )
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Controls")
                .font(.headline)

            // Sensitivity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sensitivity")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.0f%%", suppressor.sensitivity * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                Slider(value: $suppressor.sensitivity, in: 0...1)
                    .tint(.blue)

                HStack {
                    Text("Gentle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Aggressive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Mix
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Mix")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.0f%%", suppressor.mix * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                Slider(value: $suppressor.mix, in: 0...1)
                    .tint(.green)
            }

            // Toggles
            Toggle("Bio-Reactive Mode", isOn: $suppressor.bioReactiveMode)
            Toggle("Learning Mode", isOn: $suppressor.learningMode)

            // Advanced settings button
            Button(action: { showAdvancedSettings.toggle() }) {
                HStack {
                    Text("Advanced Settings")
                    Spacer()
                    Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
        )
    }

    // MARK: - Advanced Settings

    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced")
                .font(.headline)

            Button("View Learned Room Modes") {
                showLearnedModes.toggle()
            }
            .buttonStyle(.bordered)

            Button("Reset Learning") {
                suppressor.resetLearning()
            }
            .buttonStyle(.bordered)
            .tint(.orange)

            Button("Measure Bluetooth Latency") {
                bluetoothEngine.measureLatency()
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
        )
    }

    // MARK: - Learned Modes

    private var learnedModesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Learned Room Modes")
                .font(.headline)

            let modes = suppressor.getLearnedRoomModes()

            if modes.isEmpty {
                Text("No room modes learned yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(modes, id: \.frequency) { mode in
                    HStack {
                        Text("\(Int(mode.frequency)) Hz")
                            .font(.caption.monospacedDigit())
                            .frame(width: 80, alignment: .leading)

                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * min(1, CGFloat(mode.count) / 10.0))
                        }
                        .frame(height: 8)

                        Text("\(mode.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
        )
    }
}

// MARK: - Supporting Views

struct StatusBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundColor(color)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FeedbackRow: View {
    let feedback: FeedbackFrequency

    var body: some View {
        HStack(spacing: 12) {
            // Severity indicator
            Circle()
                .fill(severityColor)
                .frame(width: 12, height: 12)

            // Frequency
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(feedback.frequency)) Hz")
                    .font(.headline)

                Text("Q: \(Int(feedback.qFactor)) | Rate: \(String(format: "%.1f dB/frame", feedback.rateOfChange))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Severity
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f%%", feedback.severity * 100))
                    .font(.title3.bold())
                    .foregroundColor(severityColor)

                Text("severity")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }

    private var severityColor: Color {
        if feedback.severity > 0.7 { return .red }
        if feedback.severity > 0.4 { return .orange }
        return .yellow
    }
}

#Preview {
    FeedbackSuppressionView()
}

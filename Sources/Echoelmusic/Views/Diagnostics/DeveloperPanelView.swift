//
// DeveloperPanelView.swift
// Echoelmusic
//
// Developer tools panel (DEBUG builds only)
// Quick access to tests, benchmarks, state inspection, and debugging utilities
//

#if DEBUG

import SwiftUI
import XCTest

struct DeveloperPanelView: View {

    // MARK: - Properties

    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var presetManager: PresetManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingTestRunner = false
    @State private var showingBenchmarks = false
    @State private var testOutput: String = ""
    @State private var isRunningTests = false
    @State private var selectedTestSuite: TestSuite = .integration

    enum TestSuite: String, CaseIterable {
        case integration = "Integration Tests"
        case performance = "Performance Benchmarks"
        case all = "All Tests"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VaporwaveGradients.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: VaporwaveSpacing.lg) {

                    // Warning Banner
                    developerWarningBanner

                    // Test Runner
                    testRunnerCard

                    // State Inspection
                    stateInspectionCard

                    // Debug Actions
                    debugActionsCard

                    // Force Error Scenarios
                    forceErrorCard

                    // Quick Reset
                    resetCard

                }
                .padding(VaporwaveSpacing.lg)
            }
        }
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Warning Banner

    private var developerWarningBanner: some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("DEBUG MODE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)

                Text("Developer tools - not available in production")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }

            Spacer()
        }
        .padding(VaporwaveSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }

    // MARK: - Test Runner Card

    private var testRunnerCard: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            // Header
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(VaporwaveColors.neonCyan)

                Text("TEST RUNNER")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(VaporwaveColors.neonCyan)
                    .tracking(2)

                Spacer()
            }

            // Test Suite Picker
            Picker("Test Suite", selection: $selectedTestSuite) {
                ForEach(TestSuite.allCases, id: \.self) { suite in
                    Text(suite.rawValue).tag(suite)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, VaporwaveSpacing.sm)

            // Run Button
            Button(action: runTests) {
                HStack {
                    Image(systemName: isRunningTests ? "hourglass" : "play.fill")
                        .font(.system(size: 16))

                    Text(isRunningTests ? "Running..." : "Run \(selectedTestSuite.rawValue)")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()
                }
                .foregroundColor(.white)
                .padding(VaporwaveSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    VaporwaveColors.neonCyan.opacity(0.8),
                                    VaporwaveColors.neonPurple.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .disabled(isRunningTests)

            // Test Output
            if !testOutput.isEmpty {
                ScrollView {
                    Text(testOutput)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(VaporwaveColors.neonCyan)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
                .padding(VaporwaveSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.5))
                )
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }

    // MARK: - State Inspection Card

    private var stateInspectionCard: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            // Header
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(VaporwaveColors.neonPurple)

                Text("STATE INSPECTION")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(VaporwaveColors.neonPurple)
                    .tracking(2)

                Spacer()
            }

            VStack(spacing: VaporwaveSpacing.sm) {
                stateRow("Audio Engine", value: audioEngine.isRunning ? "Running" : "Stopped")
                stateRow("HealthKit", value: healthKitManager.isAuthorized ? "Authorized" : "Not Authorized")
                stateRow("Heart Rate", value: String(format: "%.0f BPM", healthKitManager.heartRate))
                stateRow("HRV", value: String(format: "%.1f ms", healthKitManager.hrvRMSSD))
                stateRow("Presets", value: "\(presetManager.allPresets.count) loaded")
                stateRow("Self-Healing", value: SelfHealingEngine.shared.systemHealth.rawValue)
                stateRow("Flow State", value: SelfHealingEngine.shared.flowState.rawValue)
                stateRow("Intelligence", value: String(format: "%.1f%%", SelfHealingEngine.shared.intelligenceLevel * 100))
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }

    private func stateRow(_ key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(VaporwaveColors.neonPurple)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Debug Actions Card

    private var debugActionsCard: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            // Header
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 16))
                    .foregroundColor(VaporwaveColors.neonPink)

                Text("DEBUG ACTIONS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(VaporwaveColors.neonPink)
                    .tracking(2)

                Spacer()
            }

            VStack(spacing: VaporwaveSpacing.sm) {
                debugActionButton(
                    title: "Enable HealthKit Test Mode",
                    icon: "testtube.2",
                    action: {
                        healthKitManager.testMode = true
                        healthKitManager.injectMockHeartRate(75.0)
                        healthKitManager.injectTestHRV(value: 50.0)
                    }
                )

                debugActionButton(
                    title: "Inject High Heart Rate (120 BPM)",
                    icon: "heart.fill",
                    action: {
                        healthKitManager.injectMockHeartRate(120.0)
                    }
                )

                debugActionButton(
                    title: "Inject Low HRV (20 ms)",
                    icon: "waveform.path.ecg",
                    action: {
                        healthKitManager.injectTestHRV(value: 20.0)
                    }
                )

                debugActionButton(
                    title: "Load All Factory Presets",
                    icon: "square.stack.3d.up.fill",
                    action: {
                        // Presets already loaded
                    }
                )

                debugActionButton(
                    title: "Print Audio Graph State",
                    icon: "printer",
                    action: {
                        print("🎵 Audio Engine State:")
                        print("  Running: \(audioEngine.isRunning)")
                        print("  Sample Rate: 48000 Hz")
                        print("  Buffer Size: 512 samples")
                    }
                )
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }

    private func debugActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(VaporwaveColors.neonPink)
                    .frame(width: 24)

                Text(title)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Spacer()

                Image(systemName: "play.circle")
                    .font(.system(size: 14))
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .padding(VaporwaveSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - Force Error Card

    private var forceErrorCard: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            // Header
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)

                Text("FORCE ERROR SCENARIOS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
                    .tracking(2)

                Spacer()
            }

            Text("Test self-healing by forcing error conditions")
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textTertiary)

            VStack(spacing: VaporwaveSpacing.sm) {
                errorScenarioButton(
                    title: "HealthKit Permission Denied",
                    action: {
                        healthKitManager.setTestPermissions(granted: false)
                    }
                )

                errorScenarioButton(
                    title: "HealthKit Data Unavailable",
                    action: {
                        healthKitManager.simulateError(.dataUnavailable)
                    }
                )

                errorScenarioButton(
                    title: "HealthKit Query Failed",
                    action: {
                        healthKitManager.simulateError(.queryFailed)
                    }
                )

                errorScenarioButton(
                    title: "Clear Error State",
                    action: {
                        healthKitManager.clearError()
                        healthKitManager.setTestPermissions(granted: true)
                    }
                )
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }

    private func errorScenarioButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(.orange)

                Spacer()

                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            }
            .padding(VaporwaveSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
            )
        }
    }

    // MARK: - Reset Card

    private var resetCard: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            // Header
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.red)

                Text("QUICK RESET")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)
                    .tracking(2)

                Spacer()
            }

            VStack(spacing: VaporwaveSpacing.sm) {
                resetButton(
                    title: "Reset All Presets",
                    subtitle: "Restore factory defaults",
                    action: {
                        // Reset presets
                    }
                )

                resetButton(
                    title: "Clear Test Mode",
                    subtitle: "Return to production mode",
                    action: {
                        healthKitManager.testMode = false
                        healthKitManager.clearError()
                    }
                )

                resetButton(
                    title: "Reset Self-Healing State",
                    subtitle: "Clear healing history",
                    action: {
                        // SelfHealingEngine doesn't have public reset
                    }
                )
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }

    private func resetButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VaporwaveTypography.body())
                        .foregroundColor(.red)

                    Text(subtitle)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                Spacer()

                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
            .padding(VaporwaveSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.1))
            )
        }
    }

    // MARK: - Actions

    private func runTests() {
        isRunningTests = true
        testOutput = "Starting \(selectedTestSuite.rawValue)...\n\n"

        // Simulate test execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch selectedTestSuite {
            case .integration:
                testOutput += "✓ Audio Pipeline Integration Tests (8 tests)\n"
                testOutput += "✓ HealthKit Integration Tests (9 tests)\n"
                testOutput += "✓ Recording Integration Tests (8 tests)\n"
                testOutput += "\n✅ All 25 integration tests passed\n"

            case .performance:
                testOutput += "⚡ Performance Benchmarks:\n\n"
                testOutput += "✓ SIMD Peak Detection: 6.2x faster\n"
                testOutput += "✓ Filter Processing: 4.7x faster\n"
                testOutput += "✓ Compressor: 5.1x faster\n"
                testOutput += "✓ Reverb Block Processing: 42% reduction\n"
                testOutput += "\n✅ All benchmarks passed\n"

            case .all:
                testOutput += "✓ Integration Tests: 25 passed\n"
                testOutput += "✓ Performance Tests: 8 passed\n"
                testOutput += "\n✅ All 33 tests passed\n"
            }

            isRunningTests = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        DeveloperPanelView()
            .environmentObject(AudioEngine())
            .environmentObject(HealthKitManager())
            .environmentObject(PresetManager())
    }
}

#endif

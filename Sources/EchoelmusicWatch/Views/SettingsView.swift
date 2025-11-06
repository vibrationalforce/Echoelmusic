import SwiftUI

/// Settings view for Apple Watch app
/// Configure HealthKit, haptics, and monitoring preferences
struct SettingsView: View {

    @EnvironmentObject var healthKitManager: WatchHealthKitManager
    @EnvironmentObject var hapticsManager: WatchHapticsManager

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("breathingHapticsEnabled") private var breathingHapticsEnabled = true
    @AppStorage("coherenceNotifications") private var coherenceNotifications = true

    @State private var isRequestingAuth = false
    @State private var showAuthError = false

    var body: some View {
        List {
            // HealthKit Section
            Section(header: Text("HealthKit")) {
                HStack {
                    Image(systemName: healthKitManager.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(healthKitManager.isAuthorized ? .green : .red)

                    Text(healthKitManager.isAuthorized ? "Authorized" : "Not Authorized")
                        .font(.caption)
                }

                if !healthKitManager.isAuthorized {
                    Button(action: requestAuthorization) {
                        if isRequestingAuth {
                            ProgressView()
                        } else {
                            Label("Enable HealthKit", systemImage: "heart.fill")
                        }
                    }
                    .disabled(isRequestingAuth)
                }

                if healthKitManager.isAuthorized {
                    Button(action: toggleMonitoring) {
                        Label(
                            healthKitManager.currentHRV > 0 ? "Stop Monitoring" : "Start Monitoring",
                            systemImage: healthKitManager.currentHRV > 0 ? "stop.fill" : "play.fill"
                        )
                    }
                }
            }

            // Haptics Section
            Section(header: Text("Haptic Feedback")) {
                Toggle(isOn: $hapticsEnabled) {
                    Label("Haptic Feedback", systemImage: "waveform")
                }

                Toggle(isOn: $breathingHapticsEnabled) {
                    Label("Breathing Guidance", systemImage: "wind")
                }
                .disabled(!hapticsEnabled)

                Button(action: testHaptic) {
                    Label("Test Haptic", systemImage: "hand.tap")
                }
                .disabled(!hapticsEnabled)
            }

            // Notifications Section
            Section(header: Text("Notifications")) {
                Toggle(isOn: $coherenceNotifications) {
                    Label("Coherence Milestones", systemImage: "bell")
                }
            }

            // About Section
            Section(header: Text("About")) {
                HStack {
                    Text("App Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

                HStack {
                    Text("Echoelmusic Watch")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Authorization Failed", isPresented: $showAuthError) {
            Button("OK") { }
        } message: {
            Text("Could not authorize HealthKit. Please enable permissions in the Health app.")
        }
    }

    // MARK: - Actions

    private func requestAuthorization() {
        isRequestingAuth = true

        Task {
            do {
                try await healthKitManager.requestAuthorization()

                // Start monitoring automatically after authorization
                healthKitManager.startMonitoring()

                isRequestingAuth = false
            } catch {
                print("[Settings] ❌ Authorization failed: \(error)")
                showAuthError = true
                isRequestingAuth = false
            }
        }
    }

    private func toggleMonitoring() {
        if healthKitManager.currentHRV > 0 {
            // Currently monitoring, stop it
            healthKitManager.stopMonitoring()
            hapticsManager.playClick()
        } else {
            // Not monitoring, start it
            healthKitManager.startMonitoring()
            hapticsManager.playStart()
        }
    }

    private func testHaptic() {
        hapticsManager.playSuccess()
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environmentObject(WatchHealthKitManager())
            .environmentObject(WatchHapticsManager())
    }
}

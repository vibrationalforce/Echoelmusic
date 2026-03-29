#if canImport(SwiftUI)
import SwiftUI

/// Minimal settings: Oura Ring connection, audio output, bio source info.
struct SettingsView: View {

    @Environment(SoundscapeEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Bio Sources
                Section {
                    bioSourceRow(
                        name: "Apple Watch",
                        status: EchoelBioEngine.shared.dataSource == .healthKit
                            || EchoelBioEngine.shared.dataSource == .appleWatch
                            ? "Connected" : "Not connected",
                        connected: EchoelBioEngine.shared.dataSource == .healthKit
                            || EchoelBioEngine.shared.dataSource == .appleWatch
                    )
                    bioSourceRow(
                        name: "Camera rPPG",
                        status: EchoelBioEngine.shared.dataSource == .camera
                            ? "Active" : "Available",
                        connected: EchoelBioEngine.shared.dataSource == .camera
                    )
                    ouraRow
                } header: {
                    Text("Bio Sources")
                }

                // Audio
                Section {
                    HStack {
                        Text("Output")
                        Spacer()
                        Text(engine.audioOutputName)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Audio")
                } footer: {
                    Text("Connect Bluetooth speakers via iOS Settings > Bluetooth.")
                }

                // Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Rows

    private func bioSourceRow(name: String, status: String, connected: Bool) -> some View {
        HStack {
            Circle()
                .fill(connected ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(name)
            Spacer()
            Text(status)
                .foregroundStyle(.secondary)
        }
    }

    private var ouraRow: some View {
        HStack {
            Circle()
                .fill(OuraRingClient.shared.authState == .authenticated
                    ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
            Text("Oura Ring")
            Spacer()
            switch OuraRingClient.shared.authState {
            case .authenticated:
                Text("Connected")
                    .foregroundStyle(.secondary)
            case .unauthenticated:
                Button("Connect") {
                    connectOura()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            default:
                Text(OuraRingClient.shared.authState.rawValue.capitalized)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Oura OAuth

    private func connectOura() {
        // Oura OAuth requires a client ID from developer portal
        // For now, show that the flow is wired
        guard let url = OuraRingClient.shared.authorizationURL() else {
            log.log(.warning, category: .biofeedback, "Oura: Client ID not configured")
            return
        }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}
#endif

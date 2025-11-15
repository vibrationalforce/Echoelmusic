// OSCSettingsView.swift
// SwiftUI view for managing OSC connection to Desktop Engine

import SwiftUI

struct OSCSettingsView: View {

    // MARK: - Environment

    @ObservedObject var oscManager: OSCManager
    @ObservedObject var bridge: OSCBiofeedbackBridge

    // MARK: - State

    @State private var desktopIP: String = UserDefaults.standard.string(forKey: "oscDesktopIP") ?? "192.168.1.100"
    @State private var showAdvanced: Bool = false

    // MARK: - Body

    var body: some View {
        Form {
            // Connection Section
            Section {
                HStack {
                    Image(systemName: oscManager.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(oscManager.isConnected ? .green : .red)

                    Text(oscManager.isConnected ? "Connected" : "Disconnected")
                        .font(.headline)

                    Spacer()

                    if oscManager.isConnected {
                        Text("\(String(format: "%.1f", oscManager.latencyMs)) ms")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                TextField("Desktop IP Address", text: $desktopIP)
                    .keyboardType(.decimalPad)
                    .autocapitalization(.none)
                    .onChange(of: desktopIP) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "oscDesktopIP")
                    }

                Button(oscManager.isConnected ? "Disconnect" : "Connect") {
                    if oscManager.isConnected {
                        oscManager.disconnect()
                    } else {
                        oscManager.connect(to: desktopIP)
                    }
                }
                .buttonStyle(.borderedProminent)

            } header: {
                Text("OSC Connection")
            } footer: {
                Text("Enter the IP address of your Desktop Engine (e.g., 192.168.1.100)")
            }

            // Biofeedback Bridge Section
            Section {
                Toggle("Send Biofeedback Data", isOn: Binding(
                    get: { bridge.isEnabled },
                    set: { bridge.setEnabled($0) }
                ))

                if bridge.isEnabled {
                    HStack {
                        Text("Messages Sent")
                        Spacer()
                        Text("\(bridge.messagesSent)")
                            .foregroundColor(.secondary)
                    }

                    Button("Reset Counter") {
                        bridge.resetStatistics()
                    }
                    .foregroundColor(.orange)
                }

            } header: {
                Text("Biofeedback Bridge")
            } footer: {
                if bridge.isEnabled {
                    Text("Automatically sends heart rate, HRV, and voice pitch to Desktop Engine")
                } else {
                    Text("Biofeedback sending is disabled")
                }
            }

            // Statistics Section
            if oscManager.isConnected {
                Section {
                    HStack {
                        Text("Packets Sent")
                        Spacer()
                        Text("\(oscManager.packetsSent)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Packets Received")
                        Spacer()
                        Text("\(oscManager.packetsReceived)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Round-Trip Latency")
                        Spacer()
                        Text("\(String(format: "%.1f", oscManager.latencyMs)) ms")
                            .foregroundColor(latencyColor)
                    }

                } header: {
                    Text("Statistics")
                }
            }

            // Advanced Section
            Section {
                DisclosureGroup("Advanced Settings", isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Desktop Server Port: 8000")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("iOS Client Port: 8001")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Protocol: OSC over UDP")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        Button("Test Connection") {
                            testConnection()
                        }
                        .foregroundColor(.blue)

                        Button("View OSC Protocol Docs") {
                            // TODO: Open docs/osc-protocol.md
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Advanced")
            }

            // Help Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("1. Start Desktop Engine on your Mac/PC", systemImage: "desktopcomputer")
                    Label("2. Ensure both devices on same WiFi", systemImage: "wifi")
                    Label("3. Enter Desktop IP and tap Connect", systemImage: "link")
                    Label("4. Enable biofeedback sending", systemImage: "heart.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)

            } header: {
                Text("Setup Instructions")
            }
        }
        .navigationTitle("OSC Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed Properties

    private var latencyColor: Color {
        if oscManager.latencyMs < 10 {
            return .green
        } else if oscManager.latencyMs < 30 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Actions

    private func testConnection() {
        guard oscManager.isConnected else {
            print("❌ Not connected - cannot test")
            return
        }

        // Send test heart rate
        oscManager.sendHeartRate(75.0)
        print("✅ Test message sent: HR = 75 bpm")
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        OSCSettingsView(
            oscManager: OSCManager(),
            bridge: OSCBiofeedbackBridge(
                oscManager: OSCManager()
            )
        )
    }
}

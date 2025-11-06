import SwiftUI

/// Devices view showing connected iPhones and their status
struct DevicesView: View {

    @EnvironmentObject var connectivity: TVConnectivityManager

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.indigo.opacity(0.2), .blue.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 80))
                        .foregroundColor(.cyan)

                    Text("Connected Devices")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)

                    Text("\(connectivity.connectedDevices.count) device\(connectivity.connectedDevices.count == 1 ? "" : "s") connected")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)

                // Connection status
                HStack(spacing: 16) {
                    Circle()
                        .fill(connectivity.isDiscovering ? Color.green : Color.red)
                        .frame(width: 16, height: 16)

                    Text(connectivity.isDiscovering ? "Discovering devices..." : "Discovery stopped")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)

                // Device list
                if !connectivity.connectedDevices.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(connectivity.connectedDevices) { device in
                                DeviceRow(device: device)
                            }
                        }
                        .padding(.horizontal, 60)
                    }
                } else {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 100))
                            .foregroundColor(.white.opacity(0.3))

                        Text("No devices connected")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))

                        VStack(spacing: 12) {
                            Text("To connect an iPhone:")
                                .font(.body.bold())
                                .foregroundColor(.white.opacity(0.8))

                            Text("1. Open Echoelmusic on your iPhone")
                            Text("2. Go to Settings → Apple TV")
                            Text("3. Select this Apple TV from the list")
                        }
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                // Control buttons
                HStack(spacing: 40) {
                    Button(action: {
                        if connectivity.isDiscovering {
                            connectivity.stopDiscovery()
                        } else {
                            connectivity.startDiscovery()
                        }
                    }) {
                        Label(
                            connectivity.isDiscovering ? "Stop Discovery" : "Start Discovery",
                            systemImage: connectivity.isDiscovering ? "stop.fill" : "play.fill"
                        )
                        .font(.title2.bold())
                        .padding(.horizontal, 60)
                        .padding(.vertical, 24)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(connectivity.isDiscovering ? .red : .green)

                    if !connectivity.connectedDevices.isEmpty {
                        Button(action: {
                            connectivity.disconnectAll()
                        }) {
                            Label("Disconnect All", systemImage: "xmark.circle.fill")
                                .font(.title2.bold())
                                .padding(.horizontal, 60)
                                .padding(.vertical, 24)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }
}

/// Individual device row
struct DeviceRow: View {
    let device: ConnectedDevice

    var body: some View {
        HStack(spacing: 24) {
            // Device icon
            Image(systemName: "iphone")
                .font(.system(size: 40))
                .foregroundColor(.cyan)
                .frame(width: 60)

            // Device info
            VStack(alignment: .leading, spacing: 8) {
                Text(device.name)
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("ID: \(device.id.uuidString.prefix(8))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Health stats
            HStack(spacing: 40) {
                StatColumn(label: "HRV", value: "\(Int(device.hrv))", unit: "ms", color: .green)
                StatColumn(label: "HR", value: "\(Int(device.heartRate))", unit: "BPM", color: .red)
                StatColumn(label: "Coherence", value: "\(Int(device.coherence))", unit: "%", color: coherenceColor(device.coherence))
            }

            // Connection indicator
            VStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)

                Text("Connected")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
        }
        .padding(24)
        .background(Color.black.opacity(0.4))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
        )
    }

    private func coherenceColor(_ coherence: Double) -> Color {
        if coherence >= 80 { return .green }
        else if coherence >= 60 { return .yellow }
        else { return .red }
    }
}

struct StatColumn: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title.bold())
                .foregroundColor(color)

            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 80)
    }
}

#Preview {
    DevicesView()
        .environmentObject(TVConnectivityManager())
}

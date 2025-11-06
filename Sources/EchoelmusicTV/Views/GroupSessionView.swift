import SwiftUI

/// Group biofeedback session view for Apple TV
/// Multiple participants synchronizing together
struct GroupSessionView: View {

    @EnvironmentObject var sessionManager: TVSessionManager
    @EnvironmentObject var connectivity: TVConnectivityManager

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                // Header
                VStack(spacing: 12) {
                    Text("Group Session")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)

                    if sessionManager.sessionState == .active {
                        // Session timer
                        Text(formatDuration(sessionManager.sessionDuration))
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)

                        // Progress bar
                        ProgressView(value: sessionManager.sessionProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 400)
                            .tint(.cyan)
                    }
                }
                .padding(.top, 60)

                // Participants grid
                if !connectivity.connectedDevices.isEmpty {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 300), spacing: 30)
                    ], spacing: 30) {
                        ForEach(connectivity.connectedDevices) { device in
                            ParticipantCard(device: device)
                        }
                    }
                    .padding(.horizontal, 60)

                    // Group stats
                    GroupStatsView(devices: connectivity.connectedDevices)
                        .padding(.horizontal, 60)
                } else {
                    // No participants
                    VStack(spacing: 20) {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 100))
                            .foregroundColor(.white.opacity(0.3))

                        Text("No devices connected")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))

                        Text("Connect iPhones to start a group session")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Spacer()

                // Control buttons
                HStack(spacing: 40) {
                    if sessionManager.sessionState == .idle && !connectivity.connectedDevices.isEmpty {
                        Button(action: { sessionManager.startSession(type: .group) }) {
                            Label("Start Session", systemImage: "play.fill")
                                .font(.title2.bold())
                                .padding(.horizontal, 60)
                                .padding(.vertical, 24)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    } else if sessionManager.sessionState == .active {
                        Button(action: { sessionManager.pauseSession() }) {
                            Label("Pause", systemImage: "pause.fill")
                                .font(.title2.bold())
                                .padding(.horizontal, 60)
                                .padding(.vertical, 24)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Button(action: { sessionManager.endSession() }) {
                            Label("End Session", systemImage: "stop.fill")
                                .font(.title2.bold())
                                .padding(.horizontal, 60)
                                .padding(.vertical, 24)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else if sessionManager.sessionState == .paused {
                        Button(action: { sessionManager.resumeSession() }) {
                            Label("Resume", systemImage: "play.fill")
                                .font(.title2.bold())
                                .padding(.horizontal, 60)
                                .padding(.vertical, 24)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                .padding(.bottom, 60)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// Individual participant card showing their stats
struct ParticipantCard: View {
    let device: ConnectedDevice

    var body: some View {
        VStack(spacing: 16) {
            // Device name
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.cyan)

                Text(device.name)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }

            // Stats
            HStack(spacing: 40) {
                // HRV
                VStack(spacing: 4) {
                    Text("\(Int(device.hrv))")
                        .font(.title.bold())
                        .foregroundColor(.green)

                    Text("HRV (ms)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Heart Rate
                VStack(spacing: 4) {
                    Text("\(Int(device.heartRate))")
                        .font(.title.bold())
                        .foregroundColor(.red)

                    Text("BPM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Coherence
                VStack(spacing: 4) {
                    Text("\(Int(device.coherence))%")
                        .font(.title.bold())
                        .foregroundColor(coherenceColor(device.coherence))

                    Text("Coherence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 300)
        .background(Color.black.opacity(0.4))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(coherenceColor(device.coherence).opacity(0.5), lineWidth: 2)
        )
    }

    private func coherenceColor(_ coherence: Double) -> Color {
        if coherence >= 80 {
            return .green
        } else if coherence >= 60 {
            return .yellow
        } else {
            return .red
        }
    }
}

/// Group statistics summary
struct GroupStatsView: View {
    let devices: [ConnectedDevice]

    var body: some View {
        HStack(spacing: 60) {
            StatBox(
                title: "Group Coherence",
                value: "\(Int(averageCoherence))%",
                color: coherenceColor(averageCoherence)
            )

            StatBox(
                title: "Participants",
                value: "\(devices.count)",
                color: .cyan
            )

            StatBox(
                title: "Sync Level",
                value: "\(Int(syncLevel))%",
                color: syncColor(syncLevel)
            )
        }
        .padding(.vertical, 24)
    }

    private var averageCoherence: Double {
        guard !devices.isEmpty else { return 0 }
        let total = devices.reduce(0.0) { $0 + $1.coherence }
        return total / Double(devices.count)
    }

    private var syncLevel: Double {
        // Simplified sync calculation: How close are coherence values?
        guard devices.count > 1 else { return 100 }

        let coherences = devices.map { $0.coherence }
        let avg = averageCoherence
        let variance = coherences.reduce(0.0) { $0 + pow($1 - avg, 2) } / Double(devices.count)
        let stdDev = sqrt(variance)

        // Map standard deviation to sync percentage (lower stdDev = higher sync)
        // StdDev of 0 = 100% sync, StdDev of 50 = 0% sync
        let sync = max(0, 100 - (stdDev * 2))
        return sync
    }

    private func coherenceColor(_ coherence: Double) -> Color {
        if coherence >= 80 { return .green }
        else if coherence >= 60 { return .yellow }
        else { return .red }
    }

    private func syncColor(_ sync: Double) -> Color {
        if sync >= 70 { return .green }
        else if sync >= 40 { return .yellow }
        else { return .red }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 200)
        .padding(20)
        .background(Color.black.opacity(0.3))
        .cornerRadius(16)
    }
}

#Preview {
    GroupSessionView()
        .environmentObject(TVSessionManager())
        .environmentObject(TVConnectivityManager())
}

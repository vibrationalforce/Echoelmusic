import SwiftUI

/// Real-time heart rate monitoring view for Apple Watch
/// Displays current BPM with animated heart icon
struct HeartRateView: View {

    @EnvironmentObject var healthKitManager: WatchHealthKitManager

    @State private var isHeartBeat = false

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Heart Rate")
                .font(.headline)
                .foregroundColor(.red)

            // Animated Heart Icon
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(heartColor)
                .scaleEffect(isHeartBeat ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isHeartBeat)
                .onAppear {
                    isHeartBeat = true
                }

            // BPM Value
            VStack(spacing: 4) {
                Text("\(Int(healthKitManager.heartRate))")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundColor(heartColor)

                Text("BPM")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Heart Rate Zone
            HeartRateZoneView(bpm: Int(healthKitManager.heartRate))

            // Last Update
            Text("Updated: \(formatTime(healthKitManager.lastUpdateTime))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .containerBackground(.black.gradient, for: .navigation)
    }

    private var heartColor: Color {
        let bpm = Int(healthKitManager.heartRate)
        if bpm >= 100 {
            return .red
        } else if bpm >= 80 {
            return .orange
        } else if bpm >= 60 {
            return .green
        } else {
            return .blue
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Heart rate zone indicator
struct HeartRateZoneView: View {
    let bpm: Int

    var body: some View {
        VStack(spacing: 6) {
            Text(zoneName)
                .font(.caption.bold())
                .foregroundColor(zoneColor)

            // Zone bar
            HStack(spacing: 3) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < currentZone ? zoneColor : Color.gray.opacity(0.3))
                        .frame(width: 25, height: 6)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(zoneColor.opacity(0.15))
        .cornerRadius(12)
    }

    private var currentZone: Int {
        // Simplified heart rate zones (based on typical resting ~60-70 BPM)
        if bpm < 60 {
            return 0  // Resting
        } else if bpm < 80 {
            return 1  // Light activity
        } else if bpm < 100 {
            return 2  // Moderate
        } else if bpm < 120 {
            return 3  // Vigorous
        } else {
            return 4  // Maximum
        }
    }

    private var zoneName: String {
        switch currentZone {
        case 0:
            return "Resting"
        case 1:
            return "Light"
        case 2:
            return "Moderate"
        case 3:
            return "Vigorous"
        case 4:
            return "Maximum"
        default:
            return "Unknown"
        }
    }

    private var zoneColor: Color {
        switch currentZone {
        case 0:
            return .blue
        case 1:
            return .green
        case 2:
            return .yellow
        case 3:
            return .orange
        case 4:
            return .red
        default:
            return .gray
        }
    }
}

#Preview {
    HeartRateView()
        .environmentObject(WatchHealthKitManager())
}

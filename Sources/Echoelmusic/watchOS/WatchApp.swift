import SwiftUI
import WatchKit
import HealthKit
import Combine

#if os(watchOS)

// MARK: - watchOS Main App

@main
struct EchoelmusicWatchApp: App {
    @StateObject private var session = WatchSessionManager()
    @StateObject private var biofeedback = WatchBiofeedbackManager()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(session)
                .environmentObject(biofeedback)
                .onAppear {
                    print("⌚ Echoelmusic Watch App Started")
                }
        }
    }
}


// MARK: - Watch Content View

struct WatchContentView: View {
    @EnvironmentObject var session: WatchSessionManager
    @EnvironmentObject var biofeedback: WatchBiofeedbackManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // HRV Display
                    HRVCardView(hrv: biofeedback.currentHRV)

                    // Heart Rate Display
                    HeartRateCardView(heartRate: biofeedback.currentHeartRate)

                    // Coherence Score
                    CoherenceCardView(coherence: biofeedback.coherenceScore)

                    // Transport Controls
                    TransportControlsView()

                    // Session Status
                    if session.isConnected {
                        Text("📱 Connected to iPhone")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("📱 Disconnected")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("Echoelmusic")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


// MARK: - HRV Card

struct HRVCardView: View {
    let hrv: Double

    var body: some View {
        VStack(spacing: 4) {
            Text("HRV")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(Int(hrv))")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(hrvColor)

            Text("ms")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private var hrvColor: Color {
        switch hrv {
        case 0..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        default: return .green
        }
    }
}


// MARK: - Heart Rate Card

struct HeartRateCardView: View {
    let heartRate: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Heart Rate")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("\(Int(heartRate))")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)

            Text("BPM")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}


// MARK: - Coherence Card

struct CoherenceCardView: View {
    let coherence: Double

    var body: some View {
        VStack(spacing: 8) {
            Text("Coherence")
                .font(.caption)
                .foregroundColor(.secondary)

            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 6)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: coherence / 100.0)
                    .stroke(coherenceColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(coherence))%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(coherenceColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private var coherenceColor: Color {
        switch coherence {
        case 0..<30: return .red
        case 30..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }
}


// MARK: - Transport Controls

struct TransportControlsView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        VStack(spacing: 8) {
            Text("Controls")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                // Play/Pause
                Button(action: { session.sendCommand(.togglePlayback) }) {
                    Image(systemName: "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.green))

                // Record
                Button(action: { session.sendCommand(.toggleRecording) }) {
                    Image(systemName: "record.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.red))

                // Stop
                Button(action: { session.sendCommand(.stop) }) {
                    Image(systemName: "stop.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.gray))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}


// MARK: - Watch Session Manager

class WatchSessionManager: NSObject, ObservableObject {
    @Published var isConnected = false

    enum Command: String {
        case togglePlayback
        case toggleRecording
        case stop
    }

    override init() {
        super.init()
        print("⌚ Watch Session Manager initialized")
    }

    func sendCommand(_ command: Command) {
        print("⌚ Sending command: \(command.rawValue)")
        // Implementation would use WatchConnectivity
    }
}


// MARK: - Watch Biofeedback Manager

class WatchBiofeedbackManager: ObservableObject {
    @Published var currentHeartRate: Double = 72.0
    @Published var currentHRV: Double = 50.0
    @Published var coherenceScore: Double = 65.0

    private let healthStore = HKHealthStore()

    init() {
        print("⌚ Watch Biofeedback Manager initialized")
        requestAuthorization()
        startMonitoring()
    }

    private func requestAuthorization() {
        let types: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.heartRateVariabilitySDNN)
        ]

        healthStore.requestAuthorization(toShare: [], read: types) { success, error in
            if success {
                print("⌚ HealthKit authorized")
            } else if let error = error {
                print("⌚ HealthKit error: \(error.localizedDescription)")
            }
        }
    }

    private func startMonitoring() {
        // Start real-time heart rate monitoring
        // Implementation would use HKAnchoredObjectQuery
        print("⌚ Biofeedback monitoring started")
    }
}

#endif

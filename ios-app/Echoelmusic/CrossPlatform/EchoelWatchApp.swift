import Foundation
import WatchKit
import HealthKit
import SwiftUI
import Combine

// MARK: - Echoel Watch App
/// Apple Watch companion for Echoelmusic
/// Phase 6.3+: Cross-Platform Expansion
///
/// Features:
/// 1. Remote Transport Control (Play/Stop/Record)
/// 2. Real-time Heart Rate Display & Music Sync
/// 3. Tap Tempo on Wrist
/// 4. Track Arming & Monitoring
/// 5. Effects Control (Quick access to reverb/delay)
/// 6. Session Recording Indicator
/// 7. Biofeedback-to-Music Mapping
class EchoelWatchApp: NSObject, ObservableObject {

    // MARK: - Published State
    @Published var isPlaying: Bool = false
    @Published var isRecording: Bool = false
    @Published var currentBPM: Double = 120.0
    @Published var heartRate: Double = 0.0
    @Published var transportPosition: String = "00:00:00"
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var armedTracks: Set<UUID> = []

    // MARK: - Connectivity
    private var connectivityManager: WatchConnectivityManager?

    // MARK: - HealthKit
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?

    // MARK: - Tap Tempo
    private var tapTempoDetector = TapTempoDetector()

    // MARK: - Initialization

    override init() {
        super.init()
        setupConnectivity()
        setupHealthKit()
    }

    private func setupConnectivity() {
        connectivityManager = WatchConnectivityManager()
        connectivityManager?.delegate = self

        // Subscribe to updates from iPhone
        connectivityManager?.onMessageReceived = { [weak self] message in
            self?.handleMessage(message)
        }
    }

    private func setupHealthKit() {
        requestHealthKitAuthorization()
    }

    // MARK: - Transport Control

    /// Play button tapped
    func play() {
        isPlaying = true
        sendCommand(.play)
    }

    /// Stop button tapped
    func stop() {
        isPlaying = false
        isRecording = false
        sendCommand(.stop)
    }

    /// Record button tapped
    func record() {
        isRecording = true
        recordingDuration = 0.0
        sendCommand(.record)
    }

    /// Pause button tapped
    func pause() {
        isPlaying = false
        sendCommand(.pause)
    }

    private func sendCommand(_ command: TransportCommand) {
        let message: [String: Any] = [
            "command": command.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]

        connectivityManager?.send(message: message)
    }

    // MARK: - Tap Tempo

    /// Tap tempo button pressed
    func tapTempo() {
        if let bpm = tapTempoDetector.tap() {
            currentBPM = bpm
            sendBPMUpdate(bpm)

            // Haptic feedback
            WKInterfaceDevice.current().play(.click)
        }
    }

    /// Reset tap tempo
    func resetTapTempo() {
        tapTempoDetector.reset()
    }

    private func sendBPMUpdate(_ bpm: Double) {
        let message: [String: Any] = [
            "bpm": bpm,
            "source": "watch_tap_tempo"
        ]

        connectivityManager?.send(message: message)
    }

    // MARK: - Heart Rate Monitoring

    private func requestHealthKitAuthorization() {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!

        healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { [weak self] success, _ in
            if success {
                self?.startHeartRateMonitoring()
            }
        }
    }

    private func startHeartRateMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        healthStore.execute(query)
        heartRateQuery = query
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample],
              let latest = samples.last else {
            return
        }

        let hr = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        DispatchQueue.main.async {
            self.heartRate = hr
        }

        // Send to iPhone for bio-reactive features
        sendHeartRateUpdate(hr)
    }

    func stopHeartRateMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
    }

    private func sendHeartRateUpdate(_ heartRate: Double) {
        let message: [String: Any] = [
            "heartRate": heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]

        connectivityManager?.send(message: message)
    }

    // MARK: - Track Arming

    /// Arm track for recording
    func armTrack(_ trackID: UUID) {
        armedTracks.insert(trackID)

        let message: [String: Any] = [
            "command": "armTrack",
            "trackID": trackID.uuidString
        ]

        connectivityManager?.send(message: message)

        WKInterfaceDevice.current().play(.click)
    }

    /// Disarm track
    func disarmTrack(_ trackID: UUID) {
        armedTracks.remove(trackID)

        let message: [String: Any] = [
            "command": "disarmTrack",
            "trackID": trackID.uuidString
        ]

        connectivityManager?.send(message: message)
    }

    // MARK: - Effects Control

    /// Adjust reverb send
    func setReverbSend(_ amount: Float, for trackID: UUID) {
        let message: [String: Any] = [
            "command": "setEffect",
            "trackID": trackID.uuidString,
            "effect": "reverb",
            "amount": amount
        ]

        connectivityManager?.send(message: message)
    }

    /// Adjust delay send
    func setDelaySend(_ amount: Float, for trackID: UUID) {
        let message: [String: Any] = [
            "command": "setEffect",
            "trackID": trackID.uuidString,
            "effect": "delay",
            "amount": amount
        ]

        connectivityManager?.send(message: message)
    }

    // MARK: - Message Handling

    private func handleMessage(_ message: [String: Any]) {
        // Handle updates from iPhone

        if let isPlaying = message["isPlaying"] as? Bool {
            DispatchQueue.main.async {
                self.isPlaying = isPlaying
            }
        }

        if let isRecording = message["isRecording"] as? Bool {
            DispatchQueue.main.async {
                self.isRecording = isRecording
            }
        }

        if let bpm = message["bpm"] as? Double {
            DispatchQueue.main.async {
                self.currentBPM = bpm
            }
        }

        if let position = message["transportPosition"] as? String {
            DispatchQueue.main.async {
                self.transportPosition = position
            }
        }

        if let duration = message["recordingDuration"] as? TimeInterval {
            DispatchQueue.main.async {
                self.recordingDuration = duration
            }
        }
    }
}

// MARK: - WatchConnectivityManager Delegate

extension EchoelWatchApp: WatchConnectivityDelegate {
    func didReceiveMessage(_ message: [String: Any]) {
        handleMessage(message)
    }

    func didReceiveApplicationContext(_ context: [String: Any]) {
        handleMessage(context)
    }
}

// MARK: - Supporting Types

enum TransportCommand: String {
    case play = "play"
    case stop = "stop"
    case pause = "pause"
    case record = "record"
}

// MARK: - Watch Connectivity Manager

protocol WatchConnectivityDelegate: AnyObject {
    func didReceiveMessage(_ message: [String: Any])
    func didReceiveApplicationContext(_ context: [String: Any])
}

class WatchConnectivityManager {

    weak var delegate: WatchConnectivityDelegate?
    var onMessageReceived: (([String: Any]) -> Void)?

    // WCSession integration (simplified)
    func send(message: [String: Any]) {
        // Send message to iPhone via WatchConnectivity
        // Real implementation would use WCSession
    }

    func sendApplicationContext(_ context: [String: Any]) {
        // Update application context
    }
}

// MARK: - Tap Tempo Detector (Reusable)

struct TapTempoDetector {
    private var tapTimes: [Date] = []
    private let maxTaps = 8
    private let tapTimeout: TimeInterval = 2.0

    mutating func tap() -> Double? {
        let now = Date()

        // Clear old taps
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < tapTimeout }

        // Add new tap
        tapTimes.append(now)

        // Need at least 2 taps
        guard tapTimes.count >= 2 else { return nil }

        // Calculate intervals
        var intervals: [TimeInterval] = []
        for i in 1..<tapTimes.count {
            let interval = tapTimes[i].timeIntervalSince(tapTimes[i-1])
            intervals.append(interval)
        }

        // Average interval
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

        // Convert to BPM
        let bpm = 60.0 / avgInterval

        return bpm
    }

    mutating func reset() {
        tapTimes.removeAll()
    }
}

// MARK: - Watch UI Views

@available(watchOS 7.0, *)
struct EchoelWatchMainView: View {

    @StateObject private var watchApp = EchoelWatchApp()

    var body: some View {
        TabView {
            // Transport Control Tab
            TransportView(watchApp: watchApp)
                .tabItem {
                    Label("Transport", systemImage: "play.circle")
                }

            // Tap Tempo Tab
            TapTempoView(watchApp: watchApp)
                .tabItem {
                    Label("Tempo", systemImage: "metronome")
                }

            // Heart Rate Tab
            HeartRateView(watchApp: watchApp)
                .tabItem {
                    Label("Heart", systemImage: "heart.fill")
                }

            // Quick Controls Tab
            QuickControlsView(watchApp: watchApp)
                .tabItem {
                    Label("Controls", systemImage: "slider.horizontal.3")
                }
        }
    }
}

@available(watchOS 7.0, *)
struct TransportView: View {
    @ObservedObject var watchApp: EchoelWatchApp

    var body: some View {
        VStack(spacing: 20) {
            // Position display
            Text(watchApp.transportPosition)
                .font(.title3.monospacedDigit())
                .foregroundColor(.primary)

            // Transport buttons
            HStack(spacing: 15) {
                Button(action: { watchApp.play() }) {
                    Image(systemName: watchApp.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                }

                Button(action: { watchApp.stop() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title)
                }

                Button(action: { watchApp.record() }) {
                    Image(systemName: "record.circle")
                        .font(.title)
                        .foregroundColor(watchApp.isRecording ? .red : .primary)
                }
            }

            // Recording duration
            if watchApp.isRecording {
                Text("REC \(formatDuration(watchApp.recordingDuration))")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

@available(watchOS 7.0, *)
struct TapTempoView: View {
    @ObservedObject var watchApp: EchoelWatchApp

    var body: some View {
        VStack(spacing: 20) {
            Text("Tap Tempo")
                .font(.headline)

            Text("\(Int(watchApp.currentBPM)) BPM")
                .font(.system(size: 48, weight: .bold).monospacedDigit())

            Button(action: { watchApp.tapTempo() }) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Text("TAP")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(.plain)

            Button("Reset") {
                watchApp.resetTapTempo()
            }
            .font(.caption)
        }
        .padding()
    }
}

@available(watchOS 7.0, *)
struct HeartRateView: View {
    @ObservedObject var watchApp: EchoelWatchApp

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "heart.fill")
                .font(.largeTitle)
                .foregroundColor(.red)

            Text("\(Int(watchApp.heartRate)) BPM")
                .font(.system(size: 36, weight: .bold).monospacedDigit())

            Text("Heart Rate")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text("Music BPM: \(Int(watchApp.currentBPM))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

@available(watchOS 7.0, *)
struct QuickControlsView: View {
    @ObservedObject var watchApp: EchoelWatchApp

    // Dummy track ID for demo
    private let dummyTrackID = UUID()

    var body: some View {
        List {
            Section("Effects") {
                VStack(alignment: .leading) {
                    Text("Reverb")
                        .font(.caption)
                    Slider(value: .constant(0.5), in: 0...1) { _ in
                        // Update reverb
                    }
                }

                VStack(alignment: .leading) {
                    Text("Delay")
                        .font(.caption)
                    Slider(value: .constant(0.3), in: 0...1) { _ in
                        // Update delay
                    }
                }
            }

            Section("Track Arming") {
                Toggle("Arm Track 1", isOn: .constant(false))
                Toggle("Arm Track 2", isOn: .constant(false))
                Toggle("Arm Track 3", isOn: .constant(false))
            }
        }
    }
}

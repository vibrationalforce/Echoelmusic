/*
  ==============================================================================

    EchoelWatch.swift
    Echoelmusic watchOS Companion App

    Features:
    - Real-time bio-data from Apple Watch sensors (HRV, heart rate)
    - Transport controls (play, pause, record)
    - Loop triggering
    - Coherence visualization
    - Haptic feedback for musical events
    - Session metrics display
    - Wellness reminders

    "Your wrist, your music, your wellness"

  ==============================================================================
*/

import SwiftUI
import WatchKit
import HealthKit
import WatchConnectivity

// MARK: - App Entry Point

@main
struct EchoelWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    @StateObject private var healthManager = HealthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
                .environmentObject(healthManager)
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager
    @EnvironmentObject var health: HealthManager

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TransportView()
                .tag(0)

            CoherenceView()
                .tag(1)

            LoopView()
                .tag(2)

            MetricsView()
                .tag(3)
        }
        .tabViewStyle(.page)
        .onAppear {
            health.startMonitoring()
        }
    }
}

// MARK: - Transport Controls

struct TransportView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager

    @State private var isPlaying = false
    @State private var isRecording = false

    var body: some View {
        VStack(spacing: 20) {
            Text("ECHOELMUSIC")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)

            HStack(spacing: 30) {
                // Record Button
                Button(action: toggleRecord) {
                    Circle()
                        .fill(isRecording ? Color.red : Color.gray.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Record")
                .accessibilityHint(isRecording ? "Stop recording" : "Start recording")

                // Play/Pause Button
                Button(action: togglePlay) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.black)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
            }

            // Transport State
            Text(transportStatusText)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var transportStatusText: String {
        if isRecording {
            return "Recording..."
        } else if isPlaying {
            return "Playing"
        } else {
            return "Stopped"
        }
    }

    private func togglePlay() {
        isPlaying.toggle()
        connectivity.sendCommand(.transport(isPlaying ? .play : .pause))
        WKInterfaceDevice.current().play(isPlaying ? .start : .stop)
    }

    private func toggleRecord() {
        isRecording.toggle()
        connectivity.sendCommand(.transport(isRecording ? .record : .stop))
        WKInterfaceDevice.current().play(.notification)
    }
}

// MARK: - Coherence Visualization

struct CoherenceView: View {
    @EnvironmentObject var health: HealthManager

    var body: some View {
        VStack(spacing: 12) {
            Text("COHERENCE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            // Coherence Ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 100, height: 100)

                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(health.coherence))
                    .stroke(
                        coherenceGradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                // Center value
                VStack(spacing: 2) {
                    Text("\(Int(health.coherence * 100))")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(coherenceColor)

                    Text("%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // Heart rate
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(Int(health.heartRate)) BPM")
                    .font(.system(size: 14))
            }

            // HRV
            Text("HRV: \(Int(health.hrv)) ms")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var coherenceGradient: LinearGradient {
        LinearGradient(
            colors: [coherenceColor.opacity(0.7), coherenceColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var coherenceColor: Color {
        if health.coherence > 0.7 {
            return .green
        } else if health.coherence > 0.4 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Loop Triggers

struct LoopView: View {
    @EnvironmentObject var connectivity: WatchConnectivityManager

    let loops = [
        ("A", Color.cyan),
        ("B", Color.pink),
        ("C", Color.yellow),
        ("D", Color.green)
    ]

    var body: some View {
        VStack(spacing: 8) {
            Text("LOOPS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(loops, id: \.0) { loop in
                    LoopButton(name: loop.0, color: loop.1) {
                        triggerLoop(loop.0)
                    }
                }
            }
        }
        .padding()
    }

    private func triggerLoop(_ name: String) {
        connectivity.sendCommand(.loop(name))
        WKInterfaceDevice.current().play(.click)
    }
}

struct LoopButton: View {
    let name: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            isPressed = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
        }) {
            Text(name)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 60, height: 60)
                .background(isPressed ? color : color.opacity(0.3))
                .foregroundColor(isPressed ? .black : color)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Loop \(name)")
    }
}

// MARK: - Metrics View

struct MetricsView: View {
    @EnvironmentObject var health: HealthManager
    @EnvironmentObject var connectivity: WatchConnectivityManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("SESSION")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                MetricRow(label: "Duration", value: formatDuration(connectivity.sessionDuration))
                MetricRow(label: "Avg. Coherence", value: "\(Int(health.averageCoherence * 100))%")
                MetricRow(label: "Flow Time", value: formatDuration(health.flowDuration))
                MetricRow(label: "Steps", value: "\(health.steps)")

                Divider()

                // Wellness reminder
                if health.shouldTakeBreak {
                    WellnessReminderView()
                }
            }
            .padding()
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
        }
    }
}

struct WellnessReminderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundColor(.green)
                Text("Time for a break")
                    .font(.system(size: 12, weight: .medium))
            }

            Text("You've been in high focus for a while. Take a moment to breathe.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Watch Connectivity Manager

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    @Published var isConnected = false
    @Published var sessionDuration: TimeInterval = 0

    private var session: WCSession?
    private var sessionStartTime: Date?

    enum Command {
        case transport(TransportAction)
        case loop(String)
        case bioData(coherence: Double, hrv: Double, heartRate: Double)

        enum TransportAction: String {
            case play, pause, stop, record
        }
    }

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }

        // Track session duration
        sessionStartTime = Date()
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            if let start = self?.sessionStartTime {
                self?.sessionDuration = Date().timeIntervalSince(start)
            }
        }
    }

    func sendCommand(_ command: Command) {
        guard let session = session, session.isReachable else { return }

        var message: [String: Any] = [:]

        switch command {
        case .transport(let action):
            message["type"] = "transport"
            message["action"] = action.rawValue

        case .loop(let name):
            message["type"] = "loop"
            message["name"] = name

        case .bioData(let coherence, let hrv, let heartRate):
            message["type"] = "bioData"
            message["coherence"] = coherence
            message["hrv"] = hrv
            message["heartRate"] = heartRate
        }

        session.sendMessage(message, replyHandler: nil, errorHandler: { error in
            print("Send error: \(error.localizedDescription)")
        })
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from iOS app
        DispatchQueue.main.async {
            if let type = message["type"] as? String {
                switch type {
                case "haptic":
                    if let pattern = message["pattern"] as? String {
                        self.playHaptic(pattern)
                    }
                default:
                    break
                }
            }
        }
    }

    private func playHaptic(_ pattern: String) {
        switch pattern {
        case "beat":
            WKInterfaceDevice.current().play(.click)
        case "downbeat":
            WKInterfaceDevice.current().play(.directionUp)
        case "success":
            WKInterfaceDevice.current().play(.success)
        case "notification":
            WKInterfaceDevice.current().play(.notification)
        default:
            break
        }
    }
}

// MARK: - Health Manager

class HealthManager: NSObject, ObservableObject {
    static let shared = HealthManager()

    @Published var heartRate: Double = 72
    @Published var hrv: Double = 45
    @Published var coherence: Double = 0.5
    @Published var steps: Int = 0
    @Published var averageCoherence: Double = 0.5
    @Published var flowDuration: TimeInterval = 0
    @Published var shouldTakeBreak = false

    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var coherenceHistory: [Double] = []
    private var flowStartTime: Date?
    private var lastBreakTime: Date = Date()

    override init() {
        super.init()
        requestAuthorization()
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]

        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            if success {
                self.startHeartRateMonitoring()
                self.startHRVMonitoring()
            }
        }
    }

    func startMonitoring() {
        startHeartRateMonitoring()
        startHRVMonitoring()
        startBreakReminder()
    }

    private func startHeartRateMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deleted, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] query, samples, deleted, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        healthStore.execute(query)
        heartRateQuery = query
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let sample = samples.last else { return }

        let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
        let value = sample.quantity.doubleValue(for: heartRateUnit)

        DispatchQueue.main.async {
            self.heartRate = value
            self.updateCoherence()
            self.sendBioDataToPhone()
        }
    }

    private func startHRVMonitoring() {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        let query = HKAnchoredObjectQuery(
            type: hrvType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deleted, anchor, error in
            self?.processHRVSamples(samples)
        }

        query.updateHandler = { [weak self] query, samples, deleted, anchor, error in
            self?.processHRVSamples(samples)
        }

        healthStore.execute(query)
    }

    private func processHRVSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let sample = samples.last else { return }

        let hrvUnit = HKUnit.secondUnit(with: .milli)
        let value = sample.quantity.doubleValue(for: hrvUnit)

        DispatchQueue.main.async {
            self.hrv = value
            self.updateCoherence()
            self.sendBioDataToPhone()
        }
    }

    private func updateCoherence() {
        // Coherence calculation based on HRV and heart rate stability
        // High HRV + stable heart rate = high coherence

        let hrvNormalized = min(1.0, hrv / 100.0)
        let heartRateStability = 1.0 - min(1.0, abs(heartRate - 72) / 40.0)

        coherence = (hrvNormalized + heartRateStability) / 2.0

        // Track history
        coherenceHistory.append(coherence)
        if coherenceHistory.count > 60 {
            coherenceHistory.removeFirst()
        }
        averageCoherence = coherenceHistory.reduce(0, +) / Double(coherenceHistory.count)

        // Track flow state
        if coherence > 0.7 {
            if flowStartTime == nil {
                flowStartTime = Date()
            }
            flowDuration = Date().timeIntervalSince(flowStartTime ?? Date())
        } else {
            flowStartTime = nil
        }
    }

    private func sendBioDataToPhone() {
        WatchConnectivityManager.shared.sendCommand(
            .bioData(coherence: coherence, hrv: hrv, heartRate: heartRate)
        )
    }

    private func startBreakReminder() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Suggest break if high focus for > 45 minutes
            if self.flowDuration > 45 * 60 &&
               Date().timeIntervalSince(self.lastBreakTime) > 45 * 60 {
                self.shouldTakeBreak = true
                WKInterfaceDevice.current().play(.notification)
            }
        }
    }

    func acknowledgeBreak() {
        shouldTakeBreak = false
        lastBreakTime = Date()
    }
}

// MARK: - Preview Providers

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WatchConnectivityManager.shared)
            .environmentObject(HealthManager.shared)
    }
}

struct CoherenceView_Previews: PreviewProvider {
    static var previews: some View {
        CoherenceView()
            .environmentObject(HealthManager.shared)
    }
}

struct TransportView_Previews: PreviewProvider {
    static var previews: some View {
        TransportView()
            .environmentObject(WatchConnectivityManager.shared)
    }
}
#endif

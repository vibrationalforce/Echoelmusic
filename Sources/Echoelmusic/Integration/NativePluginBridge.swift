import Foundation
import SwiftUI
import Combine
import os.log

/// Native Plugin Bridge for Swift
///
/// Pure native communication layer between Swift (HealthKit/Bio-Daten)
/// and EchoelCore audio processing - NO JUCE, NO external dependencies!
///
/// Part of the EchoelCore Philosophy: "breath → sound → light → consciousness ✨"
///
/// Usage:
/// ```swift
/// let bridge = NativePluginBridge.shared
/// bridge.updateBioData(hrv: 0.75, coherence: 0.8, heartRate: 70.0)
/// ```
///
@MainActor
class NativePluginBridge: ObservableObject {

    // MARK: - Singleton

    static let shared = NativePluginBridge()

    // MARK: - Properties

    private let log = EchoelLogger.shared

    /// Is the native audio engine active?
    @Published var isEngineActive: Bool = false

    /// Engine Version
    @Published var engineVersion: String = EchoelCore.version

    /// Last Bio-Data snapshot
    @Published var lastBioData: BioDataSnapshot?

    /// Bio-data update callback for audio engine
    var onBioDataUpdate: ((BioDataSnapshot) -> Void)?

    struct BioDataSnapshot: Sendable {
        let hrv: Float
        let coherence: Float
        let heartRate: Float
        let timestamp: TimeInterval
    }

    // MARK: - Initialization

    private init() {
        log.info("🎵 Native Plugin Bridge initialized (EchoelCore \(EchoelCore.version))", category: .plugin)
        log.info("🎵 Philosophy: Pure Native - No JUCE, No Dependencies!", category: .plugin)
    }

    // MARK: - Bio-Data Updates

    /// Update bio-data in native audio engine
    /// - Parameters:
    ///   - hrv: Heart Rate Variability (0.0 - 1.0)
    ///   - coherence: Coherence level (0.0 - 1.0)
    ///   - heartRate: Heart rate in BPM
    func updateBioData(hrv: Float, coherence: Float, heartRate: Float) {
        let snapshot = BioDataSnapshot(
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate,
            timestamp: Date().timeIntervalSince1970
        )

        lastBioData = snapshot

        // Notify audio engine of bio-data update
        onBioDataUpdate?(snapshot)

        log.info("🎵 Bio-data updated: HRV=\(hrv), Coherence=\(coherence), HR=\(heartRate)", category: .plugin)
    }

    /// Get current bio-data
    func getCurrentBioData() -> BioDataSnapshot? {
        return lastBioData
    }

    // MARK: - Engine Status

    /// Activate the native audio engine
    func activateEngine() {
        isEngineActive = true
        log.info("🎵 Native audio engine activated", category: .plugin)
    }

    /// Deactivate the native audio engine
    func deactivateEngine() {
        isEngineActive = false
        log.info("🎵 Native audio engine deactivated", category: .plugin)
    }

    /// Refresh engine status
    func refreshEngineStatus() {
        log.info("🎵 Engine Status: \(isEngineActive ? "Active" : "Inactive")", category: .plugin)
        log.info("🎵 Engine Version: \(engineVersion)", category: .plugin)
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)

struct NativePluginStatusView: View {
    @ObservedObject private var bridge = NativePluginBridge.shared

    var body: some View {
        VStack(spacing: 12) {
            Label(
                bridge.isEngineActive ? "Engine Active" : "Engine Inactive",
                systemImage: bridge.isEngineActive ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundColor(bridge.isEngineActive ? .green : .red)

            Text("EchoelCore \(bridge.engineVersion)")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Pure Native - No Dependencies ✨")
                .font(.caption2)
                .foregroundColor(.secondary)

            if let bioData = bridge.lastBioData {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Bio-Data:")
                        .font(.caption.bold())

                    HStack {
                        Text("HRV:")
                        Text(String(format: "%.2f", bioData.hrv))
                            .foregroundColor(.blue)
                    }
                    .font(.caption2)

                    HStack {
                        Text("Coherence:")
                        Text(String(format: "%.2f", bioData.coherence))
                            .foregroundColor(.green)
                    }
                    .font(.caption2)

                    HStack {
                        Text("Heart Rate:")
                        Text(String(format: "%.1f BPM", bioData.heartRate))
                            .foregroundColor(.red)
                    }
                    .font(.caption2)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }

            Button("Refresh Status") {
                bridge.refreshEngineStatus()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
#endif

// MARK: - Example Usage

extension NativePluginBridge {

    /// Example: Send test bio-data
    func sendTestData() {
        updateBioData(
            hrv: Float.random(in: 0.3...0.9),
            coherence: Float.random(in: 0.4...0.9),
            heartRate: Float.random(in: 60...100)
        )
    }

    /// Connect to HealthKit manager for real-time bio-data
    func connectToHealthKit(manager: AnyObject) {
        log.info("🎵 Connecting native bridge to HealthKit manager", category: .plugin)
        activateEngine()
    }
}

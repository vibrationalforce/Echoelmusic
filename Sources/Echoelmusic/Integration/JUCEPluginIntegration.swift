import Foundation
import os.log

#if canImport(BioDataBridge)
import BioDataBridge
#endif

/// JUCE Plugin Integration für Swift
///
/// Diese Klasse ermöglicht die Kommunikation zwischen Swift (HealthKit/Bio-Daten)
/// und dem JUCE Audio Plugin (VST3/AU/CLAP).
///
/// Usage:
/// ```swift
/// let integration = JUCEPluginIntegration.shared
/// integration.updateBioData(hrv: 0.75, coherence: 0.8, heartRate: 70.0)
/// ```
///
@MainActor
class JUCEPluginIntegration: ObservableObject {

    // MARK: - Singleton

    static let shared = JUCEPluginIntegration()

    // MARK: - Properties

    /// Ist das Plugin geladen?
    @Published var isPluginLoaded: Bool = false

    /// Plugin Version
    @Published var pluginVersion: String = "Unknown"

    /// Letzte Bio-Daten
    @Published var lastBioData: BioDataSnapshot?

    struct BioDataSnapshot {
        let hrv: Float
        let coherence: Float
        let heartRate: Float
        let timestamp: TimeInterval
    }

    // MARK: - Initialization

    private init() {
        #if canImport(BioDataBridge)
        checkPluginStatus()
        #endif

        log.info("🎸 JUCE Plugin Integration initialized", category: .plugin)
    }

    // MARK: - Bio-Data Updates

    /// Update bio-data in JUCE plugin
    /// - Parameters:
    ///   - hrv: Heart Rate Variability (0.0 - 1.0)
    ///   - coherence: Coherence level (0.0 - 1.0)
    ///   - heartRate: Heart rate in BPM
    func updateBioData(hrv: Float, coherence: Float, heartRate: Float) {
        #if canImport(BioDataBridge)
        let bridge = BioDataBridge.sharedInstance()
        bridge.updateBioData(
            withHRV: hrv,
            coherence: coherence,
            heartRate: heartRate
        )

        lastBioData = BioDataSnapshot(
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate,
            timestamp: Date().timeIntervalSince1970
        )

        log.info("🎸 Bio-data sent to JUCE plugin: HRV=\(hrv), Coherence=\(coherence), HR=\(heartRate)", category: .plugin)
        #else
        log.warning("⚠️ BioDataBridge not available - JUCE plugin not compiled", category: .plugin)
        #endif
    }

    /// Get current bio-data from plugin
    func getCurrentBioData() -> BioDataSnapshot? {
        #if canImport(BioDataBridge)
        let bridge = BioDataBridge.sharedInstance()
        guard let data = bridge.getCurrentBioData() as? [String: NSNumber] else {
            return nil
        }

        return BioDataSnapshot(
            hrv: data["hrv"]?.floatValue ?? 0.5,
            coherence: data["coherence"]?.floatValue ?? 0.5,
            heartRate: data["heartRate"]?.floatValue ?? 70.0,
            timestamp: data["timestamp"]?.doubleValue ?? 0.0
        )
        #else
        return lastBioData
        #endif
    }

    // MARK: - Plugin Status

    private func checkPluginStatus() {
        #if canImport(BioDataBridge)
        let bridge = BioDataBridge.sharedInstance()
        isPluginLoaded = bridge.isPluginLoaded()
        pluginVersion = bridge.getPluginVersion() ?? "Unknown"

        log.info("🎸 JUCE Plugin Status: \(isPluginLoaded ? "Loaded" : "Not Loaded")", category: .plugin)
        log.info("🎸 Plugin Version: \(pluginVersion)", category: .plugin)
        #endif
    }

    /// Manually check plugin status
    func refreshPluginStatus() {
        checkPluginStatus()
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

struct JUCEPluginStatusView: View {
    @State private var integration = JUCEPluginIntegration.shared

    var body: some View {
        VStack(spacing: 12) {
            Label(
                integration.isPluginLoaded ? "Plugin Loaded" : "Plugin Not Loaded",
                systemImage: integration.isPluginLoaded ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundColor(integration.isPluginLoaded ? .green : .red)

            Text("Version: \(integration.pluginVersion)")
                .font(.caption)
                .foregroundColor(.secondary)

            if let bioData = integration.lastBioData {
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
                integration.refreshPluginStatus()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
#endif

// MARK: - Example Usage

extension JUCEPluginIntegration {

    /// Example: Send test bio-data to plugin
    func sendTestData() {
        updateBioData(
            hrv: Float.random(in: 0.3...0.9),
            coherence: Float.random(in: 0.4...0.9),
            heartRate: Float.random(in: 60...100)
        )
    }

    /// Example: Connect to HealthKit manager
    func connectToHealthKit(manager: AnyObject) {
        // This would be called from the main app to connect HealthKit data
        log.info("🎸 Connecting JUCE plugin to HealthKit manager", category: .plugin)

        // In practice, you would set up a Combine pipeline:
        // healthKitManager.$currentHRV
        //     .sink { [weak self] hrv in
        //         self?.updateBioData(hrv: hrv, coherence: ..., heartRate: ...)
        //     }
    }
}

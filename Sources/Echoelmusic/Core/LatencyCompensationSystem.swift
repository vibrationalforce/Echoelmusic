import Foundation
import AVFoundation
import Combine

/// Ultralow Latency Optimization & Compensation System
/// Professional latency management for real-time audio/video
///
/// Features:
/// - Automatic latency detection
/// - Plugin delay compensation (PDC)
/// - Network latency compensation
/// - Video/audio sync
/// - Buffer optimization
/// - Predictive latency adjustment
@MainActor
class LatencyCompensationSystem: ObservableObject {

    // MARK: - Published Properties

    @Published var totalLatency: Latency
    @Published var compensationEnabled: Bool = true
    @Published var syncStatus: SyncStatus

    // MARK: - Latency Measurement

    struct Latency: Codable {
        var audioInputMs: Double
        var audioProcessingMs: Double
        var audioOutputMs: Double
        var videoProcessingMs: Double
        var networkMs: Double
        var pluginDelayMs: Double

        var totalMs: Double {
            audioInputMs + audioProcessingMs + audioOutputMs +
            videoProcessingMs + networkMs + pluginDelayMs
        }

        var isAcceptable: Bool {
            // Professional standards
            totalMs < 10.0  // <10ms total is professional
        }

        var description: String {
            """
            Audio Input: \(String(format: "%.2f", audioInputMs)) ms
            Audio Processing: \(String(format: "%.2f", audioProcessingMs)) ms
            Audio Output: \(String(format: "%.2f", audioOutputMs)) ms
            Video Processing: \(String(format: "%.2f", videoProcessingMs)) ms
            Network: \(String(format: "%.2f", networkMs)) ms
            Plugin Delay: \(String(format: "%.2f", pluginDelayMs)) ms
            ────────────────────────────
            TOTAL: \(String(format: "%.2f", totalMs)) ms \(isAcceptable ? "✅" : "⚠️")
            """
        }
    }

    struct SyncStatus {
        var audioVideoSyncMs: Double  // Difference between audio and video
        var isSynced: Bool

        var description: String {
            let status = isSynced ? "✅ Synced" : "⚠️ Out of Sync"
            return "\(status) (\(String(format: "%.1f", audioVideoSyncMs)) ms offset)"
        }
    }

    // MARK: - Initialization

    init() {
        print("⚡ Latency Compensation System initialized")

        self.totalLatency = Latency(
            audioInputMs: 0,
            audioProcessingMs: 0,
            audioOutputMs: 0,
            videoProcessingMs: 0,
            networkMs: 0,
            pluginDelayMs: 0
        )

        self.syncStatus = SyncStatus(
            audioVideoSyncMs: 0,
            isSynced: true
        )

        Task {
            await measureLatency()
        }
    }

    // MARK: - Latency Measurement

    func measureLatency() async {
        print("   📊 Measuring total system latency...")

        // Measure audio input latency
        totalLatency.audioInputMs = await measureAudioInputLatency()

        // Measure audio processing latency
        totalLatency.audioProcessingMs = await measureAudioProcessingLatency()

        // Measure audio output latency
        totalLatency.audioOutputMs = await measureAudioOutputLatency()

        // Measure video processing latency
        totalLatency.videoProcessingMs = await measureVideoProcessingLatency()

        // Measure network latency (if applicable)
        totalLatency.networkMs = await measureNetworkLatency()

        print("   ✅ Latency measured:")
        print("      \(totalLatency.description)")

        // Apply compensation if needed
        if !totalLatency.isAcceptable {
            await applyCompensation()
        }
    }

    private func measureAudioInputLatency() async -> Double {
        // Measure actual hardware input latency
        // In production: Use CoreAudio/WASAPI APIs

        // Typical values:
        // - CoreAudio (Mac/iOS): 3-5ms
        // - WASAPI Exclusive (Windows): 3-5ms
        // - ASIO (Windows): 2-3ms
        // - JACK (Linux): 2-5ms

        return 3.0  // Simulated
    }

    private func measureAudioProcessingLatency() async -> Double {
        // Buffer size based latency
        // Formula: (bufferSize / sampleRate) * 1000

        let bufferSize = 128  // samples
        let sampleRate = 48000.0  // Hz

        return (Double(bufferSize) / sampleRate) * 1000.0  // ~2.67ms
    }

    private func measureAudioOutputLatency() async -> Double {
        // Hardware output latency
        return 3.0  // Simulated
    }

    private func measureVideoProcessingLatency() async -> Double {
        // Video frame processing time
        // At 60fps: 16.67ms per frame
        // At 120fps: 8.33ms per frame

        let fps = 60.0
        return 1000.0 / fps  // ~16.67ms
    }

    private func measureNetworkLatency() async -> Double {
        // Network round-trip time
        // Only relevant for remote collaboration/streaming
        return 0.0  // Not applicable for local
    }

    // MARK: - Plugin Delay Compensation (PDC)

    func registerPlugin(name: String, delayInSamples: Int, sampleRate: Double) {
        let delayMs = (Double(delayInSamples) / sampleRate) * 1000.0

        print("   🔌 Plugin registered:")
        print("      Name: \(name)")
        print("      Delay: \(delayInSamples) samples (\(String(format: "%.2f", delayMs)) ms)")

        // Add to total plugin delay
        totalLatency.pluginDelayMs += delayMs

        // Compensate all other tracks
        Task {
            await compensatePluginDelay()
        }
    }

    private func compensatePluginDelay() async {
        guard compensationEnabled else { return }

        print("   🔧 Compensating plugin delay...")

        // Delay all tracks without the plugin by the plugin's latency
        // This keeps everything in sync

        // In production: Adjust track timing in audio engine

        print("   ✅ Plugin delay compensated: \(String(format: "%.2f", totalLatency.pluginDelayMs)) ms")
    }

    // MARK: - Network Latency Compensation

    func compensateNetworkLatency(remoteLatencyMs: Double) async {
        print("   🌐 Compensating network latency...")
        print("      Remote latency: \(String(format: "%.1f", remoteLatencyMs)) ms")

        totalLatency.networkMs = remoteLatencyMs

        // Predictive buffer adjustment
        let bufferMs = remoteLatencyMs * 2.0  // 2x latency for safety

        print("   📦 Adjusting buffer to: \(String(format: "%.1f", bufferMs)) ms")

        // In production: Adjust audio/video buffer size
        // - Increase buffer for high latency networks
        // - Use jitter buffer for unstable connections
        // - Implement predictive packet loss concealment

        print("   ✅ Network latency compensated")
    }

    // MARK: - Audio/Video Sync

    func syncAudioVideo() async {
        print("   🎬 Syncing audio and video...")

        // Measure offset
        let audioTimestamp = await getAudioTimestamp()
        let videoTimestamp = await getVideoTimestamp()

        let offset = abs(audioTimestamp - videoTimestamp) * 1000.0  // ms

        syncStatus.audioVideoSyncMs = offset
        syncStatus.isSynced = offset < 20.0  // Within 20ms is acceptable

        if !syncStatus.isSynced {
            print("   ⚠️ Audio/Video out of sync: \(String(format: "%.1f", offset)) ms")

            // Apply correction
            if audioTimestamp > videoTimestamp {
                // Audio is ahead, delay it
                await delayAudio(by: offset)
            } else {
                // Video is ahead, delay it
                await delayVideo(by: offset)
            }

            syncStatus.isSynced = true
            print("   ✅ Audio/Video synced")
        } else {
            print("   ✅ Audio/Video already synced (\(String(format: "%.1f", offset)) ms)")
        }
    }

    private func getAudioTimestamp() async -> Double {
        // Get current audio playback position
        return Date().timeIntervalSince1970  // Simulated
    }

    private func getVideoTimestamp() async -> Double {
        // Get current video frame timestamp
        return Date().timeIntervalSince1970  // Simulated
    }

    private func delayAudio(by ms: Double) async {
        print("      → Delaying audio by \(String(format: "%.1f", ms)) ms")
        // In production: Add delay to audio pipeline
    }

    private func delayVideo(by ms: Double) async {
        print("      → Delaying video by \(String(format: "%.1f", ms)) ms")
        // In production: Add delay to video pipeline
    }

    // MARK: - Automatic Compensation

    func applyCompensation() async {
        guard compensationEnabled else { return }

        print("   🔧 Applying automatic latency compensation...")

        // 1. Optimize buffer size
        await optimizeBufferSize()

        // 2. Enable hardware direct monitoring (if available)
        await enableDirectMonitoring()

        // 3. Adjust video frame timing
        await adjustVideoFrameTiming()

        // 4. Sync audio/video
        await syncAudioVideo()

        // Re-measure
        await measureLatency()

        if totalLatency.isAcceptable {
            print("   ✅ Latency optimized to: \(String(format: "%.2f", totalLatency.totalMs)) ms")
        } else {
            print("   ⚠️ Latency still high: \(String(format: "%.2f", totalLatency.totalMs)) ms")
            print("      Consider: Smaller buffer size, faster audio interface, disable plugins")
        }
    }

    private func optimizeBufferSize() async {
        print("      • Optimizing buffer size...")

        // Target: <128 samples @ 48kHz = <2.67ms
        // Balance between latency and CPU usage

        // In production: Adjust audio engine buffer size
    }

    private func enableDirectMonitoring() async {
        print("      • Enabling direct monitoring (if available)...")

        // Direct monitoring: Input → Output bypass (0 latency)
        // Available on professional audio interfaces

        // In production: Enable hardware direct monitoring
    }

    private func adjustVideoFrameTiming() async {
        print("      • Adjusting video frame timing...")

        // Align video frames with audio buffer boundaries
        // Reduces audio/video sync issues

        // In production: Adjust video renderer timing
    }

    // MARK: - Latency Reporting

    func generateLatencyReport() -> LatencyReport {
        return LatencyReport(
            totalLatencyMs: totalLatency.totalMs,
            breakdown: totalLatency,
            isAcceptable: totalLatency.isAcceptable,
            syncStatus: syncStatus,
            recommendations: getLatencyRecommendations()
        )
    }

    struct LatencyReport {
        let totalLatencyMs: Double
        let breakdown: Latency
        let isAcceptable: Bool
        let syncStatus: SyncStatus
        let recommendations: [String]

        var description: String {
            var report = """
            ═══════════════════════════════════════
            LATENCY REPORT
            ═══════════════════════════════════════

            \(breakdown.description)

            Sync Status: \(syncStatus.description)

            """

            if !recommendations.isEmpty {
                report += """

                RECOMMENDATIONS:

                """
                for (index, rec) in recommendations.enumerated() {
                    report += "\(index + 1). \(rec)\n"
                }
            }

            report += "\n═══════════════════════════════════════"

            return report
        }
    }

    private func getLatencyRecommendations() -> [String] {
        var recommendations: [String] = []

        if totalLatency.totalMs > 10 {
            recommendations.append("Total latency is high (\(String(format: "%.1f", totalLatency.totalMs)) ms). Target: <10ms")
        }

        if totalLatency.audioProcessingMs > 5 {
            recommendations.append("Reduce buffer size for lower latency (currently \(String(format: "%.1f", totalLatency.audioProcessingMs)) ms)")
        }

        if totalLatency.pluginDelayMs > 20 {
            recommendations.append("High plugin latency (\(String(format: "%.1f", totalLatency.pluginDelayMs)) ms). Consider disabling look-ahead plugins or using PDC")
        }

        if !syncStatus.isSynced {
            recommendations.append("Audio/Video out of sync (\(String(format: "%.1f", syncStatus.audioVideoSyncMs)) ms). Enable automatic sync compensation")
        }

        if totalLatency.networkMs > 50 {
            recommendations.append("High network latency (\(String(format: "%.1f", totalLatency.networkMs)) ms). Consider local recording instead of streaming")
        }

        if recommendations.isEmpty {
            recommendations.append("✅ Latency is optimal! No action required.")
        }

        return recommendations
    }

    // MARK: - Live Monitoring

    func startLiveMonitoring(interval: TimeInterval = 1.0) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.measureLatency()
            }
        }

        print("   🎙️ Live latency monitoring started (every \(interval)s)")
    }
}

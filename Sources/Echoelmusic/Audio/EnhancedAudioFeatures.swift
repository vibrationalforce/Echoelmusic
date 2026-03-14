#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Accelerate
import Observation

// MARK: - Adaptive Audio Engine

/// Dynamically adjusts audio quality and latency based on system resources
@MainActor
@Observable
final class AdaptiveAudioEngine {

    // MARK: - Quality Presets

    enum QualityPreset: String, CaseIterable {
        case batterySaver = "Battery Saver"
        case balanced = "Balanced"
        case maximum = "Maximum Quality"
        case ultraLowLatency = "Ultra Low Latency"

        var bufferSize: Int {
            switch self {
            case .batterySaver: return 2048
            case .balanced: return 512
            case .maximum: return 1024
            case .ultraLowLatency: return 128
            }
        }

        var sampleRate: Double {
            switch self {
            case .batterySaver: return 44100
            case .balanced: return 48000
            case .maximum: return 96000
            case .ultraLowLatency: return 48000
            }
        }

        var channelCount: Int {
            switch self {
            case .batterySaver: return 2
            case .balanced: return 2
            case .maximum: return 8
            case .ultraLowLatency: return 2
            }
        }
    }

    // MARK: - Published Properties

    var currentPreset: QualityPreset = .balanced
    var cpuUsage: Float = 0.0
    var currentLatency: TimeInterval = 0.0
    var isAdaptiveMode: Bool = true
    var bufferUnderrunCount: Int = 0

    // MARK: - Private Properties

    @ObservationIgnored nonisolated(unsafe) private var timer: Timer?
    private var performanceHistory: [Float] = []
    private let maxHistorySize = 30 // 30 seconds at 1Hz sampling

    // MARK: - Initialization

    init() {
        startMonitoring()
    }

    deinit {
        // Timer must be invalidated directly — stopMonitoring() is @MainActor-isolated
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Public Methods

    func setPreset(_ preset: QualityPreset) {
        currentPreset = preset
        applyAudioConfiguration()
        log.audio("Applied audio preset: \(preset.rawValue)")
    }

    func enableAdaptiveMode(_ enabled: Bool) {
        isAdaptiveMode = enabled
        if enabled {
            log.audio("Adaptive audio mode enabled")
        } else {
            log.audio("Adaptive audio mode disabled")
        }
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updatePerformanceMetrics()
            }
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updatePerformanceMetrics() {
        // Estimate CPU usage (simplified)
        let processorCount = ProcessInfo.processInfo.processorCount
        let activeProcessorCount = ProcessInfo.processInfo.activeProcessorCount
        let estimatedCPU = 1.0 - (Float(activeProcessorCount) / Float(processorCount))

        cpuUsage = estimatedCPU * 100.0
        performanceHistory.append(cpuUsage)

        if performanceHistory.count > maxHistorySize {
            performanceHistory.removeFirst()
        }

        // Adaptive quality adjustment
        if isAdaptiveMode {
            adaptQuality()
        }

        // Update latency estimate
        updateLatencyEstimate()
    }

    private func adaptQuality() {
        guard !performanceHistory.isEmpty else { return }
        let avgCPU = performanceHistory.reduce(0, +) / Float(performanceHistory.count)

        if avgCPU > 80.0 && currentPreset != .batterySaver {
            // High CPU usage - downgrade quality
            switch currentPreset {
            case .maximum:
                setPreset(.balanced)
            case .balanced, .ultraLowLatency:
                setPreset(.batterySaver)
            default:
                break
            }
        } else if avgCPU < 40.0 && currentPreset == .batterySaver {
            // Low CPU usage - can upgrade quality
            setPreset(.balanced)
        }
    }

    private func updateLatencyEstimate() {
        let bufferDuration = Double(currentPreset.bufferSize) / currentPreset.sampleRate
        currentLatency = bufferDuration * 1000.0 // Convert to milliseconds
    }

    private func applyAudioConfiguration() {
        #if os(macOS)
        log.audio("Audio configured: \(currentPreset.sampleRate)Hz, \(currentPreset.bufferSize) samples (macOS — HAL managed)")
        #else
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setPreferredIOBufferDuration(
                Double(currentPreset.bufferSize) / currentPreset.sampleRate
            )
            try audioSession.setPreferredSampleRate(currentPreset.sampleRate)

            log.audio("Audio configured: \(currentPreset.sampleRate)Hz, \(currentPreset.bufferSize) samples")
        } catch {
            log.audio("Failed to apply audio configuration: \(error)", level: .error)
        }
        #endif
    }
}
#endif

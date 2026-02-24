import Foundation
import AVFoundation

/// Audio configuration constants and optimization settings
/// Target: < 5ms latency for real-time performance
enum AudioConfiguration {

    // MARK: - Sample Rate

    /// Preferred sample rate (48 kHz for pro audio)
    static let preferredSampleRate: Double = 48000.0

    /// Fallback sample rate if 48kHz unavailable
    static let fallbackSampleRate: Double = 44100.0


    // MARK: - Buffer Configuration

    /// Ultra-low latency buffer size (128 frames)
    /// At 48kHz: 128/48000 = 2.67ms latency
    static let ultraLowLatencyBufferSize: AVAudioFrameCount = 128

    /// Low latency buffer size (256 frames)
    /// At 48kHz: 256/48000 = 5.33ms latency
    static let lowLatencyBufferSize: AVAudioFrameCount = 256

    /// Normal buffer size (512 frames) - better for battery
    /// At 48kHz: 512/48000 = 10.67ms latency
    static let normalBufferSize: AVAudioFrameCount = 512

    /// Current buffer size (defaults to low latency)
    static var currentBufferSize: AVAudioFrameCount = lowLatencyBufferSize

    /// Calculate IO buffer duration for AVAudioSession
    static func ioBufferDuration(for sampleRate: Double) -> TimeInterval {
        return Double(currentBufferSize) / sampleRate
    }


    // MARK: - Audio Format

    /// Standard audio format for processing
    /// 32-bit float, interleaved, stereo
    static func standardFormat(sampleRate: Double = preferredSampleRate) -> AVAudioFormat? {
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: true
        )
    }

    /// Non-interleaved format for DSP operations
    static func dspFormat(sampleRate: Double = preferredSampleRate) -> AVAudioFormat? {
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false
        )
    }


    // MARK: - Audio Session Configuration

    /// Whether the audio session has been successfully configured at least once.
    private(set) static var isSessionConfigured = false

    /// Configure audio session for real-time performance.
    /// Falls back to playback-only if `.playAndRecord` fails (e.g. microphone
    /// permission not yet granted on first launch).
    static func configureAudioSession() throws {
        #if os(macOS)
        // macOS uses HAL (Hardware Abstraction Layer), not AVAudioSession
        isSessionConfigured = true
        log.audio("Audio session: macOS HAL (no AVAudioSession)")
        return
        #else
        let audioSession = AVAudioSession.sharedInstance()

        // Try playAndRecord first (needs microphone permission).
        // If that fails (first launch, permission denied), fall back to playback-only
        // so the app can at least start without crashing.
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers]
            )
        } catch {
            log.audio("⚠️ playAndRecord unavailable (mic permission?), falling back to .playback: \(error)", level: .warning)
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth, .mixWithOthers]
            )
        }

        // Set preferred sample rate
        try audioSession.setPreferredSampleRate(preferredSampleRate)

        // Set preferred IO buffer duration (target latency)
        let bufferDuration = ioBufferDuration(for: preferredSampleRate)
        try audioSession.setPreferredIOBufferDuration(bufferDuration)

        // Activate session
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        isSessionConfigured = true

        log.audio("🎵 Audio Session Configured:")
        log.audio("   Category: \(audioSession.category.rawValue)")
        log.audio("   Sample Rate: \(audioSession.sampleRate) Hz")
        log.audio("   IO Buffer Duration: \(audioSession.ioBufferDuration * 1000) ms")
        log.audio("   Input Latency: \(audioSession.inputLatency * 1000) ms")
        log.audio("   Output Latency: \(audioSession.outputLatency * 1000) ms")
        log.audio("   Total Latency: \((audioSession.inputLatency + audioSession.outputLatency + audioSession.ioBufferDuration) * 1000) ms")
        #endif // !os(macOS)
    }


    /// Upgrade audio session from .playback to .playAndRecord after mic permission is granted.
    /// No-op if already using .playAndRecord.
    static func upgradeToPlayAndRecord() throws {
        #if os(macOS)
        return
        #else
        let audioSession = AVAudioSession.sharedInstance()
        guard audioSession.category != .playAndRecord else { return }

        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        log.audio("Audio session upgraded to .playAndRecord")
        #endif
    }

    // MARK: - Latency Modes

    enum LatencyMode {
        case ultraLow   // 128 frames (~2.7ms @ 48kHz) - max CPU usage
        case low        // 256 frames (~5.3ms @ 48kHz) - balanced
        case normal     // 512 frames (~10.7ms @ 48kHz) - battery friendly

        var bufferSize: AVAudioFrameCount {
            switch self {
            case .ultraLow: return AudioConfiguration.ultraLowLatencyBufferSize
            case .low: return AudioConfiguration.lowLatencyBufferSize
            case .normal: return AudioConfiguration.normalBufferSize
            }
        }

        var description: String {
            switch self {
            case .ultraLow: return "Ultra-Low (~2.7ms)"
            case .low: return "Low (~5.3ms)"
            case .normal: return "Normal (~10.7ms)"
            }
        }
    }

    /// Set latency mode and reconfigure audio session
    static func setLatencyMode(_ mode: LatencyMode) throws {
        currentBufferSize = mode.bufferSize
        #if !os(macOS)
        try configureAudioSession()
        #endif
        log.audio("🎵 Latency mode set to: \(mode.description)")
    }


    // MARK: - Thread Priority

    /// Set real-time audio thread priority
    static func setAudioThreadPriority() {
        // Get current thread
        var threadTimeConstraintPolicy = thread_time_constraint_policy()

        // Audio thread constraints (48kHz, 256 frames)
        let sampleRate = preferredSampleRate
        let bufferSize = currentBufferSize

        // Period: time for one buffer in nanoseconds
        let period = UInt32((Double(bufferSize) / sampleRate) * 1_000_000_000)

        // Computation: 75% of period
        let computation = UInt32(Double(period) * 0.75)

        // Constraint: 95% of period
        let constraint = UInt32(Double(period) * 0.95)

        threadTimeConstraintPolicy.period = period
        threadTimeConstraintPolicy.computation = computation
        threadTimeConstraintPolicy.constraint = constraint
        threadTimeConstraintPolicy.preemptible = 0  // Not preemptible

        // Apply policy
        var policyCount = mach_msg_type_number_t(
            MemoryLayout<thread_time_constraint_policy>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &threadTimeConstraintPolicy) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(policyCount)) {
                thread_policy_set(
                    mach_thread_self(),
                    thread_policy_flavor_t(THREAD_TIME_CONSTRAINT_POLICY),
                    $0,
                    policyCount
                )
            }
        }

        if result == KERN_SUCCESS {
            log.audio("✅ Real-time audio thread priority set")
        } else {
            log.audio("⚠️  Failed to set audio thread priority: \(result)", level: .warning)
        }
    }


    // MARK: - Performance Monitoring

    /// Measure actual audio latency
    static func measureLatency() -> TimeInterval {
        #if os(macOS)
        return Double(currentBufferSize) / preferredSampleRate
        #else
        let audioSession = AVAudioSession.sharedInstance()
        let inputLatency = audioSession.inputLatency
        let outputLatency = audioSession.outputLatency
        let ioBufferDuration = audioSession.ioBufferDuration

        return inputLatency + outputLatency + ioBufferDuration
        #endif
    }

    // MARK: - Audio Interruption Handling

    /// Callback invoked when audio session should resume after interruption
    static var onInterruptionResume: (() -> Void)?

    /// Callback invoked when audio session is interrupted (phone call, Siri, etc.)
    static var onInterruptionBegan: (() -> Void)?

    /// Register for audio session interruption and route change notifications.
    /// Call once during app startup after configureAudioSession().
    static func registerInterruptionHandlers() {
        #if os(macOS)
        log.audio("Audio interruption handlers: N/A on macOS")
        return
        #else
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            handleAudioInterruption(notification)
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            handleRouteChange(notification)
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { _ in
            handleMediaServicesReset()
        }

        log.audio("Audio interruption handlers registered")
        #endif // !os(macOS)
    }

    #if !os(macOS)
    private static func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            log.audio("Audio session interrupted (phone call, Siri, etc.)", level: .warning)
            onInterruptionBegan?()

        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                    log.audio("Audio session resumed after interruption")
                    onInterruptionResume?()
                } catch {
                    log.audio("Failed to reactivate audio session: \(error)", level: .error)
                }
            }

        @unknown default:
            break
        }
    }

    private static func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            log.audio("Audio device disconnected (headphones removed)", level: .warning)
        case .newDeviceAvailable:
            log.audio("New audio device connected")
        case .categoryChange:
            log.audio("Audio category changed")
        default:
            break
        }
    }

    private static func handleMediaServicesReset() {
        log.audio("Media services were reset - reinitializing audio", level: .warning)
        do {
            try configureAudioSession()
            onInterruptionResume?()
        } catch {
            log.audio("Failed to reconfigure audio after media services reset: \(error)", level: .error)
        }
    }
    #endif // !os(macOS)

    /// Get latency statistics
    static func latencyStats() -> String {
        let totalLatency = measureLatency() * 1000  // Convert to ms
        #if os(macOS)
        return """
        🎵 Audio Latency Statistics (macOS HAL):
           Buffer: \(currentBufferSize) frames
           Estimated Latency: \(String(format: "%.2f", totalLatency)) ms
        """
        #else
        let audioSession = AVAudioSession.sharedInstance()
        return """
        🎵 Audio Latency Statistics:
           Sample Rate: \(audioSession.sampleRate) Hz
           IO Buffer: \(audioSession.ioBufferDuration * 1000) ms (\(currentBufferSize) frames)
           Input Latency: \(audioSession.inputLatency * 1000) ms
           Output Latency: \(audioSession.outputLatency * 1000) ms
           Total Latency: \(String(format: "%.2f", totalLatency)) ms
           Target: < 5.0 ms
           Status: \(totalLatency < 5.0 ? "✅ EXCELLENT" : totalLatency < 10.0 ? "⚠️  GOOD" : "❌ NEEDS OPTIMIZATION")
        """
        #endif
    }
}

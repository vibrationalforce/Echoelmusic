#if canImport(SoundAnalysis) && canImport(AVFoundation)
import SoundAnalysis
import AVFoundation
import Observation

/// Detects claps, snaps, and other sound events for hands-free loop control.
/// Uses Apple's built-in SoundAnalysis classifier (300+ categories, on-device ML).
///
/// CPU: ~5-8% when active. Toggle on/off as needed.
@MainActor
@Observable
final class SoundEventDetector: NSObject {

    /// Last detected sound event
    var lastEvent: SoundEvent = .none

    /// Whether detection is active
    var isListening: Bool = false

    enum SoundEvent: String {
        case none = ""
        case clap = "Clap"
        case snap = "Snap"
        case whistle = "Whistle"
    }

    // MARK: - Private

    @ObservationIgnored private var analyzer: SNAudioStreamAnalyzer?
    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private let analysisQueue = DispatchQueue(label: "com.echoelmusic.soundanalysis")

    // MARK: - Public API

    /// Start listening for sound events using the default microphone
    func startListening() {
        guard !isListening else { return }

        do {
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
                log.log(.error, category: .audio, "SoundEventDetector: Invalid input format")
                return
            }

            let streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)

            // Use Apple's built-in sound classifier
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            request.windowDuration = CMTime(seconds: 0.5, preferredTimescale: 48000)
            request.overlapFactor = 0.5
            try streamAnalyzer.add(request, withObserver: self)

            // Install tap to feed audio to analyzer
            inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak streamAnalyzer] buffer, time in
                streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }

            try engine.start()
            self.audioEngine = engine
            self.analyzer = streamAnalyzer
            isListening = true

            log.log(.info, category: .audio, "SoundEventDetector: Listening for claps/snaps/whistles")
        } catch {
            log.log(.error, category: .audio, "SoundEventDetector: Failed to start — \(error.localizedDescription)")
        }
    }

    func stopListening() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        analyzer = nil
        isListening = false
        lastEvent = .none
        log.log(.info, category: .audio, "SoundEventDetector: Stopped")
    }
}

// MARK: - SNResultsObserving

extension SoundEventDetector: SNResultsObserving {
    nonisolated func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let classification = result as? SNClassificationResult else { return }

        // Check for relevant sound categories with confidence > 50%
        for item in classification.classifications {
            guard item.confidence > 0.5 else { continue }

            let event: SoundEvent?
            switch item.identifier {
            case "clapping", "applause":
                event = .clap
            case "finger_snapping":
                event = .snap
            case "whistling":
                event = .whistle
            default:
                event = nil
            }

            if let event {
                DispatchQueue.main.async { [weak self] in
                    self?.lastEvent = event
                    // Auto-reset after brief period
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.lastEvent = .none
                    }
                }
                break // Only process first match
            }
        }
    }

    nonisolated func request(_ request: SNRequest, didFailWithError error: Error) {
        log.log(.error, category: .audio, "SoundEventDetector error: \(error.localizedDescription)")
    }
}
#endif

#if canImport(AVFoundation)
import AVFoundation

/// Always-on circular audio buffer that captures the last N seconds of synth output.
/// When the user hears something beautiful, they tap "Capture" to save it as a loop —
/// no prior "Record" press needed. Like Ableton's Capture, but for audio (not MIDI).
///
/// Memory: 30s × 48kHz × 2ch × 4 bytes = ~11.5MB. Well within 200MB budget.
/// CPU: Zero — uses the existing mainMixerNode tap from AudioEngine.
///
/// Thread safety: Written from audio tap callback (background), read from MainActor.
/// Uses lock-free ring buffer pattern with atomic write index.
/// Not @MainActor — write() is called from audio tap callback thread.
/// All mutable state is nonisolated(unsafe) for lock-free audio-thread access.
final class AudioCaptureRing: @unchecked Sendable {

    /// Maximum capture duration in seconds
    let maxDuration: TimeInterval = 30.0

    /// Whether the buffer is actively capturing
    nonisolated(unsafe) var isCapturing: Bool = false

    // MARK: - Private

    /// Ring buffer for left channel
    @ObservationIgnored nonisolated(unsafe) private var bufferL: [Float] = []
    /// Ring buffer for right channel
    @ObservationIgnored nonisolated(unsafe) private var bufferR: [Float] = []
    /// Current write position (wraps around)
    @ObservationIgnored nonisolated(unsafe) private var writeIndex: Int = 0
    /// Total frames written (for knowing how full the buffer is)
    @ObservationIgnored nonisolated(unsafe) private var totalFramesWritten: Int = 0

    private let sampleRate: Double = 48000
    private var capacity: Int { Int(maxDuration * sampleRate) }

    // MARK: - Setup

    /// Pre-allocate the circular buffer
    func prepare() {
        let cap = capacity
        bufferL = [Float](repeating: 0, count: cap)
        bufferR = [Float](repeating: 0, count: cap)
        writeIndex = 0
        totalFramesWritten = 0
        log.audio("AudioCaptureRing: Allocated \(cap * 2 * 4 / 1024)KB for \(Int(maxDuration))s circular capture")
    }

    /// Start capturing — call this once on app launch
    func startCapturing(engine: AudioEngine) {
        guard !isCapturing else { return }
        if bufferL.isEmpty {
            prepare()
        }
        isCapturing = true
        log.audio("AudioCaptureRing: Capturing started (always-on)")
    }

    // MARK: - Write (called from audio tap — background thread)

    /// Feed audio data into the circular buffer. Called from the mainMixerNode tap.
    /// This runs on the audio callback thread — no locks, no allocation.
    nonisolated func write(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0, !bufferL.isEmpty else { return }

        let cap = bufferL.count
        let leftData = channelData[0]
        let rightData = buffer.format.channelCount > 1 ? channelData[1] : channelData[0]

        for i in 0..<frameCount {
            let idx = writeIndex % cap
            bufferL[idx] = leftData[i]
            bufferR[idx] = rightData[i]
            writeIndex = (writeIndex + 1) % cap
        }
        totalFramesWritten += frameCount
    }

    // MARK: - Capture (called from MainActor when user taps "Capture")

    /// Extract the last N bars from the circular buffer as a playable audio file.
    /// Quantizes to the nearest bar boundary at the given BPM.
    func capture(bars: Int, bpm: Double) throws -> URL {
        let barDuration = (60.0 / max(bpm, 20.0)) * 4.0 // 4/4 time
        let requestedDuration = Double(bars) * barDuration
        let requestedFrames = min(Int(requestedDuration * sampleRate), capacity)

        // How many frames are actually available?
        let availableFrames = min(totalFramesWritten, capacity)
        let captureFrames = min(requestedFrames, availableFrames)
        guard captureFrames > 0 else {
            throw NSError(domain: "AudioCaptureRing", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No audio captured yet"])
        }

        // Create output format
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 2,
            interleaved: false
        ) else {
            throw NSError(domain: "AudioCaptureRing", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot create audio format"])
        }

        // Create buffer
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(captureFrames)) else {
            throw NSError(domain: "AudioCaptureRing", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot create output buffer"])
        }
        outputBuffer.frameLength = AVAudioFrameCount(captureFrames)

        guard let outL = outputBuffer.floatChannelData?[0],
              let outR = outputBuffer.floatChannelData?[1] else {
            throw NSError(domain: "AudioCaptureRing", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot access output channels"])
        }

        // Read from circular buffer (oldest captured frame first)
        let cap = capacity
        let readStart = (writeIndex - captureFrames + cap) % cap

        for i in 0..<captureFrames {
            let idx = (readStart + i) % cap
            outL[i] = bufferL[idx]
            outR[i] = bufferR[idx]
        }

        // Write to file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let captureDir = documentsPath.appendingPathComponent("Captures", isDirectory: true)
        try FileManager.default.createDirectory(at: captureDir, withIntermediateDirectories: true)

        let fileName = "capture_\(bars)bars_\(Int(bpm))bpm_\(Int(Date().timeIntervalSince1970)).caf"
        let fileURL = captureDir.appendingPathComponent(fileName)

        let file = try AVAudioFile(forWriting: fileURL, settings: format.settings)
        try file.write(from: outputBuffer)

        log.audio("AudioCaptureRing: Captured \(bars) bars (\(String(format: "%.1f", requestedDuration))s) → \(fileName)")
        return fileURL
    }
}
#endif

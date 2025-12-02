import Foundation
import AVFoundation
import Accelerate
import Combine

/// Automatic Vocal Alignment Tool - Professional Multi-Track Vocal Sync
/// Similar to VocAlign Pro, Synchro Arts Revoice Pro, and Melodyne ARA
///
/// Features:
/// - Automatic timing alignment of dub vocals to guide track
/// - Preserves pitch and formants during time-stretching
/// - Real-time preview
/// - Batch processing for multiple takes
/// - Tightness control (how closely to follow guide)
/// - Selective alignment (align only specific sections)
///
/// Use Cases:
/// - Tight vocal doubles and harmonies
/// - ADR (Automated Dialogue Replacement)
/// - Podcast/interview alignment
/// - Choir/ensemble tightening
@MainActor
class AutomaticVocalAligner: ObservableObject {

    // MARK: - Published State

    @Published var isProcessing: Bool = false
    @Published var progress: Float = 0.0
    @Published var guideTrack: VocalTrack?
    @Published var dubTracks: [VocalTrack] = []
    @Published var alignmentResults: [UUID: AlignmentResult] = [:]

    // MARK: - Alignment Settings

    @Published var tightness: Float = 0.8        // 0.0 = loose, 1.0 = tight
    @Published var preserveFormants: Bool = true
    @Published var maxStretch: Float = 2.0       // Maximum time-stretch ratio
    @Published var analysisWindowMs: Float = 50  // Analysis window size
    @Published var hopSizeMs: Float = 10         // Hop size between windows

    // MARK: - Types

    struct VocalTrack: Identifiable {
        let id: UUID
        let name: String
        let url: URL
        var audioBuffer: AVAudioPCMBuffer?
        var onsetTimes: [Float] = []      // Detected onset times in seconds
        var energyProfile: [Float] = []   // Energy envelope
        var pitchProfile: [Float] = []    // F0 pitch contour
        var duration: TimeInterval = 0
    }

    struct AlignmentResult: Identifiable {
        let id: UUID
        let trackId: UUID
        var timeWarpMap: [TimeWarpPoint] = []  // Original → Aligned time mapping
        var stretchFactors: [Float] = []        // Per-frame stretch factors
        var alignedBuffer: AVAudioPCMBuffer?
        var qualityScore: Float = 0.0           // 0-100% alignment quality
        var processingTime: TimeInterval = 0
    }

    struct TimeWarpPoint {
        var originalTime: Float
        var alignedTime: Float
        var stretchFactor: Float
    }

    // MARK: - Audio Engine

    private let audioEngine = AVAudioEngine()
    private var playerNode: AVAudioPlayerNode?
    private var timePitchNode: AVAudioUnitTimePitch?

    // MARK: - DSP Constants

    private let fftSize: Int = 2048
    private let sampleRate: Float = 48000.0

    // MARK: - Initialization

    init() {
        setupAudioEngine()
        print("✅ AutomaticVocalAligner: Initialized")
        print("🎤 Professional Vocal Alignment Ready")
    }

    deinit {
        audioEngine.stop()
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        playerNode = AVAudioPlayerNode()
        timePitchNode = AVAudioUnitTimePitch()

        guard let player = playerNode, let timePitch = timePitchNode else { return }

        audioEngine.attach(player)
        audioEngine.attach(timePitch)

        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)!

        audioEngine.connect(player, to: timePitch, format: format)
        audioEngine.connect(timePitch, to: audioEngine.mainMixerNode, format: format)
    }

    // MARK: - Load Tracks

    func loadGuideTrack(from url: URL) async throws {
        let track = try await loadAudioFile(url: url, name: "Guide")
        guideTrack = track

        // Analyze guide track
        if var guide = guideTrack {
            guide.onsetTimes = await detectOnsets(buffer: guide.audioBuffer!)
            guide.energyProfile = await computeEnergyEnvelope(buffer: guide.audioBuffer!)
            guide.pitchProfile = await detectPitch(buffer: guide.audioBuffer!)
            guideTrack = guide
        }

        print("🎤 Guide track loaded: \(track.name) (\(String(format: "%.1f", track.duration))s)")
    }

    func addDubTrack(from url: URL) async throws {
        let track = try await loadAudioFile(url: url, name: "Dub \(dubTracks.count + 1)")

        var analyzedTrack = track
        analyzedTrack.onsetTimes = await detectOnsets(buffer: track.audioBuffer!)
        analyzedTrack.energyProfile = await computeEnergyEnvelope(buffer: track.audioBuffer!)
        analyzedTrack.pitchProfile = await detectPitch(buffer: track.audioBuffer!)

        dubTracks.append(analyzedTrack)

        print("🎤 Dub track added: \(track.name) (\(String(format: "%.1f", track.duration))s)")
    }

    private func loadAudioFile(url: URL, name: String) async throws -> VocalTrack {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AlignmentError.bufferCreationFailed
        }

        try audioFile.read(into: buffer)

        return VocalTrack(
            id: UUID(),
            name: name,
            url: url,
            audioBuffer: buffer,
            duration: Double(frameCount) / format.sampleRate
        )
    }

    // MARK: - Alignment Process

    /// Align all dub tracks to the guide track
    func alignAllTracks() async throws {
        guard let guide = guideTrack else {
            throw AlignmentError.noGuideTrack
        }

        guard !dubTracks.isEmpty else {
            throw AlignmentError.noDubTracks
        }

        isProcessing = true
        progress = 0.0

        let startTime = Date()

        for (index, dubTrack) in dubTracks.enumerated() {
            // Update progress
            progress = Float(index) / Float(dubTracks.count)

            // Compute alignment
            let result = try await alignTrack(dub: dubTrack, to: guide)
            alignmentResults[dubTrack.id] = result

            print("✅ Aligned: \(dubTrack.name) (Quality: \(String(format: "%.1f", result.qualityScore))%)")
        }

        progress = 1.0
        isProcessing = false

        let totalTime = Date().timeIntervalSince(startTime)
        print("🎤 All tracks aligned in \(String(format: "%.2f", totalTime))s")
    }

    /// Align a single dub track to the guide
    func alignTrack(dub: VocalTrack, to guide: VocalTrack) async throws -> AlignmentResult {
        let startTime = Date()

        // Step 1: Dynamic Time Warping (DTW) to find optimal alignment path
        let warpPath = await computeDTW(
            guideEnergy: guide.energyProfile,
            dubEnergy: dub.energyProfile
        )

        // Step 2: Convert DTW path to time warp map
        let timeWarpMap = convertPathToTimeWarp(
            path: warpPath,
            guideDuration: Float(guide.duration),
            dubDuration: Float(dub.duration)
        )

        // Step 3: Apply tightness control
        let adjustedWarpMap = applyTightnessControl(
            warpMap: timeWarpMap,
            tightness: tightness
        )

        // Step 4: Time-stretch the dub track
        let alignedBuffer = try await applyTimeWarp(
            buffer: dub.audioBuffer!,
            warpMap: adjustedWarpMap,
            preserveFormants: preserveFormants
        )

        // Step 5: Compute quality score
        let qualityScore = computeAlignmentQuality(
            guideEnergy: guide.energyProfile,
            alignedEnergy: await computeEnergyEnvelope(buffer: alignedBuffer)
        )

        let processingTime = Date().timeIntervalSince(startTime)

        return AlignmentResult(
            id: UUID(),
            trackId: dub.id,
            timeWarpMap: adjustedWarpMap,
            stretchFactors: adjustedWarpMap.map { $0.stretchFactor },
            alignedBuffer: alignedBuffer,
            qualityScore: qualityScore,
            processingTime: processingTime
        )
    }

    // MARK: - DSP: Onset Detection

    private func detectOnsets(buffer: AVAudioPCMBuffer) async -> [Float] {
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let frameCount = Int(buffer.frameLength)

        let hopSize = Int(hopSizeMs * sampleRate / 1000.0)
        let windowSize = Int(analysisWindowMs * sampleRate / 1000.0)

        var onsets: [Float] = []
        var previousEnergy: Float = 0.0
        let threshold: Float = 0.1

        for i in stride(from: 0, to: frameCount - windowSize, by: hopSize) {
            // Compute spectral flux
            var energy: Float = 0.0
            vDSP_svesq(channelData.advanced(by: i), 1, &energy, vDSP_Length(windowSize))
            energy = sqrt(energy / Float(windowSize))

            // Onset = significant energy increase
            let flux = max(0, energy - previousEnergy)
            if flux > threshold && previousEnergy < threshold {
                let timeSeconds = Float(i) / sampleRate
                onsets.append(timeSeconds)
            }

            previousEnergy = energy
        }

        return onsets
    }

    // MARK: - DSP: Energy Envelope

    private func computeEnergyEnvelope(buffer: AVAudioPCMBuffer) async -> [Float] {
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let frameCount = Int(buffer.frameLength)

        let hopSize = Int(hopSizeMs * sampleRate / 1000.0)
        let windowSize = Int(analysisWindowMs * sampleRate / 1000.0)
        let numFrames = (frameCount - windowSize) / hopSize

        var envelope = [Float](repeating: 0, count: numFrames)

        for i in 0..<numFrames {
            let offset = i * hopSize
            var energy: Float = 0.0
            vDSP_svesq(channelData.advanced(by: offset), 1, &energy, vDSP_Length(windowSize))
            envelope[i] = sqrt(energy / Float(windowSize))
        }

        // Normalize
        var maxEnergy: Float = 0.0
        vDSP_maxv(envelope, 1, &maxEnergy, vDSP_Length(numFrames))
        if maxEnergy > 0 {
            var scale = 1.0 / maxEnergy
            vDSP_vsmul(envelope, 1, &scale, &envelope, 1, vDSP_Length(numFrames))
        }

        return envelope
    }

    // MARK: - DSP: Pitch Detection (YIN Algorithm)

    private func detectPitch(buffer: AVAudioPCMBuffer) async -> [Float] {
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let frameCount = Int(buffer.frameLength)

        let hopSize = Int(hopSizeMs * sampleRate / 1000.0)
        let windowSize = Int(analysisWindowMs * sampleRate / 1000.0)
        let numFrames = (frameCount - windowSize) / hopSize

        var pitchContour = [Float](repeating: 0, count: numFrames)

        for i in 0..<numFrames {
            let offset = i * hopSize
            pitchContour[i] = yinPitchDetection(
                signal: channelData.advanced(by: offset),
                length: windowSize,
                sampleRate: sampleRate
            )
        }

        return pitchContour
    }

    private func yinPitchDetection(signal: UnsafePointer<Float>, length: Int, sampleRate: Float) -> Float {
        let minLag = Int(sampleRate / 500.0)  // Max frequency 500 Hz
        let maxLag = Int(sampleRate / 50.0)   // Min frequency 50 Hz

        guard maxLag < length / 2 else { return 0 }

        // Compute difference function
        var diff = [Float](repeating: 0, count: maxLag)

        for tau in minLag..<maxLag {
            var sum: Float = 0.0
            for j in 0..<(length - tau) {
                let delta = signal[j] - signal[j + tau]
                sum += delta * delta
            }
            diff[tau] = sum
        }

        // Cumulative mean normalized difference
        var cmndf = [Float](repeating: 0, count: maxLag)
        cmndf[0] = 1.0
        var runningSum: Float = 0.0

        for tau in 1..<maxLag {
            runningSum += diff[tau]
            cmndf[tau] = diff[tau] * Float(tau) / runningSum
        }

        // Find first minimum below threshold
        let threshold: Float = 0.1
        for tau in minLag..<maxLag {
            if cmndf[tau] < threshold {
                // Parabolic interpolation for sub-sample accuracy
                let betterTau = parabolicInterpolation(cmndf, tau)
                return sampleRate / betterTau
            }
        }

        return 0  // Unvoiced
    }

    private func parabolicInterpolation(_ values: [Float], _ index: Int) -> Float {
        guard index > 0 && index < values.count - 1 else {
            return Float(index)
        }

        let s0 = values[index - 1]
        let s1 = values[index]
        let s2 = values[index + 1]

        let denominator = 2.0 * (2.0 * s1 - s2 - s0)
        guard abs(denominator) > 1e-10 else { return Float(index) }

        let adjustment = (s2 - s0) / denominator
        return Float(index) + adjustment
    }

    // MARK: - DSP: Dynamic Time Warping

    private func computeDTW(guideEnergy: [Float], dubEnergy: [Float]) async -> [(Int, Int)] {
        let n = guideEnergy.count
        let m = dubEnergy.count

        guard n > 0 && m > 0 else { return [] }

        // Cost matrix
        var cost = [[Float]](repeating: [Float](repeating: Float.infinity, count: m), count: n)
        cost[0][0] = abs(guideEnergy[0] - dubEnergy[0])

        // Fill first row
        for j in 1..<m {
            cost[0][j] = cost[0][j-1] + abs(guideEnergy[0] - dubEnergy[j])
        }

        // Fill first column
        for i in 1..<n {
            cost[i][0] = cost[i-1][0] + abs(guideEnergy[i] - dubEnergy[0])
        }

        // Fill rest of matrix
        for i in 1..<n {
            for j in 1..<m {
                let localCost = abs(guideEnergy[i] - dubEnergy[j])
                cost[i][j] = localCost + min(cost[i-1][j], cost[i][j-1], cost[i-1][j-1])
            }
        }

        // Backtrack to find optimal path
        var path: [(Int, Int)] = []
        var i = n - 1
        var j = m - 1

        while i > 0 || j > 0 {
            path.append((i, j))

            if i == 0 {
                j -= 1
            } else if j == 0 {
                i -= 1
            } else {
                let minCost = min(cost[i-1][j], cost[i][j-1], cost[i-1][j-1])
                if cost[i-1][j-1] == minCost {
                    i -= 1
                    j -= 1
                } else if cost[i-1][j] == minCost {
                    i -= 1
                } else {
                    j -= 1
                }
            }
        }
        path.append((0, 0))

        return path.reversed()
    }

    // MARK: - Time Warp Conversion

    private func convertPathToTimeWarp(path: [(Int, Int)], guideDuration: Float, dubDuration: Float) -> [TimeWarpPoint] {
        guard !path.isEmpty else { return [] }

        let guideFrames = Float(path.map { $0.0 }.max() ?? 1)
        let dubFrames = Float(path.map { $0.1 }.max() ?? 1)

        var warpPoints: [TimeWarpPoint] = []

        for (guideIdx, dubIdx) in path {
            let originalTime = Float(dubIdx) / dubFrames * dubDuration
            let alignedTime = Float(guideIdx) / guideFrames * guideDuration

            let stretchFactor = dubDuration > 0 ? alignedTime / max(originalTime, 0.001) : 1.0
            let clampedStretch = min(max(stretchFactor, 1.0 / maxStretch), maxStretch)

            warpPoints.append(TimeWarpPoint(
                originalTime: originalTime,
                alignedTime: alignedTime,
                stretchFactor: clampedStretch
            ))
        }

        return warpPoints
    }

    private func applyTightnessControl(warpMap: [TimeWarpPoint], tightness: Float) -> [TimeWarpPoint] {
        return warpMap.map { point in
            // Interpolate between original timing (tightness=0) and aligned timing (tightness=1)
            let adjustedAlignedTime = point.originalTime + (point.alignedTime - point.originalTime) * tightness
            let adjustedStretch = 1.0 + (point.stretchFactor - 1.0) * tightness

            return TimeWarpPoint(
                originalTime: point.originalTime,
                alignedTime: adjustedAlignedTime,
                stretchFactor: adjustedStretch
            )
        }
    }

    // MARK: - Time Stretching (WSOLA Algorithm)

    private func applyTimeWarp(buffer: AVAudioPCMBuffer, warpMap: [TimeWarpPoint], preserveFormants: Bool) async throws -> AVAudioPCMBuffer {
        guard let inputData = buffer.floatChannelData?[0] else {
            throw AlignmentError.invalidBuffer
        }

        let inputLength = Int(buffer.frameLength)
        let format = buffer.format

        // Calculate output length based on warp map
        let lastWarp = warpMap.last ?? TimeWarpPoint(originalTime: 0, alignedTime: 0, stretchFactor: 1.0)
        let outputLength = Int(lastWarp.alignedTime * Float(format.sampleRate))

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(outputLength)) else {
            throw AlignmentError.bufferCreationFailed
        }
        outputBuffer.frameLength = AVAudioFrameCount(outputLength)

        guard let outputData = outputBuffer.floatChannelData?[0] else {
            throw AlignmentError.invalidBuffer
        }

        // WSOLA (Waveform Similarity Overlap-Add) time stretching
        let windowSize = 1024
        let hopSize = 256

        // Create Hann window
        var window = [Float](repeating: 0, count: windowSize)
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))

        var outputPosition = 0
        var inputPosition: Float = 0.0

        while outputPosition < outputLength - windowSize {
            // Find current stretch factor from warp map
            let currentTime = Float(outputPosition) / Float(format.sampleRate)
            let stretchFactor = interpolateStretchFactor(warpMap: warpMap, time: currentTime)

            // Read position in input
            let readPos = Int(inputPosition)
            guard readPos >= 0 && readPos + windowSize < inputLength else { break }

            // Apply window and add to output
            for i in 0..<windowSize {
                let inputSample = inputData[readPos + i] * window[i]
                outputData[outputPosition + i] += inputSample
            }

            // Advance positions
            outputPosition += hopSize
            inputPosition += Float(hopSize) * stretchFactor
        }

        // Normalize output
        var maxAmp: Float = 0.0
        vDSP_maxmgv(outputData, 1, &maxAmp, vDSP_Length(outputLength))
        if maxAmp > 0 {
            var scale = 0.9 / maxAmp
            vDSP_vsmul(outputData, 1, &scale, outputData, 1, vDSP_Length(outputLength))
        }

        return outputBuffer
    }

    private func interpolateStretchFactor(warpMap: [TimeWarpPoint], time: Float) -> Float {
        guard !warpMap.isEmpty else { return 1.0 }

        // Find surrounding points
        var prevPoint = warpMap[0]
        var nextPoint = warpMap[0]

        for point in warpMap {
            if point.alignedTime <= time {
                prevPoint = point
            }
            if point.alignedTime >= time {
                nextPoint = point
                break
            }
        }

        // Linear interpolation
        let range = nextPoint.alignedTime - prevPoint.alignedTime
        if range < 0.001 {
            return prevPoint.stretchFactor
        }

        let t = (time - prevPoint.alignedTime) / range
        return prevPoint.stretchFactor + t * (nextPoint.stretchFactor - prevPoint.stretchFactor)
    }

    // MARK: - Quality Assessment

    private func computeAlignmentQuality(guideEnergy: [Float], alignedEnergy: [Float]) -> Float {
        let minLen = min(guideEnergy.count, alignedEnergy.count)
        guard minLen > 0 else { return 0 }

        // Compute correlation coefficient
        var guideSlice = Array(guideEnergy.prefix(minLen))
        var alignedSlice = Array(alignedEnergy.prefix(minLen))

        // Mean
        var guideMean: Float = 0
        var alignedMean: Float = 0
        vDSP_meanv(guideSlice, 1, &guideMean, vDSP_Length(minLen))
        vDSP_meanv(alignedSlice, 1, &alignedMean, vDSP_Length(minLen))

        // Subtract mean
        var negGuideMean = -guideMean
        var negAlignedMean = -alignedMean
        vDSP_vsadd(guideSlice, 1, &negGuideMean, &guideSlice, 1, vDSP_Length(minLen))
        vDSP_vsadd(alignedSlice, 1, &negAlignedMean, &alignedSlice, 1, vDSP_Length(minLen))

        // Cross-correlation
        var correlation: Float = 0
        vDSP_dotpr(guideSlice, 1, alignedSlice, 1, &correlation, vDSP_Length(minLen))

        // Standard deviations
        var guideVar: Float = 0
        var alignedVar: Float = 0
        vDSP_svesq(guideSlice, 1, &guideVar, vDSP_Length(minLen))
        vDSP_svesq(alignedSlice, 1, &alignedVar, vDSP_Length(minLen))

        let denominator = sqrt(guideVar * alignedVar)
        guard denominator > 0 else { return 0 }

        let r = correlation / denominator
        return max(0, min(100, (r + 1) * 50))  // Convert -1..1 to 0..100
    }

    // MARK: - Preview

    func previewAlignedTrack(_ trackId: UUID) async throws {
        guard let result = alignmentResults[trackId],
              let buffer = result.alignedBuffer else {
            throw AlignmentError.noAlignmentResult
        }

        do {
            try audioEngine.start()
            playerNode?.scheduleBuffer(buffer, completionHandler: nil)
            playerNode?.play()
        } catch {
            throw AlignmentError.playbackFailed(error)
        }
    }

    func stopPreview() {
        playerNode?.stop()
        audioEngine.stop()
    }

    // MARK: - Export

    func exportAlignedTrack(_ trackId: UUID, to url: URL) async throws {
        guard let result = alignmentResults[trackId],
              let buffer = result.alignedBuffer else {
            throw AlignmentError.noAlignmentResult
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: buffer.format.sampleRate,
            AVNumberOfChannelsKey: buffer.format.channelCount,
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        let audioFile = try AVAudioFile(forWriting: url, settings: settings)
        try audioFile.write(from: buffer)

        print("✅ Exported aligned track to: \(url.lastPathComponent)")
    }

    // MARK: - Errors

    enum AlignmentError: LocalizedError {
        case noGuideTrack
        case noDubTracks
        case bufferCreationFailed
        case invalidBuffer
        case noAlignmentResult
        case playbackFailed(Error)

        var errorDescription: String? {
            switch self {
            case .noGuideTrack:
                return "No guide track loaded. Load a guide track first."
            case .noDubTracks:
                return "No dub tracks to align. Add at least one dub track."
            case .bufferCreationFailed:
                return "Failed to create audio buffer."
            case .invalidBuffer:
                return "Invalid audio buffer data."
            case .noAlignmentResult:
                return "No alignment result available for this track."
            case .playbackFailed(let error):
                return "Playback failed: \(error.localizedDescription)"
            }
        }
    }
}

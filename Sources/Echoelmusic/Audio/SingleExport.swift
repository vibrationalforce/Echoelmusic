#if canImport(AVFoundation)
import AVFoundation
import Accelerate
import Observation

/// Mastering + export for a completed improvisation session.
/// Takes the raw .caf from RetroCapture, applies LUFS normalization,
/// and exports a release-ready file (WAV/AAC) ready for sharing.
///
/// Usage:
///   let exporter = SingleExport()
///   exporter.outputFormat = .aac
///   exporter.targetLUFS = -14        // or nil to skip normalisation entirely
///   await exporter.export(sourceURL: cafURL)
///   let url = exporter.exportState.exportedURL
@MainActor @Observable
final class SingleExport {

    // MARK: - Export format

    enum OutputFormat: CaseIterable, Identifiable {
        case wav, aac

        var id: String { label }

        var label: String {
            switch self {
            case .wav: return "WAV (lossless)"
            case .aac: return "AAC (streaming)"
            }
        }

        var fileExtension: String {
            switch self {
            case .wav: return "wav"
            case .aac: return "m4a"
            }
        }

        var avFileType: AVFileType {
            switch self {
            case .wav: return .wav
            case .aac: return .m4a
            }
        }
    }

    // MARK: - State

    enum ExportState: Equatable {
        case idle
        case analyzing
        case exporting(progress: Float)
        case done(URL)
        case error(String)

        var isDone: Bool {
            if case .done = self { return true }
            return false
        }

        var exportedURL: URL? {
            if case .done(let url) = self { return url }
            return nil
        }
    }

    private(set) var exportState: ExportState = .idle
    var outputFormat: OutputFormat = .aac
    /// Loudness to normalise to, or `nil` for NO normalisation (render at the level
    /// that was actually captured). Optional rather than a sentinel because "off" is a
    /// real delivery choice the Master panel offers — see `LoudnessTarget.off`.
    var targetLUFS: Float? = -14

    // Bar-aligned loop trim (audit C6/C7). When `trimLengthSeconds` is set, ONLY
    // the window [duration − trimFromEnd − length, +length] of the source is
    // measured AND rendered — the exact loop, cut from the end of the capture
    // (window math: StudioCalculator.loopTrimWindow). Falls back to an unaligned
    // end cut, then to the untrimmed file, when the capture is too short.
    var trimLengthSeconds: Double?
    var trimFromEndSeconds: Double = 0
    /// Micro fade at the trimmed edges — kills residual seam ticks without an
    /// audible dip (~4 ms). Applied only when a trim window is active.
    var edgeFadeSeconds: Double = 0

    // MARK: - Export

    /// Gain to apply so a take measured at `measuredDB` lands on `target` — or 0 dB
    /// when `target` is nil ("No target": deliver at the captured level). Clamped to
    /// ±12 dB so a mismeasured or near-silent take can't be slammed.
    ///
    /// Pure + static ON PURPOSE. Inline inside the `async` AVFoundation method this
    /// arithmetic was untestable, and it is the one line the "No target" fix actually
    /// changes in the audio path — so it was the half of that fix nothing asserted.
    /// A pure seam makes "nil ⇒ 0 dB" a test rather than a hope.
    nonisolated static func normalizeGainDB(target: Float?, measuredDB: Float) -> Float {
        let raw = target.map { $0 - measuredDB } ?? 0
        return Swift.min(Swift.max(raw, -12), 12)
    }

    // MARK: - Post-normalisation peak safety (E1)
    //
    // ⛔ THE DEFECT THIS CLOSES. `normalizeGainDB` may ask for up to +12 dB, and the loudness
    // it steers by is an RMS over the whole window — it knows nothing about PEAKS. A sparse
    // take (a quiet body with one hot transient near full scale) measures quiet, gets the
    // full boost, and the transient lands up to ~12 dB over full scale. Nothing after the
    // `vDSP_vsmul` bounded it: the WAV branch then converts to 24-bit integer PCM (hard clip
    // at the converter), and the AAC branch hands the same over-range floats to the encoder.
    //
    // ⭐ THE REPAIR IS A GAIN BOUND, NOT A LIMITER. The export already reads the whole window
    // once to measure loudness; that pass now also takes the SAMPLE PEAK, and a positive gain
    // is capped so `peak × gain` stays at or under `exportSamplePeakCeilingDBFS`. Nothing is
    // clipped and no dynamics change: the bound only lowers ONE scalar, so the waveform is the
    // same shape at a lower level. `EchoelLimiter` (`DSP/EchoelDynamics.swift`) was NOT reused:
    // it is a stateful real-time stage with release ballistics — running it offline here would
    // change what the export SOUNDS like, which is a mastering decision, not a safety repair.
    //
    // ⚠️ WHAT THIS IS, NAMED HONESTLY: a SAMPLE-PEAK bound on the decoded 44.1 kHz float
    // samples, measured and rendered from the SAME reader settings and window. It is NOT a
    // true-peak (inter-sample) bound, and it does not bound what the AAC ENCODER does to the
    // signal afterwards (codec overshoot). The −1 dBFS ceiling leaves room for both, but that
    // room is headroom, not a proof.
    //
    // NEEDS-FOUNDER-VERIFY: export a sparse take (quiet pad + one hard hit) at target −14 as
    // WAV and as AAC and listen — the hit must not crackle, and a plainly quiet take must still
    // come out louder than it was captured. Guard: `TheExportGainCannotClipTests`.

    /// Sample-peak ceiling a NORMALISATION BOOST may raise the export to, in dBFS.
    /// Sample peak, not true peak — see the block above.
    nonisolated static let exportSamplePeakCeilingDBFS: Float = -1

    /// Safety margin under the ceiling so float rounding in `log10f`/`powf`/the multiply can
    /// never land a sample a hair ABOVE it. ~0.01 % in level — inaudible by four orders.
    nonisolated static let peakBoundMarginDB: Float = 0.001

    /// The gain actually applied: `requestedDB` from `normalizeGainDB`, capped so a BOOST
    /// cannot lift the sample peak above `exportSamplePeakCeilingDBFS`.
    ///
    /// The rule, and why each branch is what it is:
    /// · requested ≤ 0 dB passes UNCHANGED — attenuation never raises a peak, and "No target"
    ///   (exactly 0 dB) must stay exactly the captured level.
    /// · a boost is capped at the headroom `ceiling − peak`, never below 0 dB — a source whose
    ///   peak already sits above the ceiling gets no boost, but it is not attenuated either:
    ///   its level is the performer's, not caused by this gain.
    /// · digital silence (peak 0) has nothing to overshoot, so the boost stands.
    /// · a non-finite peak or request cannot vouch for a boost — 0 dB.
    /// Consequence: whenever the applied gain is positive, `peak × gain ≤ ceiling`; whenever it
    /// is not, no sample grows. Normalisation still raises quiet material.
    nonisolated static func peakSafeGainDB(requestedDB: Float, sourcePeak: Float) -> Float {
        guard requestedDB.isFinite else { return 0 }
        guard requestedDB > 0 else { return requestedDB }
        guard sourcePeak.isFinite, sourcePeak >= 0 else { return 0 }
        guard sourcePeak > 0 else { return requestedDB }
        let headroomDB = exportSamplePeakCeilingDBFS - 20 * log10f(sourcePeak) - peakBoundMarginDB
        return Swift.min(requestedDB, Swift.max(headroomDB, 0))
    }

    /// Largest |sample| in a block. A NaN in the block may be reported as NaN — callers keep it,
    /// so `peakSafeGainDB` refuses the boost rather than trusting a partial measurement.
    nonisolated static func samplePeak(_ samples: UnsafePointer<Float>, count: Int) -> Float {
        guard count > 0 else { return 0 }
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(count))
        return peak
    }

    /// dB → linear, the ONE conversion the renderer uses (so a test drives the same number).
    nonisolated static func gainFactor(dB: Float) -> Float {
        powf(10, dB / 20)
    }

    /// The ONE place the export gain touches samples. In place, one scalar for every channel —
    /// interleaved stereo shares the gain, so the hottest channel's peak governs both.
    nonisolated static func applyGain(_ samples: UnsafeMutablePointer<Float>, count: Int,
                                      linearGain: Float) {
        guard count > 0 else { return }
        var gain = linearGain
        vDSP_vsmul(samples, 1, &gain, samples, 1, vDSP_Length(count))
    }

    func export(sourceURL: URL) async {
        guard exportState == .idle else { return }
        exportState = .analyzing
        log.log(.info, category: .audio, "SingleExport: analyzing \(sourceURL.lastPathComponent)")

        do {
            let outputURL = try makeOutputURL(sourceURL: sourceURL)
            let timeRange = try await resolveTrimRange(sourceURL: sourceURL)
            let levels = try await measureLUFS(sourceURL: sourceURL, timeRange: timeRange)
            let requestedGain = Self.normalizeGainDB(target: targetLUFS, measuredDB: levels.loudnessDB)
            let safeGain = Self.peakSafeGainDB(requestedDB: requestedGain, sourcePeak: levels.samplePeak)

            exportState = .exporting(progress: 0)
            log.log(.info, category: .audio, "SingleExport: gain \(String(format: "%.1f", safeGain))dB (requested \(String(format: "%.1f", requestedGain))dB) → \(outputFormat.label)")

            try await renderWithGain(sourceURL: sourceURL, outputURL: outputURL,
                                     gainDB: safeGain, timeRange: timeRange)
            exportState = .done(outputURL)
            log.log(.info, category: .audio, "SingleExport complete → \(outputURL.lastPathComponent)")
        } catch {
            exportState = .error(error.localizedDescription)
            log.log(.error, category: .audio, "SingleExport failed: \(error.localizedDescription)")
        }
    }

    func reset() {
        exportState = .idle
        trimLengthSeconds = nil
        trimFromEndSeconds = 0
        edgeFadeSeconds = 0
    }

    /// The CMTimeRange to read, honouring the loop-trim window. nil = whole file.
    private func resolveTrimRange(sourceURL: URL) async throws -> CMTimeRange? {
        guard let length = trimLengthSeconds else { return nil }
        let asset = AVAsset(url: sourceURL)
        let fileDuration = CMTimeGetSeconds(try await asset.load(.duration))
        // Bar-aligned first; unaligned end cut second; untrimmed as the last resort
        // (an untrimmed export is today's behaviour — never fail the whole export
        // just because the capture came up short).
        let window = StudioCalculator.loopTrimWindow(fileDuration: fileDuration,
                                                     loopSeconds: length,
                                                     secondsSinceBarStart: trimFromEndSeconds)
            ?? StudioCalculator.loopTrimWindow(fileDuration: fileDuration,
                                               loopSeconds: length,
                                               secondsSinceBarStart: 0)
        guard let window else {
            log.log(.error, category: .audio,
                    "SingleExport: capture (\(String(format: "%.2f", fileDuration))s) shorter than loop — exporting untrimmed")
            return nil
        }
        let scale: CMTimeScale = 44_100
        return CMTimeRange(start: CMTime(seconds: window.start, preferredTimescale: scale),
                           duration: CMTime(seconds: window.duration, preferredTimescale: scale))
    }

    // MARK: - LUFS measurement (BS.1770 approximation via RMS)

    /// Loudness (the RMS approximation below — E2 replaces it) AND the sample peak of the
    /// exact window that will be rendered, from one read.
    private func measureLUFS(sourceURL: URL,
                             timeRange: CMTimeRange?) async throws -> (loudnessDB: Float, samplePeak: Float) {
        let asset = AVAsset(url: sourceURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw ExportError.noAudioTrack
        }
        _ = track   // confirm audio track present

        let reader = try AVAssetReader(asset: asset)
        // Measure ONLY the loop window (C6): normalising against audio outside the
        // final cut would set the wrong gain for what actually ships in the file.
        if let timeRange { reader.timeRange = timeRange }
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let readerOutput = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: outputSettings)
        reader.add(readerOutput)
        guard reader.startReading() else {
            throw ExportError.cannotReadSource
        }

        var sumOfSquares: Double = 0
        var sampleCount: Int = 0
        // `isNaN ||` keeps a NaN once seen: `Swift.max(x, NaN)` would silently drop it, and a
        // dropped NaN reads as a clean measurement that can vouch for a boost.
        var peak: Float = 0

        while let buffer = readerOutput.copyNextSampleBuffer(),
              let blockBuffer = CMSampleBufferGetDataBuffer(buffer) {
            // Walk the block by offset: only `lengthAtOffset` bytes are guaranteed
            // contiguous at each returned pointer; `totalLength` may span multiple
            // segments, so reading totalLength/4 from one pointer would over-read a
            // segmented buffer. LPCM reader output is normally single-segment, so
            // this loops once in the common case.
            var offset = 0
            var totalLength = 0
            repeat {
                var lengthAtOffset = 0
                var dataPointer: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(blockBuffer, atOffset: offset,
                                            lengthAtOffsetOut: &lengthAtOffset,
                                            totalLengthOut: &totalLength,
                                            dataPointerOut: &dataPointer)
                guard let ptr = dataPointer, lengthAtOffset >= 4 else { break }
                let count = lengthAtOffset / 4
                let floatPtr = UnsafeRawPointer(ptr).bindMemory(to: Float.self, capacity: count)
                var rms: Float = 0
                vDSP_measqv(floatPtr, 1, &rms, vDSP_Length(count))
                sumOfSquares += Double(rms) * Double(count)
                sampleCount += count
                let segmentPeak = Self.samplePeak(floatPtr, count: count)
                if segmentPeak.isNaN || segmentPeak > peak { peak = segmentPeak }
                offset += lengthAtOffset
            } while offset < totalLength
        }

        guard sampleCount > 0 else { throw ExportError.emptyAudio }
        let rmsOverall = Float(sqrt(sumOfSquares / Double(sampleCount)))
        guard rmsOverall > 0.000001 else { return (-60, peak) }
        let dBFS = 20 * log10f(rmsOverall)
        return (dBFS - 0.1, peak)   // BS.1770 K-weighting approximation
    }

    // MARK: - Render with gain

    private func renderWithGain(sourceURL: URL, outputURL: URL, gainDB: Float,
                                timeRange: CMTimeRange?) async throws {
        let asset = AVAsset(url: sourceURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw ExportError.noAudioTrack
        }

        let duration = try await asset.load(.duration)
        let reader = try AVAssetReader(asset: asset)
        // Render ONLY the loop window (C6/C7): the output file is exactly one
        // bar-aligned loop, so it sits on the DAW grid and loops seamlessly.
        if let timeRange { reader.timeRange = timeRange }
        let inputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let readerOutput = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: inputSettings)
        reader.add(readerOutput)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: outputFormat.avFileType)
        let outputSettings = makeOutputSettings()
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        guard reader.startReading() else { throw ExportError.cannotReadSource }
        writer.startWriting()
        // With a trim window the reader delivers buffers stamped at their ORIGINAL
        // source times — the session must start at the window start or every
        // sample would be offset (silence at the head, tail cut off).
        writer.startSession(atSourceTime: timeRange?.start ?? .zero)

        let linearGain = Self.gainFactor(dB: gainDB)
        let windowStartSeconds = timeRange.map { CMTimeGetSeconds($0.start) } ?? 0
        let durationSeconds = timeRange.map { CMTimeGetSeconds($0.duration) }
            ?? CMTimeGetSeconds(duration)
        // Micro edge fades (loop seam safety): frame counts at the 44.1 kHz LPCM
        // reader rate, applied over interleaved stereo. Only the first/last
        // buffers ever intersect the fade zones, so the per-sample loop is cheap.
        let totalFrames = Int(durationSeconds * 44_100)
        let fadeFrames = edgeFadeSeconds > 0 ? Int(edgeFadeSeconds * 44_100) : 0
        var framesWritten = 0
        // ONE main-actor hop per PERCENT, not per sample buffer (#1335). The pull loop
        // below is OFFLINE — `expectsMediaDataInRealTime = false`, so it runs as fast as
        // the encoder accepts data and a few minutes of audio arrive as thousands of
        // buffers within seconds. A `Task { @MainActor }` per buffer is the 10.76.48
        // shape CLAUDE.md names: a flood of tiny main-actor submissions starves the
        // SwiftUI executor, and an open `.menu` Picker stops responding while it runs.
        // A progress bar cannot show more than 100 steps, so every submission past the
        // hundredth carried no information. Captured like `framesWritten` above — the
        // block runs on ONE serial queue, so this is not a race.
        var lastProgressPercent = -1

        await withCheckedContinuation { continuation in
            writerInput.requestMediaDataWhenReady(on: DispatchQueue(label: "com.echoelmusic.export")) {
                while writerInput.isReadyForMoreMediaData {
                    guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                        writerInput.markAsFinished()
                        writer.finishWriting { continuation.resume() }
                        return
                    }

                    let bufferFrames = CMSampleBufferGetNumSamples(sampleBuffer)
                    let bufferStartFrame = framesWritten

                    // Apply gain in-place on the PCM data
                    if let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
                        // Walk segments by offset — applying gain to totalLength/4 from
                        // a single pointer would be an out-of-bounds WRITE on a
                        // segmented block. Loops once for the usual single-segment buffer.
                        var offset = 0
                        var totalLength = 0
                        var segmentStartFloat = 0
                        repeat {
                            var lengthAtOffset = 0
                            var dataPointer: UnsafeMutablePointer<Int8>?
                            CMBlockBufferGetDataPointer(blockBuffer, atOffset: offset,
                                                        lengthAtOffsetOut: &lengthAtOffset,
                                                        totalLengthOut: &totalLength,
                                                        dataPointerOut: &dataPointer)
                            guard let ptr = dataPointer, lengthAtOffset >= 4 else { break }
                            let n = lengthAtOffset / 4
                            let floatPtr = UnsafeMutableRawPointer(ptr).bindMemory(to: Float.self, capacity: n)
                            SingleExport.applyGain(floatPtr, count: n, linearGain: linearGain)

                            // Edge fades — interleaved stereo: float i belongs to
                            // frame (bufferStartFrame + (segmentStartFloat + i) / 2).
                            if fadeFrames > 0 {
                                let segStartFrame = bufferStartFrame + segmentStartFloat / 2
                                let segEndFrame = bufferStartFrame + (segmentStartFloat + n) / 2
                                if segStartFrame < fadeFrames || segEndFrame > totalFrames - fadeFrames {
                                    for i in 0..<n {
                                        let frame = bufferStartFrame + (segmentStartFloat + i) / 2
                                        var g: Float = 1
                                        if frame < fadeFrames {
                                            g = Float(frame) / Float(fadeFrames)
                                        }
                                        let fromEnd = totalFrames - 1 - frame
                                        if fromEnd < fadeFrames {
                                            g = Swift.min(g, Float(Swift.max(fromEnd, 0)) / Float(fadeFrames))
                                        }
                                        if g < 1 { floatPtr[i] *= g }
                                    }
                                }
                            }
                            segmentStartFloat += n
                            offset += lengthAtOffset
                        } while offset < totalLength
                    }
                    framesWritten = bufferStartFrame + bufferFrames

                    // Update progress (relative to the trimmed window when set)
                    let pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                    let progress = durationSeconds > 0
                        ? Float((pts - windowStartSeconds) / durationSeconds) : 0
                    // `clamped(to:)` and NOT `min(max(…))`: an invalid PTS makes `progress`
                    // NaN, and `Swift.max(NaN, 0)` returns NaN (the argument-order law in
                    // CLAUDE.md). The old spelling let that NaN reach the progress bar —
                    // cosmetic there, but `Int(NaN * 100)` one line down is a TRAP that kills
                    // the test host without an assertion message (#1174). NaN maps to 0 here.
                    let shown = progress.clamped(to: 0...0.99)
                    let percent = Int(shown * 100)
                    if percent != lastProgressPercent {
                        lastProgressPercent = percent
                        Task { @MainActor [weak self] in
                            if case .exporting = self?.exportState {
                                self?.exportState = .exporting(progress: shown)
                            }
                        }
                    }

                    writerInput.append(sampleBuffer)
                }
            }
        }
    }

    // MARK: - Output settings

    private func makeOutputSettings() -> [String: Any] {
        switch outputFormat {
        case .wav:
            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVLinearPCMBitDepthKey: 24,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                // AVAssetWriterInput requires ALL four AVLinearPCM* keys when any is
                // present; omitting this throws NSInvalidArgumentException at init.
                AVLinearPCMIsNonInterleaved: false,
            ]
        case .aac:
            return [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 256_000,
                AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
            ]
        }
    }

    // MARK: - Output URL

    private func makeOutputURL(sourceURL: URL) throws -> URL {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ExportError.noDocumentsDirectory
        }
        let exports = docs.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)

        let basename = sourceURL.deletingPathExtension().lastPathComponent
        let filename = "\(basename)_master.\(outputFormat.fileExtension)"
        return exports.appendingPathComponent(filename)
    }

    // MARK: - Errors

    enum ExportError: LocalizedError {
        case noAudioTrack, cannotReadSource, emptyAudio, noDocumentsDirectory

        var errorDescription: String? {
            switch self {
            case .noAudioTrack:    return "No audio track found in recording"
            case .cannotReadSource: return "Cannot read source recording"
            case .emptyAudio:      return "Recording appears to be silent"
            case .noDocumentsDirectory: return "Cannot locate the documents directory"
            }
        }
    }
}
#endif

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

    /// Gain to apply so a take measured at `measuredDB` (integrated loudness, LUFS — see
    /// `ExportLoudnessMeasurement`) lands on `target` — or 0 dB when `target` is nil ("No
    /// target": deliver at the captured level). Clamped to ±12 dB so a mismeasured take
    /// can't be slammed.
    ///
    /// `measuredDB` nil (or non-finite) means the loudness is UNDEFINED — no 400 ms block
    /// cleared the BS.1770 gates: digital silence, material under −70 LUFS throughout, or a
    /// window shorter than one block. Then there is no measurement to normalise against, and
    /// the answer is 0 dB — never the +12 dB a floor value would ask for, which only lifts a
    /// noise floor (E2).
    ///
    /// Pure + static ON PURPOSE. Inline inside the `async` AVFoundation method this
    /// arithmetic was untestable, and it is the one line the "No target" fix actually
    /// changes in the audio path — so it was the half of that fix nothing asserted.
    /// A pure seam makes "nil ⇒ 0 dB" a test rather than a hope.
    nonisolated static func normalizeGainDB(target: Float?, measuredDB: Float?) -> Float {
        guard let target, target.isFinite else { return 0 }
        guard let measuredDB, measuredDB.isFinite else { return 0 }
        return Swift.min(Swift.max(target - measuredDB, -12), 12)
    }

    // MARK: - Post-normalisation peak safety (E1)
    //
    // ⛔ THE DEFECT THIS CLOSES. `normalizeGainDB` may ask for up to +12 dB, and the loudness
    // it steers by (an RMS until E2, gated integrated LUFS since) knows nothing about PEAKS. A sparse
    // take (a quiet body with one hot transient near full scale) measures quiet, gets the
    // full boost, and the transient lands up to ~12 dB over full scale. Nothing after the
    // `vDSP_vsmul` bounded it: the WAV branch then converts to 24-bit integer PCM (hard clip
    // at the converter), and the AAC branch hands the same over-range floats to the encoder.
    //
    // ⭐ THE REPAIR IS A GAIN BOUND, NOT A LIMITER. The export reads the whole window once at
    // the RENDER's settings (`exportSampleRate`) to take the SAMPLE PEAK — since E3 in the same
    // pass that measures loudness (see `ExportLoudnessMeasurement`) — and a positive gain
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

    /// The ONE rate the export decodes at — for the analysis pass (peak + loudness) and for
    /// the render — and encodes at. One constant on purpose: E1 bounds the gain by the peak
    /// of the samples the gain is applied to, which only holds while analysis and render
    /// decode alike (E3 folded the loudness pass into the analysis pass).
    nonisolated static let exportSampleRate = 44_100

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
            let levels = try await measureExportLevels(sourceURL: sourceURL, timeRange: timeRange)
            let requestedGain = Self.normalizeGainDB(target: targetLUFS, measuredDB: levels.integratedLUFS)
            let safeGain = Self.peakSafeGainDB(requestedDB: requestedGain, sourcePeak: levels.samplePeak)

            exportState = .exporting(progress: 0)
            let loudnessText = levels.integratedLUFS.map { String(format: "%.1f LUFS", $0) } ?? "undefined"
            let gainText = "gain \(String(format: "%.1f", safeGain))dB (requested \(String(format: "%.1f", requestedGain))dB)"
            log.log(.info, category: .audio, "SingleExport: integrated \(loudnessText), \(gainText) → \(outputFormat.label)")

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

    // MARK: - Export levels (E2 loudness · E1 peak)

    /// The two numbers the gain is decided from, both taken in ONE decode of EXACTLY the window
    /// that will be rendered (C6: normalising against audio outside the final cut would set the
    /// wrong gain for what actually ships in the file), at the render's own rate:
    /// · `integratedLUFS` — gated BS.1770 integrated loudness via `ExportLoudnessMeasurement`;
    ///   nil when undefined (see `normalizeGainDB`).
    /// · `samplePeak` — of the very samples the gain is later applied to (E1).
    /// ⛔ Until E3 this was two decodes: loudness had to be decoded at 48 kHz, because the
    /// meter's K-weighting was the 48 kHz table at every rate. The meter now derives its
    /// coefficients per rate, so the loudness pass rides along with the peak pass.
    private func measureExportLevels(sourceURL: URL,
                                     timeRange: CMTimeRange?) async throws -> (integratedLUFS: Float?, samplePeak: Float) {
        // `isNaN ||` keeps a NaN once seen: `Swift.max(x, NaN)` would silently drop it, and a
        // dropped NaN reads as a clean measurement that can vouch for a boost.
        var peak: Float = 0
        let loudness = ExportLoudnessMeasurement(sampleRate: Self.exportSampleRate)
        try await forEachDecodedSegment(sourceURL: sourceURL, timeRange: timeRange,
                                        sampleRate: Self.exportSampleRate) { floatPtr, count in
            let segmentPeak = Self.samplePeak(floatPtr, count: count)
            if segmentPeak.isNaN || segmentPeak > peak { peak = segmentPeak }
            loudness.append(interleaved: floatPtr, sampleCount: count)
        }
        return (loudness.integratedLUFS(), peak)
    }

    /// Decode `timeRange` of `sourceURL` to interleaved stereo Float32 at `sampleRate` and
    /// hand every contiguous segment to `body` as (pointer, float count). Throws when the
    /// source has no audio, yields nothing, or the reader fails part-way — a measurement over
    /// a truncated read is not a measurement of the window.
    private func forEachDecodedSegment(sourceURL: URL, timeRange: CMTimeRange?, sampleRate: Int,
                                       _ body: (UnsafePointer<Float>, Int) -> Void) async throws {
        let asset = AVAsset(url: sourceURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw ExportError.noAudioTrack
        }

        let reader = try AVAssetReader(asset: asset)
        if let timeRange { reader.timeRange = timeRange }
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
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

        var sampleCount = 0
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
                body(floatPtr, count)
                sampleCount += count
                offset += lengthAtOffset
            } while offset < totalLength
        }

        if reader.status == .failed { throw ExportError.cannotReadSource }
        guard sampleCount > 0 else { throw ExportError.emptyAudio }
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
            AVSampleRateKey: Self.exportSampleRate,
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
        // Micro edge fades (loop seam safety): frame counts at the LPCM reader rate
        // (`exportSampleRate`), applied over interleaved stereo. Only the first/last
        // buffers ever intersect the fade zones, so the per-sample loop is cheap.
        let readerRate = Double(Self.exportSampleRate)
        let totalFrames = Int(durationSeconds * readerRate)
        let fadeFrames = edgeFadeSeconds > 0 ? Int(edgeFadeSeconds * readerRate) : 0
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
                AVSampleRateKey: Self.exportSampleRate,
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
                AVSampleRateKey: Self.exportSampleRate,
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

// MARK: - Export loudness (E2, rate-folded in E3)
//
// ⛔ THE DEFECT E2 CLOSED. The export normalised by a function named `measureLUFS` that was
// not LUFS: mean-square → RMS → dBFS − 0.1, with no K-weighting and no gating. The Master
// panel meanwhile shows real BS.1770 loudness from `EchoelLoudnessMeter` — so the number the
// user reads and the number the export steered by were two different truths.
//
// ⭐ ONE METER. This type feeds the SAME `EchoelLoudnessMeter` the Master readout uses — no
// second loudness algorithm exists. It only adapts the export's interleaved stream to it and
// owns the one decision the live meter does not have to make:
// · THE BLOCK GRID: the meter records at most ONE 400 ms gating block per call, taken at the
//   end of the call. Fed exactly one 100 ms hop (`EchoelLoudnessMeter.gatingHopFrames`) per
//   call, every block lands on the BS.1770 grid (400 ms blocks, 75 % overlap); fed a reader's
//   arbitrary segment sizes it would skip and misplace blocks.
// ⛔ E2 ALSO OWNED THE RATE: it decoded a separate 48 kHz pass, because the meter used the
// 48 kHz K-weighting table at every rate (up to +1.1 dB wrong at 44.1 kHz). Since E3 the meter
// derives its coefficients per rate, so the measurement runs at the export's own rate inside
// the one analysis decode. A rate outside `EchoelLoudnessMeter.supportedSampleRates` yields no
// reading (nil), never a wrong one.
//
// ⚠️ WHAT THIS IS, NAMED HONESTLY: gated integrated loudness per ITU-R BS.1770-4 for a stereo
// programme (K-weighting per rate, L/R weight 1.0, absolute gate −70 LUFS, relative gate
// −10 LU), for the rates the meter supports. The meter keeps block loudness in 0.1 LU
// histogram bins (libebur128 technique), so the result is quantised: a steady tone reads up to
// +0.05 LU off. It is NOT a claim of full EBU R128 conformance — no true-peak and no LRA enter
// the export decision, and nothing here was run against the full EBU test-vector set.
// Guards: `TheExportNormalisesByIntegratedLoudnessTests`, `TheLoudnessMeterIsSampleRateCorrectTests`.

/// Integrated programme loudness (LUFS) of an interleaved-stereo stream, measured by the app's
/// one BS.1770 meter at `sampleRate`. Offline, owned by a single measurement pass; not for a
/// render thread (it is fed from a decode loop, and the meter itself is audio-thread safe).
final class ExportLoudnessMeasurement {

    let sampleRate: Int
    /// One 100 ms gating hop — the METER's own hop, asked rather than restated (#416).
    let hopFrames: Int

    private let meter: EchoelLoudnessMeter
    private var left: [Float]
    private var right: [Float]
    private var filled = 0
    /// Channel parity carried ACROSS calls: a segment boundary may split a frame, and a
    /// per-call pairing would then swap L and R for the rest of the take.
    private var expectingLeft = true

    init(sampleRate: Int) {
        self.sampleRate = sampleRate
        let meter = EchoelLoudnessMeter(sampleRate: Float(sampleRate))
        self.meter = meter
        self.hopFrames = meter.gatingHopFrames
        left = [Float](repeating: 0, count: meter.gatingHopFrames)
        right = [Float](repeating: 0, count: meter.gatingHopFrames)
    }

    /// Append `sampleCount` interleaved floats (L R L R …).
    func append(interleaved samples: UnsafePointer<Float>, sampleCount: Int) {
        guard sampleCount > 0 else { return }
        for i in 0..<sampleCount {
            if expectingLeft {
                left[filled] = samples[i]
                expectingLeft = false
                continue
            }
            right[filled] = samples[i]
            expectingLeft = true
            filled += 1
            if filled == hopFrames {
                meter.processStereo(left: left, right: right, frameCount: filled)
                filled = 0
            }
        }
    }

    /// Gated integrated loudness in LUFS, or nil when BS.1770 leaves it undefined — no 400 ms
    /// block above the −70 LUFS absolute gate (silence, near-silence, or less than one block) —
    /// or when the meter does not support this rate. A trailing partial hop is not fed: it
    /// cannot complete a block, so it could not change the result.
    func integratedLUFS() -> Float? {
        let value = meter.integratedLUFS
        guard value.isFinite, value > EchoelLoudnessMeter.floorLUFS else { return nil }
        return value
    }
}
#endif

import AVFoundation
import EchoelCore
import EchoelDSP
import EchoelEngine
import Foundation

/// An export brought to a loudness (CUT, 2026-11-01): the rendered mix read back from its file as
/// often as the search needs (`LoudnessNormalizer`), then written once through the gain and, where
/// needed, the limiter. At Off the mix is copied as it is. Off the main thread, like every export;
/// what it reports, the status line says.
enum MixLoudness {
    /// What an export measured: the file as written, and — when a target changed the mix — what the
    /// mix measured before, the gain, and how far the limiter brought the loudest peak down.
    struct Report: Equatable, Sendable {
        /// The file as written, LUFS; `LoudnessMeter.silent` for silence.
        let integrated: Double
        /// The file as written, dBTP; `LoudnessMeter.silent` for silence.
        let truePeak: Double
        /// What the export was brought to; `.off` for the mix as it plays.
        let loudness: ExportLoudness
        /// The mix before; nil at Off.
        let before: LoudnessNormalizer.Measurement?
        /// The gain applied, dB; 0 at Off.
        let gain: Double
        /// How far the limiter brought the loudest peak down, dB; 0 where it did not work.
        let limited: Double

        /// The mix as it plays, measured as it was written.
        init(_ measured: LoudnessNormalizer.Measurement) {
            integrated = measured.integrated
            truePeak = measured.truePeak
            loudness = .off
            before = nil
            gain = 0
            limited = 0
        }

        init(after: LoudnessNormalizer.Measurement, loudness: ExportLoudness, before: LoudnessNormalizer.Measurement,
             settings: LoudnessNormalizer.Settings) {
            integrated = after.integrated
            truePeak = after.truePeak
            self.loudness = loudness
            self.before = before
            gain = settings.gain
            // The gain alone moves the peak by itself; whatever is missing from the peak the limiter took.
            let taken = before.truePeak + settings.gain - after.truePeak
            limited = settings.limiterCeiling != nil && taken.isFinite ? Swift.max(0, taken) : 0
        }

        /// The file is on its target — always at Off. A mix whose peaks held it down is not, and
        /// the status line says so.
        var reachedTarget: Bool { loudness.isReached(by: integrated) }
    }

    struct UnreadableMix: Error {}

    /// Frames read per block.
    static let blockFrames: AVAudioFrameCount = 32_768

    /// Every block of `first ..< last` frames of `file`, in order; a file of one channel gives the
    /// same samples as both sides.
    static func forEachBlock(of file: AVAudioFile, from first: AVAudioFramePosition, to last: AVAudioFramePosition,
                             _ body: LoudnessNormalizer.Block) throws {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: blockFrames) else {
            throw UnreadableMix()
        }
        file.framePosition = first
        var position = first
        while position < last {
            let want = AVAudioFrameCount(Swift.min(Int64(buffer.frameCapacity), last - position))
            try file.read(into: buffer, frameCount: want)
            let count = Int(buffer.frameLength)
            guard count > 0, let channels = buffer.floatChannelData else { break }
            let left = channels[0]
            let right = buffer.format.channelCount > 1 ? channels[1] : channels[0]
            try body(left, right, count)
            position += AVAudioFramePosition(count)
        }
    }

    /// `first ..< last` of `file`, which measured `measured`, into `writer`: copied as it is at Off,
    /// otherwise brought to the target under the true-peak ceiling. The writer is left open.
    static func write(_ file: AVAudioFile, from first: AVAudioFramePosition, to last: AVAudioFramePosition,
                      measured: LoudnessNormalizer.Measurement, loudness: ExportLoudness,
                      into writer: WAVWriter) throws -> Report {
        guard let target = loudness.target else {
            try forEachBlock(of: file, from: first, to: last) { left, right, count in
                try writer.append(left: left, right: right, count: count)
            }
            return Report(measured)
        }
        let rate = file.processingFormat.sampleRate
        let replay: LoudnessNormalizer.Replay = { block in
            try forEachBlock(of: file, from: first, to: last, block)
        }
        let settings = try LoudnessNormalizer.settings(target: target, ceiling: ExportLoudness.truePeakCeiling,
                                                       measured: measured, sampleRate: rate, replay: replay)
        let after = try LoudnessNormalizer.apply(settings, sampleRate: rate, replay: replay) { left, right, count in
            try writer.append(left: left, right: right, count: count)
        }
        return Report(after: after, loudness: loudness, before: measured, settings: settings)
    }

    /// The whole mix at `source`, which measured `measured`, brought to `loudness` as a 24-bit WAV at
    /// `url`. A file left half-written is removed.
    static func write(_ source: URL, measured: LoudnessNormalizer.Measurement, loudness: ExportLoudness,
                      to url: URL) throws -> Report {
        let file = try AVAudioFile(forReading: source)
        let writer = try WAVWriter(url: url, sampleRate: file.processingFormat.sampleRate)
        do {
            let report = try write(file, from: 0, to: file.length, measured: measured, loudness: loudness, into: writer)
            try writer.finish()
            return report
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }
}

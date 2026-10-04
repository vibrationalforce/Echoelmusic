#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Spatial S-A3c-1 (ADR-008 §4–§5, accepted 2026-10-04): the writer that drains stem rings to disk.
/// One `StemCaptureRing` per stem fills on the audio thread; this type empties them on ONE
/// non-audio thread and writes one mono PCM file per stem — 24-bit integer, the take's rate.
///
/// THE RULES (each one a decision, not a default):
/// · **Same zero point.** Every ring must start at the same engine sample time; the writer refuses
///   a set that does not (`mismatchedStart`). A stem never starts "a bit later".
/// · **Same length.** `finish(endSampleTime:)` cuts every stem at the same end. A stem whose ring
///   holds less is filled with silence up to the end and the fill is COUNTED (`paddedFrames`); a
///   stem whose ring holds more is cut there, never longer than the master.
/// · **Nothing lost silently.** Frames the producer overwrote before the writer reached them come
///   out as zeros in place (the ring's rule) and are summed in `silencedFrames`. Gaps and refused
///   jumps are copied from the ring. The exporter aborts a take with `discontinuities > 0` and
///   reports `silencedFrames` as "at most" (ADR-008: interruptions break loudly).
///
/// ⚠️ THREADING: not thread-safe and never on the audio thread — file I/O lives here precisely so
/// it never lives in a render block (the RetroCapture rule since #1413). Call `drainAvailable()`
/// and `finish(endSampleTime:)` from ONE serial context. Call `finish` only after every producer
/// is quiescent (`StemTapPoint.releaseRetiredIfQuiescent()` true, `hasRetiredTarget` false);
/// a block written after `finish` stays in its ring and never reaches the file.
///
/// ⚠️ LEVEL: the files carry the stem exactly as captured. The stems of generated voices are
/// PRE-FADER (K2) — mixer level and mute are applied by the exporter, not here.
///
/// Built: yes. Wired: NO — no capture session constructs a writer yet (S-A3c-2). Device: no.
final class StemFileWriter {

    struct Stem {
        let name: String
        let ring: StemCaptureRing
        let url: URL
    }

    /// What one stem lost, filled or refused. Non-zero `discontinuities` = abort the take.
    struct StemReport: Equatable {
        let name: String
        let framesWritten: Int64
        let silencedFrames: Int64
        let paddedFrames: Int64
        let gapFrames: Int64
        let discontinuities: Int64
    }

    enum WriterError: Error, Equatable {
        case noStems
        case mismatchedStart
        case formatUnavailable
        case bufferUnavailable
        case endBeforeStart
        case alreadyFinished
    }

    /// The bit depth every stem file is written with (ADR-008 §4: PCM 24 bit).
    static let fileBitDepth = 24

    /// The engine sample time every stem starts at.
    let startSampleTime: Int64

    private let stems: [Stem]
    private var files: [AVAudioFile]
    private let buffer: AVAudioPCMBuffer
    private let chunkFrames: Int
    private var written: [Int64]
    private var silenced: [Int64]
    private var finished = false

    init(stems: [Stem], sampleRate: Double, chunkFrames: Int = 4_096) throws {
        guard let first = stems.first else { throw WriterError.noStems }
        let start = first.ring.readSampleTime
        guard stems.allSatisfy({ $0.ring.readSampleTime == start }) else { throw WriterError.mismatchedStart }
        guard sampleRate.isFinite, sampleRate > 0,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                                         channels: 1, interleaved: false) else {
            throw WriterError.formatUnavailable
        }
        let frames = max(chunkFrames, 1)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else {
            throw WriterError.bufferUnavailable
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: StemFileWriter.fileBitDepth,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        self.files = try stems.map {
            try AVAudioFile(forWriting: $0.url, settings: settings,
                            commonFormat: .pcmFormatFloat32, interleaved: false)
        }
        self.startSampleTime = start
        self.stems = stems
        self.buffer = buffer
        self.chunkFrames = frames
        self.written = Array(repeating: 0, count: stems.count)
        self.silenced = Array(repeating: 0, count: stems.count)
    }

    /// Writes everything the producers have published so far. Returns the frames written.
    @discardableResult
    func drainAvailable() throws -> Int64 {
        guard !finished else { throw WriterError.alreadyFinished }
        return try drain(until: nil)
    }

    /// Writes every stem up to `endSampleTime` (exclusive), fills a short stem with silence up to
    /// it, and closes the files. Every stem file is then exactly `endSampleTime - startSampleTime`
    /// frames long.
    func finish(endSampleTime: Int64) throws -> [StemReport] {
        guard !finished else { throw WriterError.alreadyFinished }
        guard endSampleTime >= startSampleTime else { throw WriterError.endBeforeStart }
        try drain(until: endSampleTime)
        guard let channel = buffer.floatChannelData?[0] else { throw WriterError.bufferUnavailable }
        let length = endSampleTime - startSampleTime
        var padded = Array(repeating: Int64(0), count: stems.count)
        for index in stems.indices {
            var missing = length - written[index]
            padded[index] = max(0, missing)
            while missing > 0 {
                let count = Int(min(Int64(chunkFrames), missing))
                channel.update(repeating: 0, count: count)
                buffer.frameLength = AVAudioFrameCount(count)
                try files[index].write(from: buffer)
                written[index] += Int64(count)
                missing -= Int64(count)
            }
        }
        finished = true
        files = []                       // releasing the files finalizes their headers
        return stems.indices.map { index in
            StemReport(name: stems[index].name,
                       framesWritten: written[index],
                       silencedFrames: silenced[index],
                       paddedFrames: padded[index],
                       gapFrames: stems[index].ring.gapFrames,
                       discontinuities: stems[index].ring.discontinuities)
        }
    }

    @discardableResult
    private func drain(until end: Int64?) throws -> Int64 {
        guard let channel = buffer.floatChannelData?[0] else { throw WriterError.bufferUnavailable }
        var total: Int64 = 0
        for index in stems.indices {
            let ring = stems[index].ring
            while true {
                var maxFrames = chunkFrames
                if let end {
                    let remaining = end - ring.readSampleTime
                    guard remaining > 0 else { break }
                    maxFrames = Int(min(Int64(chunkFrames), remaining))
                }
                let read = ring.read(into: channel, maxFrames: maxFrames)
                guard read.frames > 0 else { break }
                buffer.frameLength = AVAudioFrameCount(read.frames)
                try files[index].write(from: buffer)
                written[index] += Int64(read.frames)
                silenced[index] += Int64(read.silencedFrames)
                total += Int64(read.frames)
            }
        }
        return total
    }
}
#endif

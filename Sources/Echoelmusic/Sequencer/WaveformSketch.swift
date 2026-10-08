// WaveformSketch.swift
// Echoelmusic — Sequencer (audio editor W1, founder 2026-10-08: "Die klassische DAW Audio
// Editing View fehlt mir noch.")
//
// WHY THIS EXISTS. An audio part on the Arrange canvas was a plain tinted bar: nothing said
// where the hits are, where the file goes quiet, or which part of the file a trimmed part
// plays. Every DAW draws the audio inside the part, and the editing slices after this one
// (gain, trim, fades) need it to be seen. This file is the data half: ONE overview per media
// file, read off the main actor, and a pure window that cuts the part's own stretch of it into
// display columns. `Studio/AudioPartWaveform` draws it.
//
// ⭐ THE REDUCTION RULE IS `WaveformReducer`'s, NOT A NEW ONE (#416). The overview folds the
// channels with `WaveformReducer.foldStereo` (the louder sample wins, so a hard-panned hit
// stays visible), buckets them with `reduce` (min · max · RMS per bucket — the extremes
// survive, never raw PCM), and a display column joins its buckets with `downsample` (min of
// mins, max of maxes, RMS of RMS). That pure core was parked test-only since #132 Slice 5;
// this is its consumer.
//
// ⭐ THE WINDOW IS THE PLAYER'S, NOT A LOOKALIKE (#416). The canvas hands in the part's media
// position and length from `AudioRegionPlayback.filePositionSeconds` and the region's
// `StretchPlan` rate — the two calls `AudioLanePlayer.start` makes — so the picture is the
// stretch of the file the part sounds. A column before the file's start or past its end is
// silent (a part longer than its file plays silence there, and draws a flat line).
//
// ⚠️ NEVER ON THE AUDIO THREAD, NEVER ON THE MAIN ACTOR. `overview(ofRef:)` opens and reads a
// whole file. It is a plain `enum` with no global actor, spelled `nonisolated` anyway so the
// fact survives a future default isolation, and both its callers (the canvas leaf, and since
// W9 the part bar's Normalize) run it inside `Task.detached`; the canvas forwards cancellation. It checks `Task.isCancelled` per chunk: a part scrolled
// away stops reading within one chunk.
//
// ⚠️ IT ASKS THE PLAYER'S RESOLVER (#1439). The file is found by `MediaLibrary.resolveRef` —
// the function the app's injected `resolveURL:` closure calls for `AudioLanePlayer` — so a
// part draws a waveform exactly when its file resolves for playback. It is called directly,
// off the main actor, because the player's own wrapper is main-actor state.
//
// ⭐ W9 — NORMALIZE READS THE SAME BUCKETS. `peak` finds the part's loudest sample through
// `overlap`, the one rule `window` draws by, so the level Normalize sets answers the wave the
// person sees. Its caller is the part bar, and it reads the file the same way: detached, once.
//
// ⚠️ BOUNDED. At most `maxBuckets` buckets per file (~100 per second for files up to a few
// minutes, coarser for longer ones), at most `maxColumns` per draw, and a file that would need
// more than `maxFramesPerBucket` frames per bucket is refused rather than half-read.

import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

enum WaveformSketch {

    /// One file's waveform at overview resolution: `buckets` in file order, each covering
    /// `secondsPerBucket` of the file (the last may cover less).
    struct Overview: Equatable, Sendable {
        let buckets: [WaveformBucket]
        let secondsPerBucket: Double
    }

    /// The overview's target resolution for files short enough to have it.
    static let bucketsPerSecond: Double = 100
    /// The most buckets one overview holds — a longer file gets coarser buckets, never more.
    static let maxBuckets = 16_384
    /// Past this many frames per bucket a file is refused (≈ 100 hours at 48 kHz).
    static let maxFramesPerBucket = 1 << 20
    /// Frames read per chunk, rounded down to whole buckets so buckets never straddle a chunk.
    static let chunkFrames = 65_536
    /// The most display columns one part draws, at any zoom.
    static let maxColumns = 1_024
    /// Points per display column — one column per two points reads as a continuous wave.
    static let pointsPerColumn: Double = 2

    /// A column with nothing in it: before the file's start, past its end, or unreadable.
    static let silent = WaveformBucket(min: 0, max: 0, rms: 0)

    /// Frames per overview bucket for a file of `totalFrames` at `sampleRate`: the coarser of
    /// `bucketsPerSecond` and the `maxBuckets` cap. 0 = refuse (no frames, a degenerate rate,
    /// or a file so long a bucket would pass `maxFramesPerBucket`).
    nonisolated static func framesPerBucket(totalFrames: Int64, sampleRate: Double) -> Int {
        guard totalFrames > 0, sampleRate.isFinite, sampleRate > 0 else { return 0 }
        let byRate = (sampleRate / bucketsPerSecond).rounded(.up)
        let byCap = (Double(totalFrames) / Double(maxBuckets)).rounded(.up)
        let frames = Swift.max(1, byRate, byCap)
        guard frames <= Double(maxFramesPerBucket) else { return 0 }
        return Int(frames)
    }

    /// How many columns a part `widthPoints` wide draws: one per `pointsPerColumn`, at least
    /// one, at most `maxColumns`. A degenerate width draws none.
    nonisolated static func columns(forWidthPoints widthPoints: Double) -> Int {
        guard widthPoints.isFinite, widthPoints > 0 else { return 0 }
        return Int((widthPoints / pointsPerColumn).rounded(.up)
            .clamped(to: 1...Double(maxColumns)))
    }

    /// The part's stretch of the file — `lengthSeconds` from `fromSeconds` — as `columns`
    /// display columns, each the `WaveformReducer.downsample` join of the buckets it overlaps
    /// (a column narrower than a bucket takes the bucket it falls in). Amplitudes are scaled by
    /// the part's own `gain` and clamped to ±1 for drawing; a non-finite value draws as
    /// silence. Degenerate input — no buckets, a non-finite or non-positive length, no
    /// columns — draws nothing.
    nonisolated static func window(_ overview: Overview, fromSeconds: Double, lengthSeconds: Double,
                                   columns: Int, gain: Float) -> [WaveformBucket] {
        let count = overview.buckets.count
        let perBucket = overview.secondsPerBucket
        guard count > 0, columns > 0, perBucket.isFinite, perBucket > 0,
              fromSeconds.isFinite, lengthSeconds.isFinite, lengthSeconds > 0 else { return [] }
        let total = Swift.min(columns, maxColumns)
        let level = gain.isFinite ? Swift.max(0, gain) : 1
        let step = lengthSeconds / Double(total)
        var out: [WaveformBucket] = []
        out.reserveCapacity(total)
        for column in 0..<total {
            let start = (fromSeconds + Double(column) * step) / perBucket
            let end = (fromSeconds + Double(column + 1) * step) / perBucket
            // Wholly before the file's start or past its end: silence, never a borrowed bucket.
            guard let span = overlap(start: start, end: end, count: count),
                  let joined = WaveformReducer.downsample(Array(overview.buckets[span]),
                                                          factor: span.count).first else {
                out.append(silent); continue
            }
            out.append(drawable(joined, level: level))
        }
        return out
    }

    /// The buckets a stretch from `start` to `end` (in BUCKET units) overlaps — nil when it lies
    /// wholly before the file's start or past its end. A stretch narrower than a bucket takes
    /// the bucket it falls in. The ONE overlap rule of `window` and `peak` (#416): the level
    /// Normalize sets is read off exactly the buckets the canvas draws.
    nonisolated static func overlap(start: Double, end: Double, count: Int) -> Range<Int>? {
        let limit = Double(count)
        guard count > 0, start.isFinite, end.isFinite, end > 0, start < limit else { return nil }
        let first = Int(start.clamped(to: 0...limit).rounded(.down))
        let last = Swift.min(count, Swift.max(first + 1, Int(end.clamped(to: 0...limit).rounded(.up))))
        return first < last ? first..<last : nil
    }

    /// The loudest sample magnitude in the part's stretch of the file — `lengthSeconds` from
    /// `fromSeconds` — with the part's own level NOT applied: Normalize asks what the FILE does
    /// there. A bucket's extremes are exact sample extremes (`WaveformReducer.reduce` keeps the
    /// min and the max, and `foldStereo` the louder channel), so the only error is the two edge
    /// buckets reaching a few milliseconds past the part: the peak can read high, never low, and
    /// a level set from it errs quieter, never into a clip. nil for a stretch outside the file,
    /// degenerate input, or a non-finite bucket.
    nonisolated static func peak(_ overview: Overview, fromSeconds: Double, lengthSeconds: Double) -> Float? {
        let perBucket = overview.secondsPerBucket
        guard perBucket.isFinite, perBucket > 0, fromSeconds.isFinite, lengthSeconds.isFinite,
              lengthSeconds > 0,
              let span = overlap(start: fromSeconds / perBucket,
                                 end: (fromSeconds + lengthSeconds) / perBucket,
                                 count: overview.buckets.count) else { return nil }
        var loudest: Float = 0
        for bucket in overview.buckets[span] {
            // Each extreme is checked BEFORE the max: `Swift.max(0, NaN)` is 0, so a NaN in the
            // second argument would read as silence and pass a check on the result.
            guard bucket.min.isFinite, bucket.max.isFinite else { return nil }
            loudest = Swift.max(loudest, Swift.max(abs(bucket.min), abs(bucket.max)))
        }
        return loudest
    }

    /// One column made safe to draw: scaled by the part's level, clamped to ±1 (RMS to 0…1),
    /// every non-finite value replaced by silence.
    nonisolated static func drawable(_ bucket: WaveformBucket, level: Float) -> WaveformBucket {
        func safe(_ value: Float, _ range: ClosedRange<Float>) -> Float {
            let scaled = value * level
            return scaled.isFinite ? scaled.clamped(to: range) : 0
        }
        return WaveformBucket(min: safe(bucket.min, -1...1), max: safe(bucket.max, -1...1),
                              rms: safe(bucket.rms, 0...1))
    }

    // MARK: - The one impure step

    #if canImport(AVFoundation)

    /// The overview of the file `ref` names, or nil when it does not resolve, cannot be opened,
    /// is empty or too long (`framesPerBucket` refuses it), or the read was cancelled. Reads
    /// the whole file once, in `chunkFrames` chunks, on whatever executor calls it — which must
    /// never be the main actor or an audio thread (see the file header).
    nonisolated static func overview(ofRef ref: String) -> Overview? {
        guard let url = MediaLibrary.resolveRef(ref),
              let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let channels = Int(format.channelCount)
        let perBucket = framesPerBucket(totalFrames: file.length, sampleRate: format.sampleRate)
        guard channels > 0, perBucket > 0 else { return nil }
        let chunk = perBucket * Swift.max(1, chunkFrames / perBucket)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(chunk)) else { return nil }
        var buckets: [WaveformBucket] = []
        buckets.reserveCapacity(Swift.min(maxBuckets, Int(file.length / Int64(perBucket)) + 1))
        while file.framePosition < file.length {
            if Task.isCancelled { return nil }
            do {
                try file.read(into: buffer, frameCount: AVAudioFrameCount(chunk))
            } catch {
                break
            }
            let frames = Int(buffer.frameLength)
            guard frames > 0, let data = buffer.floatChannelData else { break }
            var folded = Array(UnsafeBufferPointer(start: data[0], count: frames))
            for channel in 1..<channels {
                folded = WaveformReducer.foldStereo(
                    left: folded, right: Array(UnsafeBufferPointer(start: data[channel], count: frames)))
            }
            buckets += WaveformReducer.reduce(folded, bucketSize: perBucket)
        }
        guard !buckets.isEmpty else { return nil }
        return Overview(buckets: buckets, secondsPerBucket: Double(perBucket) / format.sampleRate)
    }

    #endif
}

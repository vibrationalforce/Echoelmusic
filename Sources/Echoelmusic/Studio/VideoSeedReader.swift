// VideoSeedReader.swift
// Echoel — MV2 (founder order 2026-09-27): the ONE impure step between a picked video file and its
// `VideoSeed`. AVFoundation reads the duration, the frame rate and a bounded number of frames; each
// frame is reduced at once to the small summary the pure core wants (`Core/VideoSeed.swift`).
//
// ⭐ THE FILE IS NEVER LOADED WHOLE. `AVURLAsset` reads from disk on demand; `AVAssetImageGenerator`
// decodes one frame per requested time, at most `maxFrameSide` pixels on a side, and each frame is
// reduced to a 16 × 16 luma grid and a mean colour before the next is asked for. At most
// `sampleCount` frames are read, however long the clip is, and a clip longer than
// `VideoSeedAnalysis.maxDurationSeconds` is refused before any frame is decoded.
//
// ⭐ CLOSE PAIRS ON A LONG CLIP (GMMW VV-1b). The core measures motion only between frames at most
// `VideoSeedAnalysis.motionPairMaxSeconds` apart (VV-1a): change between frames seconds apart
// saturates, and read evenly a 600 s clip read 0.24 for footage a 6 s clip of it read at 0.39. A
// clip short enough to be read evenly that close still is; a longer one is read as half as many
// PAIRS, `pairGapSeconds` (at least one frame) apart, spread over the clip — the same 48 frames.
// Cuts are still found between pairs; inside moving footage a cut between two pairs can hide in
// the pairs' own change, which an even reading of a long clip could not tell apart either.
//
// ⭐ CANCELLABLE. `read(url:)` is async and checks `Task.isCancelled` before every frame; a newer
// pick cancels an older read, which then returns nil and decodes nothing more.
//
// ⭐ OFF THE MAIN ACTOR, NEVER ON THE AUDIO THREAD. Nothing here touches the engine, the bus or the
// transport. The frame reduction is plain arithmetic on a 16 × 16 buffer.
//
// ⚠️ WHAT IT DOES NOT DO. It does not play the video, render its frames into the visual, or read
// its sound. `hasAudioTrack` only says whether the file carries sound.

#if canImport(AVFoundation) && canImport(CoreGraphics)
import Foundation
import AVFoundation
import CoreGraphics

enum VideoSeedReader {

    /// Frames read per clip — the bound on the work (≤ `VideoSeedAnalysis.maxSamples`).
    static let sampleCount = 48
    /// Frames read per second of a SHORT clip, so a 3 s clip is not read 48 times.
    static let samplesPerSecond = 4.0
    /// The longest side a frame is decoded at.
    static let maxFrameSide = 512
    /// The two frames of a pair on a long clip are this far apart — or one frame, when that is
    /// longer — inside `VideoSeedAnalysis.motionPairMaxSeconds`, so their change measures motion.
    static let pairGapSeconds = 0.1

    /// When to read frames: ascending, inside the clip, at most `sampleCount`. Even at
    /// `samplesPerSecond` while that spacing is close; past it, `count / 2` pairs (header). A clip
    /// whose frames are farther apart than close (under about 3.3 fps) is read evenly as before:
    /// its pairs could not be close, and mixed with the far gaps between them every pair would
    /// read as a cut. Its motion takes the length-dependent fallback (VV-1a) — said, not hidden.
    static func sampleTimes(seconds: Double, frameRate: Double) -> [Double] {
        guard seconds.isFinite, seconds > 0 else { return [] }
        let count = Swift.min(sampleCount, Swift.max(2, Int((seconds * samplesPerSecond).rounded())))
        let frame = frameRate.isFinite && frameRate > 0 ? 1 / frameRate : pairGapSeconds
        guard seconds / Double(count) > VideoSeedAnalysis.motionPairMaxSeconds,
              frame <= VideoSeedAnalysis.motionPairMaxSeconds else {
            // The middle of each of `count` equal slices: strictly increasing, inside the clip.
            return (0..<count).map { seconds * (Double($0) + 0.5) / Double(count) }
        }
        let pairs = Swift.max(1, count / 2)
        let slice = seconds / Double(pairs)
        // At least one frame apart (0.1 s at 5 fps would read one frame twice), at most half a
        // slice, so a pair never reaches the next one.
        let gap = Swift.min(Swift.max(pairGapSeconds, frame), slice / 2)
        var times: [Double] = []
        times.reserveCapacity(pairs * 2)
        for i in 0..<pairs {
            let first = seconds * (Double(i) + 0.5) / Double(pairs)
            times.append(first)
            times.append(Swift.min(first + gap, seconds))
        }
        return times
    }

    /// A read video: its seed, one representative frame, and whether it carries sound.
    /// `CGImage` is immutable once made, so handing it to the main actor shares nothing mutable.
    struct Read: @unchecked Sendable {
        let seed: VideoSeed
        let proxy: CGImage
        let hasAudioTrack: Bool
    }

    /// Reads a video file. nil when it has no readable video track, is longer than the limit, was
    /// cancelled, or its frames cannot be read.
    static func read(url: URL) async -> Read? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        let seconds = duration.seconds
        guard seconds.isFinite, seconds > 0, seconds <= VideoSeedAnalysis.maxDurationSeconds,
              let track = try? await asset.loadTracks(withMediaType: .video).first else { return nil }
        // The nominal rate, or — for a variable-rate file that reports none — the fastest frame's.
        // A file that gives neither is refused, never given an invented rate.
        let nominal = (try? await track.load(.nominalFrameRate)).map(Double.init) ?? 0
        let fastest = (try? await track.load(.minFrameDuration))?.seconds ?? 0
        let frameRate = VideoSeedAnalysis.frameRateRange.contains(nominal)
            ? nominal : (fastest > 0 && fastest.isFinite ? 1 / fastest : 0)
        guard VideoSeedAnalysis.frameRateRange.contains(frameRate) else { return nil }
        let audioTracks = (try? await asset.loadTracks(withMediaType: .audio)) ?? []

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxFrameSide, height: maxFrameSide)
        // The default tolerance is unbounded, and then the generator hands back the nearest KEYFRAME:
        // every sample of a long-GOP clip would be the same picture, and a cut would land seconds
        // from where it is. Zero tolerance decodes the frame actually asked for.
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        let times = sampleTimes(seconds: seconds, frameRate: frameRate)
        var samples: [VideoFrameSample] = []
        samples.reserveCapacity(times.count)
        var proxy: CGImage?
        for (i, time) in times.enumerated() {
            if Task.isCancelled { return nil }
            guard let frame = try? await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image,
                  let summary = summarize(frame, at: time) else { continue }
            if proxy == nil || i == times.count / 2 { proxy = frame }
            samples.append(summary)
        }
        guard let proxy,
              let seed = VideoSeedAnalysis.analyze(samples: samples, durationSeconds: seconds,
                                                   frameRate: frameRate) else { return nil }
        return Read(seed: seed, proxy: proxy, hasAudioTrack: !audioTracks.isEmpty)
    }

    /// One frame reduced to the core's summary: drawn into a `gridSide × gridSide` sRGB buffer,
    /// Rec. 709 luma per cell, mean colour over the cells.
    static func summarize(_ image: CGImage, at time: Double) -> VideoFrameSample? {
        let side = VideoSeedAnalysis.gridSide
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side,
                                          bitsPerComponent: 8, bytesPerRow: side * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                return false
            }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        var luma = [UInt8](repeating: 0, count: side * side)
        var red = 0.0, green = 0.0, blue = 0.0
        for cell in 0..<(side * side) {
            let r = Double(bytes[cell * 4]) / 255
            let g = Double(bytes[cell * 4 + 1]) / 255
            let b = Double(bytes[cell * 4 + 2]) / 255
            red += r; green += g; blue += b
            let y = 0.2126 * r + 0.7152 * g + 0.0722 * b
            luma[cell] = UInt8(Swift.min(255, Swift.max(0, (y * 255).rounded())))
        }
        let cells = Double(side * side)
        return VideoFrameSample(time: time, luma: luma, meanRed: red / cells,
                                meanGreen: green / cells, meanBlue: blue / cells)
    }
}
#endif

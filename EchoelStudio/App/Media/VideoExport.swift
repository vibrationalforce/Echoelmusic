import AVFoundation
import CoreGraphics
import EchoelCore
import EchoelDSP
import EchoelEngine
import Foundation

/// Writing the song as a video (wave W7, C6): the cut list `VideoPlan` lays over the rendered mix,
/// in one of the frames social platforms take, encoded as H.264 or HEVC with AAC sound in an MP4.
/// Every file it reads stays as it is — the export writes one new file and nothing else — and
/// neither the picture nor the mix is cut to the other's length (`VideoExportPlan`).
enum VideoExport {
    struct Options: Hashable, Sendable {
        var shape: VideoExportPlan.Shape = .vertical
        var fit: VideoExportPlan.Fit = .fill
        var codec: VideoExportPlan.Codec = .h264
        /// Brings the mix to social loudness (−14 LUFS) on the way.
        var normalizesLoudness = true
        /// A short export of these bars; nil exports the whole song.
        var range: ClosedRange<Tick>?
    }

    enum ExportError: LocalizedError {
        case noPicture
        case unreadableMix
        case cannotEncode
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .noPicture: "There is no video in that stretch of the song."
            case .unreadableMix: "The mix could not be read back for the video."
            case .cannotEncode: "This device cannot encode the video in that format."
            case .failed(let reason): "The video could not be written: \(reason)"
            }
        }
    }

    /// What the mix sounds like after the gain, for the status line.
    struct Loudness: Sendable {
        let integrated: Double
        let truePeak: Double
    }

    // MARK: - The mix

    /// The mix from `from` to `to` seconds as a new WAV in `folder`, brought to social loudness
    /// under the peak ceiling when `normalize` is on. Nil when the stretch holds none of the mix.
    static func preparedMix(_ source: URL, from: Double, to: Double, normalize: Bool,
                            into folder: URL) throws -> (url: URL, loudness: Loudness)? {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: source)
        } catch {
            throw ExportError.unreadableMix
        }
        let rate = file.processingFormat.sampleRate
        guard rate > 0, from.isFinite, to.isFinite else { return nil }
        let first = AVAudioFramePosition(Swift.max(0, (from * rate).rounded()))
        let last = Swift.min(file.length, AVAudioFramePosition(Swift.max(0, (to * rate).rounded())))
        guard last > first else { return nil }
        let block = 32_768
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(block)) else {
            throw ExportError.unreadableMix
        }
        var meter = LoudnessMeter(sampleRate: rate)
        try forEachBlock(of: file, from: first, to: last, buffer: buffer) { left, right, count in
            meter.process(left: left, right: right, count: count)
        }
        let gainDB = normalize ? VideoExportPlan.loudnessGain(integrated: meter.integratedLoudness, truePeak: meter.truePeak) : 0
        let gain = Float(pow(10, gainDB / 20))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        let writer = try WAVWriter(url: url, sampleRate: rate)
        var left = [Float](repeating: 0, count: block)
        var right = [Float](repeating: 0, count: block)
        do {
            try forEachBlock(of: file, from: first, to: last, buffer: buffer) { sourceLeft, sourceRight, count in
                for index in 0..<count {
                    left[index] = sourceLeft[index] * gain
                    right[index] = sourceRight[index] * gain
                }
                try writer.append(left: left, right: right, count: count)
            }
            try writer.finish()
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        return (url, Loudness(integrated: meter.integratedLoudness + gainDB, truePeak: meter.truePeak + gainDB))
    }

    private static func forEachBlock(of file: AVAudioFile, from first: AVAudioFramePosition, to last: AVAudioFramePosition,
                                     buffer: AVAudioPCMBuffer,
                                     _ body: (UnsafePointer<Float>, UnsafePointer<Float>, Int) throws -> Void) throws {
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

    // MARK: - The picture

    /// Lays `segments` (seconds of the export) from `files` into one picture track, the `mix` under
    /// it, and writes an MP4 to `url`. Each part is scaled into the frame by `options.fit`; gaps
    /// and the time past the last part are black. `duration` is how long the export runs at least.
    static func write(segments: [VideoPlan.Segment], files: [MediaID: URL], mix: URL?, duration: Double,
                      options: Options, to url: URL) async throws {
        let timescale: CMTimeScale = 48_000
        func moment(_ seconds: Double) -> CMTime { CMTime(seconds: seconds, preferredTimescale: timescale) }
        let composition = AVMutableComposition()
        guard let picture = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.cannotEncode
        }
        let frame = CGSize(width: options.shape.width, height: options.shape.height)
        var instructions: [AVMutableVideoCompositionInstruction] = []
        var cursor = CMTime.zero
        func black(until end: CMTime) {
            guard CMTimeCompare(end, cursor) > 0 else { return }
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: cursor, end: end)
            instruction.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
            instructions.append(instruction)
            cursor = end
        }
        for segment in segments {
            guard let fileURL = files[segment.media] else { continue }
            let asset = AVURLAsset(url: fileURL)
            guard let source = try? await asset.loadTracks(withMediaType: .video).first,
                  let loaded = try? await source.load(.naturalSize, .preferredTransform, .timeRange) else {
                continue
            }
            let (natural, transform, available) = loaded
            let from = moment(segment.fileSeconds)
            let end = CMTimeMinimum(CMTimeRangeGetEnd(available), CMTimeAdd(from, moment(segment.duration)))
            guard CMTimeCompare(end, from) > 0 else { continue }
            let length = CMTimeSubtract(end, from)
            let at = CMTimeMaximum(moment(segment.songSeconds), cursor)
            do {
                try picture.insertTimeRange(CMTimeRange(start: from, duration: length), of: source, at: at)
            } catch {
                continue
            }
            black(until: at)
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: picture)
            layer.setTransform(placement(natural: natural, transform: transform, in: frame, fit: options.fit), at: at)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: at, duration: length)
            instruction.backgroundColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
            instruction.layerInstructions = [layer]
            instructions.append(instruction)
            cursor = CMTimeAdd(at, length)
        }
        guard !instructions.isEmpty else { throw ExportError.noPicture }

        var total = CMTimeMaximum(cursor, moment(Swift.max(0, duration)))
        if let mix, let sound = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let asset = AVURLAsset(url: mix)
            guard let source = try? await asset.loadTracks(withMediaType: .audio).first,
                  let range = try? await source.load(.timeRange) else { throw ExportError.unreadableMix }
            do {
                try sound.insertTimeRange(range, of: source, at: .zero)
            } catch {
                throw ExportError.unreadableMix
            }
            total = CMTimeMaximum(total, range.duration)
        }
        // The picture runs as long as the export: black after its last part, never a cut sound.
        if CMTimeCompare(total, cursor) > 0 {
            picture.insertEmptyTimeRange(CMTimeRange(start: cursor, end: total))
            black(until: total)
        }

        let video = AVMutableVideoComposition()
        video.renderSize = frame
        video.frameDuration = CMTime(value: 1, timescale: 30)
        video.instructions = instructions

        let preset = options.codec == .hevc ? AVAssetExportPresetHEVCHighestQuality : AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: composition, presetName: preset) else { throw ExportError.cannotEncode }
        session.videoComposition = video
        session.shouldOptimizeForNetworkUse = true
        try? FileManager.default.removeItem(at: url)
        do {
            try await session.export(to: url, as: .mp4)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw ExportError.failed(error.localizedDescription)
        }
    }

    /// The transform that turns a source picture upright and places it in `frame`.
    private static func placement(natural: CGSize, transform: CGAffineTransform, in frame: CGSize,
                                  fit: VideoExportPlan.Fit) -> CGAffineTransform {
        let upright = CGRect(origin: .zero, size: natural).applying(transform)
        guard let place = VideoExportPlan.placement(sourceWidth: abs(upright.width), sourceHeight: abs(upright.height),
                                                    targetWidth: frame.width, targetHeight: frame.height, fit: fit) else {
            return transform
        }
        return transform
            .concatenating(CGAffineTransform(translationX: -upright.minX, y: -upright.minY))
            .concatenating(CGAffineTransform(scaleX: place.scale, y: place.scale))
            .concatenating(CGAffineTransform(translationX: place.x, y: place.y))
    }
}

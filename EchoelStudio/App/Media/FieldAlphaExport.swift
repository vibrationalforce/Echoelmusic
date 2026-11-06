import AVFoundation
import CoreVideo
import EchoelCore
import EchoelEngine
import Foundation
import VideoToolbox

/// The Field alone, as a video with its own transparency, for compositing in DaVinci Resolve or
/// Final Cut (PRO-W2, 2026-11-04): ProRes 4444 with alpha where the device encodes it, HEVC with
/// alpha otherwise, in a QuickTime movie at 30 frames a second from the song's start. Every frame
/// is the Field the video export would draw — computed from the song and the mix alone
/// (`FieldExport`), the same film twice — keyed to straight alpha by its light (`FieldAlphaKey`).
/// No sound: the mix is its own export, and both start at the song's first sample.
enum FieldAlphaExport {
    enum Codec: Sendable {
        case proRes4444
        case hevcWithAlpha

        var title: String {
            switch self {
            case .proRes4444: "ProRes 4444"
            case .hevcWithAlpha: "HEVC with alpha"
            }
        }
    }

    enum ExportError: LocalizedError {
        case noEncoder
        case noFieldLayer
        case stopped
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .noEncoder: "This device cannot encode video with transparency (ProRes 4444 or HEVC with alpha)."
            case .noFieldLayer: "This device cannot draw the Field into a video."
            case .stopped: "The Field could not be drawn into the video. Keep Echoel open while it exports, and export again."
            case .failed(let reason): "The Field video could not be written (\(reason)). Check the free space and export again."
            }
        }
    }

    /// The writer settings for `codec` at `width` × `height`.
    static func settings(_ codec: Codec, width: Int, height: Int) -> [String: Any] {
        switch codec {
        case .proRes4444:
            return [AVVideoCodecKey: AVVideoCodecType.proRes4444, AVVideoWidthKey: width, AVVideoHeightKey: height]
        case .hevcWithAlpha:
            return [AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha, AVVideoWidthKey: width, AVVideoHeightKey: height,
                    AVVideoCompressionPropertiesKey: [
                        kVTCompressionPropertyKey_AlphaChannelMode as String: kVTAlphaChannelMode_StraightAlpha as String,
                        AVVideoQualityKey: 0.9,
                    ]]
        }
    }

    /// The codecs this device's writer takes at that size, ProRes first; empty when it takes neither.
    static func codecs(width: Int, height: Int) -> [Codec] {
        [Codec.proRes4444, .hevcWithAlpha].filter { canEncode($0, width: width, height: height) }
    }

    private static func canEncode(_ codec: Codec, width: Int, height: Int) -> Bool {
        // A writer to a throwaway URL answers for this device's encoders; nothing is written.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("echoel-probe-\(UUID().uuidString).mov")
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mov) else { return false }
        return writer.canApply(outputSettings: settings(codec, width: width, height: height), forMediaType: .video)
    }

    /// Writes `film` (one Field and its looks per frame, at `FieldExport.framesPerSecond`) through
    /// `pass` into a movie at `url`, `width` × `height`, in `codec`. Runs off the main thread.
    static func write(film shown: [FieldExport.Shown], pass: FieldLayerPass, codec: Codec, width: Int, height: Int,
                      to url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            throw ExportError.failed(error.localizedDescription)
        }
        let output = settings(codec, width: width, height: height)
        guard writer.canApply(outputSettings: output, forMediaType: .video) else { throw ExportError.noEncoder }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: output)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Int](),
        ])
        guard writer.canAdd(input) else { throw ExportError.noEncoder }
        writer.add(input)
        guard writer.startWriting() else {
            throw ExportError.failed(writer.error?.localizedDescription ?? "the writer did not start")
        }
        writer.startSession(atSourceTime: .zero)
        // Field only: no picture under it, the layer adds the Field to black at full strength.
        let film = FieldLayerFilm(pass: pass, layer: FieldLayer(blend: .add, opacity: 1), film: shown)
        let rate = Int32(FieldExport.framesPerSecond)
        do {
            for index in 0..<Swift.max(1, shown.count) {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    guard writer.status == .writing else { throw ExportError.failed(writer.error?.localizedDescription ?? "the writer stopped") }
                    try await Task.sleep(nanoseconds: 2_000_000)
                }
                guard let pool = adaptor.pixelBufferPool else { throw ExportError.failed("no pixel buffers") }
                var made: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made) == kCVReturnSuccess, let frame = made else {
                    throw ExportError.failed("no pixel buffer")
                }
                let seconds = Double(index) / Double(rate)
                guard film.draw(nil, placement: nil, at: seconds, into: frame) else { throw ExportError.stopped }
                key(frame)
                guard adaptor.append(frame, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: rate)) else {
                    throw ExportError.failed(writer.error?.localizedDescription ?? "a frame was refused")
                }
            }
            input.markAsFinished()
            await writer.finishWriting()
            guard writer.status == .completed else {
                throw ExportError.failed(writer.error?.localizedDescription ?? "the movie was not finished")
            }
        } catch {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    /// Keys the frame's pixels to straight alpha in place, on the CPU, once the GPU has written them.
    private static func key(_ frame: CVPixelBuffer) {
        guard CVPixelBufferLockBaseAddress(frame, []) == kCVReturnSuccess else { return }
        defer { CVPixelBufferUnlockBaseAddress(frame, []) }
        guard let base = CVPixelBufferGetBaseAddress(frame) else { return }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(frame), height = CVPixelBufferGetHeight(frame)
        FieldAlphaKey.keyBGRA(UnsafeMutableRawBufferPointer(start: base, count: bytesPerRow * height),
                              width: CVPixelBufferGetWidth(frame), height: height, bytesPerRow: bytesPerRow)
    }
}

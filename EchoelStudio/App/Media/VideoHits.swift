import AVFoundation
import EchoelCore
import EchoelDSP
import Foundation
import Observation

/// The hits of the song's video files (CUT, 2026-11-01): where a sound in a file's own audio begins
/// and where its picture cuts hard, found once per file off the main thread and kept for this
/// launch. Derived from the files, never stored in the song — the next launch finds them again.
/// `files` changes only when a file's search ends, never with the clock, so a view may read it.
@MainActor
@Observable
final class VideoHits {
    /// The hits found so far, per file.
    private(set) var files: [MediaID: Hits.FileHits] = [:]
    /// Files whose search has started this launch: each is read once.
    @ObservationIgnored private var started: Set<MediaID> = []

    /// Starts the search for every video file of `project` not searched yet; `url` says where a
    /// file is now. A file that cannot be read ends with no hits.
    func find(in project: Project, url: (MediaFile) -> URL?) {
        for file in project.media where file.kind == .video && !started.contains(file.id) {
            guard let location = url(file) else { continue }
            started.insert(file.id)
            let id = file.id
            Task { [weak self] in
                let found = await Task.detached(priority: .utility) { await VideoHitSearch.hits(of: location) }.value
                self?.files[id] = found
            }
        }
    }
}

/// Reading a video file for its hits: its own sound through `OnsetDetector`, its picture through
/// `CutDetector`. Plain functions on no actor — the caller runs them off the main thread, because a
/// long video takes a while to decode. Every file stays as it is.
enum VideoHitSearch {
    /// The rate the file's sound is read at, mixed to one channel: enough for where a hit begins.
    static let soundRate = 22_050.0
    /// The picture is measured as a grid of this many cells across and down.
    static let columns = 16
    static let rows = 9
    /// Pixels read per cell, across and down.
    static let samplesPerCell = 8

    /// The hits of the video at `url`; none of a kind when the file has no such track or cannot be read.
    static func hits(of url: URL) async -> Hits.FileHits {
        let asset = AVURLAsset(url: url)
        let sounds = (try? await onsets(of: asset)) ?? []
        let cuts = (try? await cuts(of: asset)) ?? []
        return Hits.FileHits(sounds: sounds, cuts: cuts)
    }

    /// Where sounds begin in the file's first audio track, in seconds of the file.
    static func onsets(of asset: AVURLAsset) async throws -> [Double] {
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return [] }
        return try onsets(of: asset, track: track)
    }

    /// The reading itself, synchronous, so each buffer can have its own autorelease pool.
    private static func onsets(of asset: AVURLAsset, track: AVAssetTrack) throws -> [Double] {
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: soundRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return [] }
        reader.add(output)
        guard reader.startReading() else { return [] }
        var detector = OnsetDetector(sampleRate: soundRate)
        var first: Double?
        var samples: [Float] = []
        var reading = true
        while reading {
            // One pool per buffer: a long file must not gather the decoder's leftovers until it ends.
            reading = autoreleasepool { () -> Bool in
                guard let buffer = output.copyNextSampleBuffer() else { return false }
                if first == nil {
                    let time = CMSampleBufferGetPresentationTimeStamp(buffer)
                    first = time.isValid && time.seconds.isFinite ? time.seconds : 0
                }
                feed(buffer, into: &detector, through: &samples)
                return true
            }
        }
        guard reader.status == .completed else { return [] }
        let offset = first ?? 0
        return detector.onsets.map { $0 + offset }
    }

    /// One buffer of mono float samples into the detector, through `scratch`.
    private static func feed(_ buffer: CMSampleBuffer, into detector: inout OnsetDetector, through scratch: inout [Float]) {
        guard let block = CMSampleBufferGetDataBuffer(buffer) else { return }
        let count = CMBlockBufferGetDataLength(block) / MemoryLayout<Float>.size
        guard count > 0 else { return }
        if scratch.count < count { scratch = [Float](repeating: 0, count: count) }
        let status = scratch.withUnsafeMutableBytes { bytes -> OSStatus in
            guard let destination = bytes.baseAddress else { return -1 }
            return CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count * MemoryLayout<Float>.size,
                                              destination: destination)
        }
        guard status == kCMBlockBufferNoErr else { return }
        scratch.withUnsafeBufferPointer { stored in
            guard let start = stored.baseAddress else { return }
            detector.process(start, count: count)
        }
    }

    /// The first frame of each new shot in the file's first video track, in seconds of the file.
    static func cuts(of asset: AVURLAsset) async throws -> [Double] {
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { return [] }
        return try cuts(of: asset, track: track)
    }

    private static func cuts(of asset: AVURLAsset, track: AVAssetTrack) throws -> [Double] {
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return [] }
        reader.add(output)
        guard reader.startReading() else { return [] }
        var detector = CutDetector()
        var cells = [Float](repeating: 0, count: columns * rows)
        var reading = true
        while reading {
            reading = autoreleasepool { () -> Bool in
                guard let buffer = output.copyNextSampleBuffer() else { return false }
                let time = CMSampleBufferGetPresentationTimeStamp(buffer)
                if time.isValid, time.seconds.isFinite, let image = CMSampleBufferGetImageBuffer(buffer),
                   brightness(of: image, into: &cells) {
                    detector.add(cells, at: time.seconds)
                }
                return true
            }
        }
        guard reader.status == .completed else { return [] }
        return detector.cuts
    }

    /// The mean brightness of each cell of the picture's luma plane, 0 … 1, from an even sample of
    /// its pixels. False for a picture without a readable luma plane.
    static func brightness(of image: CVPixelBuffer, into cells: inout [Float]) -> Bool {
        CVPixelBufferLockBaseAddress(image, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
        guard CVPixelBufferGetPlaneCount(image) >= 1, cells.count == columns * rows,
              let base = CVPixelBufferGetBaseAddressOfPlane(image, 0) else { return false }
        let width = CVPixelBufferGetWidthOfPlane(image, 0)
        let height = CVPixelBufferGetHeightOfPlane(image, 0)
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(image, 0)
        let across = columns * samplesPerCell, down = rows * samplesPerCell
        guard width >= across, height >= down, rowBytes >= width else { return false }
        let luma = base.assumingMemoryBound(to: UInt8.self)
        for cell in 0..<cells.count { cells[cell] = 0 }
        for sampleRow in 0..<down {
            let y = (2 * sampleRow + 1) * height / (2 * down)
            let line = luma + y * rowBytes
            for sampleColumn in 0..<across {
                let x = (2 * sampleColumn + 1) * width / (2 * across)
                cells[(sampleRow / samplesPerCell) * columns + sampleColumn / samplesPerCell] += Float(line[x])
            }
        }
        let scale = 1 / Float(255 * samplesPerCell * samplesPerCell)
        for cell in 0..<cells.count { cells[cell] *= scale }
        return true
    }
}

import AVFoundation
import EchoelDSP
import Foundation

/// The pictures of the song's audio files, for the waveform inside each region on the
/// arrangement (`WaveformOverview`). A file is read ONCE, off the main thread, in chunks, and the
/// read stops between two chunks when the region that asked for it goes away — scrolled out,
/// deleted, or pointed at another file. Every region of the same file then draws from the one
/// picture it left here.
///
/// Cold by design: the picture lands once per file and never changes while it is shown, so a
/// region redraws only when its own size or window does (Law 6). Nothing here is ever reached
/// from the render thread.
@MainActor
final class WaveformCache {
    static let shared = WaveformCache()

    private var overviews: [URL: WaveformOverview] = [:]

    /// Past this many files the cache starts over; a song rarely holds that many.
    private static let capacity = 64
    /// The finest picture: a column per hundredth of a second.
    private nonisolated static let columnsPerSecond: Double = 100
    /// The most columns one file's picture holds — a long file gets coarser columns, never more.
    private nonisolated static let maximumColumns = 16_384
    /// Frames read per chunk.
    private nonisolated static let chunkFrames: AVAudioFrameCount = 65_536

    /// The picture of the file at `url`: the one already read, or a fresh read off the main
    /// thread. Nil when the file cannot be read or holds nothing, or when the caller was
    /// cancelled — then the read stops too, and nothing is kept.
    func overview(of url: URL) async -> WaveformOverview? {
        if let known = overviews[url] { return known }
        let reading = Task.detached(priority: .utility) {
            WaveformCache.read(url, isCancelled: { Task.isCancelled })
        }
        let read = await withTaskCancellationHandler {
            await reading.value
        } onCancel: {
            reading.cancel()
        }
        // A detached read does not inherit cancellation: one for a region that no longer asks
        // must not be kept as if it finished.
        guard !Task.isCancelled, let read else { return nil }
        if overviews.count >= Self.capacity { overviews.removeAll() }
        overviews[url] = read
        return read
    }

    /// Frames each column covers for a file of `frameCount` frames at `sampleRate`: a hundredth
    /// of a second, coarser for a file that would need more than `maximumColumns`. Nil for a rate
    /// that is not a positive number or a file without frames.
    nonisolated static func framesPerColumn(frameCount: Int64, sampleRate: Double) -> Int? {
        guard frameCount > 0, sampleRate.isFinite, sampleRate > 0 else { return nil }
        let byRate = (sampleRate / columnsPerSecond).rounded(.up)
        let byCap = (Double(frameCount) / Double(maximumColumns)).rounded(.up)
        let frames = Swift.max(1, byRate, byCap)
        guard frames.isFinite, frames < Double(Int32.max) else { return nil }
        return Int(frames)
    }

    /// Reads the whole file at `url` mixed to one channel, a chunk at a time, into its picture.
    /// A plain function on no actor, for a detached task; nil when the file cannot be opened or
    /// read, holds no frames, or `isCancelled` says stop (checked before every chunk).
    nonisolated static func read(_ url: URL, isCancelled: () -> Bool) -> WaveformOverview? {
        guard let audio = try? AVAudioFile(forReading: url) else { return nil }
        let format = audio.processingFormat
        let channels = Int(format.channelCount)
        guard channels > 0,
              let perColumn = framesPerColumn(frameCount: audio.length, sampleRate: format.sampleRate),
              let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else { return nil }
        var builder = WaveformOverview.Builder(framesPerColumn: perColumn)
        var mono = [Float](repeating: 0, count: Int(chunkFrames))
        let scale = 1 / Float(channels)
        while audio.framePosition < audio.length {
            if isCancelled() { return nil }
            do { try audio.read(into: chunk) } catch { return nil }
            let frames = Swift.min(Int(chunk.frameLength), mono.count)
            guard frames > 0, let data = chunk.floatChannelData else { break }
            for index in 0..<frames {
                var sum: Float = 0
                for channel in 0..<channels { sum += data[channel][index] }
                mono[index] = sum * scale
            }
            mono.withUnsafeBufferPointer { all in
                builder.append(UnsafeBufferPointer(rebasing: all[0..<frames]))
            }
        }
        let overview = builder.finished()
        return overview.isEmpty ? nil : overview
    }
}

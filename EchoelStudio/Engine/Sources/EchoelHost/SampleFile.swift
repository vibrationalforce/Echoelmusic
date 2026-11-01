import AVFoundation
import Foundation

/// Reading an audio file into memory: as the mono frames the Echoel Sampler plugin plays
/// (`read(into:)`), or with its two sides kept, as the app's import holds a file (`read(sidesInto:)`).
/// Plain functions on no actor: callers run them off the main thread, because a long file takes a
/// while to read.
public enum SampleFile {
    public struct Mono: Sendable, Equatable {
        public let samples: [Float]
        public let sampleRate: Double

        public init(samples: [Float], sampleRate: Double) {
            self.samples = samples
            self.sampleRate = sampleRate
        }
    }

    public enum ReadError: Error, Equatable {
        case unreadable
        case empty
        case tooLong(maximumSeconds: Double)
    }

    /// Frames read per pass while decoding.
    private static let chunkFrames: AVAudioFrameCount = 65_536

    /// Reads a whole file and mixes its channels down to one. Throws `tooLong` before reading
    /// anything when the file runs past `maximumSeconds`, or holds more than `maximumFrames` —
    /// a limit in frames is what bounds the memory: ten minutes at 768 kHz are 1.8 GB of floats.
    /// `tooLong` names the limit at the file's own rate.
    public static func readMono(_ url: URL, maximumSeconds: Double, maximumFrames: Int = .max) throws -> Mono {
        let reader = try Reader(url, maximumSeconds: maximumSeconds, maximumFrames: maximumFrames)
        var mono = [Float](repeating: 0, count: reader.frameCount)
        let read = try mono.withUnsafeMutableBufferPointer { try reader.read(into: $0) }
        guard read > 0 else { throw ReadError.empty }
        if read < mono.count { mono.removeLast(mono.count - read) }
        return Mono(samples: mono, sampleRate: reader.sampleRate)
    }

    /// An open file, measured and checked against the limits before a frame is read, that reads
    /// into memory the caller owns — so a file decoded straight into its sample buffer is held
    /// once, not in an array and then again in its copy (second night review, 2026-10-23).
    public final class Reader {
        /// The frames the file says it holds; a read writes at most these.
        public let frameCount: Int
        public let sampleRate: Double
        /// The channels the file holds.
        public let channelCount: Int
        /// The values per frame `read(sidesInto:)` writes: 1 for a mono file, 2 for any other.
        public let keptChannels: Int
        private let audio: AVAudioFile
        private let chunk: AVAudioPCMBuffer

        /// Opens `url`, throwing `tooLong` before reading anything when it runs past
        /// `maximumSeconds`, holds more than `maximumFrames`, or its frames would take more than
        /// `maximumValues` values of `keptChannels` each — the memory `read(sidesInto:)` writes —
        /// the limit named at its own rate.
        public init(_ url: URL, maximumSeconds: Double, maximumFrames: Int = .max, maximumValues: Int = .max) throws {
            do { audio = try AVAudioFile(forReading: url) } catch { throw ReadError.unreadable }
            let format = audio.processingFormat
            sampleRate = format.sampleRate
            channelCount = Int(format.channelCount)
            keptChannels = channelCount > 1 ? 2 : 1
            guard sampleRate.isFinite, sampleRate > 0, channelCount > 0 else { throw ReadError.unreadable }
            guard audio.length > 0, audio.length <= Int64(Int.max) else { throw ReadError.empty }
            let longest = Swift.min(maximumSeconds, Double(Swift.max(0, maximumFrames)) / sampleRate,
                                    Double(Swift.max(0, maximumValues) / keptChannels) / sampleRate)
            guard Double(audio.length) / sampleRate <= longest else { throw ReadError.tooLong(maximumSeconds: longest) }
            frameCount = Int(audio.length)
            guard let made = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: SampleFile.chunkFrames) else {
                throw ReadError.unreadable
            }
            chunk = made
        }

        /// Reads the file from where it stands, mixed down to one channel, into `destination`
        /// from its start; returns how many frames it wrote — fewer than `frameCount` when the
        /// file ends early, never more than `destination` holds.
        public func read(into destination: UnsafeMutableBufferPointer<Float>) throws -> Int {
            let channels = channelCount
            let scale = 1 / Float(channels)
            var written = 0
            while written < destination.count, audio.framePosition < audio.length {
                do { try audio.read(into: chunk) } catch { throw ReadError.unreadable }
                let frames = Swift.min(Int(chunk.frameLength), destination.count - written)
                guard frames > 0, let data = chunk.floatChannelData else { break }
                for i in 0..<frames {
                    var sum: Float = 0
                    for c in 0..<channels { sum += data[c][i] }
                    destination[written + i] = sum * scale
                }
                written += frames
            }
            return written
        }

        /// Reads the file from where it stands into `destination` from its start, `keptChannels`
        /// values a frame, interleaved: a mono file as it is, a stereo one left and right. A file of
        /// more channels keeps its first as the left and its second as the right and shares every
        /// further one equally between them, so the two sides averaged are exactly what
        /// `read(into:)` mixes. Returns how many frames it wrote — fewer than `frameCount` when the
        /// file ends early, never more than `destination` holds whole.
        public func read(sidesInto destination: UnsafeMutableBufferPointer<Float>) throws -> Int {
            let channels = channelCount
            let kept = keptChannels
            let room = destination.count / kept
            // Each side: its own channel and half of every further one, over half the channels.
            let scale = 2 / Float(channels)
            var written = 0
            while written < room, audio.framePosition < audio.length {
                do { try audio.read(into: chunk) } catch { throw ReadError.unreadable }
                let frames = Swift.min(Int(chunk.frameLength), room - written)
                guard frames > 0, let data = chunk.floatChannelData else { break }
                if channels == 1 {
                    for i in 0..<frames { destination[written + i] = data[0][i] }
                } else if channels == 2 {
                    for i in 0..<frames {
                        destination[2 * (written + i)] = data[0][i]
                        destination[2 * (written + i) + 1] = data[1][i]
                    }
                } else {
                    for i in 0..<frames {
                        var shared: Float = 0
                        for c in 2..<channels { shared += data[c][i] }
                        shared *= 0.5
                        destination[2 * (written + i)] = (data[0][i] + shared) * scale
                        destination[2 * (written + i) + 1] = (data[1][i] + shared) * scale
                    }
                }
                written += frames
            }
            return written
        }
    }
}

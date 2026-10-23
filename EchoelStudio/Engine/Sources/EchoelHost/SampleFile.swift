import AVFoundation
import Foundation

/// Reading an audio file into the mono frames a sampler plays. Shared by the app's import and
/// the Echoel Sampler plugin. Plain functions on no actor: callers run them off the main
/// thread, because a long file takes a while to read.
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
        let audio: AVAudioFile
        do { audio = try AVAudioFile(forReading: url) } catch { throw ReadError.unreadable }
        let format = audio.processingFormat
        let rate = format.sampleRate
        let length = audio.length
        let channels = Int(format.channelCount)
        guard rate.isFinite, rate > 0, channels > 0 else { throw ReadError.unreadable }
        guard length > 0 else { throw ReadError.empty }
        let longest = Swift.min(maximumSeconds, Double(Swift.max(0, maximumFrames)) / rate)
        guard Double(length) / rate <= longest else { throw ReadError.tooLong(maximumSeconds: longest) }
        guard let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
            throw ReadError.unreadable
        }

        var mono = [Float]()
        mono.reserveCapacity(Int(length))
        let scale = 1 / Float(channels)
        while audio.framePosition < length {
            do { try audio.read(into: chunk) } catch { throw ReadError.unreadable }
            let frames = Int(chunk.frameLength)
            guard frames > 0, let data = chunk.floatChannelData else { break }
            for i in 0..<frames {
                var sum: Float = 0
                for c in 0..<channels { sum += data[c][i] }
                mono.append(sum * scale)
            }
        }
        guard !mono.isEmpty else { throw ReadError.empty }
        return Mono(samples: mono, sampleRate: rate)
    }
}

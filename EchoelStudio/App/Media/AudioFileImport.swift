import AVFoundation
import EchoelCore
import EchoelDSP
import Foundation

/// Bringing an audio file into a song: copy it into the song package, then decode the copy to
/// the mono buffer the sampler plays. Plain functions on no actor — callers run them off the
/// main thread, because a long file takes a while to read.
enum AudioFileImport {
    /// The longest file a sampler takes: ten minutes, about 115 MB of mono floats at 48 kHz.
    static let maximumSeconds: Double = 600
    /// Frames read per pass while decoding.
    private static let chunkFrames: AVAudioFrameCount = 65_536

    enum ImportError: LocalizedError {
        case unreadable
        case empty
        case tooLong

        var errorDescription: String? {
            switch self {
            case .unreadable: "This file is not an audio format Echoel can read."
            case .empty: "This file holds no audio."
            case .tooLong: "This file is longer than ten minutes."
            }
        }
    }

    struct Imported: Sendable {
        let file: MediaFile
        let buffer: SampleBuffer
    }

    /// Copies `source` into the `Media` folder of the song package at `package` under a fresh
    /// id, decodes the copy, and describes it for `media.add`. Nothing is left behind when the
    /// file turns out to be unreadable.
    static func importFile(_ source: URL, into package: URL) throws -> Imported {
        let id = MediaID()
        let path = "\(MediaFile.directory)/\(id).\(fileExtension(of: source))"
        let name = displayName(of: source)
        let probe = MediaFile(id: id, name: name, path: path, frameCount: 1, sampleRate: 1)
        guard let destination = probe.url(in: package) else { throw ImportError.unreadable }

        let fm = FileManager.default
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: source, to: destination)
        do {
            let buffer = try decode(destination)
            let file = MediaFile(id: id, name: name, path: path, frameCount: buffer.frameCount,
                                 sampleRate: buffer.sampleRate)
            return Imported(file: file, buffer: buffer)
        } catch {
            try? fm.removeItem(at: destination)
            throw error
        }
    }

    /// Reads a whole file and mixes its channels down to one.
    static func decode(_ url: URL) throws -> SampleBuffer {
        let audio: AVAudioFile
        do { audio = try AVAudioFile(forReading: url) } catch { throw ImportError.unreadable }
        let format = audio.processingFormat
        let rate = format.sampleRate
        let length = audio.length
        let channels = Int(format.channelCount)
        guard rate.isFinite, rate > 0, channels > 0 else { throw ImportError.unreadable }
        guard length > 0 else { throw ImportError.empty }
        guard Double(length) / rate <= maximumSeconds else { throw ImportError.tooLong }
        guard let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
            throw ImportError.unreadable
        }

        var mono = [Float]()
        mono.reserveCapacity(Int(length))
        let scale = 1 / Float(channels)
        while audio.framePosition < length {
            do { try audio.read(into: chunk) } catch { throw ImportError.unreadable }
            let frames = Int(chunk.frameLength)
            guard frames > 0, let data = chunk.floatChannelData else { break }
            for i in 0..<frames {
                var sum: Float = 0
                for c in 0..<channels { sum += data[c][i] }
                mono.append(sum * scale)
            }
        }
        guard let buffer = SampleBuffer(samples: mono, sampleRate: rate) else { throw ImportError.empty }
        return buffer
    }

    /// The original extension when it is a short plain word, so the copy keeps its type hint.
    private static func fileExtension(of url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        let plain = !ext.isEmpty && ext.count <= 8 && ext.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return plain ? ext : "audio"
    }

    private static func displayName(of url: URL) -> String {
        let base = url.deletingPathExtension().lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "Sample" : String(base.prefix(Names.maximumLength))
    }
}

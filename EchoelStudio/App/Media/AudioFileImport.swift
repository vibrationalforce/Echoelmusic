import AVFoundation
import EchoelCore
import EchoelDSP
import EchoelEngine
import EchoelHost
import Foundation

/// Bringing an audio file into a song: copy it into the song package, then decode the copy to
/// the mono buffer the sampler plays. Plain functions on no actor — callers run them off the
/// main thread, because a long file takes a while to read.
enum AudioFileImport {
    /// The longest file a sampler takes: ten minutes, about 115 MB of mono floats at 48 kHz.
    static let maximumSeconds: Double = 600
    /// The most frames a file or a take holds: ten minutes at 48 kHz. A higher rate makes the
    /// limit shorter instead of the file larger — ten minutes at 768 kHz are 1.8 GB of floats,
    /// decoded before the song's memory plan could refuse them (R9).
    static let maximumFrames = Int(maximumSeconds * 48_000)

    /// The longest a file or a take may run at `rate`.
    static func longestSeconds(atRate rate: Double) -> Double {
        guard rate.isFinite, rate > 0 else { return maximumSeconds }
        return Swift.min(maximumSeconds, Double(maximumFrames) / rate)
    }

    /// A limit in words: "ten minutes", "5 minutes", "37 seconds".
    static func spoken(_ seconds: Double) -> String {
        if seconds >= maximumSeconds { return "ten minutes" }
        let minutes = seconds / 60
        if minutes >= 1 {
            let shown = minutes.formatted(.number.precision(.fractionLength(0...1)))
            return "\(shown) \(shown == "1" ? "minute" : "minutes")"
        }
        return "\(Int(seconds)) seconds"
    }

    /// How much decoded audio one song keeps in memory: a quarter of the device's memory, at
    /// least 512 MiB and at most 2 GiB. A song opens with all its audio decoded, so without a
    /// limit enough long files end the app on every open (ultra-audit R9).
    static let songBudgetBytes: Int = {
        let quarter = ProcessInfo.processInfo.physicalMemory / 4
        return Int(Swift.min(Swift.max(quarter, 512 << 20), 2 << 30))
    }()

    enum ImportError: LocalizedError {
        case unreadable
        case empty
        case tooLong(maximumSeconds: Double)
        /// The memory to decode it was not there: the file is fine, the device is full right now.
        case noMemory

        var errorDescription: String? {
            switch self {
            case .unreadable: "This file is not an audio format Echoel can read."
            case .empty: "This file holds no audio."
            case .noMemory: "There is not enough free memory to load this file right now."
            case .tooLong(let seconds) where seconds < AudioFileImport.maximumSeconds:
                "This file is longer than \(AudioFileImport.spoken(seconds)), the longest Echoel keeps at its sample rate."
            case .tooLong: "This file is longer than ten minutes."
            }
        }
    }

    struct Imported: Sendable {
        let file: MediaFile
        let buffer: SampleBuffer
    }

    /// Copies `source` into the `Media` folder of the song package at `package` under the fresh
    /// `id`, decodes the copy, and describes it for `media.add`. Nothing is left behind when the
    /// file turns out to be unreadable.
    static func importFile(_ source: URL, into package: URL, id: MediaID = MediaID()) throws -> Imported {
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

    /// Reads a whole file and mixes its channels down to one, refusing one past the limits
    /// before reading it. The defaults are the import's; a song opening its own files passes the
    /// room its memory plan has left instead, so a file kept from an earlier build is not
    /// refused for its length alone.
    /// The file is decoded straight into the buffer, so it is held in memory once: decoded into
    /// an array and copied, every file briefly cost twice what the memory plan counts — on a song
    /// opening near its budget, that is the out-of-memory end R9 is there to prevent (second night
    /// review, 2026-10-23).
    static func decode(_ url: URL, maximumSeconds: Double = AudioFileImport.maximumSeconds,
                       maximumFrames: Int = AudioFileImport.maximumFrames) throws -> SampleBuffer {
        do {
            let reader = try SampleFile.Reader(url, maximumSeconds: maximumSeconds, maximumFrames: maximumFrames)
            guard let buffer = try SampleBuffer(capacity: reader.frameCount, sampleRate: reader.sampleRate,
                                                fill: { try reader.read(into: $0) }) else { throw ImportError.empty }
            return buffer
        } catch is SampleBuffer.OutOfMemory {
            throw ImportError.noMemory
        } catch let error as SampleFile.ReadError {
            switch error {
            case .unreadable: throw ImportError.unreadable
            case .empty: throw ImportError.empty
            case .tooLong(let seconds): throw ImportError.tooLong(maximumSeconds: seconds)
            }
        }
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

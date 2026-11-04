import EchoelCore
import Foundation

/// Writes an export bundle — an `.otioz`, a `.dawproject` — as a stored ZIP (`ZipArchive`), the
/// text parts from memory and each media file streamed through in pieces, so a long video is never
/// held in memory. Runs off the main thread; touches only the bundle it writes (PRO-W2).
enum ExportBundleWriter {
    enum Source: Sendable {
        case data(Data)
        case file(URL)
    }

    struct Part: Sendable {
        let name: String
        let source: Source
    }

    private static let chunk = 1 << 20

    /// Writes `parts` in order into a new archive at `url`, replacing one that is there. Throws
    /// `ZipArchive.Failure.tooLarge` before writing past 4 GiB, and removes the half-written file.
    static func write(_ parts: [Part], to url: URL) throws {
        let files = FileManager.default
        if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
        guard files.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        do {
            let out = try FileHandle(forWritingTo: url)
            defer { try? out.close() }
            var writer = ZipArchive.Writer()
            for part in parts {
                switch part.source {
                case .data(let data):
                    try out.write(contentsOf: try writer.header(for: part.name, size: data.count,
                                                                  crc: ZipArchive.CRC32.checksum(data)))
                    try out.write(contentsOf: data)
                case .file(let source):
                    let (size, crc) = try measure(source)
                    try out.write(contentsOf: try writer.header(for: part.name, size: size, crc: crc))
                    let input = try FileHandle(forReadingFrom: source)
                    defer { try? input.close() }
                    var copied = 0
                    while let piece = try input.read(upToCount: chunk), !piece.isEmpty {
                        try out.write(contentsOf: piece)
                        copied += piece.count
                    }
                    // A file that changed between the two passes would leave a lying header.
                    guard copied == size else { throw CocoaError(.fileReadUnknown) }
                }
            }
            try out.write(contentsOf: try writer.finish())
        } catch {
            try? files.removeItem(at: url)
            throw error
        }
    }

    /// The file's size and CRC-32, read once in pieces.
    private static func measure(_ url: URL) throws -> (Int, UInt32) {
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        var crc = ZipArchive.CRC32()
        var size = 0
        while let piece = try input.read(upToCount: chunk), !piece.isEmpty {
            crc.update(piece)
            size += piece.count
            guard UInt64(size) <= ZipArchive.maximumSize else { throw ZipArchive.Failure.tooLarge }
        }
        return (size, crc.checksum)
    }
}

import EchoelDSP
import EchoelEngine
import EchoelHost
import Foundation

/// The musician's own click sound on this device (2026-11-19): one file kept in the app's support
/// folder, never in a song — like the click's level, it belongs to the musician, not the song.
/// A pick replaces the file before it; "Built-in Click" removes it.
enum ClickSoundFile {
    /// A file longer than this is no click; the picker says so instead of decoding it.
    static let maximumSeconds: Double = 10

    nonisolated static var folder: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Click Sound", isDirectory: true)
    }

    /// The kept file, if there is one.
    nonisolated static var kept: URL? {
        guard let folder,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return nil }
        return names.sorted().first.map { folder.appendingPathComponent($0) }
    }

    /// Copies `picked` in place of the file before it, which stays until the copy is whole; the
    /// kept copy's URL.
    nonisolated static func keep(_ picked: URL) throws -> URL {
        guard let folder else { throw CocoaError(.fileNoSuchFile) }
        let fm = FileManager.default
        let incoming = folder.deletingLastPathComponent().appendingPathComponent("Click Sound (new)", isDirectory: true)
        if fm.fileExists(atPath: incoming.path) { try fm.removeItem(at: incoming) }
        try fm.createDirectory(at: incoming, withIntermediateDirectories: true)
        try fm.copyItem(at: picked, to: incoming.appendingPathComponent(picked.lastPathComponent))
        if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) }
        try fm.moveItem(at: incoming, to: folder)
        return folder.appendingPathComponent(picked.lastPathComponent)
    }

    nonisolated static func forget() {
        guard let folder else { return }
        try? FileManager.default.removeItem(at: folder)
    }

    /// The file's first `ClickSound.maximumSeconds`, mixed to one channel at its own rate; nil when
    /// it cannot be read, is empty, or runs past `maximumSeconds`.
    nonisolated static func decode(_ url: URL) -> SampleBuffer? {
        guard let mono = try? SampleFile.readMono(url, maximumSeconds: maximumSeconds,
                                                  maximumFrames: Int(maximumSeconds * 384_000)),
              mono.sampleRate.isFinite, mono.sampleRate > 0 else { return nil }
        let frames = Int((ClickSound.maximumSeconds * mono.sampleRate).rounded(.up)) + 1
        return SampleBuffer(samples: Array(mono.samples.prefix(frames)), sampleRate: mono.sampleRate)
    }

    /// The name the menu shows: the file's name without its extension.
    nonisolated static func name(of url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
}

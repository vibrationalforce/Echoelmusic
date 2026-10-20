import Foundation

/// The user's songs on disk. Each song is a `.echoel` package — a folder holding
/// `project.json`, with room for audio and plugin state beside it later — so a song is one
/// item in the Files app and copies, shares and backs up as one.
///
/// Plain file I/O: callers keep it off the main thread when the song is large.
public struct ProjectLibrary: Sendable {
    public static let fileExtension = "echoel"
    public static let documentName = "project.json"

    public struct Entry: Equatable, Sendable, Identifiable {
        public let url: URL
        public let name: String
        public let modified: Date
        public var id: URL { url }
    }

    public enum LibraryError: Error, Equatable, Sendable {
        case notAPackage(URL)
    }

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// Every song in the directory, newest first. Folders that are not songs are skipped.
    public func list() throws -> [Entry] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return [] }
        let urls = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey],
                                              options: [.skipsHiddenFiles])
        return urls
            .filter { $0.pathExtension == Self.fileExtension }
            .compactMap { url -> Entry? in
                let document = url.appendingPathComponent(Self.documentName)
                guard let attributes = try? fm.attributesOfItem(atPath: document.path) else { return nil }
                let modified = attributes[.modificationDate] as? Date ?? .distantPast
                return Entry(url: url, name: url.deletingPathExtension().lastPathComponent, modified: modified)
            }
            .sorted { $0.modified != $1.modified ? $0.modified > $1.modified : $0.name < $1.name }
    }

    /// A package URL for a new song called `name` that does not exist yet: "Song", then
    /// "Song 2", "Song 3"… Characters a file name cannot hold become dashes.
    public func newURL(for name: String) -> URL {
        let base = Self.fileName(for: name)
        var candidate = directory.appendingPathComponent(base).appendingPathExtension(Self.fileExtension)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) \(n)").appendingPathExtension(Self.fileExtension)
            n += 1
        }
        return candidate
    }

    /// Writes `project` into the package at `url`, creating it if needed. The document is
    /// replaced atomically, so a crash mid-save leaves the previous version intact.
    public func write(_ project: Project, to url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let data = try ProjectCodec.encode(project)
        try data.write(to: url.appendingPathComponent(Self.documentName), options: .atomic)
    }

    public func read(_ url: URL) throws -> Project {
        let document = url.appendingPathComponent(Self.documentName)
        guard FileManager.default.fileExists(atPath: document.path) else { throw LibraryError.notAPackage(url) }
        return try ProjectCodec.decode(Data(contentsOf: document))
    }

    /// Brings in a song from outside the library — tapped in Files, sent by AirDrop, shared from
    /// another app — and returns where it now lives. One already in the library stays where it
    /// is. Any other is read first, so a damaged file is refused before anything is copied, and
    /// then copied whole, media and all, under a free name; one in the system's `Inbox` is moved
    /// instead, so it leaves no second copy behind.
    public func adopt(_ source: URL) throws -> URL {
        guard source.pathExtension == Self.fileExtension else { throw LibraryError.notAPackage(source) }
        let folder = Self.canonicalPath(source.deletingLastPathComponent())
        if folder == Self.canonicalPath(directory) { return source }
        _ = try read(source)
        let target = newURL(for: source.deletingPathExtension().lastPathComponent)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if folder == Self.canonicalPath(directory.appendingPathComponent("Inbox")) {
            try FileManager.default.moveItem(at: source, to: target)
        } else {
            try FileManager.default.copyItem(at: source, to: target)
        }
        return target
    }

    /// One spelling per folder: no trailing slash, no `..`, symbolic links resolved (`/var` is
    /// `/private/var` on Apple systems).
    private static func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    public func delete(_ url: URL) throws {
        guard url.pathExtension == Self.fileExtension else { throw LibraryError.notAPackage(url) }
        try FileManager.default.removeItem(at: url)
    }

    /// A file name for `name`, for exports beside the library.
    public static func safeFileName(for name: String) -> String { fileName(for: name) }

    static func fileName(for name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines).union(.controlCharacters)
        let cleaned = name.unicodeScalars.map { forbidden.contains($0) ? "-" : String($0) }.joined()
            .trimmingCharacters(in: .whitespaces)
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return trimmed.isEmpty ? "Untitled" : String(trimmed.prefix(100))
    }
}

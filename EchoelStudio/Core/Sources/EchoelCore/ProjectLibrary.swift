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

    /// A change of case that failed half way and could not go back: the package is at `url`,
    /// under the name in between, and `underlying` is why the second step failed.
    public struct RenameStranded: Error {
        public let url: URL
        public let underlying: Error
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
        try Self.writeDocument(project, to: url)
    }

    /// Writes `project` as a new package at `target` to hand to someone: its document as passed,
    /// and each media file the song names, read from `package` and placed at the same path. Files
    /// the song does not name (a take being recorded, an import the song let go) stay out. Returns
    /// the names of media files that are not in `package`; their entries stay in the song, which
    /// then opens without them on the other side, as it would here. A `target` already there is
    /// replaced; a copy that fails leaves nothing behind.
    public static func shareableCopy(of project: Project, mediaIn package: URL?, at target: URL) throws -> [String] {
        let files = FileManager.default
        if files.fileExists(atPath: target.path) { try files.removeItem(at: target) }
        do {
            try writeDocument(project, to: target)
            var missing: [String] = []
            for file in project.media {
                guard let package, let source = file.url(in: package), let destination = file.url(in: target),
                      files.fileExists(atPath: source.path) else {
                    missing.append(file.name)
                    continue
                }
                // Two entries on one path share one file.
                guard !files.fileExists(atPath: destination.path) else { continue }
                try files.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try files.copyItem(at: source, to: destination)
            }
            return missing
        } catch {
            try? files.removeItem(at: target)
            throw error
        }
    }

    private static func writeDocument(_ project: Project, to url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let data = try ProjectCodec.encode(project)
        try data.write(to: url.appendingPathComponent(documentName), options: .atomic)
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

    /// Where the package at `current` goes for a song now called `name`: `current` itself when its
    /// file name already spells `name`, else the first free spelling — "Beat", "Beat 2"… — with
    /// `current` counted as free, so "Beat 2" named "Beat" stays "Beat 2" while another song holds
    /// "Beat". A spelling that differs from `current` only in case is `current` on a volume that
    /// does not tell them apart, and is returned as it is spelled: that is a change of case.
    public func renamedURL(for name: String, from current: URL) -> URL {
        let base = Self.fileName(for: name)
        for number in 1...10_000 {
            let stem = number == 1 ? base : "\(base) \(number)"
            let candidate = directory.appendingPathComponent(stem).appendingPathExtension(Self.fileExtension)
            if candidate.lastPathComponent == current.lastPathComponent { return current }
            if !FileManager.default.fileExists(atPath: candidate.path) || Self.isSameItem(candidate, current) {
                return candidate
            }
        }
        return current
    }

    /// Moves the package at `url`, media and all, to `renamedURL(for: name, from: url)` and returns
    /// where it is now; `url` itself when nothing moves. A change of case only goes through a
    /// name of its own first, so it works where the volume holds "beat" and "Beat" as one name; that
    /// name stays visible in the list, so a song caught between the two steps is never hidden. A
    /// spelling taken between the look and the move — the earlier songs' import reserves names off
    /// the main thread — is passed over for the next free one.
    public func rename(_ url: URL, to name: String) throws -> URL {
        try rename(url, to: name, moving: { try FileManager.default.moveItem(at: $0, to: $1) })
    }

    /// `rename(_:to:)` with the move in the caller's hand, so a test can fail one step of it.
    func rename(_ url: URL, to name: String, moving move: (URL, URL) throws -> Void) throws -> URL {
        guard url.pathExtension == Self.fileExtension,
              Self.canonicalPath(url.deletingLastPathComponent()) == Self.canonicalPath(directory) else {
            throw LibraryError.notAPackage(url)
        }
        let files = FileManager.default
        for _ in 0..<8 {
            let target = renamedURL(for: name, from: url)
            guard target.lastPathComponent != url.lastPathComponent else { return url }
            if target.lastPathComponent.lowercased() == url.lastPathComponent.lowercased() {
                let between = directory.appendingPathComponent(Self.betweenStem(for: url.deletingPathExtension().lastPathComponent))
                    .appendingPathExtension(Self.fileExtension)
                try move(url, between)
                do {
                    try move(between, target)
                } catch {
                    do { try move(between, url) } catch {}
                    // Ask the package, not its old name: another song may hold that name by now (the
                    // earlier songs' import reserves names off the main thread, review 006 round 3).
                    // Still under the name in between, the caller learns where it is, instead of
                    // writing into that other package.
                    guard !files.fileExists(atPath: between.path) else { throw RenameStranded(url: between, underlying: error) }
                    throw error
                }
                return target
            }
            do {
                try move(url, target)
                return target
            } catch {
                guard files.fileExists(atPath: target.path), files.fileExists(atPath: url.path) else { throw error }
            }
        }
        throw CocoaError(.fileWriteFileExists)
    }

    /// The name a change of case passes through: the stem, " renaming " and the first eight
    /// characters of a fresh UUID, in capitals on every platform. Visible on purpose, so a song
    /// caught between the two steps is never hidden.
    static func betweenStem(for stem: String) -> String {
        "\(stem) renaming \(UUID().uuidString.prefix(8).uppercased())"
    }

    /// Whether `stem` is a name in between exactly as `rename` writes it: a song left there by a
    /// change of case that did not finish, not a name anyone chose. Only capitals count, so a name
    /// typed by hand in lower case is never taken for one (review 007 round 1).
    public static func isBetweenStem(_ stem: String) -> Bool {
        guard let marker = stem.range(of: " renaming ", options: .backwards),
              marker.lowerBound > stem.startIndex else { return false }
        let tail = stem[marker.upperBound...]
        return tail.count == 8 && tail.allSatisfy { "0123456789ABCDEF".contains($0) }
    }

    /// Two paths that name one item on disk, as one volume spells it two ways.
    private static func isSameItem(_ a: URL, _ b: URL) -> Bool {
        let files = FileManager.default
        guard let first = try? files.attributesOfItem(atPath: a.path), let second = try? files.attributesOfItem(atPath: b.path),
              let one = first[.systemFileNumber] as? NSNumber, let other = second[.systemFileNumber] as? NSNumber,
              let volume = first[.systemNumber] as? NSNumber, let otherVolume = second[.systemNumber] as? NSNumber else {
            return false
        }
        return one == other && volume == otherVolume
    }

    public func delete(_ url: URL) throws {
        guard url.pathExtension == Self.fileExtension else { throw LibraryError.notAPackage(url) }
        try FileManager.default.removeItem(at: url)
    }

    /// A file name for `name`, for exports beside the library.
    public static func safeFileName(for name: String) -> String { fileName(for: name) }

    /// The most bytes a file name's stem takes in UTF-8. A file system limits a name in bytes (255),
    /// not in characters, and one character can carry many scalars — a letter with marks, an
    /// emoji with a skin tone — so a name the door accepts could be far too long for a file. 200
    /// leaves room for " 10000", a rename's " renaming 1A2B3C4D" and ".echoel" (review 006).
    static let stemByteLimit = 200

    static func fileName(for name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines).union(.controlCharacters)
        let cleaned = name.unicodeScalars.map { forbidden.contains($0) ? "-" : String($0) }.joined()
            .trimmingCharacters(in: .whitespaces)
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        var stem = String(trimmed.prefix(100))
        while stem.utf8.count > stemByteLimit { stem.removeLast() }
        // A cut can end on a space or a dot, which a file name does not keep well.
        stem = stem.trimmingCharacters(in: CharacterSet(charactersIn: ".").union(.whitespaces))
        return stem.isEmpty ? "Untitled" : stem
    }
}

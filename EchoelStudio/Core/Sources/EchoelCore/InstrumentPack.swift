import Foundation

/// The catalogue of instrument packs (IL-1, founder 2026-11-18): open sample instruments — SFZ or
/// Echoel's own JSON zone map plus their audio files — that a musician may install. Pure data and
/// pure rules: nothing here fetches, stores or plays a file. Reading a catalogue is reading an
/// untrusted document, so it is checked like a command at the door (Law 4): one bad pack falls out
/// on its own with the reason, and the packs around it stay.
public struct InstrumentPackManifest: Codable, Sendable, Equatable {
    /// The one catalogue shape this build reads; a catalogue of another shape is refused whole.
    public static let currentSchema = 1
    /// A catalogue is a list of names and addresses, never audio: anything larger is not one.
    public static let maximumBytes = 1 << 20

    public var schema: Int
    public var packs: [InstrumentPackEntry]

    public init(schema: Int = InstrumentPackManifest.currentSchema, packs: [InstrumentPackEntry]) {
        self.schema = schema
        self.packs = packs
    }

    /// Reads a catalogue. Throws when the whole document cannot be one — too large, not JSON (a
    /// fault of syntax anywhere refuses all of it), another shape. A pack that is JSON but not a
    /// pack is counted in `undecodable` and falls out alone.
    public static func decode(_ data: Data) throws -> (manifest: InstrumentPackManifest, undecodable: Int) {
        guard data.count <= maximumBytes else { throw InstrumentPackError.tooLarge }
        let read: Lenient
        do {
            read = try JSONDecoder().decode(Lenient.self, from: data)
        } catch {
            throw InstrumentPackError.notACatalogue
        }
        guard read.schema == currentSchema else { throw InstrumentPackError.unsupportedSchema(read.schema) }
        let packs = read.packs.compactMap(\.entry)
        return (InstrumentPackManifest(schema: read.schema, packs: packs), read.packs.count - packs.count)
    }

    /// The packs `policy` accepts, in catalogue order, and every refused one with its reason. Of two
    /// packs with one id the first stays, so a later entry cannot replace a pack already listed.
    public func checked(by policy: InstrumentPackPolicy) -> (accepted: [InstrumentPackEntry], refused: [InstrumentPackRefusal]) {
        var accepted: [InstrumentPackEntry] = []
        var refused: [InstrumentPackRefusal] = []
        var ids = Set<String>()
        for pack in packs {
            if let reason = policy.problem(with: pack) {
                refused.append(InstrumentPackRefusal(id: pack.id, problem: reason))
            } else if !ids.insert(pack.id).inserted {
                refused.append(InstrumentPackRefusal(id: pack.id, problem: .duplicateID))
            } else {
                accepted.append(pack)
            }
        }
        return (accepted, refused)
    }

    /// The document as read before any pack is decoded: every pack is tried on its own.
    private struct Lenient: Decodable {
        let schema: Int
        let packs: [OnePack]
    }

    private struct OnePack: Decodable {
        let entry: InstrumentPackEntry?

        init(from decoder: Decoder) throws {
            entry = try? InstrumentPackEntry(from: decoder)
        }
    }
}

/// One pack of the catalogue: what it is, whose it is, under which licence, and its files.
public struct InstrumentPackEntry: Codable, Sendable, Equatable, Identifiable {
    /// Stable name, lowercase letters, digits, dots and hyphens: "echoel.felt-piano".
    public var id: String
    /// What the list shows: "Felt Piano".
    public var name: String
    /// One of `InstrumentPackCategory`; an unknown word reads as `.other`.
    public var category: String
    /// The licence as an SPDX identifier: "CC0-1.0", "CC-BY-4.0".
    public var licence: String
    /// Who made the recordings, as the credit names them.
    public var author: String
    /// Grows with every change to the pack's files; a song names the version it took.
    public var version: Int
    /// The path, among `files`, of the zone map: an `.sfz` or a `.json` file.
    public var mapping: String
    public var files: [InstrumentPackFile]

    public init(id: String, name: String, category: String, licence: String, author: String, version: Int,
                mapping: String, files: [InstrumentPackFile]) {
        self.id = id
        self.name = name
        self.category = category
        self.licence = licence
        self.author = author
        self.version = version
        self.mapping = mapping
        self.files = files
    }

    public var kind: InstrumentPackCategory { InstrumentPackCategory(rawValue: category) ?? .other }

    /// What the pack's files take on the device, in bytes, as the catalogue states them.
    /// A sum that would not fit reads as `Int.max`, which no policy accepts.
    public var totalBytes: Int {
        var total = 0
        for file in files {
            let (sum, overflow) = total.addingReportingOverflow(file.bytes)
            if overflow { return Int.max }
            total = sum
        }
        return total
    }
}

/// One file of a pack: where it goes inside the pack, where it is fetched from, how large it is and
/// its SHA-256, which the downloaded bytes must match before the pack is installed.
public struct InstrumentPackFile: Codable, Sendable, Equatable {
    /// Relative to the pack's folder: "samples/c4.wav".
    public var path: String
    /// HTTPS, on a host the policy names.
    public var url: String
    public var bytes: Int
    /// 64 hexadecimal digits.
    public var sha256: String

    public init(path: String, url: String, bytes: Int, sha256: String) {
        self.path = path
        self.url = url
        self.bytes = bytes
        self.sha256 = sha256
    }

    /// The checksum in lowercase, the one form a computed digest is compared with.
    public var checksum: String { sha256.lowercased() }
}

/// What a pack plays, for the list's sections. Stored as its word in the catalogue, never in a song.
public enum InstrumentPackCategory: String, CaseIterable, Sendable {
    case keys, strings, winds, brass, percussion, drums, voice, synth, effects, other
}

/// Why a pack was left out.
public enum InstrumentPackProblem: Equatable, Sendable {
    case badID
    case duplicateID
    case badName
    case licenceNotAllowed(String)
    case missingAuthor
    case badVersion
    case noFiles
    case tooManyFiles
    case badPath(String)
    case duplicatePath(String)
    case badExtension(String)
    case urlNotAllowed(String)
    case badSize(String)
    case packTooLarge
    case badChecksum(String)
    case mappingMissing
}

public struct InstrumentPackRefusal: Equatable, Sendable {
    public let id: String
    public let problem: InstrumentPackProblem
}

public enum InstrumentPackError: Error, Equatable {
    case tooLarge
    case notACatalogue
    case unsupportedSchema(Int)
}

/// What a catalogue may offer: which licences, which hosts, how large. A value, so a decision on
/// the host or on the licences changes one constant and every test follows.
public struct InstrumentPackPolicy: Sendable, Equatable {
    public var licences: Set<String>
    public var hosts: Set<String>
    public var maximumFileBytes: Int
    public var maximumPackBytes: Int
    public var maximumFiles: Int

    public init(licences: Set<String>, hosts: Set<String>, maximumFileBytes: Int, maximumPackBytes: Int, maximumFiles: Int) {
        self.licences = licences
        self.hosts = hosts
        self.maximumFileBytes = maximumFileBytes
        self.maximumPackBytes = maximumPackBytes
        self.maximumFiles = maximumFiles
    }

    /// The proposed policy, not yet decided: licences that leave a musician's song
    /// free to sell — CC0, and CC-BY with the author credited — and one host. Nothing fetches yet.
    public static let recommended = InstrumentPackPolicy(
        licences: ["CC0-1.0", "CC-BY-4.0"], hosts: ["raw.githubusercontent.com"],
        maximumFileBytes: 64 << 20, maximumPackBytes: 256 << 20, maximumFiles: 512)

    /// The extensions a pack's audio may have; the zone map is `.sfz` or `.json`.
    public static let audioExtensions: Set<String> = ["wav", "wave", "aif", "aiff", "caf", "flac"]
    public static let mappingExtensions: Set<String> = ["sfz", "json"]

    /// The first reason `pack` may not be offered, or nil.
    public func problem(with pack: InstrumentPackEntry) -> InstrumentPackProblem? {
        guard Self.isValidID(pack.id) else { return .badID }
        guard Self.isValidText(pack.name, maximum: 64) else { return .badName }
        guard licences.contains(pack.licence) else { return .licenceNotAllowed(pack.licence) }
        guard Self.isValidText(pack.author, maximum: 120) else { return .missingAuthor }
        guard (1...1_000_000).contains(pack.version) else { return .badVersion }
        guard !pack.files.isEmpty else { return .noFiles }
        guard pack.files.count <= maximumFiles else { return .tooManyFiles }
        var names = Set<String>()
        var neededFolders = Set<String>()
        for file in pack.files {
            if let reason = fileProblem(file) { return reason }
            // One name per file whatever the letter case, and never a file where another path needs a
            // folder: a pack that passes can be written to any disk exactly as it is listed.
            let name = Self.diskName(file.path)
            let parents = Self.folders(of: name)
            guard names.insert(name).inserted, !neededFolders.contains(name), names.isDisjoint(with: parents) else {
                return .duplicatePath(file.path)
            }
            neededFolders.formUnion(parents)
        }
        guard pack.totalBytes <= maximumPackBytes else { return .packTooLarge }
        // The zone map is one of the files, named exactly as that file is: it is opened by this name.
        let mapping = pack.mapping
        guard Self.mappingExtensions.contains(Self.pathExtension(mapping)),
              pack.files.contains(where: { $0.path == mapping }) else { return .mappingMissing }
        return nil
    }

    private func fileProblem(_ file: InstrumentPackFile) -> InstrumentPackProblem? {
        guard Self.isSafePath(file.path) else { return .badPath(file.path) }
        let ext = Self.pathExtension(file.path)
        guard Self.audioExtensions.contains(ext) || Self.mappingExtensions.contains(ext) else { return .badExtension(file.path) }
        guard isAllowedURL(file.url) else { return .urlNotAllowed(file.url) }
        guard file.bytes > 0, file.bytes <= maximumFileBytes else { return .badSize(file.path) }
        guard Self.isChecksum(file.sha256) else { return .badChecksum(file.path) }
        return nil
    }

    /// The address as it may be fetched, or nil: HTTPS on a named host, the standard port, no user
    /// name or password, no query and no fragment, printable ASCII with no space and no backslash, a
    /// host written without percent signs, and a path beyond "/". A download takes this URL, never
    /// the string, so what was checked is what is fetched.
    public func allowedURL(_ text: String) -> URL? {
        guard text.utf8.count <= 2_048,
              text.unicodeScalars.allSatisfy({ (scalar: Unicode.Scalar) -> Bool in
                  (0x21...0x7E).contains(scalar.value) && scalar.value != 0x5C
              }),
              let authority = Self.authority(of: text), !authority.contains("%"),
              let parts = URLComponents(string: text), parts.scheme?.lowercased() == "https",
              parts.user == nil, parts.password == nil, parts.port == nil || parts.port == 443,
              parts.query == nil, parts.fragment == nil,
              let host = parts.host?.lowercased(), hosts.contains(host), parts.path.count > 1,
              let url = parts.url, url.host?.lowercased() == host else { return nil }
        return url
    }

    public func isAllowedURL(_ text: String) -> Bool { allowedURL(text) != nil }

    /// What stands between `://` and the next `/`, as written: the host is judged on the text
    /// itself, so no parser's idea of percent-decoding decides which host it is.
    private static func authority(of text: String) -> Substring? {
        guard let scheme = text.range(of: "://") else { return nil }
        return text[scheme.upperBound...].prefix(while: { $0 != "/" })
    }

    /// 3 … 64 characters of `a`–`z`, `0`–`9`, `.` and `-`, beginning with a letter, never two dots or
    /// a dot or hyphen at the end: a name that is also a safe folder name.
    public static func isValidID(_ id: String) -> Bool {
        guard (3...64).contains(id.count), let first = id.unicodeScalars.first, isLowercaseLetter(first),
              let last = id.unicodeScalars.last, isLowercaseLetter(last) || isDigit(last), !id.contains("..") else { return false }
        return id.unicodeScalars.allSatisfy { (scalar: Unicode.Scalar) -> Bool in
            isLowercaseLetter(scalar) || isDigit(scalar) || scalar.value == 0x2E || scalar.value == 0x2D
        }
    }

    /// `a` … `z` and `0` … `9` by their code points, so no other alphabet's letter or digit passes.
    private static func isLowercaseLetter(_ scalar: Unicode.Scalar) -> Bool { (0x61...0x7A).contains(scalar.value) }
    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool { (0x30...0x39).contains(scalar.value) }
    private static func isHexLetter(_ scalar: Unicode.Scalar) -> Bool {
        (0x61...0x66).contains(scalar.value) || (0x41...0x46).contains(scalar.value)
    }

    /// A relative path inside the pack, in names every disk and every tool keeps apart: ASCII
    /// letters, digits, the space and `. _ - # + ( ) & ' ,`, steps divided by `/`; no step empty,
    /// none beginning or ending with a dot or a space (so no `.`, no `..`, no hidden file); at most
    /// 200 bytes. No such path leaves the pack, no two spellings of it are one file, and no name
    /// outgrows a disk's limit. A pack with other names is renamed by its maker, never guessed at.
    public static func isSafePath(_ path: String) -> Bool {
        guard !path.isEmpty, path.utf8.count <= 200 else { return false }
        guard path.unicodeScalars.allSatisfy({ (scalar: Unicode.Scalar) -> Bool in isPathScalar(scalar) }) else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { (step: Substring) -> Bool in
            guard let first = step.unicodeScalars.first, let last = step.unicodeScalars.last else { return false }
            return first.value != 0x2E && first.value != 0x20 && last.value != 0x2E && last.value != 0x20
        }
    }

    /// `/` and the punctuation a file name may carry: space . _ - # + ( ) & ' ,
    private static let pathPunctuation: Set<UInt32> = [0x2F, 0x20, 0x2E, 0x5F, 0x2D, 0x23, 0x2B, 0x28, 0x29, 0x26, 0x27, 0x2C]

    private static func isPathScalar(_ scalar: Unicode.Scalar) -> Bool {
        isLowercaseLetter(scalar) || isDigit(scalar) || (0x41...0x5A).contains(scalar.value)
            || pathPunctuation.contains(scalar.value)
    }

    /// The form in which two paths are the same file on a case-blind disk (a safe path is ASCII, so
    /// lowercase is the whole fold).
    static func diskName(_ path: String) -> String {
        path.lowercased()
    }

    /// Every folder a path needs: "a" and "a/b" for "a/b/c.wav".
    static func folders(of path: String) -> Set<String> {
        var found = Set<String>()
        var prefix = ""
        for step in path.split(separator: "/").dropLast() {
            prefix = prefix.isEmpty ? String(step) : prefix + "/" + String(step)
            found.insert(prefix)
        }
        return found
    }

    static func pathExtension(_ path: String) -> String {
        guard let name = path.split(separator: "/").last, let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return name[name.index(after: dot)...].lowercased()
    }

    static func isChecksum(_ text: String) -> Bool {
        text.unicodeScalars.count == 64 && text.unicodeScalars.allSatisfy { (scalar: Unicode.Scalar) -> Bool in
            isDigit(scalar) || isHexLetter(scalar)
        }
    }

    /// Letters that draw as nothing (Hangul fillers): refused with the invisible characters.
    private static let blankLetters: Set<UInt32> = [0x115F, 0x1160, 0x3164, 0xFFA0]

    /// Visible text of at most `maximum` characters: no control, format, private-use or unassigned
    /// character and no line or paragraph separator, so nothing hidden rides in a name.
    static func isValidText(_ text: String, maximum: Int) -> Bool {
        guard text.count <= maximum, text.utf8.count <= maximum * 4,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return text.unicodeScalars.allSatisfy { (scalar: Unicode.Scalar) -> Bool in
            guard !blankLetters.contains(scalar.value) else { return false }
            switch scalar.properties.generalCategory {
            case .control, .format, .privateUse, .unassigned, .surrogate, .lineSeparator, .paragraphSeparator:
                return false
            default:
                return true
            }
        }
    }
}

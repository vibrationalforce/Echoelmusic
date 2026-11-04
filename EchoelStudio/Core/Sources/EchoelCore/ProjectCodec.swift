import Foundation

/// Reads and writes the project document as JSON. The output is pretty-printed with sorted
/// keys, so the same project always produces the same bytes and a diff shows only real changes.
public enum ProjectCodec {
    public enum DecodeError: Error, Equatable, Sendable {
        /// The file was written by a newer version of the app.
        case newerFormat(found: Int, supported: Int)
        case missingFormatVersion
        /// A format number below 1: no build ever wrote one.
        case invalidFormatVersion(Int)
        /// The file breaks a rule every command enforces (`Project.validate`).
        case invalidContent(CommandError)
        /// Larger than any song document Echoel writes (`maximumDocumentBytes`): refused before it is
        /// parsed, so a crafted or damaged file cannot take the memory a parse of it would need.
        case tooLarge(bytes: Int)
    }

    /// The most bytes a song document may have. Media lives beside it in the package, never in it,
    /// so a real document is kilobytes to a few megabytes; this leaves a wide margin for long songs
    /// full of notes and automation (team SAFE 2026-11-04).
    public static let maximumDocumentBytes = 64 * 1024 * 1024

    public static func encode(_ project: Project) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(project)
    }

    public static func decode(_ data: Data) throws -> Project {
        guard data.count <= maximumDocumentBytes else { throw DecodeError.tooLarge(bytes: data.count) }
        struct Header: Decodable { let formatVersion: Int? }
        let header = try JSONDecoder().decode(Header.self, from: data)
        guard let version = header.formatVersion else { throw DecodeError.missingFormatVersion }
        guard version >= 1 else { throw DecodeError.invalidFormatVersion(version) }
        guard version <= Project.currentFormatVersion else {
            throw DecodeError.newerFormat(found: version, supported: Project.currentFormatVersion)
        }
        let project = try JSONDecoder().decode(Project.self, from: data)
        do {
            try project.validate()
        } catch let error as CommandError {
            throw DecodeError.invalidContent(error)
        }
        return project
    }
}

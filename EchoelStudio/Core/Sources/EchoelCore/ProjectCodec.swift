import Foundation

/// Reads and writes the project document as JSON. The output is pretty-printed with sorted
/// keys, so the same project always produces the same bytes and a diff shows only real changes.
public enum ProjectCodec {
    public enum DecodeError: Error, Equatable, Sendable {
        /// The file was written by a newer version of the app.
        case newerFormat(found: Int, supported: Int)
        case missingFormatVersion
        /// The file breaks a rule every command enforces (`Project.validate`).
        case invalidContent(CommandError)
    }

    public static func encode(_ project: Project) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(project)
    }

    public static func decode(_ data: Data) throws -> Project {
        struct Header: Decodable { let formatVersion: Int? }
        let header = try JSONDecoder().decode(Header.self, from: data)
        guard let version = header.formatVersion else { throw DecodeError.missingFormatVersion }
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

import Foundation

/// A typed identifier. `Identifier<Track>` and `Identifier<Clip>` are different types, so a
/// clip id can never be passed where a track id is expected. Encoded as a plain UUID string.
public struct Identifier<Tag>: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(UUID.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue.uuidString }
}

public typealias TrackID = Identifier<Track>
public typealias ClipID = Identifier<Clip>
public typealias PlacementID = Identifier<Placement>
public typealias NoteID = Identifier<Note>
public typealias SceneID = Identifier<Scene>
public typealias MediaID = Identifier<MediaFile>
public typealias RegionID = Identifier<AudioRegion>

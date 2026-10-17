/// A stretch of an audio file on an audio track's timeline. The region starts at a musical
/// position and plays the file at its own speed from `offset` for `length` frames, so a
/// tempo change moves where it starts but never how it sounds.
public struct AudioRegion: Codable, Equatable, Sendable, Identifiable {
    public var id: RegionID
    public var media: MediaID
    /// Timeline position in ticks.
    public var start: Tick
    /// First frame of the file that plays.
    public var offset: Int
    /// Frames played from `offset`; at least one, never past the end of the file.
    public var length: Int

    public init(id: RegionID = RegionID(), media: MediaID, start: Tick, offset: Int = 0, length: Int) {
        self.id = id
        self.media = media
        self.start = start
        self.offset = offset
        self.length = length
    }
}

extension Track {
    public func regionIndex(_ id: RegionID) -> Int? {
        regions.firstIndex { $0.id == id }
    }
}

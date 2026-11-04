import Foundation

/// A named position on the song's timeline — "Verse", "Drop", "Cue 3" — shown on the ruler and
/// carried into every export that has a place for it: a MIDI file's marker events, a WAV or stem
/// file's cue points, an edit decision list's locators (PRO-W1, 2026-11-04). Optional inside
/// format 4: a song without markers stores no key, exactly as before.
public struct Marker: Codable, Equatable, Hashable, Sendable {
    /// Where the marker stands, in ticks from the song's start. One marker per tick.
    public var tick: Tick
    public var name: String

    public init(tick: Tick, name: String) {
        self.tick = tick
        self.name = name
    }

    /// How many markers one song holds. Far more than any arrangement names; the bound keeps a
    /// damaged file from carrying millions of them into the ruler.
    public static let maximumCount = 1_000
}

extension Project {
    /// The marker at `tick`, if one stands there.
    public func marker(at tick: Tick) -> Marker? {
        markers.first { $0.tick == tick }
    }

    /// Markers ticks rising from 0 to at most `maximumTick`, each tick once, each with a name, at
    /// most `Marker.maximumCount`.
    static func validateMarkers(_ markers: [Marker], nameLimit: Int) throws {
        guard markers.count <= Marker.maximumCount else {
            throw invalid("markers", "at most \(Marker.maximumCount)")
        }
        var previous: Tick = -1
        for marker in markers {
            guard marker.tick > previous, marker.tick <= MusicalTime.maximumTick else {
                throw invalid("markers", "ticks must rise from 0 to at most \(MusicalTime.maximumTick), each once")
            }
            let trimmed = marker.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, marker.name.count <= nameLimit else {
                throw invalid("markers", "a name is empty or longer than \(nameLimit) characters")
            }
            previous = marker.tick
        }
    }

    /// The next free name of the form "Marker N", for a marker the musician adds without naming it.
    public func nextMarkerName() -> String {
        let taken = Set(markers.map(\.name))
        var number = markers.count + 1
        while taken.contains("Marker \(number)") { number += 1 }
        return "Marker \(number)"
    }

    /// Each marker's place in seconds from the song's start, over the song's tempo map — what a
    /// WAV cue point, a timecode and a video editor count in.
    public func markerSeconds() -> [(seconds: Double, name: String)] {
        let map = tempoMap
        return markers.map { (map.seconds(at: $0.tick), $0.name) }
    }
}

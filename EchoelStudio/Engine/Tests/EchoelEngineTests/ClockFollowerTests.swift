import EchoelCore
import XCTest
@testable import EchoelEngine

final class ClockFollowerTests: XCTestCase {
    func testTheTempoComesFromAQuarterOfPulsesAndIgnoresJitterAndPauses() {
        var follower = ClockFollower()
        let spacing = 0.5 / 24                         // 120 BPM
        var time = 0.0
        for n in 0..<24 {
            _ = follower.receive(status: 0xF8, at: time)
            time += spacing + (n % 2 == 0 ? 0.0004 : -0.0004)
        }
        XCTAssertNil(follower.tempo, "not before a full quarter of intervals")
        _ = follower.receive(status: 0xF8, at: time)
        XCTAssertEqual(follower.tempo ?? 0, 120, accuracy: 0.05)

        time += 3                                      // the sender paused
        _ = follower.receive(status: 0xF8, at: time)
        XCTAssertEqual(follower.tempo ?? 0, 120, accuracy: 0.05, "a pause is not a slow beat")
    }

    func testASenderThatReallySlowsDownIsFollowedAndNotTakenForAPause() {
        var follower = ClockFollower()
        var time = 0.0
        for _ in 0...24 {
            _ = follower.receive(status: 0xF8, at: time)
            time += 60 / (200 * 24)
        }
        XCTAssertEqual(follower.tempo ?? 0, 200, accuracy: 0.05)
        for _ in 0...30 {
            time += 60 / (45 * 24)                     // more than four times slower
            _ = follower.receive(status: 0xF8, at: time)
        }
        XCTAssertEqual(follower.tempo ?? 0, 45, accuracy: 0.05)
    }

    func testTransportMessagesBecomeActions() {
        var follower = ClockFollower()
        XCTAssertEqual(follower.receive(status: 0xFA, at: 0), .start)
        XCTAssertEqual(follower.receive(status: 0xFC, at: 1), .stop)
        XCTAssertEqual(follower.receive(status: 0xF2, 16, 1, at: 1), .position(16 + 128))
        XCTAssertEqual(follower.receive(status: 0xFB, at: 2), .resume)
        XCTAssertNil(follower.receive(status: 0xFE, at: 2), "active sensing is not transport")
    }

    func testTheFollowerKnowsWhereTheSendersSongStands() {
        var follower = ClockFollower()
        let spacing = 0.5 / 24
        XCTAssertNil(follower.position(at: 0), "nothing before a start")
        _ = follower.receive(status: 0xFA, at: 0)
        XCTAssertNil(follower.position(at: 0), "nor before the first pulse")
        var time = 0.01
        for _ in 0..<48 {                               // two quarters
            _ = follower.receive(status: 0xF8, at: time)
            time += spacing
        }
        let lastPulse = time - spacing
        let tick = Double(ClockFollower.ticksPerPulse)
        XCTAssertEqual(follower.position(at: lastPulse) ?? -1, 47 * tick, accuracy: 1e-9,
                       "the first pulse after a start is the top of the song")
        XCTAssertEqual(follower.position(at: lastPulse + spacing / 2) ?? -1, 47.5 * tick, accuracy: 0.01,
                       "between pulses it carries on at the tempo")
        XCTAssertEqual(follower.position(at: lastPulse + 10) ?? -1, 48 * tick, accuracy: 1e-9,
                       "but never more than one pulse past the last")

        _ = follower.receive(status: 0xFC, at: time)
        XCTAssertNil(follower.position(at: time), "stopped")
        _ = follower.receive(status: 0xFB, at: time)
        _ = follower.receive(status: 0xF8, at: time + 0.01)
        XCTAssertEqual(follower.position(at: time + 0.01) ?? -1, 48 * tick, accuracy: 1e-9, "continue goes on from the stop")

        _ = follower.receive(status: 0xFC, at: time + 1)
        _ = follower.receive(status: 0xF2, 8, 0, at: time + 1)    // sixteenth 8 = beat 3
        _ = follower.receive(status: 0xFB, at: time + 1)
        _ = follower.receive(status: 0xF8, at: time + 1.01)
        XCTAssertEqual(follower.position(at: time + 1.01) ?? -1, Double(2 * MusicalTime.ticksPerQuarter), accuracy: 1e-9,
                       "a song position is where the next pulse stands")
    }

    /// While a clock is followed, what the engine plays is the clock's tempo and none of the
    /// song's tempo changes — the map every placement and automation point is computed from.
    func testThePlayedSongCarriesTheClocksTempoAndNoneOfItsOwnChanges() throws {
        var song = Project(tempo: 100)
        try Command.setTempoChange(at: 3_840, bpm: 140).apply(to: &song)
        XCTAssertEqual(song.tempoMap.segments.count, 2)

        let played = ClockFollower.played(song, tempo: 123.45)
        XCTAssertEqual(played.tempo, 123.45)
        XCTAssertEqual(played.tempoChanges, [])
        XCTAssertEqual(played.tempoMap.segments.count, 1, "the clock is the one tempo")
        XCTAssertEqual(played.tempoMap.bpm(at: 7_680), 123.45, "also past the song's own change")
        XCTAssertEqual(song.tempo, 100, "the song itself is not written")
        XCTAssertEqual(song.tempoChanges.count, 1)

        let unknown = ClockFollower.played(song, tempo: nil)
        XCTAssertEqual(unknown.tempo, 100, "until the clock's tempo is known, the song's own tempo")
        XCTAssertEqual(unknown.tempoChanges, [], "but never its changes, which would run it off the clock")
        XCTAssertEqual(ClockFollower.played(song, tempo: .nan).tempo, 100)
        XCTAssertEqual(ClockFollower.played(song, tempo: .infinity).tempo, 100)
        XCTAssertEqual(ClockFollower.played(song, tempo: 1).tempo, Tempo.range.lowerBound)
        XCTAssertEqual(ClockFollower.played(song, tempo: 5_000).tempo, Tempo.range.upperBound)
    }
}

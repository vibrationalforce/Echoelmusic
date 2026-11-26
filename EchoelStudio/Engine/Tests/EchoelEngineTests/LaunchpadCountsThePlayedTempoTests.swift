import EchoelCore
import XCTest
@testable import EchoelEngine

/// The pads' flash limit counts the tempo our clock sends, which is the song as the engine plays
/// it: its fastest tempo change, or, while a clock is followed, the clock's tempo in place of the
/// song's own (`ClockFollower.played`). An unknown tempo anywhere counts as too fast.
final class LaunchpadCountsThePlayedTempoTests: XCTestCase {
    private func song(tempo: Double, changes: [Double]) -> Project {
        var tempoChanges: [TempoChange] = []
        for (index, bpm) in changes.enumerated() {
            tempoChanges.append(TempoChange(tick: Tick(1_920 * (index + 1)), bpm: bpm))
        }
        return Project(tempo: tempo, tempoChanges: tempoChanges)
    }

    func testTheFastestTempoOfTheSongCounts() {
        XCTAssertEqual(Launchpad.fastestBPM(of: song(tempo: 120, changes: [200, 90])), 200)
        XCTAssertEqual(Launchpad.fastestBPM(of: song(tempo: 150, changes: [])), 150)
    }

    func testAFollowedClockSetsTheTempoInPlaceOfTheSongs() {
        let fastSong = song(tempo: 120, changes: [200])
        XCTAssertEqual(Launchpad.fastestBPM(of: ClockFollower.played(fastSong, tempo: 150)), 150,
                       "the song's own changes are left out while a clock sets the pace")
        let followed = Launchpad.fastestBPM(of: ClockFollower.played(song(tempo: 120, changes: []), tempo: 200))
        XCTAssertEqual(followed, 200)
        XCTAssertFalse(Launchpad.animates(keptClockBPM: followed), "a 200 BPM clock sent on keeps the pads steady")
    }

    func testAnUnknownTempoAnywhereCountsAsTooFast() {
        XCTAssertTrue(Launchpad.fastestBPM(of: song(tempo: 120, changes: [.nan, 90])).isNaN)
        XCTAssertTrue(Launchpad.fastestBPM(of: song(tempo: .nan, changes: [90])).isNaN)
        let unknown = Launchpad.fastestBPM(of: song(tempo: 120, changes: [.nan]))
        XCTAssertFalse(Launchpad.animates(clockReachesDevice: true, fastestBPM: unknown))
    }
}

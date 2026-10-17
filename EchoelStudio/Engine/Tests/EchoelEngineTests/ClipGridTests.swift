import EchoelCore
import XCTest
@testable import EchoelEngine

final class ClipGridTests: XCTestCase {
    /// Ten instrument tracks and ten scenes; track t has a clip in scene t only.
    private func song() throws -> Project {
        var project = Project()
        for t in 0..<10 {
            try Command.addTrack(id: TrackID(), name: "T\(t)", kind: .instrument, index: nil).apply(to: &project)
        }
        try Command.addTrack(id: TrackID(), name: "Verb", kind: .returnTrack, index: nil).apply(to: &project)
        for s in 0..<10 { try Command.addScene(id: SceneID(), name: "S\(s)", index: nil).apply(to: &project) }
        for t in 0..<10 {
            let track = project.tracks[t].id, clip = ClipID()
            try Command.createClip(track: track, id: clip, name: "C", length: 1_920).apply(to: &project)
            try Command.setSlot(track: track, scene: project.scenes[t].id, clip: clip).apply(to: &project)
        }
        return project
    }

    func testTheGridShowsTracksAsColumnsAndScenesAsRowsWithTheirState() throws {
        let project = try song()
        let first = project.tracks[0], second = project.tracks[1]
        let grid = ClipGrid(project: project, playing: [first.id: first.clips[0].id],
                            queued: [second.id: second.clips[0].id], trackOffset: 0, sceneOffset: 0)
        XCTAssertEqual(grid.pads[0][0], .playing(color: first.colorIndex))
        XCTAssertEqual(grid.pads[1][1], .queued(color: second.colorIndex))
        XCTAssertEqual(grid.pads[2][2], .clip(color: project.tracks[2].colorIndex))
        XCTAssertEqual(grid.pads[0][1], .empty)
        XCTAssertEqual(grid.slot(column: 3, row: 5)?.track, project.tracks[3].id)
        XCTAssertEqual(grid.slot(column: 3, row: 5)?.scene, project.scenes[5].id)
        XCTAssertTrue(grid.canMoveRight && grid.canMoveDown)
        XCTAssertFalse(grid.canMoveLeft || grid.canMoveUp)
        XCTAssertFalse(grid.tracks.contains(project.tracks[10].id), "a return track has no clips to launch")
    }

    func testTheOffsetsStopWhereTheSongEnds() throws {
        let project = try song()
        let grid = ClipGrid(project: project, playing: [:], queued: [:], trackOffset: 50, sceneOffset: -3)
        XCTAssertEqual(grid.trackOffset, 2)
        XCTAssertEqual(grid.sceneOffset, 0)
        XCTAssertEqual(grid.tracks.first, project.tracks[2].id)
        XCTAssertFalse(grid.canMoveRight)

        let small = ClipGrid(project: Project(), playing: [:], queued: [:], trackOffset: 0, sceneOffset: 0)
        XCTAssertTrue(small.pads.allSatisfy { $0.allSatisfy { $0 == .off } })
        XCTAssertNil(small.slot(column: 0, row: 0))
    }

    func testALaunchpadPadIsItsNoteAndItsLightIsTheSameNoteBack() {
        XCTAssertEqual(Launchpad.press(status: 0x90, 81, 127), .pad(column: 0, row: 0), "top left")
        XCTAssertEqual(Launchpad.press(status: 0x90, 18, 100), .pad(column: 7, row: 7), "bottom right")
        XCTAssertNil(Launchpad.press(status: 0x90, 81, 0), "a release")
        XCTAssertEqual(Launchpad.press(status: 0xB0, 89, 127), .scene(row: 0))
        XCTAssertEqual(Launchpad.press(status: 0xB0, 19, 127), .scene(row: 7))
        XCTAssertEqual(Launchpad.press(status: 0xB0, 91, 127), .up)
        XCTAssertNil(Launchpad.press(status: 0xB0, 98, 127))
        XCTAssertNil(Launchpad.press(status: 0x90, 90, 127))

        XCTAssertEqual(Launchpad.model(named: "LPMiniMK3 MIDI"), .miniMK3)
        XCTAssertEqual(Launchpad.model(named: "Launchpad Pro MK3 LPProMK3 MIDI"), .proMK3)
        XCTAssertEqual(Launchpad.model(named: "LPX MIDI"), .x)
        XCTAssertNil(Launchpad.model(named: "LPMiniMK3 DAW"), "the DAW port is not ours")
        XCTAssertNil(Launchpad.model(named: "LPK25"))
        XCTAssertEqual(Launchpad.programmerMode(.miniMK3), [0xF0, 0x00, 0x20, 0x29, 0x02, 0x0D, 0x0E, 0x01, 0xF7])
    }

    func testOnlyChangedLightsAreSentAgain() throws {
        let project = try song()
        let first = project.tracks[0]
        let idle = ClipGrid(project: project, playing: [:], queued: [:], trackOffset: 0, sceneOffset: 0)
        let all = Launchpad.lights(idle, previous: nil)
        XCTAssertEqual(all.count, 64 + 8 + 4, "every pad, scene button and arrow")
        XCTAssertTrue(all.contains([0x90, 81, Launchpad.trackColors[first.colorIndex]]))
        XCTAssertTrue(all.contains([0x90, 82, 0]), "an empty slot is dark")

        let playing = ClipGrid(project: project, playing: [first.id: first.clips[0].id], queued: [:],
                               trackOffset: 0, sceneOffset: 0)
        XCTAssertEqual(Launchpad.lights(playing, previous: idle), [[0x92, 81, Launchpad.playingColor]], "pulsing")
        XCTAssertEqual(Launchpad.lights(playing, previous: playing), [])
    }

    func testMessagesBecomeUniversalMIDIPackets() {
        XCTAssertEqual(UniversalMIDI.packets([0x92, 81, 21]), [[0x2092_5115]])
        let sysex = UniversalMIDI.packets(Launchpad.programmerMode(.miniMK3))
        XCTAssertEqual(sysex.count, 2, "seven data bytes: six, then one")
        XCTAssertEqual(sysex[0], [0x3016_0020, 0x2902_0D0E])
        XCTAssertEqual(sysex[1], [0x3031_0100, 0x0000_0000])
        XCTAssertEqual(UniversalMIDI.packets([0xF0, 0x7E, 0xF7]), [[0x3001_7E00, 0]])
        XCTAssertEqual(UniversalMIDI.packets([0x40]), [], "a data byte alone is no message")
    }
}

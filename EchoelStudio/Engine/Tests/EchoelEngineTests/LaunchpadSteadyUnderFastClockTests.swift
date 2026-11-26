import EchoelCore
import XCTest
@testable import EchoelEngine

/// A Launchpad flashes a waiting pad and pulses a playing one on its own clock: its default tempo,
/// or the MIDI clock it is sent. When Echoelmusic sends it clock fast enough that one animation
/// cycle a beat would pass three a second (WCAG 2.3.1), the pads must stay steady and tell waiting
/// from playing by colour alone.
final class LaunchpadSteadyUnderFastClockTests: XCTestCase {
    private func song() throws -> (project: Project, track: TrackID, clip: ClipID) {
        var project = Project()
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "T", kind: .instrument, index: nil).apply(to: &project)
        try Command.addScene(id: SceneID(), name: "S", index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: 1_920).apply(to: &project)
        try Command.setSlot(track: track, scene: project.scenes[0].id, clip: clip).apply(to: &project)
        return (project, track, clip)
    }

    func testThePadsAnimateOnlyWhileTheClockCannotDriveThemPastThreeTimesASecond() {
        XCTAssertTrue(Launchpad.animates(clockReachesDevice: false, fastestBPM: 999),
                      "a device that never heard a clock keeps its own default tempo")
        XCTAssertTrue(Launchpad.animates(clockReachesDevice: true, fastestBPM: 120))
        XCTAssertTrue(Launchpad.animates(clockReachesDevice: true, fastestBPM: 180), "three a second is the limit")
        XCTAssertFalse(Launchpad.animates(clockReachesDevice: true, fastestBPM: 181))
        XCTAssertFalse(Launchpad.animates(clockReachesDevice: true, fastestBPM: 999))
        XCTAssertFalse(Launchpad.animates(clockReachesDevice: true, fastestBPM: .nan), "an unknown tempo is no proof")
        XCTAssertFalse(Launchpad.animates(clockReachesDevice: true, fastestBPM: .infinity))
    }

    func testSteadyPadsSendOnlyLitMessagesAndStillTellWaitingFromPlaying() throws {
        let s = try song()
        let queued = ClipGrid(project: s.project, playing: [:], queued: [s.track: s.clip], trackOffset: 0, sceneOffset: 0)
        let playing = ClipGrid(project: s.project, playing: [s.track: s.clip], queued: [:], trackOffset: 0, sceneOffset: 0)
        for grid in [queued, playing] {
            let messages: [[UInt8]] = Launchpad.lights(grid, previous: nil, animated: false)
            let notes: [[UInt8]] = messages.filter { (message: [UInt8]) -> Bool in
                guard let status = message.first else { return false }
                return status & 0xF0 == 0x90
            }
            XCTAssertFalse(notes.isEmpty)
            for message in notes {
                XCTAssertEqual(message.first, 0x90, "channel 1 only: lit, never flashing or pulsing")
            }
        }
        let waiting = Launchpad.lights(queued, previous: nil, animated: false).first { $0.count == 3 && $0[1] == 81 }
        let sounding = Launchpad.lights(playing, previous: nil, animated: false).first { $0.count == 3 && $0[1] == 81 }
        XCTAssertNotNil(waiting)
        XCTAssertNotEqual(waiting, sounding, "waiting and playing keep different colours")
        XCTAssertEqual(Launchpad.lights(playing, previous: nil, animated: true).first { $0.count == 3 && $0[1] == 81 },
                       [0x92, 81, Launchpad.playingColor], "animated as before when the clock allows it")
    }
}

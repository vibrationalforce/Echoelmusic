import EchoelCore
import XCTest
@testable import EchoelEngine

/// A Launchpad's pads must never be made to blink faster than 3 Hz (WCAG 2.3.1). The app refreshes
/// the lights every 40 ms (`LaunchpadController`, 25 Hz), so the one way our code could blink a pad
/// is by sending it different lights on successive frames. These tests hold that it never does: a
/// pad's light is sent once per change of its clip's state, and the waiting and playing animations
/// are the device's own (flashing and pulsing channels), not on/off messages from us.
final class LaunchpadLightRateTests: XCTestCase {
    private let framesPerSecond = 25

    private func song() throws -> (project: Project, track: TrackID, clip: ClipID) {
        var project = Project()
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "T", kind: .instrument, index: nil).apply(to: &project)
        try Command.addScene(id: SceneID(), name: "S", index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: 1_920).apply(to: &project)
        try Command.setSlot(track: track, scene: project.scenes[0].id, clip: clip).apply(to: &project)
        return (project, track, clip)
    }

    /// Ten seconds of the 25 Hz light loop: idle for one second, queued for half a second, then
    /// playing. Returns the messages each frame sent.
    private func run(_ s: (project: Project, track: TrackID, clip: ClipID)) -> [[[UInt8]]] {
        var shown: ClipGrid?
        var sent: [[[UInt8]]] = []
        for frame in 0..<(10 * framesPerSecond) {
            let queued: [TrackID: ClipID] = (25..<38).contains(frame) ? [s.track: s.clip] : [:]
            let playing: [TrackID: ClipID] = frame >= 38 ? [s.track: s.clip] : [:]
            let now = ClipGrid(project: s.project, playing: playing, queued: queued, trackOffset: 0, sceneOffset: 0)
            sent.append(Launchpad.lights(now, previous: shown))
            shown = now
        }
        return sent
    }

    func testAPadIsSentOncePerChangeOfItsClipNeverOnEveryFrame() throws {
        let sent = run(try song())
        let pad: UInt8 = 81                                   // top left: track 1, scene 1
        let padMessages = sent.dropFirst().flatMap { $0 }.filter { $0.count == 3 && $0[1] == pad && $0[0] & 0xF0 == 0x90 }
        XCTAssertEqual(padMessages, [[0x91, pad, Launchpad.playingColor], [0x92, pad, Launchpad.playingColor]],
                       "queued, then playing: two changes, two messages in ten seconds")
        let quietFrames = sent.dropFirst().filter(\.isEmpty).count
        XCTAssertEqual(quietFrames, 10 * framesPerSecond - 1 - 2, "every other frame sends nothing")
    }

    func testNoPadIsSwitchedOnAndOffByUsFasterThanThreeTimesASecond() throws {
        let sent = run(try song())
        // Per note, the frames on which a light was sent; within any one second at most three.
        var frames: [UInt8: [Int]] = [:]
        for (frame, messages) in sent.enumerated() where frame > 0 {
            for message in messages where message.count == 3 { frames[message[1], default: []].append(frame) }
        }
        for (note, at) in frames {
            for (index, first) in at.enumerated() {
                let inOneSecond = at[index...].prefix { $0 - first < framesPerSecond }.count
                XCTAssertLessThanOrEqual(inOneSecond, 3, "note \(note) changed \(inOneSecond) times in a second")
            }
        }
    }

    func testWaitingAndPlayingAreTheDevicesFlashAndPulseNotLightsWeAlternate() throws {
        let s = try song()
        let queued = ClipGrid(project: s.project, playing: [:], queued: [s.track: s.clip], trackOffset: 0, sceneOffset: 0)
        let playing = ClipGrid(project: s.project, playing: [s.track: s.clip], queued: [:], trackOffset: 0, sceneOffset: 0)
        let first = Launchpad.lights(queued, previous: nil)
        XCTAssertTrue(first.contains([0x91, 81, Launchpad.playingColor]), "channel 2: the device flashes it")
        XCTAssertEqual(Launchpad.lights(queued, previous: queued), [], "a waiting pad is not sent again")
        XCTAssertEqual(Launchpad.lights(playing, previous: queued), [[0x92, 81, Launchpad.playingColor]],
                       "channel 3: the device pulses it")
        XCTAssertEqual(Launchpad.lights(playing, previous: playing), [])
    }
}

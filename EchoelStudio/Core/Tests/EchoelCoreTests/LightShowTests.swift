import XCTest
@testable import EchoelCore

/// The light show (CUES): patching, the channel layout of every profile, the 16-bit position
/// words, fades, the flash limit on a strobing cue, and the render's determinism.
final class LightShowTests: XCTestCase {
    private func fixture(_ profile: FixtureProfile, universe: Int = 1, address: Int, name: String = "F") -> PatchedFixture {
        PatchedFixture(name: name, profile: profile, universe: universe, address: address)
    }

    // MARK: - Patch

    func testAnOverlappingPatchIsRefusedAndTheSongIsUntouched() throws {
        var project = Project()
        let head = fixture(.movingHead, address: 1, name: "Head")
        try Command.addFixture(head).apply(to: &project)
        let before = project
        // A dimmer on channel 8 lands on the head's blue.
        let clash = fixture(.dimmer, address: 8, name: "Par")
        XCTAssertNotNil(project.lighting.conflictMessage(for: clash))
        XCTAssertThrowsError(try Command.addFixture(clash).apply(to: &project))
        XCTAssertEqual(project, before)
        // The next channel is free, so is the same channel in another universe.
        try Command.addFixture(fixture(.dimmer, address: 9, name: "Par")).apply(to: &project)
        try Command.addFixture(fixture(.dimmer, universe: 2, address: 8, name: "Par 2")).apply(to: &project)
        XCTAssertEqual(project.lighting.fixtures.count, 3)
        // Moving the head onto the dimmer is refused; moving it onto its own channels is not.
        XCTAssertThrowsError(try Command.patchFixture(head.id, universe: 1, address: 2).apply(to: &project))
        try Command.patchFixture(head.id, universe: 1, address: 1).apply(to: &project)
        // A fixture that would run past channel 512 is refused, as is an unknown universe.
        XCTAssertThrowsError(try Command.addFixture(fixture(.rgb, address: 511)).apply(to: &project))
        XCTAssertThrowsError(try Command.addFixture(fixture(.rgb, universe: 0, address: 1)).apply(to: &project))
        XCTAssertEqual(project.lighting.freeAddress(for: .rgb, in: 1), 10)
    }

    func testRemovingAFixtureTakesItOutOfEveryCue() throws {
        var project = Project()
        let par = fixture(.dimmer, address: 1)
        try Command.addFixture(par).apply(to: &project)
        let cue = LightCue(name: "A", values: [CueFixtureValues(fixture: par.id, values: ["dimmer": 1])])
        try Command.addCue(cue, index: nil).apply(to: &project)
        try Command.placeCue(cue.id, at: 0).apply(to: &project)
        try Command.removeFixture(par.id).apply(to: &project)
        XCTAssertEqual(project.lighting.cues.first?.values, [])
        try Command.removeCue(cue.id).apply(to: &project)
        XCTAssertTrue(project.lighting.isEmpty, "removing a cue removes its places on the timeline")
        // A cue naming a fixture the rig lacks, or a value past 1, is refused.
        XCTAssertThrowsError(try Command.addCue(cue, index: nil).apply(to: &project))
        try Command.addFixture(par).apply(to: &project)
        XCTAssertThrowsError(try Command.addCue(cue.setting(.dimmer, of: par.id, to: 1.5), index: nil).apply(to: &project))
        XCTAssertThrowsError(try Command.addCue(LightCue(name: "B", fade: .nan), index: nil).apply(to: &project))
    }

    // MARK: - Layout

    func testEveryProfileLaysOutItsChannelsInOrder() {
        XCTAssertEqual(FixtureProfile.dimmer.layout, [.single(.dimmer)])
        XCTAssertEqual(FixtureProfile.rgb.layout, [.single(.red), .single(.green), .single(.blue)])
        XCTAssertEqual(FixtureProfile.rgbw.layout, [.single(.red), .single(.green), .single(.blue), .single(.white)])
        XCTAssertEqual(FixtureProfile.rgbaUV.layout,
                       [.single(.red), .single(.green), .single(.blue), .single(.amber), .single(.uv)])
        XCTAssertEqual(FixtureProfile.movingHead.layout,
                       [.coarse(.pan), .fine(.pan), .coarse(.tilt), .fine(.tilt), .single(.dimmer), .single(.red),
                        .single(.green), .single(.blue)])
        XCTAssertEqual(FixtureProfile.strobe.layout, [.single(.dimmer), .fixed(0)])
        XCTAssertEqual(FixtureProfile.allCases.map(\.footprint), [1, 3, 4, 5, 8, 2])
        XCTAssertEqual(FixtureProfile.movingHead.attributes, [.pan, .tilt, .dimmer, .red, .green, .blue])
    }

    func testTheRigWritesEachFixtureAtItsAddress() {
        let head = fixture(.movingHead, address: 10)
        let strobe = fixture(.strobe, address: 20)
        let other = fixture(.rgb, universe: 3, address: 1)
        let lighting = Lighting(fixtures: [head, strobe, other])
        var state = lighting.restState
        state[head.id] = [.pan: DMXWord.value(0x1234), .tilt: DMXWord.value(0xABCD), .dimmer: 1, .red: 0.5, .green: 0, .blue: 1]
        state[strobe.id] = [.dimmer: 1]
        let universes = lighting.universes(state)
        XCTAssertEqual(Set(universes.keys), [1, 3])
        let one = universes[1] ?? []
        XCTAssertEqual(one.count, 512)
        XCTAssertEqual(Array(one[9...16]), [0x12, 0x34, 0xAB, 0xCD, 255, 128, 0, 255])
        XCTAssertEqual(Array(one[19...20]), [255, 0], "the strobe's own rate stays off")
        XCTAssertEqual(one[8], 0)
        XCTAssertEqual(universes[3]?.prefix(3).map { $0 }, [0, 0, 0])
        // A head at rest points at its centre.
        let rest = lighting.universes(lighting.restState)[1] ?? []
        XCTAssertEqual(Array(rest[9...12]), [0x80, 0x00, 0x80, 0x00])
    }

    // MARK: - 16 bit

    func testA16BitWordSplitsAndJoins() {
        for word: UInt16 in [0, 1, 255, 256, 0x1234, 0x8000, 0xFFFE, 0xFFFF] {
            let (coarse, fine) = DMXWord.split(word)
            XCTAssertEqual(coarse, UInt8(word >> 8))
            XCTAssertEqual(fine, UInt8(word & 0xFF))
            XCTAssertEqual(DMXWord.join(coarse: coarse, fine: fine), word)
            XCTAssertEqual(DMXWord.word(DMXWord.value(word)), word)
        }
        XCTAssertEqual(DMXWord.word(.nan), 0)
        XCTAssertEqual(DMXWord.word(2), 0xFFFF)
    }

    func testPanAndTiltGlideOnThe16BitGrid() {
        // Half way from 0x0100 to 0x0200 is 0x0180 — a fine step an 8-bit fade would skip.
        XCTAssertEqual(DMXWord.interpolate(from: 0x0100, to: 0x0200, progress: 0.5), 0x0180)
        XCTAssertEqual(DMXWord.interpolate(from: 0xFFFF, to: 0, progress: 0.25), 0xBFFF)
        XCTAssertEqual(DMXWord.interpolate(from: 10, to: 20, progress: 2), 20)
        XCTAssertEqual(DMXWord.interpolate(from: 10, to: 20, progress: .nan), 20)
        // Every step of a slow pan moves the fine byte, not only the coarse one.
        var fines = Set<UInt8>()
        for step in 0...64 {
            let word = DMXWord.interpolate(from: 0x4000, to: 0x4040, progress: Double(step) / 64)
            fines.insert(DMXWord.split(word).fine)
            XCTAssertEqual(DMXWord.split(word).coarse, 0x40)
        }
        XCTAssertEqual(fines.count, 65)
    }

    // MARK: - Fades

    func testACueFadesLinearlyFromWhatWasShowing() {
        let par = fixture(.dimmer, address: 1)
        let head = fixture(.movingHead, address: 2)
        let a = LightCue(name: "A", fade: 0, values: [CueFixtureValues(fixture: par.id, values: ["dimmer": 0.2])])
        let b = LightCue(name: "B", fade: 2, values: [CueFixtureValues(fixture: par.id, values: ["dimmer": 1]),
                                                      CueFixtureValues(fixture: head.id, values: ["pan": 1])])
        // At 120 bpm one quarter is half a second: A at 0 s, B at 2 s.
        let lighting = Lighting(fixtures: [par, head], cues: [a, b],
                                placements: [CuePlacement(tick: 0, cue: a.id), CuePlacement(tick: 3_840, cue: b.id)])
        let map = Project(tempo: 120).tempoMap
        let dark = LightFixture.Look.dark
        func dimmer(_ seconds: Double) -> Double? {
            lighting.timelineTarget(atSeconds: seconds, tempoMap: map) { _ in dark }?[par.id]?[.dimmer]
        }
        XCTAssertEqual(dimmer(1) ?? -1, 0.2, accuracy: 1e-9)
        XCTAssertEqual(dimmer(2) ?? -1, 0.2, accuracy: 1e-9)
        XCTAssertEqual(dimmer(2.5) ?? -1, 0.4, accuracy: 1e-9)
        XCTAssertEqual(dimmer(3) ?? -1, 0.6, accuracy: 1e-9)
        XCTAssertEqual(dimmer(4) ?? -1, 1, accuracy: 1e-9)
        XCTAssertEqual(dimmer(9) ?? -1, 1, accuracy: 1e-9)
        let pan = lighting.timelineTarget(atSeconds: 3, tempoMap: map) { _ in dark }?[head.id]?[.pan] ?? -1
        XCTAssertEqual(DMXWord.word(pan), DMXWord.interpolate(from: 0x8000, to: 0xFFFF, progress: 0.5))
        // Before the first cue nothing is asked of the timeline.
        let late = Lighting(fixtures: [par], cues: [a], placements: [CuePlacement(tick: 960, cue: a.id)])
        XCTAssertNil(late.timelineTarget(atSeconds: 0.1, tempoMap: map) { _ in dark })
    }

    func testACueTakesOverAFadeFromWhereItStands() {
        let par = fixture(.dimmer, address: 1)
        let up = LightCue(name: "Up", fade: 4, values: [CueFixtureValues(fixture: par.id, values: ["dimmer": 1])])
        let down = LightCue(name: "Down", fade: 1, values: [CueFixtureValues(fixture: par.id, values: ["dimmer": 0])])
        // Up from 0 s over 4 s, Down at 1 s: it starts from 0.25.
        let lighting = Lighting(fixtures: [par], cues: [up, down],
                                placements: [CuePlacement(tick: 0, cue: up.id), CuePlacement(tick: 1_920, cue: down.id)])
        let map = Project(tempo: 120).tempoMap
        let value = lighting.timelineTarget(atSeconds: 1.5, tempoMap: map) { _ in .dark }?[par.id]?[.dimmer] ?? -1
        XCTAssertEqual(value, 0.125, accuracy: 1e-9)
    }

    func testASongLookCueLightsFromTheSong() {
        let rgb = fixture(.rgb, address: 1)
        let head = fixture(.movingHead, address: 4)
        let cue = LightCue(name: "Song", look: LightCue.songLook,
                           values: [CueFixtureValues(fixture: head.id, values: ["pan": 0.1, "red": 0])])
        let lighting = Lighting(fixtures: [rgb, head], cues: [cue])
        let look = LightFixture.Look(dimmer: 0.5, red: 1, green: 0.5, blue: 0)
        let state = lighting.target(of: cue, songLook: look)
        XCTAssertEqual(state[rgb.id]?[.red], 0.5, "a fixture without a dimmer takes the colour scaled")
        XCTAssertEqual(state[rgb.id]?[.green], 0.25)
        XCTAssertEqual(state[head.id]?[.dimmer], 0.5)
        XCTAssertEqual(state[head.id]?[.red], 1, "the song's colour wins over the snapshot's")
        XCTAssertEqual(state[head.id]?[.pan], 0.1, "the position stays the cue's")
    }

    // MARK: - Flash limit

    /// A strobe cue pair placed every eighth note at 240 bpm (eight changes a second) and a GO
    /// hammered at the same rate: what reaches the wire never swings by a flash step faster than
    /// three times a second.
    func testAStrobingCueNeverFlashesFasterThanThreeTimesASecond() {
        let strobe = fixture(.strobe, address: 1)
        let on = LightCue(name: "On", values: [CueFixtureValues(fixture: strobe.id, values: ["dimmer": 1])])
        let off = LightCue(name: "Off", values: [CueFixtureValues(fixture: strobe.id, values: ["dimmer": 0])])
        var placements: [CuePlacement] = []
        for step in 0..<80 { placements.append(CuePlacement(tick: Tick(step * 480), cue: step % 2 == 0 ? on.id : off.id)) }
        var project = Project(tempo: 240)
        project.lighting = Lighting(fixtures: [strobe], cues: [on, off], placements: placements)
        let rate = 100.0
        let frames = LightShowRender.frames(of: project, duration: 10, frameRate: rate)
        let values: [Double] = frames.map { Double($0.universes[1]?[0] ?? 0) / 255 }
        XCTAssertGreaterThan(values.max() ?? 0, 0.05, "the strobe does light")
        // Count flashes as swings of at least the flash step between turning points.
        var flashes: [Double] = []
        var anchor = values.first ?? 0, rising = true, extreme = anchor
        for (index, value) in values.enumerated() {
            if rising {
                if value > extreme { extreme = value }
                if extreme - value >= FlashLimit.flashStep && extreme - anchor >= FlashLimit.flashStep {
                    flashes.append(Double(index) / rate); anchor = extreme; extreme = value; rising = false
                }
            } else {
                if value < extreme { extreme = value }
                if value - extreme >= FlashLimit.flashStep { anchor = extreme; extreme = value; rising = true }
            }
        }
        for start in stride(from: 0.0, to: 9.0, by: 0.1) {
            let inSecond = flashes.filter { $0 >= start && $0 < start + 1 }.count
            XCTAssertLessThanOrEqual(inSecond, 3, "more than three flashes in the second from \(start)")
        }
        // And between two frames no channel moves more than the limit's rate allows (one byte of rounding).
        for (a, b) in zip(values, values.dropFirst()) {
            XCTAssertLessThanOrEqual(abs(b - a), FlashLimit.maximumRate / rate + 1.0 / 255 + 1e-9)
        }
    }

    func testTheGuardLeavesPositionAloneAndSlowsTheLight() {
        let head = fixture(.movingHead, address: 1)
        var guardRail = RigFlashGuard()
        let target: RigState = [head.id: [.pan: 1, .tilt: 0, .dimmer: 1, .red: 1, .green: 1, .blue: 1]]
        let next = guardRail.next(towards: target, after: 0.1)
        XCTAssertEqual(next[head.id]?[.pan], 1)
        XCTAssertEqual(next[head.id]?[.tilt], 0)
        XCTAssertEqual(next[head.id]?[.dimmer] ?? -1, FlashLimit.maximumRate * 0.1, accuracy: 1e-9)
        let dark = RigFlashGuard.dark(target)
        XCTAssertEqual(dark[head.id]?[.dimmer], 0)
        XCTAssertEqual(dark[head.id]?[.pan], 1)
    }

    /// When the app lets go of the rig, every light goes to 0 where it stands: the frame a node
    /// keeps holding lights nothing, and no head swings back to its centre on the way.
    func testTheFrameLeftBehindLightsNothingAndHoldsPosition() {
        let head = fixture(.movingHead, address: 1)
        let lighting = Lighting(fixtures: [head])
        let lit: RigState = [head.id: [.pan: 0.8, .tilt: 0.3, .dimmer: 1, .red: 1, .green: 0.5, .blue: 1]]
        let still: RigState = [head.id: [.pan: 0.8, .tilt: 0.3, .dimmer: 0, .red: 0, .green: 0, .blue: 0]]
        XCTAssertEqual(lighting.leavingUniverses(from: lit), lighting.universes(still))
        XCTAssertNotEqual(lighting.leavingUniverses(from: lit), lighting.universes(lit))
        XCTAssertEqual(lighting.leavingUniverses(from: nil), lighting.universes(lighting.restState), "before any frame, at rest")
    }

    // MARK: - Determinism

    func testTheSameSongAlwaysRendersTheSameDMX() throws {
        var project = Project(tempo: 97)
        project.context.root = 7
        let head = fixture(.movingHead, address: 1)
        let wash = fixture(.rgbaUV, universe: 2, address: 100)
        let a = LightCue(name: "A", fade: 1.5, values: [CueFixtureValues(fixture: head.id, values: ["pan": 0.9, "tilt": 0.1, "dimmer": 1]),
                                                        CueFixtureValues(fixture: wash.id, values: ["uv": 1, "amber": 0.3])])
        let b = LightCue(name: "B", fade: 3, look: LightCue.songLook)
        project.lighting = Lighting(fixtures: [head, wash], cues: [a, b],
                                    placements: [CuePlacement(tick: 480, cue: a.id), CuePlacement(tick: 7_680, cue: b.id)])
        let reopened = try ProjectCodec.decode(ProjectCodec.encode(project))
        let duration = LightShowRender.duration(of: project)
        XCTAssertGreaterThan(duration, 5)
        let first = LightShowRender.frames(of: project, duration: duration)
        let second = LightShowRender.frames(of: reopened, duration: duration)
        XCTAssertEqual(first, second)
        XCTAssertEqual(LightShowRender.csv(first), LightShowRender.csv(second))
        XCTAssertEqual(first.count, Int(duration * LightShowRender.defaultFrameRate) + 1)
        XCTAssertTrue(LightShowRender.csv(first).hasPrefix("seconds,universe,channel,value\n"))
        // Something moved, in both universes.
        XCTAssertNotEqual(first.first?.universes[1], first.last?.universes[1])
        XCTAssertNotEqual(first.first?.universes[2], first.last?.universes[2])
        XCTAssertEqual(LightShowRender.frames(of: Project(), duration: 3), [], "no rig, no frames")
    }
}

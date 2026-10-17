import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelEngine

final class EngineCoreTests: XCTestCase {
    private let rate = 48_000.0
    private let bar = MusicalTime.ticksPerBar(.common)
    private var generation: UInt64 = 0

    private struct Song {
        var project: Project
        var tracks: [TrackID]
    }

    /// One instrument track per note list, each with one clip placed at 0.
    private func song(_ noteLists: [[Note]], tempo: Double = 120) throws -> Song {
        var project = Project(tempo: tempo)
        var ids: [TrackID] = []
        for (n, notes) in noteLists.enumerated() {
            let track = TrackID(), clip = ClipID()
            try Command.addTrack(id: track, name: "T\(n)", kind: .instrument, index: nil).apply(to: &project)
            try Command.createClip(track: track, id: clip, name: "C", length: 8 * bar).apply(to: &project)
            if !notes.isEmpty { try Command.addNotes(clip, notes).apply(to: &project) }
            try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
            ids.append(track)
        }
        return Song(project: project, tracks: ids)
    }

    private func publish(_ project: Project, to core: EngineCore) {
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        generation += 1
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project,
                                    slots: slots.slots, sampleRate: rate, generation: generation))
    }

    private func render(_ core: EngineCore, frames: Int, block: Int = 256) -> (left: [Float], right: [Float]) {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let n = Swift.min(block, frames - start)
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    core.render(frameCount: n, left: lp + start, right: rp + start)
                }
            }
            start += n
        }
        return (left, right)
    }

    private func firstSound(_ samples: [Float]) -> Int? {
        samples.firstIndex { Swift.abs($0) > 1e-6 }
    }

    private func core() -> EngineCore {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        return core
    }

    func testANoteStartsOnItsSample() throws {
        let s = try song([[Note(pitch: 60, start: 960, length: 960)]])
        let core = core()
        publish(s.project, to: core)
        core.play()
        let out = render(core, frames: 48_000)
        // Beat 2 at 120 BPM is 0.5 s = sample 24 000; a saw starts at zero, so allow two samples.
        let first = try XCTUnwrap(firstSound(out.left))
        XCTAssertTrue((24_000...24_002).contains(first), "\(first)")
    }

    func testTheOutputDoesNotDependOnTheBlockSize() throws {
        let notes = [Note(pitch: 48, start: 0, length: 700), Note(pitch: 55, start: 333, length: 2_000),
                     Note(pitch: 62, start: 1_920, length: 480)]
        var outputs: [[Float]] = []
        for block in [64, 256, 1_000, 4_096] {
            let s = try song([notes])
            let core = core()
            publish(s.project, to: core)
            core.play()
            outputs.append(render(core, frames: 72_000, block: block).left)
        }
        for other in outputs.dropFirst() {
            XCTAssertEqual(other, outputs[0])
        }
    }

    func testNothingPlaysUntilPlayAndStopRewinds() throws {
        let s = try song([[Note(pitch: 60, start: 0, length: 9_600)]])
        let core = core()
        publish(s.project, to: core)
        XCTAssertNil(firstSound(render(core, frames: 4_800).left))
        XCTAssertEqual(core.positionSample, 0)
        core.play()
        _ = render(core, frames: 4_800)
        XCTAssertEqual(core.positionSample, 4_800)
        core.stop()
        _ = render(core, frames: 48_000)               // the release rings out
        XCTAssertEqual(core.positionSample, 0)
        XCTAssertNil(firstSound(render(core, frames: 4_800).left))
    }

    func testMuteSoloAndPanShapeTheMix() throws {
        var s = try song([[Note(pitch: 60, start: 0, length: 9_600)], [Note(pitch: 67, start: 0, length: 9_600)]])
        let core = core()

        try Command.setMute(s.tracks[0], true).apply(to: &s.project)
        try Command.setMute(s.tracks[1], true).apply(to: &s.project)
        publish(s.project, to: core)
        core.play()
        XCTAssertNil(firstSound(render(core, frames: 9_600).left), "both muted")

        try Command.setMute(s.tracks[0], false).apply(to: &s.project)
        try Command.setMute(s.tracks[1], false).apply(to: &s.project)
        try Command.setSolo(s.tracks[0], true).apply(to: &s.project)
        try Command.setPan(.track(s.tracks[0]), pan: -1).apply(to: &s.project)
        core.stop()
        publish(s.project, to: core)
        core.play()
        let out = render(core, frames: 9_600)
        XCTAssertNotNil(firstSound(out.left), "the solo plays")
        XCTAssertNil(firstSound(out.right), "hard left, and the other track is not soloed")
    }

    func testANoteAfterATempoChangeLandsWhereTheMapSays() throws {
        var s = try song([[Note(pitch: 60, start: bar + 960, length: 480)]])
        try Command.setTempoChange(at: bar, bpm: 60).apply(to: &s.project)
        let core = core()
        publish(s.project, to: core)
        core.play()
        let out = render(core, frames: 160_000)
        // One bar at 120 (2 s = 96 000) plus one quarter at 60 (1 s = 48 000).
        let first = try XCTUnwrap(firstSound(out.left))
        XCTAssertTrue((144_000...144_002).contains(first), "\(first)")
    }

    func testTheClickFallsOnTheBeatsAndAccentsTheDownbeat() throws {
        let s = try song([[]])
        let core = EngineCore(sampleRate: rate)
        publish(s.project, to: core)
        core.play()
        let out = render(core, frames: 96_000).left
        func energy(_ range: Range<Int>) -> Float { out[range].reduce(0) { $0 + $1 * $1 } }
        XCTAssertGreaterThan(energy(0..<1_440), 1)
        XCTAssertGreaterThan(energy(24_000..<25_440), 0.1)
        XCTAssertEqual(energy(12_000..<23_990), 0)
        XCTAssertGreaterThan(energy(0..<1_440), energy(24_000..<25_440))
    }

    func testEditingWhilePlayingKeepsTimeAndNeverHangsANote() throws {
        var s = try song([[Note(pitch: 60, start: 0, length: 8 * bar)]])
        let core = core()
        publish(s.project, to: core)
        core.play()
        _ = render(core, frames: 24_000)
        // Delete the sounding note mid-way: it must release, and time must run on.
        let clip = try XCTUnwrap(s.project.tracks[0].clips.first)
        try Command.removeNotes(clip.id, clip.notes.map(\.id)).apply(to: &s.project)
        publish(s.project, to: core)
        _ = render(core, frames: 48_000)
        XCTAssertEqual(core.positionSample, 72_000)
        XCTAssertNil(firstSound(render(core, frames: 4_800).left))
    }

    func testFaderGainsFollowTheMixerLaw() {
        XCTAssertEqual(EngineSnapshot.linear(MixerStrip.volumeRange.lowerBound), 0)
        XCTAssertEqual(EngineSnapshot.linear(0), 1, accuracy: 1e-6)
        XCTAssertEqual(EngineSnapshot.linear(-6), 0.501, accuracy: 1e-3)
        XCTAssertEqual(EngineSnapshot.linear(.nan), 0)
        let (l, r) = EngineSnapshot.gains(track: MixerStrip(), master: MixerStrip())
        XCTAssertEqual(l, r, accuracy: 1e-6)
        XCTAssertEqual(l * l + r * r, 1, accuracy: 1e-5)   // constant power
    }

    func testSlotsStayWithTheirTrackAndAreReused() throws {
        var project = Project()
        let a = TrackID(), b = TrackID(), c = TrackID()
        for id in [a, b] { try Command.addTrack(id: id, name: "x", kind: .instrument, index: nil).apply(to: &project) }
        try Command.addTrack(id: TrackID(), name: "audio", kind: .audio, index: nil).apply(to: &project)
        var slots = SlotAssigner(capacity: 2)
        slots.update(for: project)
        let slotB = slots.slots[b]
        XCTAssertEqual(slots.slots.count, 2)

        try Command.removeTrack(a).apply(to: &project)
        try Command.addTrack(id: c, name: "y", kind: .instrument, index: 0).apply(to: &project)
        slots.update(for: project)
        XCTAssertEqual(slots.slots[b], slotB)
        XCTAssertNotNil(slots.slots[c])
        XCTAssertNotEqual(slots.slots[c], slotB)

        try Command.addTrack(id: TrackID(), name: "z", kind: .instrument, index: nil).apply(to: &project)
        slots.update(for: project)
        XCTAssertEqual(slots.slots.count, 2, "beyond capacity a track gets no slot")
    }

    func testADrumTrackPlaysTheKitAndOnlyKitNotes() throws {
        // Kick on the downbeat; middle C is not in the drum map and must stay silent.
        var s = try song([[Note(pitch: 36, start: 0, length: 240), Note(pitch: 60, start: bar, length: 240)]])
        try Command.setInstrumentDevice(s.tracks[0], .drums).apply(to: &s.project)
        let engine = core()
        publish(s.project, to: engine)
        engine.play()
        let beat = Int(rate / 2)
        let out = render(engine, frames: 8 * beat)
        XCTAssertEqual(firstSound(out.left), 0, "the kick starts on its sample")
        let kick = out.left[0..<beat].reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }
        XCTAssertGreaterThan(kick, 0.05)
        // The kick has died away (−60 dB) by 2.3 s; bar 2 from 2 s holds only a C.
        let afterKickTail = out.left[(5 * beat)...].reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }
        XCTAssertEqual(afterKickTail, 0, "the kit ignores a note outside the drum map")
    }

    func testSwitchingTheInstrumentChangesTheSoundOfTheSameNotes() throws {
        var s = try song([[Note(pitch: 38, start: 0, length: 960)]])
        let synth = core()
        publish(s.project, to: synth)
        synth.play()
        let synthOut = render(synth, frames: 9_600).left
        try Command.setInstrumentDevice(s.tracks[0], .drums).apply(to: &s.project)
        let drums = core()
        publish(s.project, to: drums)
        drums.play()
        let drumOut = render(drums, frames: 9_600).left
        XCTAssertNotNil(firstSound(drumOut))
        XCTAssertNotEqual(synthOut, drumOut)
    }
}

final class InstrumentPatchTests: XCTestCase {
    func testTheDefaultSettingsGiveTheDefaultSoundAndAPresetChangesIt() throws {
        let initial = SynthPatch(InstrumentSettings())
        XCTAssertEqual(initial.waveform, .saw)
        XCTAssertEqual(initial.cutoff, 800)
        let preset = try XCTUnwrap(InstrumentPreset.named("Sub Bass"))
        let bass = SynthPatch(InstrumentSettings(preset: preset.name, values: preset.values))
        XCTAssertEqual(bass.waveform, .sine)
        XCTAssertEqual(bass.cutoff, 300)
        XCTAssertNotEqual(bass, initial)
    }

    func testEachTrackPlaysItsOwnSound() throws {
        var project = Project()
        let a = TrackID(), b = TrackID()
        for (id, preset) in [(a, "Sub Bass"), (b, "Square Lead")] {
            let clip = ClipID()
            try Command.addTrack(id: id, name: preset, kind: .instrument, index: nil).apply(to: &project)
            try Command.loadInstrumentPreset(id, name: preset).apply(to: &project)
            try Command.createClip(track: id, id: clip, name: "C", length: 3_840).apply(to: &project)
            try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 960)]).apply(to: &project)
            try Command.placeClip(track: id, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        }
        let snapshot = EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project,
                                      slots: { var s = SlotAssigner(capacity: 4); s.update(for: project); return s.slots }(),
                                      sampleRate: 48_000, generation: 1)
        XCTAssertEqual(snapshot.lanes.map(\.patch.waveform), [.sine, .square])
    }
}

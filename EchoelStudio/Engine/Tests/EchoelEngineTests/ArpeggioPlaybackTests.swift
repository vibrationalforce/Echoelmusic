import EchoelCore
import XCTest
@testable import EchoelEngine

/// The arpeggiator in the engine (EDIT-2): a clip arpeggiates live as in the export, keys played
/// live arpeggiate on the same steps as the same notes in a clip, on the song's grid through a
/// tempo ramp, and on their own clock while the song is stopped.
final class ArpeggioPlaybackTests: XCTestCase {
    private let rate = 48_000.0
    private let q = MusicalTime.ticksPerQuarter
    private var generation: UInt64 = 0

    private func project(notes: [Note], arpeggio: Arpeggio, tempo: Double = 120) throws -> (Project, TrackID) {
        var project = Project(tempo: tempo)
        let track = TrackID(), clip = ClipID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "C", length: 8 * q).apply(to: &project)
        if !notes.isEmpty { try Command.addNotes(clip, notes).apply(to: &project) }
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        try Command.setArpeggio(track, arpeggio).apply(to: &project)
        return (project, track)
    }

    private func engine(for project: Project) -> (EngineCore, Int) {
        let core = EngineCore(sampleRate: rate)
        core.setClickEnabled(false)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: project)
        generation += 1
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: project), project: project, slots: slots.slots,
                                    sampleRate: rate, generation: generation))
        let slot = project.tracks.first.flatMap { slots.slots[$0.id] } ?? 0
        core.setNoteOut(slot: slot)
        return (core, slot)
    }

    private func render(_ core: EngineCore, frames: Int, block: Int = 256) -> [Float] {
        var left = [Float](repeating: 0, count: frames), right = [Float](repeating: 0, count: frames)
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
        return left
    }

    /// The note-ons the slot played, as (absolute frame, pitch), rendering `frames` in blocks.
    private func noteOns(_ core: EngineCore, frames: Int, block: Int = 256) -> [[Int]] {
        var heard: [[Int]] = []
        var done = 0
        while done < frames {
            let n = Swift.min(block, frames - done)
            _ = render(core, frames: n, block: n)
            while let message = core.noteOut.pop() {
                guard message.status == 0x90, message.data2 > 0 else { continue }
                heard.append([done + message.frame, Int(message.data1)])
            }
            done += n
        }
        return heard
    }

    private let chord = [Note(pitch: 60, start: 0, length: 3_840), Note(pitch: 64, start: 0, length: 3_840),
                         Note(pitch: 67, start: 0, length: 3_840)]

    /// A key's release lost in a full live ring does not leave an arpeggiating track stepping on:
    /// the phrase ends with everything else.
    func testAnArpeggioWhoseKeysReleaseWasLostInAFullRingStops() throws {
        let (empty, _) = try project(notes: [], arpeggio: Arpeggio(rate: .quarter, order: .up))
        let (core, slot) = engine(for: empty)
        core.playLive(slot: slot, status: 0x90, 60, 100)
        core.play()
        XCTAssertFalse(noteOns(core, frames: 48_000).isEmpty, "the phrase steps")
        for step in 0..<1_100 { core.playLive(slot: slot, status: 0xB0, 1, UInt8(step % 128)) }
        core.playLive(slot: slot, status: 0x80, 60, 0)
        _ = noteOns(core, frames: 256)
        XCTAssertTrue(noteOns(core, frames: 96_000).isEmpty, "no step after the lost release")
    }

    /// Keys held live into an arpeggiating track play on through the song loop's wrap: the pass
    /// after it steps on the same samples as the first, from the loop's start. A quarter at 120 BPM
    /// is 24,000 samples, the one-bar loop 96,000.
    func testKeysArpeggiatedLiveKeepPlayingInThePassAfterAWrap() throws {
        let (empty, _) = try project(notes: [], arpeggio: Arpeggio(rate: .quarter, order: .up))
        let (core, slot) = engine(for: empty)
        core.setLoop(0..<(4 * q))
        for pitch: UInt8 in [60, 64] { core.playLive(slot: slot, status: 0x90, pitch, 100) }
        core.play()
        let heard = noteOns(core, frames: 192_000)
        let first: [Int] = heard.filter { $0[0] < 96_000 }.map { $0[0] }
        let second: [Int] = heard.filter { $0[0] >= 96_000 }.map { $0[0] - 96_000 }
        XCTAssertEqual(first, [0, 24_000, 48_000, 72_000], "a bar of quarters")
        XCTAssertEqual(second, first, "the pass after the wrap steps as the first did")
    }

    func testAnArpeggiatedClipPlaysLiveAsItExports() throws {
        let (song, _) = try project(notes: chord, arpeggio: Arpeggio(rate: .eighthTriplet, order: .upDown, octaves: 2, gate: 0.7))
        let export = OfflineRender.render(song, sampleRate: rate, tailSeconds: 0, ringOutSeconds: 0)
        let (core, _) = engine(for: song)
        core.play()
        let played = render(core, frames: export.left.count, block: 333)
        XCTAssertGreaterThan(export.left.map(abs).max() ?? 0, 0.01, "the export sounds")
        for i in 0..<export.left.count where abs(export.left[i] - played[i]) > 1e-6 {
            XCTFail("sample \(i) differs: \(export.left[i]) vs \(played[i])")
            break
        }
    }

    func testKeysPlayedLiveFallOnTheStepsOfTheSameNotesInAClip() throws {
        let arp = Arpeggio(rate: .sixteenth, order: .up, gate: 0.5)
        let (clipSong, _) = try project(notes: chord, arpeggio: arp)
        let (clipCore, _) = engine(for: clipSong)
        clipCore.play()
        let fromClip = noteOns(clipCore, frames: 96_000)

        let (empty, _) = try project(notes: [], arpeggio: arp)
        let (liveCore, slot) = engine(for: empty)
        for pitch: UInt8 in [60, 64, 67] { liveCore.playLive(slot: slot, status: 0x90, pitch, 100) }
        liveCore.play()
        let fromKeys = noteOns(liveCore, frames: 96_000)
        XCTAssertEqual(fromClip.count, 16, "two bars of sixteenths at 120 BPM in two seconds")
        XCTAssertEqual(fromKeys, fromClip, "the same steps, sample for sample")
        XCTAssertEqual(fromKeys.prefix(4).map { $0[1] }, [60, 64, 67, 60])
        XCTAssertEqual(fromKeys.prefix(3).map { $0[0] }, [0, 6_000, 12_000])

        for pitch: UInt8 in [60, 64, 67] { liveCore.playLive(slot: slot, status: 0x80, pitch, 0) }
        _ = noteOns(liveCore, frames: 12_000)
        XCTAssertEqual(noteOns(liveCore, frames: 24_000), [], "let go, the phrase ends")
    }

    func testTheStepsFollowATempoRampOnTheSongsGrid() throws {
        var (song, _) = try project(notes: chord, arpeggio: Arpeggio(rate: .eighth))
        try Command.setTempoChange(at: 2 * q, bpm: 180).apply(to: &song)
        try Command.setTempoCurve(at: 2 * q, curve: .linear).apply(to: &song)
        let (core, _) = engine(for: song)
        core.play()
        let heard = noteOns(core, frames: 96_000, block: 128)
        let time = TimeConversion(tempoMap: song.tempoMap, sampleRate: rate)
        let expected = (0..<heard.count).map { (step: Int) -> Int in Int(time.sample(at: Tick(step) * q / 2)) }
        XCTAssertEqual(heard.count, 8, "a bar of eighths")
        XCTAssertEqual(heard.map { $0[0] }, expected, "every step on its tick's sample, through the ramp")
    }

    func testKeysArpeggiateWhileStoppedAndAllNotesOffEndsThePhrase() throws {
        let (empty, _) = try project(notes: [], arpeggio: Arpeggio(rate: .quarter, order: .down))
        let (core, slot) = engine(for: empty)
        _ = render(core, frames: 256)
        core.playLive(slot: slot, status: 0x90, 48, 90)
        core.playLive(slot: slot, status: 0x90, 55, 90)
        let heard = noteOns(core, frames: 48_000)
        // A quarter at 120 BPM is 24 000 samples: steps at 0 and 24 000, high key first.
        XCTAssertEqual(heard.map { $0[1] }, [55, 48])
        XCTAssertEqual(heard.map { $0[0] }, [0, 24_000])
        core.playLive(slot: slot, status: 0xB0, 123, 0)
        XCTAssertEqual(noteOns(core, frames: 72_000), [], "all notes off ends it")
    }

    func testLatchKeepsPlayingAfterTheKeysAreReleased() throws {
        let (empty, _) = try project(notes: [], arpeggio: Arpeggio(rate: .quarter, latch: true))
        let (core, slot) = engine(for: empty)
        _ = render(core, frames: 256)
        core.playLive(slot: slot, status: 0x90, 60, 90)
        core.playLive(slot: slot, status: 0x80, 60, 0)
        XCTAssertEqual(noteOns(core, frames: 72_000).count, 3, "held by the latch")
        var off = Arpeggio(rate: .quarter, latch: true)
        off.isOn = false
        var song = empty
        try Command.setArpeggio(try XCTUnwrap(song.tracks.first?.id), off).apply(to: &song)
        var slots = SlotAssigner(capacity: core.slotCapacity)
        slots.update(for: song)
        generation += 1
        core.publish(EngineSnapshot(plan: PlaybackPlan(compiling: song), project: song, slots: slots.slots,
                                    sampleRate: rate, generation: generation))
        XCTAssertEqual(noteOns(core, frames: 72_000), [], "switched off, it lets go")
        core.playLive(slot: slot, status: 0x90, 62, 90)
        XCTAssertEqual(noteOns(core, frames: 256).map { $0[1] }, [62], "a key plays as itself again")
    }
}

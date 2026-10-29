import XCTest
@testable import EchoelCore

/// `generateLoopFromVibe` is the One-door for the Loop Generator (wave W11.1d). It goes through
/// the same validation as `addNotes`, works only on MIDI clips, and leaves the project untouched
/// when a precondition fails.
final class GenerateLoopFromVibeCommandTests: XCTestCase {

    private func makeMidiClip() throws -> (Project, TrackID, ClipID) {
        var project = Project()
        let track = TrackID()
        let clip = ClipID()
        try Command.addTrack(id: track, name: "Beat", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "Loop",
                               length: MusicalTime.ticksPerBar(.common)).apply(to: &project)
        return (project, track, clip)
    }

    private var vibe: VibeParameters {
        VibeParameters(genre: .hipHop, energy: 0.6, density: 0.5, brightness: 0.5,
                       targetBPM: 90, targetKeyRoot: 0, targetScale: .minor)
    }

    func testApplyAddsDrumsNotesToTheClip() throws {
        var (project, track, clip) = try makeMidiClip()
        try Command.generateLoopFromVibe(clip, vibe: vibe, seed: 42, role: .drums, bars: 1).apply(to: &project)
        let notes = project.tracks.first(where: { $0.id == track })?.clips.first(where: { $0.id == clip })?.notes ?? []
        XCTAssertFalse(notes.isEmpty)
        XCTAssertTrue(notes.contains(where: { $0.pitch == 36 }))
    }

    func testApplyIsDeterministic() throws {
        var (projectA, _, clipA) = try makeMidiClip()
        var (projectB, _, clipB) = try makeMidiClip()
        try Command.generateLoopFromVibe(clipA, vibe: vibe, seed: 7, role: .bass, bars: 1).apply(to: &projectA)
        try Command.generateLoopFromVibe(clipB, vibe: vibe, seed: 7, role: .bass, bars: 1).apply(to: &projectB)
        let a = projectA.tracks.flatMap(\.clips).flatMap(\.notes).map { [$0.pitch, Int($0.start), Int($0.length), $0.velocity] }
        let b = projectB.tracks.flatMap(\.clips).flatMap(\.notes).map { [$0.pitch, Int($0.start), Int($0.length), $0.velocity] }
        XCTAssertEqual(a, b)
    }

    func testApplyRejectsAnAudioClip() throws {
        var project = Project()
        let track = TrackID()
        let clip = ClipID()
        try Command.addTrack(id: track, name: "Audio", kind: .audio, index: nil).apply(to: &project)
        let media = MediaFile(id: MediaID(), name: "x.wav", path: "x.wav", frameCount: 48_000, sampleRate: 48_000)
        try Command.addMedia(media).apply(to: &project)
        try Command.createAudioClip(track: track, id: clip, name: "Clip",
                                    length: MusicalTime.ticksPerBar(.common),
                                    audio: ClipAudio(media: media.id, offset: 0, length: 48_000)).apply(to: &project)
        XCTAssertThrowsError(try Command.generateLoopFromVibe(clip, vibe: vibe, seed: 1, role: .drums, bars: 1).apply(to: &project))
    }

    func testApplyRejectsOutOfRangeBars() throws {
        var (project, _, clip) = try makeMidiClip()
        XCTAssertThrowsError(try Command.generateLoopFromVibe(clip, vibe: vibe, seed: 1, role: .drums, bars: 0).apply(to: &project))
        XCTAssertThrowsError(try Command.generateLoopFromVibe(clip, vibe: vibe, seed: 1, role: .drums, bars: 32).apply(to: &project))
    }

    func testApplyTrimsNotesThatWouldOverrunTheClipLength() throws {
        // One-bar clip, two bars requested; the second bar's notes must not be stored.
        var (project, _, clip) = try makeMidiClip()
        try Command.generateLoopFromVibe(clip, vibe: vibe, seed: 7, role: .drums, bars: 2).apply(to: &project)
        let notes = project.tracks.flatMap(\.clips).flatMap(\.notes)
        let bar = MusicalTime.ticksPerBar(.common)
        for n in notes {
            XCTAssertLessThan(n.start, bar)
        }
    }

    func testCatalogExposesTheCommand() {
        XCTAssertTrue(CommandCatalog.all.contains(where: { $0.name == "loop.generate" }))
    }

    func testKindRoundtripsThroughCatalog() {
        let kinds = Command.Kind.allCases
        XCTAssertTrue(kinds.contains(.generateLoopFromVibe))
        XCTAssertEqual(CommandCatalog.spec(for: .generateLoopFromVibe).name, "loop.generate")
    }
}

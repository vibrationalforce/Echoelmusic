import XCTest
@testable import EchoelCore

/// The synth's wavetable engine takes its cycles from a file of the song (EchoelTools: a synth
/// fed with the musician's own sample): which file and how many cycles, through the one door.
final class WavetableSourceTests: XCTestCase {
    private func song() throws -> (Project, TrackID, MediaFile) {
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        let file = MediaFile(name: "Voice", path: "Media/voice.wav", frameCount: 96_000, sampleRate: 48_000)
        try Command.addMedia(file).apply(to: &project)
        return (project, track, file)
    }

    func testAFileIsChosenAndClearedThroughTheDoor() throws {
        var (p, track, file) = try song()
        let source = WavetableSource(media: file.id, frames: WavetableSource.frames(for: file))
        XCTAssertEqual(source.frames, 46, "one cycle per 2048 frames of the file")
        try Command.setInstrumentWavetable(track, source).apply(to: &p)
        XCTAssertEqual(p.track(track)?.instrument.wavetable, source)
        try Command.setInstrumentWavetable(track, nil).apply(to: &p)
        XCTAssertNil(p.track(track)?.instrument.wavetable)
    }

    func testTheDoorRefusesWhatCannotBeCut() throws {
        var (p, track, file) = try song()
        let before = p
        XCTAssertThrowsError(try Command.setInstrumentWavetable(track, WavetableSource(media: MediaID(), frames: 8)).apply(to: &p))
        for frames in [0, 1, 65, -3] {
            XCTAssertThrowsError(try Command.setInstrumentWavetable(track, WavetableSource(media: file.id, frames: frames))
                .apply(to: &p), "\(frames)")
        }
        let audio = TrackID()
        var withAudio = p
        try Command.addTrack(id: audio, name: "A", kind: .audio, index: nil).apply(to: &withAudio)
        XCTAssertThrowsError(try Command.setInstrumentWavetable(audio, WavetableSource(media: file.id, frames: 8))
            .apply(to: &withAudio), "only an instrument track")
        XCTAssertEqual(p, before)
    }

    func testTheFramesOfAShortAndALongFileStayInRange() {
        let short = MediaFile(name: "s", path: "Media/s.wav", frameCount: 100, sampleRate: 48_000)
        let long = MediaFile(name: "l", path: "Media/l.wav", frameCount: 48_000 * 600, sampleRate: 48_000)
        XCTAssertEqual(WavetableSource.frames(for: short), 2)
        XCTAssertEqual(WavetableSource.frames(for: long), 64)
    }

    /// Removing the file leaves nothing pointing at it: the synth plays the factory shapes again.
    func testRemovingTheFileClearsTheWavetable() throws {
        var (p, track, file) = try song()
        try Command.setInstrumentWavetable(track, WavetableSource(media: file.id, frames: 8)).apply(to: &p)
        try Command.removeMedia(file.id).apply(to: &p)
        XCTAssertNil(p.track(track)?.instrument.wavetable)
    }

    /// The file is heard — loaded, kept under memory pressure — only while the synth plays the
    /// wavetable engine.
    func testTheFileIsHeardOnlyWhileTheWavetableEnginePlays() throws {
        var (p, track, file) = try song()
        try Command.setInstrumentWavetable(track, WavetableSource(media: file.id, frames: 8)).apply(to: &p)
        XCTAssertEqual(p.audibleMedia, [])
        try Command.setInstrumentParameter(track, key: "synth.engine", value: Double(WavetableSource.engineIndex)).apply(to: &p)
        XCTAssertEqual(SynthParameter.engine.choices[WavetableSource.engineIndex], "Wavetable")
        XCTAssertEqual(p.audibleMedia, [file.id])
        XCTAssertEqual(p.releasableMedia(among: [file.id]), [])
        try Command.setInstrumentDevice(track, .drums).apply(to: &p)
        XCTAssertEqual(p.audibleMedia, [])
    }

    /// Saved and opened again it is the same song; a song without it stores no key.
    func testTheWavetableRoundTripsAndIsOnlyWrittenWhenSet() throws {
        var (p, track, file) = try song()
        let plain = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(p)) as? [String: Any])
        let plainTrack = try XCTUnwrap((plain["tracks"] as? [[String: Any]])?.first)
        XCTAssertNil((plainTrack["instrument"] as? [String: Any])?["wavetable"])
        try Command.setInstrumentWavetable(track, WavetableSource(media: file.id, frames: 12)).apply(to: &p)
        let data = try ProjectCodec.encode(p)
        XCTAssertEqual(try ProjectCodec.decode(data), p)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let stored = try XCTUnwrap(((root["tracks"] as? [[String: Any]])?.first?["instrument"] as? [String: Any])?["wavetable"]
            as? [String: Any])
        XCTAssertEqual(Set(stored.keys), ["media", "frames"])
        XCTAssertEqual(stored["frames"] as? Int, 12)
    }
}

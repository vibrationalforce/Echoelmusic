import XCTest
@testable import EchoelCore

final class MediaTests: XCTestCase {
    private func file(path: String = "Media/kick.wav", frames: Int = 48_000, rate: Double = 48_000) -> MediaFile {
        MediaFile(name: "Kick", path: path, frameCount: frames, sampleRate: rate)
    }

    private func project() throws -> (Project, TrackID) {
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        return (project, track)
    }

    func testAnImportedFileIsStoredAndMeasured() throws {
        var (p, _) = try project()
        let f = file(frames: 24_000)
        try Command.addMedia(f).apply(to: &p)
        XCTAssertEqual(p.mediaFile(f.id)?.name, "Kick")
        XCTAssertEqual(p.mediaFile(f.id)?.duration ?? 0, 0.5, accuracy: 1e-9)
    }

    func testOnlyPathsInsideTheMediaFolderAreAccepted() throws {
        var (p, _) = try project()
        let before = p
        for bad in ["", "/etc/passwd", "kick.wav", "Media/", "Media/../x.wav", "Media//x.wav", "Media/./x.wav", "Other/x.wav", "Media\\x.wav"] {
            XCTAssertThrowsError(try Command.addMedia(file(path: bad)).apply(to: &p), bad)
        }
        XCTAssertThrowsError(try Command.addMedia(file(frames: 0)).apply(to: &p))
        XCTAssertThrowsError(try Command.addMedia(file(rate: .nan)).apply(to: &p))
        for rate in [1e-300, 0.5, 999, 768_001, 1e300] {
            XCTAssertThrowsError(try Command.addMedia(file(rate: rate)).apply(to: &p), "\(rate)")
        }
        XCTAssertThrowsError(try Command.addMedia(file(frames: MediaFile.maximumFrameCount + 1)).apply(to: &p))
        XCTAssertEqual(p, before)
        XCTAssertNoThrow(try Command.addMedia(file(path: "Media/sub/x.wav")).apply(to: &p))
    }

    func testAFileResolvesInsideItsPackageAndAnEscapingPathDoesNot() {
        let package = URL(fileURLWithPath: "/songs/Song.echoel", isDirectory: true)
        XCTAssertEqual(file(path: "Media/sub/kick.wav").url(in: package)?.path, "/songs/Song.echoel/Media/sub/kick.wav")
        // A song read from disk never went through media.add, so the reader must refuse these itself.
        for bad in ["../../etc/passwd", "/etc/passwd", "Media/../../x.wav", "Other/x.wav"] {
            XCTAssertNil(file(path: bad).url(in: package), bad)
        }
    }

    /// A song's audio is decoded whole when it opens; the plan keeps what the song plays inside
    /// the memory it is given, and a song with too much audio opens instead of ending the app.
    func testTheLoadPlanTakesWhatTheSongPlaysFirstAndSkipsWhatDoesNotFit() throws {
        var p = Project()
        let audio = TrackID(), keys = TrackID()
        try Command.addTrack(id: audio, name: "Audio", kind: .audio, index: nil).apply(to: &p)
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &p)
        let unused = file(path: "Media/unused.wav", frames: 1_000)
        let take = file(path: "Media/take.wav", frames: 1_000)
        let sample = file(path: "Media/sample.wav", frames: 500)
        let small = file(path: "Media/small.wav", frames: 100)
        for media in [unused, take, sample, small] { try Command.addMedia(media).apply(to: &p) }
        try Command.placeAudio(track: audio, id: RegionID(), media: take.id, start: 0).apply(to: &p)
        try Command.setInstrumentSample(keys, sample.id).apply(to: &p)
        try Command.setInstrumentDevice(keys, .sampler).apply(to: &p)
        let bytes = Project.decodedBytesPerFrame
        XCTAssertEqual(bytes, 4, "one mono Float per frame")

        let roomy = p.mediaLoadPlan(budget: .max)
        XCTAssertEqual(roomy.load.map(\.id), [take.id, sample.id, unused.id, small.id])
        XCTAssertEqual(roomy.skipped, [])

        // Room for 1,600 frames: the take and the sample fit, the unused file does not, and the
        // small one after it still does.
        let tight = p.mediaLoadPlan(budget: 1_600 * bytes)
        XCTAssertEqual(tight.load.map(\.id), [take.id, sample.id, small.id])
        XCTAssertEqual(tight.skipped.map(\.id), [unused.id])

        // A sample counts as played only while the sampler plays its track.
        try Command.setInstrumentDevice(keys, .synth).apply(to: &p)
        XCTAssertEqual(p.mediaLoadPlan(budget: .max).load.map(\.id), [take.id, unused.id, sample.id, small.id])

        XCTAssertEqual(p.mediaLoadPlan(budget: 0).load, [])
        XCTAssertEqual(p.mediaLoadPlan(budget: -1).skipped.count, 4)
    }

    func testADuplicateIDIsRefused() throws {
        var (p, _) = try project()
        let f = file()
        try Command.addMedia(f).apply(to: &p)
        XCTAssertThrowsError(try Command.addMedia(f).apply(to: &p))
    }

    func testATrackChoosesAKnownSampleAndRemovingTheFileClearsIt() throws {
        var (p, track) = try project()
        let f = file()
        XCTAssertThrowsError(try Command.setInstrumentSample(track, f.id).apply(to: &p), "unknown file")
        try Command.addMedia(f).apply(to: &p)
        try Command.setInstrumentDevice(track, .sampler).apply(to: &p)
        try Command.setInstrumentSample(track, f.id).apply(to: &p)
        XCTAssertEqual(p.track(track)?.instrument.sample, f.id)
        try Command.loadInstrumentPreset(track, name: "Pluck").apply(to: &p)
        XCTAssertEqual(p.track(track)?.instrument.sample, f.id, "a preset keeps the sample")
        try Command.removeMedia(f.id).apply(to: &p)
        XCTAssertNil(p.track(track)?.instrument.sample)
        XCTAssertTrue(p.media.isEmpty)
        XCTAssertThrowsError(try Command.removeMedia(f.id).apply(to: &p))
    }

    func testMediaSurvivesEncodingAndOldSongsHaveNone() throws {
        var (p, _) = try project()
        try Command.addMedia(file()).apply(to: &p)
        let again = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(again, p)

        var json = try XCTUnwrap(try JSONSerialization.jsonObject(with: JSONEncoder().encode(Project())) as? [String: Any])
        json.removeValue(forKey: "media")
        let old = try JSONDecoder().decode(Project.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(old.media, [])
    }
}

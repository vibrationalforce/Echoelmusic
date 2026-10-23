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
        XCTAssertEqual(tight.silenced, [], "nothing the song plays is left out")
        XCTAssertEqual(p.mediaLoadPlan(budget: 1_200 * bytes).silenced.map(\.id), [sample.id],
                       "the sample the sampler plays does not fit: that is heard as silence")

        // A sample counts as played only while the sampler plays its track.
        try Command.setInstrumentDevice(keys, .synth).apply(to: &p)
        XCTAssertEqual(p.mediaLoadPlan(budget: .max).load.map(\.id), [take.id, unused.id, sample.id, small.id])

        XCTAssertEqual(p.mediaLoadPlan(budget: 0).load, [])
        XCTAssertEqual(p.mediaLoadPlan(budget: -1).skipped.count, 4)
    }

    /// A file is judged where it will be: placed, it plays and ranks before the files nothing
    /// plays, so a song full of leftovers still takes it (second night review, 2026-10-23).
    func testAPlacedFileRanksBeforeTheLeftovers() throws {
        var p = Project()
        let audio = TrackID()
        try Command.addTrack(id: audio, name: "Audio", kind: .audio, index: nil).apply(to: &p)
        let played = file(path: "Media/played.wav", frames: 300)
        let left1 = file(path: "Media/left1.wav", frames: 300), left2 = file(path: "Media/left2.wav", frames: 300)
        for media in [played, left1, left2] { try Command.addMedia(media).apply(to: &p) }
        try Command.placeAudio(track: audio, id: RegionID(), media: played.id, start: 0).apply(to: &p)
        let budget = 1_000 * Project.decodedBytesPerFrame

        let fits = file(path: "Media/new.wav", frames: 200)
        var orphan = p
        try Command.addMedia(fits).apply(to: &orphan)
        XCTAssertEqual(orphan.mediaLoadPlan(budget: budget).skipped.map(\.id), [fits.id], "appended alone, it ranks last")
        var placed = p
        try Command.addMedia(fits).apply(to: &placed)
        // Later than the region already there: regions keep start order, so the order is fixed.
        try Command.placeAudio(track: audio, id: RegionID(), media: fits.id, start: 1_000).apply(to: &placed)
        XCTAssertEqual(placed.mediaLoadPlan(budget: budget).skipped.map(\.id), [left2.id], "placed, a leftover gives way")
        XCTAssertEqual(placed.newlySilencedMedia(budget: budget, comparedTo: p), [])

        let tooBig = file(path: "Media/big.wav", frames: 800)
        var big = p
        try Command.addMedia(tooBig).apply(to: &big)
        try Command.placeAudio(track: audio, id: RegionID(), media: tooBig.id, start: 1_000).apply(to: &big)
        XCTAssertEqual(big.newlySilencedMedia(budget: budget, comparedTo: p).map(\.id), [tooBig.id])
    }

    /// A take can push a file the song plays out of memory while a leftover drops back in: the
    /// count of skipped files stays the same, and still something heard goes silent.
    func testATakeThatSwapsWhatIsSkippedNamesWhatGoesSilent() throws {
        var p = Project()
        let one = TrackID(), two = TrackID()
        try Command.addTrack(id: one, name: "One", kind: .audio, index: nil).apply(to: &p)
        try Command.addTrack(id: two, name: "Two", kind: .audio, index: nil).apply(to: &p)
        let first = file(path: "Media/a.wav", frames: 330), second = file(path: "Media/p.wav", frames: 115)
        let leftover = file(path: "Media/u.wav", frames: 100)
        for media in [first, second, leftover] { try Command.addMedia(media).apply(to: &p) }
        try Command.placeAudio(track: one, id: RegionID(), media: first.id, start: 0).apply(to: &p)
        try Command.placeAudio(track: two, id: RegionID(), media: second.id, start: 0).apply(to: &p)
        let budget = 537 * Project.decodedBytesPerFrame
        XCTAssertEqual(p.mediaLoadPlan(budget: budget).skipped.map(\.id), [leftover.id])

        let take = file(path: "Media/take.wav", frames: 95)
        var after = p
        try Command.addMedia(take).apply(to: &after)
        try Command.placeAudio(track: one, id: RegionID(), media: take.id, start: 1_000).apply(to: &after)
        XCTAssertEqual(after.mediaLoadPlan(budget: budget).skipped.map(\.id), [second.id], "one skipped before, one after")
        XCTAssertEqual(after.newlySilencedMedia(budget: budget, comparedTo: p).map(\.id), [second.id])
        XCTAssertEqual(p.newlySilencedMedia(budget: budget, comparedTo: after), [], "a leftover going out is heard by no one")
    }

    /// An audio clip plays while it sits in a slot; taken out of every slot it is a leftover, and
    /// its file is not named silent when it does not fit.
    func testAnAudioClipPlaysWhileItIsInASlot() throws {
        var p = Project()
        let audio = TrackID(), clip = ClipID(), scene = SceneID()
        try Command.addTrack(id: audio, name: "Audio", kind: .audio, index: nil).apply(to: &p)
        try Command.addScene(id: scene, name: "A", index: nil).apply(to: &p)
        let loop = file(path: "Media/loop.wav", frames: 1_000)
        try Command.addMedia(loop).apply(to: &p)
        try Command.createAudioClip(track: audio, id: clip, name: "Loop", length: 3_840,
                                    audio: ClipAudio(media: loop.id, length: 1_000)).apply(to: &p)
        XCTAssertEqual(p.audibleMedia, [], "a clip in no slot plays nowhere")
        try Command.setSlot(track: audio, scene: scene, clip: clip).apply(to: &p)
        XCTAssertEqual(p.audibleMedia, [loop.id])
        XCTAssertEqual(p.mediaLoadPlan(budget: 0).silenced.map(\.id), [loop.id])
        try Command.setSlot(track: audio, scene: scene, clip: nil).apply(to: &p)
        XCTAssertEqual(p.mediaLoadPlan(budget: 0).silenced, [], "out of every slot, nothing plays it")
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

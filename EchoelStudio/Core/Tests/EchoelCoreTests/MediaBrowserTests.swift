import Foundation
import XCTest
@testable import EchoelCore

final class MediaBrowserTests: XCTestCase {
    private typealias Item = MediaBrowser.Item

    private func item(_ name: String, _ kind: MediaBrowser.Kind = .audio, origin: MediaBrowser.Origin = .song,
                      duration: Double? = nil) -> Item {
        Item(id: "\(origin.title)/\(name)", name: name, kind: kind, origin: origin, duration: duration)
    }

    private func names(_ items: [Item]) -> [String] { items.map(\.name) }

    // MARK: - Filter and search

    func testTheKindFilterKeepsOnlyThatKindAndNilKeepsAll() {
        let items = [item("Kick"), item("Clip", .video), item("Cover", .image)]
        XCTAssertEqual(names(MediaBrowser.filtered(items, kind: .audio, query: "")), ["Kick"])
        XCTAssertEqual(names(MediaBrowser.filtered(items, kind: .video, query: "")), ["Clip"])
        XCTAssertEqual(names(MediaBrowser.filtered(items, kind: .image, query: "")), ["Cover"])
        XCTAssertEqual(MediaBrowser.filtered(items, kind: nil, query: "").count, 3)
    }

    func testSearchIgnoresCaseAccentsAndWordOrder() {
        let items = [item("Café Loop 120"), item("Kick Hard"), item("Snare")]
        XCTAssertEqual(names(MediaBrowser.filtered(items, kind: nil, query: "cafe")), ["Café Loop 120"])
        XCTAssertEqual(names(MediaBrowser.filtered(items, kind: nil, query: "LOOP café")), ["Café Loop 120"])
        XCTAssertEqual(names(MediaBrowser.filtered(items, kind: nil, query: "hard kick")), ["Kick Hard"])
        XCTAssertEqual(MediaBrowser.filtered(items, kind: nil, query: "kick snare"), [], "every word must match")
        XCTAssertEqual(MediaBrowser.filtered(items, kind: nil, query: "   ").count, 3, "only spaces matches everything")
        XCTAssertTrue(MediaBrowser.matches("Vocal Take", query: "  take  "))
        XCTAssertFalse(MediaBrowser.matches("Vocal Take", query: "drum"))
    }

    func testSearchAndFilterCombine() {
        let items = [item("Rain", .audio), item("Rain", .video), item("Wind", .audio)]
        XCTAssertEqual(MediaBrowser.filtered(items, kind: .video, query: "rain").map(\.kind), [.video])
    }

    // MARK: - Sort

    func testNameSortPutsNumbersInOrderAndIgnoresCase() {
        let items = [item("kick 10"), item("Kick 2"), item("bass")]
        XCTAssertEqual(names(MediaBrowser.sorted(items, by: .name)), ["bass", "Kick 2", "kick 10"])
    }

    func testLengthSortIsLongestFirstWithUnmeasuredLast() {
        let items = [item("Short", duration: 1), item("None"), item("Long", duration: 30), item("Also Long", duration: 30)]
        XCTAssertEqual(names(MediaBrowser.sorted(items, by: .duration)), ["Also Long", "Long", "Short", "None"],
                       "equal lengths fall back to the name")
    }

    func testWhereSortPutsTheOpenSongFirstThenSongsThenImported() {
        let items = [item("A", origin: .imported), item("B", origin: .library(song: "Zebra")),
                     item("C", origin: .library(song: "Alpha")), item("D", origin: .song)]
        XCTAssertEqual(names(MediaBrowser.sorted(items, by: .origin)), ["D", "C", "B", "A"])
    }

    /// The Samples folder comes after the songs and before the imported files, each subfolder as
    /// its own group in order.
    func testWhereSortPutsTheSamplesFolderBetweenTheSongsAndTheImportedFiles() {
        let items = [item("A", origin: .imported), item("B", origin: .samples(folder: "Kicks")),
                     item("C", origin: .samples(folder: "")), item("D", origin: .library(song: "Alpha")),
                     item("E", origin: .song)]
        XCTAssertEqual(names(MediaBrowser.sorted(items, by: .origin)), ["E", "D", "C", "B", "A"])
    }

    /// A file in the Samples folder is named by the subfolder that holds it; a file outside the
    /// folder has none.
    func testASamplesFileIsNamedByTheSubfolderThatHoldsIt() {
        let root = URL(fileURLWithPath: "/Documents/Samples", isDirectory: true)
        XCTAssertEqual(MediaBrowser.samplesFolder(of: root.appendingPathComponent("Kick.wav"), in: root), "")
        XCTAssertEqual(MediaBrowser.samplesFolder(of: root.appendingPathComponent("Drums/Kicks/Kick 2.wav"), in: root),
                       "Drums › Kicks")
        XCTAssertNil(MediaBrowser.samplesFolder(of: URL(fileURLWithPath: "/Documents/Other/Kick.wav"), in: root))
        XCTAssertEqual(MediaBrowser.Origin.samples(folder: "").title, "Samples")
        XCTAssertEqual(MediaBrowser.Origin.samples(folder: "Drums › Kicks").title, "Samples › Drums › Kicks")
    }

    func testTheOrderDoesNotDependOnTheOrderItemsCameIn() {
        let items = [item("Same", origin: .song), item("Same", origin: .imported), item("Other")]
        for sort in MediaBrowser.Sort.allCases {
            XCTAssertEqual(MediaBrowser.sorted(items, by: sort), MediaBrowser.sorted(items.reversed(), by: sort))
        }
    }

    func testShownFiltersSearchesAndSortsAndCountsEachKind() {
        let items = [item("Kick 2", duration: 1), item("Kick 1", duration: 3), item("Kick Clip", .video), item("Pad")]
        XCTAssertEqual(names(MediaBrowser.shown(items, kind: .audio, query: "kick", sort: .duration)), ["Kick 1", "Kick 2"])
        XCTAssertEqual(MediaBrowser.counts(items), [.audio: 3, .video: 1])
    }

    // MARK: - Listing a song

    private func song() throws -> (Project, audio: MediaFile, video: MediaFile, track: TrackID) {
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Loops", kind: .audio, index: nil).apply(to: &project)
        let audio = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)
        let video = MediaFile(name: "Clip", path: "Media/clip.mov", frameCount: 240_000,
                              sampleRate: MediaFile.videoTimeBase, kind: .video)
        try Command.addMedia(audio).apply(to: &project)
        try Command.addMedia(video).apply(to: &project)
        return (project, audio, video, track)
    }

    func testASongsFilesAreListedWithWhatItMeasuredAndNothingMore() throws {
        let (project, audio, video, _) = try song()
        let items = MediaBrowser.items(of: project, origin: .song, package: nil)
        XCTAssertEqual(items.count, 2)
        let sound = try XCTUnwrap(items.first { $0.media == audio.id })
        XCTAssertEqual(sound.kind, .audio)
        XCTAssertEqual(sound.duration ?? 0, 2, accuracy: 1e-9)
        XCTAssertEqual(sound.sampleRate, 48_000)
        XCTAssertNil(sound.tempo, "no region states a tempo, so none is shown")
        let picture = try XCTUnwrap(items.first { $0.media == video.id })
        XCTAssertEqual(picture.kind, .video)
        XCTAssertEqual(picture.duration ?? 0, 5, accuracy: 1e-9)
        XCTAssertNil(picture.sampleRate, "a video's time base is not a sample rate")
        XCTAssertFalse(picture.canListen)
        XCTAssertTrue(sound.canListen)
    }

    func testATempoIsShownOnlyWhenTheSongStatesOneAndItsRegionsAgree() throws {
        let fixture = try song()
        var project = fixture.0
        let audio = fixture.audio, track = fixture.track
        let first = RegionID(), second = RegionID()
        try Command.placeAudio(track: track, id: first, media: audio.id, start: 0).apply(to: &project)
        XCTAssertNil(MediaBrowser.tempo(of: audio.id, in: project))
        try Command.setRegionWarp(track: track, first, nativeBPM: 98, followsTempo: false).apply(to: &project)
        XCTAssertEqual(MediaBrowser.tempo(of: audio.id, in: project), 98)
        try Command.placeAudio(track: track, id: second, media: audio.id, start: 7_680).apply(to: &project)
        XCTAssertEqual(MediaBrowser.tempo(of: audio.id, in: project), 98, "a region that states nothing does not disagree")
        try Command.setRegionWarp(track: track, second, nativeBPM: 120, followsTempo: false).apply(to: &project)
        XCTAssertNil(MediaBrowser.tempo(of: audio.id, in: project), "two tempos for one file: neither is shown")
    }

    func testAnotherSongsFilesAreReadFromItsPackageAndNeverOutsideIt() throws {
        let fixture = try song()
        var project = fixture.0
        let audio = fixture.audio
        var escape = MediaFile(name: "Escape", path: "Media/x.wav", frameCount: 10, sampleRate: 48_000)
        escape.path = "../outside.wav"
        project.media.append(escape)
        let package = URL(fileURLWithPath: "/songs/Other.echoel", isDirectory: true)
        let items = MediaBrowser.items(of: project, origin: .library(song: "Other"), package: package)
        XCTAssertEqual(items.map(\.name).sorted(), ["Clip", "Loop"], "a path that leaves the package is not listed")
        let loop = try XCTUnwrap(items.first { $0.name == "Loop" })
        XCTAssertNil(loop.media, "a file of another song is not the open song's")
        XCTAssertEqual(loop.location?.path, package.appendingPathComponent(audio.path).path)
        XCTAssertNotEqual(loop.id, MediaBrowser.items(of: project, origin: .song, package: nil).first { $0.name == "Loop" }?.id)
    }

    func testMeasurementsThatAreNotUsableAreNotShown() {
        let odd = Item(id: "x", name: "Odd", kind: .audio, origin: .imported, duration: .nan, sampleRate: 5, tempo: 2_000)
        XCTAssertNil(odd.duration)
        XCTAssertNil(odd.sampleRate)
        XCTAssertNil(odd.tempo)
    }

    // MARK: - Placing

    func testAPictureGoesNowhereAndASoundToEveryPlaceThatTakesOne() throws {
        let fixture = try song()
        var project = fixture.0
        let audioTrack = fixture.track
        let keys = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        XCTAssertEqual(MediaBrowser.destinations(for: .image, in: project, at: 0), [])
        XCTAssertEqual(MediaBrowser.destinations(for: .audio, in: project, at: 960),
                       [.track(audioTrack, at: 960), .sampler(keys), .wavetable(keys)])
        XCTAssertEqual(MediaBrowser.destinations(for: .video, in: project, at: -5), [.video(nil, at: 0)],
                       "a time before the song starts it at the start")
    }

    func testPlacingASongFileUsesTheExistingCommands() throws {
        let fixture = try song()
        var project = fixture.0
        let audio = fixture.audio, video = fixture.video, audioTrack = fixture.track
        let keys = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)

        var placed = project
        for command in try MediaBrowser.commands(placing: audio.id, on: .track(audioTrack, at: 1_920), in: placed) {
            try command.apply(to: &placed)
        }
        XCTAssertEqual(placed.track(audioTrack)?.regions.first?.start, 1_920)
        XCTAssertEqual(placed.media.count, project.media.count, "nothing is added to the song but the placement")

        var sampled = project
        for command in try MediaBrowser.commands(placing: audio.id, on: .sampler(keys), in: sampled) {
            try command.apply(to: &sampled)
        }
        XCTAssertEqual(sampled.track(keys)?.instrument.device, .sampler)
        XCTAssertEqual(sampled.track(keys)?.instrument.sample, audio.id)

        var tabled = project
        for command in try MediaBrowser.commands(placing: audio.id, on: .wavetable(keys), in: tabled) {
            try command.apply(to: &tabled)
        }
        XCTAssertEqual(tabled.track(keys)?.instrument.device, .synth)
        XCTAssertEqual(tabled.track(keys)?.instrument.wavetable?.media, audio.id)
        XCTAssertEqual(tabled.track(keys)?.instrument.heardWavetable, audio.id, "the wavetable engine plays it")

        var filmed = project
        let newTrack = TrackID()
        for command in try MediaBrowser.commands(placing: video.id, on: .video(nil, at: 0), in: filmed, newTrack: newTrack) {
            try command.apply(to: &filmed)
        }
        XCTAssertEqual(filmed.track(newTrack)?.kind, .video)
        XCTAssertEqual(filmed.track(newTrack)?.regions.first?.media, video.id)
    }

    func testAFileGoesOnlyWhereItsKindBelongs() throws {
        let fixture = try song()
        var project = fixture.0
        let audio = fixture.audio, video = fixture.video, audioTrack = fixture.track
        let keys = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        XCTAssertThrowsError(try MediaBrowser.commands(placing: video.id, on: .sampler(keys), in: project)) {
            XCTAssertEqual($0 as? MediaBrowser.PlacementError, .wrongKind)
        }
        XCTAssertThrowsError(try MediaBrowser.commands(placing: audio.id, on: .video(nil, at: 0), in: project)) {
            XCTAssertEqual($0 as? MediaBrowser.PlacementError, .wrongKind)
        }
        XCTAssertThrowsError(try MediaBrowser.commands(placing: audio.id, on: .sampler(audioTrack), in: project)) {
            XCTAssertEqual($0 as? MediaBrowser.PlacementError, .noSuchTrack, "an audio track has no sampler")
        }
        XCTAssertThrowsError(try MediaBrowser.commands(placing: MediaID(), on: .track(audioTrack, at: 0), in: project)) {
            XCTAssertEqual($0 as? MediaBrowser.PlacementError, .notInSong)
        }
    }

    func testTheMeasuredRootJoinsTheSamplerPlacementAsOneStep() throws {
        let fixture = try song()
        var project = fixture.0
        let keys = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        let commands = try MediaBrowser.commands(placing: fixture.audio.id, on: .sampler(keys), in: project, rootKey: 57)
        XCTAssertEqual(commands.count, 3)
        for command in commands { try command.apply(to: &project) }
        XCTAssertEqual(project.track(keys)?.instrument.value(InstrumentParameter.samplerRoot), 57)
        let track = fixture.track
        XCTAssertEqual(try MediaBrowser.commands(placing: fixture.audio.id, on: .track(track, at: 0), in: project, rootKey: 57).count, 1,
                       "a root key means nothing on an audio track")
        XCTAssertEqual(MediaBrowser.rootCommands(nil, on: keys), [])
    }

    func testAPitchReadsAsNoteAndCents() {
        XCTAssertEqual(MediaBrowser.pitchText(note: 57, cents: 0.4), "A3")
        XCTAssertEqual(MediaBrowser.pitchText(note: 57, cents: 4.2), "A3 +4 ct")
        XCTAssertEqual(MediaBrowser.pitchText(note: 60, cents: -12.6), "C4 −13 ct")
        XCTAssertEqual(MediaBrowser.pitchText(note: 60, cents: .nan), "C4")
    }
}

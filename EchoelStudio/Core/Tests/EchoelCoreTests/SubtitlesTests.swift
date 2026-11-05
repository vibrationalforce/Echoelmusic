import XCTest
@testable import EchoelCore

final class SubtitlesTests: XCTestCase {
    /// 120 BPM: 1 920 ticks a second.
    private let perSecond: Tick = 1_920

    private func cue(_ start: Tick, _ end: Tick, _ text: String, id: Int = 1) -> SubtitleCue {
        let raw = String(format: "5B700000-0000-4000-8000-%012d", id)
        return SubtitleCue(id: SubtitleID(UUID(uuidString: raw) ?? UUID()), start: start, end: end, text: text)
    }

    // MARK: - Lines

    func testTextBreaksIntoLinesOfFortyTwoAtSpaces() {
        let text = "The quick brown fox jumps over the lazy dog and keeps on running"
        let lines = Subtitles.lines(text)
        XCTAssertEqual(lines, ["The quick brown fox jumps over the lazy", "dog and keeps on running"])
        XCTAssertTrue(lines.allSatisfy { $0.count <= 42 })
        XCTAssertEqual(Subtitles.lines(String(repeating: "x", count: 42)), [String(repeating: "x", count: 42)])
        XCTAssertEqual(Subtitles.lines(String(repeating: "y", count: 50)),
                       [String(repeating: "y", count: 42), String(repeating: "y", count: 8)], "a word longer than a line is cut")
        XCTAssertEqual(Subtitles.lines("Grüße  an\nalle"), ["Grüße an alle"], "characters, not bytes; spaces collapse")
    }

    func testATextThatNeedsThreeLinesIsNotACue() {
        XCTAssertTrue(Subtitles.isValidText("Hello there"))
        XCTAssertFalse(Subtitles.isValidText(""))
        XCTAssertFalse(Subtitles.isValidText(" Hello"), "a stored text is normalized")
        XCTAssertFalse(Subtitles.isValidText("Hello\nthere"))
        let long = Array(repeating: "word", count: 20).joined(separator: " ")
        XCTAssertGreaterThan(Subtitles.lines(long).count, 2)
        XCTAssertFalse(Subtitles.isValidText(long))
    }

    // MARK: - Words into cues

    func testAPauseOverSevenTenthsStartsANewCue() {
        let words = [Subtitles.Word(text: "Hello", start: 0, end: 0.4),
                     Subtitles.Word(text: "world", start: 0.5, end: 0.9),
                     Subtitles.Word(text: "again", start: 1.7, end: 2.0)]
        let cues = Subtitles.cues(from: words)
        XCTAssertEqual(cues, [Subtitles.TimedText(start: 0, end: 0.9, text: "Hello world"),
                              Subtitles.TimedText(start: 1.7, end: 2.0, text: "again")])
        // A pause of exactly 0.7 s keeps the words together.
        let close = Subtitles.cues(from: [Subtitles.Word(text: "a", start: 0, end: 1),
                                          Subtitles.Word(text: "b", start: 1.7, end: 2)])
        XCTAssertEqual(close.map(\.text), ["a b"])
    }

    func testACueLastsAtMostSixSeconds() {
        let words = (0..<20).map { (index: Int) -> Subtitles.Word in
            Subtitles.Word(text: "w\(index)", start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.4)
        }
        let cues = Subtitles.cues(from: words)
        XCTAssertGreaterThan(cues.count, 1)
        for cue in cues {
            XCTAssertLessThanOrEqual(cue.end - cue.start, 6.0 + 1e-9)
            XCTAssertLessThanOrEqual(Subtitles.lines(cue.text).count, 2)
        }
        XCTAssertEqual(cues.map(\.text).joined(separator: " "), words.map(\.text).joined(separator: " "), "no word is lost")
        let held = Subtitles.cues(from: [Subtitles.Word(text: "Ooooh", start: 1, end: 20)])
        XCTAssertEqual(held, [Subtitles.TimedText(start: 1, end: 7, text: "Ooooh")])
    }

    func testACueThatWouldNeedAThirdLineIsSplit() {
        let words = (0..<30).map { (index: Int) -> Subtitles.Word in
            Subtitles.Word(text: "speech", start: Double(index) * 0.1, end: Double(index) * 0.1 + 0.08)
        }
        let cues = Subtitles.cues(from: words)
        XCTAssertGreaterThan(cues.count, 1)
        XCTAssertTrue(cues.allSatisfy { Subtitles.isValidText($0.text) })
        for (a, b) in zip(cues, cues.dropFirst()) { XCTAssertLessThanOrEqual(a.end, b.start, "cues never overlap") }
    }

    func testWordsWithoutTextOrTimeAreLeftOutAndTheRestIsOrdered() {
        let words = [Subtitles.Word(text: "two", start: 1, end: 1.2),
                     Subtitles.Word(text: "  ", start: 0.5, end: 0.6),
                     Subtitles.Word(text: "nan", start: .nan, end: 1),
                     Subtitles.Word(text: "one", start: 0.6, end: 0.9)]
        XCTAssertEqual(Subtitles.cues(from: words), [Subtitles.TimedText(start: 0.6, end: 1.2, text: "one two")])
        XCTAssertEqual(Subtitles.cues(from: []), [])
    }

    func testCuesArePlacedFromTheRegionStartOnTheTempoMap() {
        let map = TempoMap(bpm: 120, changes: [])
        let timed = [Subtitles.TimedText(start: 0, end: 1, text: "Hi"), Subtitles.TimedText(start: 2, end: 2.5, text: "there")]
        let placed = Subtitles.placed(timed, at: 1, tempoMap: map)
        XCTAssertEqual(placed.map(\.start), [perSecond, 3 * perSecond])
        XCTAssertEqual(placed.map(\.end), [2 * perSecond, 3 * perSecond + perSecond / 2])
        XCTAssertEqual(placed.map(\.text), ["Hi", "there"])
        let stretched = Subtitles.placed(timed, at: 0, scale: 2, tempoMap: map)
        XCTAssertEqual(stretched.map(\.start), [0, 4 * perSecond])
        XCTAssertTrue(Subtitles.placed(timed, at: .nan, tempoMap: map).isEmpty)
    }

    // MARK: - SRT and WebVTT

    func testTimestampsRoundToTheNearestMillisecond() {
        XCTAssertEqual(Subtitles.milliseconds(1.0004), 1_000)
        XCTAssertEqual(Subtitles.milliseconds(1.0005), 1_001)
        XCTAssertEqual(Subtitles.milliseconds(-1), 0)
        XCTAssertEqual(Subtitles.milliseconds(.nan), 0)
        XCTAssertEqual(Subtitles.timestamp(3_723_045, separator: ","), "01:02:03,045")
        XCTAssertEqual(Subtitles.timestamp(5, separator: "."), "00:00:00.005")
    }

    func testSpecialCharactersAreEscaped() {
        XCTAssertEqual(Subtitles.escapedVTT("Tom & <Jerry> -->"), "Tom &amp; &lt;Jerry&gt; --&gt;")
        XCTAssertEqual(Subtitles.escapedSRT("<i>not italic</i> -->"), "‹i›not italic‹/i› --›")
    }

    private var song: Project {
        var project = Project(name: "Talk", tempo: 120)
        project.subtitles = [cue(0, perSecond + perSecond / 2, "Hello & welcome", id: 1),
                             cue(2 * perSecond, 4 * perSecond,
                                 "The quick brown fox jumps over the lazy dog and keeps on running", id: 2)]
        return project
    }

    func testSRTIsNumberedWithCommaTimestamps() {
        XCTAssertEqual(Subtitles.srt(for: song), """
        1
        00:00:00,000 --> 00:00:01,500
        Hello & welcome

        2
        00:00:02,000 --> 00:00:04,000
        The quick brown fox jumps over the lazy
        dog and keeps on running


        """)
    }

    func testWebVTTHasItsHeaderAndEscapes() {
        XCTAssertEqual(Subtitles.vtt(for: song), """
        WEBVTT

        00:00:00.000 --> 00:00:01.500
        Hello &amp; welcome

        00:00:02.000 --> 00:00:04.000
        The quick brown fox jumps over the lazy
        dog and keeps on running


        """)
        XCTAssertEqual(Subtitles.vtt(for: Project()), "WEBVTT\n\n")
        XCTAssertEqual(Subtitles.srt(for: Project()), "")
    }

    func testTheSameSongGivesTheSameBytes() throws {
        let project = song
        let decoded = try ProjectCodec.decode(ProjectCodec.encode(project))
        XCTAssertEqual(Subtitles.srt(for: decoded), Subtitles.srt(for: project))
        XCTAssertEqual(Subtitles.vtt(for: decoded), Subtitles.vtt(for: project))
        XCTAssertEqual(try ProjectCodec.encode(decoded), try ProjectCodec.encode(project))
    }

    func testOTIOCarriesEachSubtitleAsAMarkerWithItsText() {
        let json = OTIOExport.json(for: song, title: "Talk", rate: .fps25)
        XCTAssertTrue(json.contains("\"comment\": \"Hello & welcome\""), json)
        XCTAssertTrue(json.contains("\"CYAN\""))
        XCTAssertFalse(OTIOExport.json(for: Project(), title: "Empty", rate: .fps25).contains("CYAN"))
    }

    // MARK: - Commands

    func testPlacingReplacesTheCuesItOverlaps() throws {
        var project = song
        try Command.placeSubtitles([cue(perSecond, 3 * perSecond, "New", id: 3)]).apply(to: &project)
        XCTAssertEqual(project.subtitles.map(\.text), ["New"], "both old cues overlapped it")
        try Command.placeSubtitles([cue(5 * perSecond, 6 * perSecond, "Later", id: 4)]).apply(to: &project)
        XCTAssertEqual(project.subtitles.map(\.text), ["New", "Later"])
    }

    func testEditsAreValidatedAtTheDoor() throws {
        var project = song
        let first = project.subtitles[0].id, second = project.subtitles[1].id
        try Command.setSubtitleText(first, text: "  Hi\nthere ").apply(to: &project)
        XCTAssertEqual(project.subtitle(first)?.text, "Hi there")
        let before = project
        let long = Array(repeating: "word", count: 20).joined(separator: " ")
        for command in [Command.setSubtitleText(first, text: "   "), .setSubtitleText(first, text: long),
                        .setSubtitleTiming(first, start: 10, end: 10),
                        .setSubtitleTiming(first, start: 0, end: 3 * perSecond),
                        .setSubtitleTiming(SubtitleID(), start: 0, end: 10),
                        .removeSubtitle(SubtitleID()), .placeSubtitles([]),
                        .placeSubtitles([cue(0, 10, "a", id: 7), cue(5, 20, "b", id: 8)])] {
            XCTAssertThrowsError(try command.apply(to: &project), "\(command)")
            XCTAssertEqual(project, before, "a refused edit leaves the song as it was")
        }
        try Command.setSubtitleTiming(second, start: 5 * perSecond, end: 6 * perSecond).apply(to: &project)
        try Command.setSubtitleTiming(first, start: 0, end: 4 * perSecond).apply(to: &project)
        XCTAssertEqual(project.subtitles.map(\.id), [first, second])
        try Command.removeSubtitle(first).apply(to: &project)
        XCTAssertEqual(project.subtitles.map(\.id), [second])
    }

    func testEachSubtitleEditIsOneUndoStep() async throws {
        let placed = cue(0, perSecond, "Hello", id: 9)
        try await MainActor.run {
            let store = ProjectStore()
            try store.perform(.placeSubtitles([placed]))
            XCTAssertEqual(store.undoTitle, "Add Subtitles")
            try store.perform(.setSubtitleText(placed.id, text: "Hello there"))
            XCTAssertEqual(store.undoTitle, "Edit Subtitle")
            try store.perform(.removeSubtitle(placed.id))
            store.undo()
            XCTAssertEqual(store.project.subtitles.map(\.text), ["Hello there"])
            store.undo()
            XCTAssertEqual(store.project.subtitles, [placed])
            store.undo()
            XCTAssertTrue(store.project.subtitles.isEmpty)
        }
    }
}

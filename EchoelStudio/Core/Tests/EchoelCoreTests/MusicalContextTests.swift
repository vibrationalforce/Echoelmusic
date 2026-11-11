import XCTest
@testable import EchoelCore

final class MusicalContextTests: XCTestCase {
    func testTheDefaultFramesNothing() {
        let context = MusicalContext()
        XCTAssertTrue((0...127).allSatisfy(context.contains), "chromatic keeps every pitch")
        XCTAssertEqual((0...127).map(context.nearest), Array(0...127))
        XCTAssertEqual(context.centsTable(), Array(repeating: 0, count: 12), "12 equal at 440 Hz retunes nothing")
    }

    func testAScaleKeepsItsPitchesAndSnapsOthersDownOnATie() {
        let cMajor = MusicalContext(scale: .major)
        XCTAssertEqual((60...71).filter(cMajor.contains), [60, 62, 64, 65, 67, 69, 71])
        XCTAssertEqual(cMajor.nearest(61), 60, "C♯ is between C and D: the lower wins")
        XCTAssertEqual(cMajor.nearest(66), 65)
        XCTAssertEqual(cMajor.nearest(64), 64)

        let dMajor = MusicalContext(root: 2, scale: .major)
        XCTAssertTrue(dMajor.contains(61), "C♯ is the seventh of D major")
        XCTAssertFalse(dMajor.contains(60))

        let pentatonic = MusicalContext(root: 9, scale: .minorPentatonic)
        XCTAssertEqual((57...68).filter(pentatonic.contains), [57, 60, 62, 64, 67])
    }

    // MARK: The key shown on a keyboard

    func testAKeyWearsItsPlaceInTheSongsKey() {
        let cMajor = MusicalContext(scale: .major)
        XCTAssertEqual(cMajor.keyMark(of: 60), .root)
        XCTAssertEqual(cMajor.keyMark(of: 72), .root, "every octave of the root")
        XCTAssertEqual(cMajor.keyMark(of: 62), .scaleTone)
        XCTAssertEqual(cMajor.keyMark(of: 61), KeyMark.unmarked, "C♯ is outside C major")

        let aMinor = MusicalContext(root: 9, scale: .minor)
        XCTAssertEqual(aMinor.keyMark(of: 57), .root)
        XCTAssertEqual(aMinor.keyMark(of: 60), .scaleTone, "C is the third of A minor")
        XCTAssertEqual(aMinor.keyMark(of: 61), KeyMark.unmarked)
    }

    func testAChromaticSongMarksNoKey() {
        let chromatic = MusicalContext()
        XCTAssertTrue((0...127).allSatisfy { (pitch: Int) -> Bool in chromatic.keyMark(of: pitch) == KeyMark.unmarked })
        let rooted = MusicalContext(root: 7, scale: .chromatic)
        XCTAssertEqual(rooted.keyMark(of: 67), KeyMark.unmarked, "a root alone frames nothing")
    }

    func testAPitchOutsideTheKeyboardWearsNothing() {
        let cMajor = MusicalContext(scale: .major)
        XCTAssertEqual(cMajor.keyMark(of: -12), KeyMark.unmarked)
        XCTAssertEqual(cMajor.keyMark(of: 128), KeyMark.unmarked)
        XCTAssertEqual(cMajor.keyMark(of: 0), .root)
        XCTAssertEqual(cMajor.keyMark(of: 127), .scaleTone, "G9 is the fifth of C")
    }

    /// In every scale and on every root, one octave shows one root and as many other marks as
    /// the scale has other tones — and a marked key is exactly a key the scale contains.
    func testAnOctaveShowsOneRootAndTheScalesOtherTones() {
        for scale in Scale.allCases where scale != .chromatic {
            for root in MusicalContext.rootRange {
                let context = MusicalContext(root: root, scale: scale)
                let marks: [KeyMark] = (60..<72).map { (pitch: Int) -> KeyMark in context.keyMark(of: pitch) }
                let roots = marks.filter { (mark: KeyMark) -> Bool in mark == .root }.count
                let tones = marks.filter { (mark: KeyMark) -> Bool in mark == .scaleTone }.count
                XCTAssertEqual(roots, 1, "\(context.title)")
                XCTAssertEqual(tones, scale.intervals.count - 1, "\(context.title)")
                for pitch in 60..<72 {
                    XCTAssertEqual(context.keyMark(of: pitch) != KeyMark.unmarked, context.contains(pitch), "\(context.title), pitch \(pitch)")
                }
            }
        }
    }

    func testTheFrameReadsAsKeyAndScale() throws {
        XCTAssertEqual(MusicalContext(root: 2, scale: .dorian).title, "D Dorian")
        XCTAssertEqual(MusicalContext(root: 10, scale: .harmonicMinor).title, "B♭ Harmonic Minor")
        XCTAssertEqual(MusicalContext().title, "Chromatic")
        XCTAssertEqual(MusicalContext(root: 7).title, "Chromatic", "chromatic has no key to name")
        var later = try JSONDecoder().decode(MusicalContext.self, from: Data(
            #"{"root":2,"scale":"bebop","tuning":"edo12","concertPitch":440,"swing":0}"#.utf8))
        XCTAssertEqual(later.title, "Chromatic", "a scale this build does not know frames nothing")
        later.scale = .minor
        XCTAssertEqual(later.title, "D Minor")
    }

    func testNearestStaysAMIDIPitch() {
        let cMajor = MusicalContext(scale: .major)
        XCTAssertEqual(cMajor.nearest(200), 127)
        XCTAssertEqual(cMajor.nearest(-5), 0)
        XCTAssertEqual(MusicalContext(root: 2, scale: .major).nearest(0), 1, "C is not in D major; C♯ is")
    }

    func testAToneSystemRetunesFromTheKeysRoot() {
        let justThird = 386.314 - 400
        let inC = MusicalContext(tuning: "just-major").centsTable()
        XCTAssertEqual(inC[4], justThird, accuracy: 0.001, "E is the just major third of C")
        XCTAssertEqual(inC[0], 0, accuracy: 0.001)

        let inD = MusicalContext(root: 2, tuning: "just-major").centsTable()
        XCTAssertEqual(inD[6], justThird, accuracy: 0.001, "F♯ is the just major third of D")
        XCTAssertEqual(inD[2], 0, accuracy: 0.001)

        XCTAssertEqual(MusicalContext(tuning: "edo24").centsTable(), Array(repeating: 0, count: 12),
                       "quarter tones contain every semitone")
        XCTAssertEqual(MusicalContext(tuning: "bohlen-pierce").centsTable(), Array(repeating: 0, count: 12),
                       "a system without octaves has no twelve-note retuning")
        XCTAssertEqual(MusicalContext(tuning: "from-a-later-build").centsTable(), Array(repeating: 0, count: 12))
    }

    func testConcertPitchShiftsEveryPitchClassAlike() {
        let shift = 1200 * Foundation.log2(432.0 / 440)
        for cents in MusicalContext(concertPitch: 432).centsTable() {
            XCTAssertEqual(cents, shift, accuracy: 1e-9)
        }
    }

    /// Every named concert pitch is one a song can store, and every one is a historical or
    /// orchestral standard — no pitch derived from an orbit. A song that stores such a
    /// pitch keeps it: the song holds only the number.
    func testEveryConcertPitchPresetIsAStorableStandard() throws {
        let presets = MusicalContext.concertPitchPresets
        XCTAssertEqual(presets.first?.hertz, 440)
        for preset in presets {
            XCTAssertTrue(MusicalContext.concertPitchRange.contains(preset.hertz), preset.title)
            var project = Project()
            XCTAssertNoThrow(try Command.setConcertPitch(hertz: preset.hertz).apply(to: &project), preset.title)
        }
        XCTAssertEqual(presets.map(\.hertz), [440, 442, 415, 430, 435, 466])
        XCTAssertEqual(Set(presets.map(\.title)).count, presets.count)
        var project = Project()
        try Command.setConcertPitch(hertz: 432.10).apply(to: &project)
        let reopened = try ProjectCodec.decode(ProjectCodec.encode(project))
        XCTAssertEqual(reopened.context.concertPitch, 432.10, accuracy: 1e-9, "a stored pitch off the list stays")
    }

    func testTheToneSystemIdsAreUniqueAndEqualTemperamentComesFirst() {
        let ids = TuningSystem.library.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ids.first, "edo12")
        XCTAssertTrue(TuningSystem.library.allSatisfy { $0.degreesCents.first == 0 && !$0.degreesCents.isEmpty })
    }

    func testTheCommandsSetTheContext() throws {
        var project = Project()
        try Command.setKeyRoot(9).apply(to: &project)
        try Command.setScale(.dorian).apply(to: &project)
        try Command.setTuning(id: "meantone-quarter").apply(to: &project)
        try Command.setConcertPitch(hertz: 415).apply(to: &project)
        try Command.setSwing(0.5).apply(to: &project)
        XCTAssertEqual(project.context, MusicalContext(root: 9, scale: .dorian, tuning: "meantone-quarter",
                                                       concertPitch: 415, swing: 0.5))
    }

    func testOutOfRangeContextValuesAreRefusedAndChangeNothing() {
        var project = Project()
        let refused: [Command] = [
            .setKeyRoot(12), .setKeyRoot(-1), .setTuning(id: "nope"),
            .setConcertPitch(hertz: 399), .setConcertPitch(hertz: .nan), .setConcertPitch(hertz: .infinity),
            .setSwing(1.5), .setSwing(-0.1), .setSwing(.nan),
        ]
        for command in refused {
            XCTAssertThrowsError(try command.apply(to: &project), "\(command)")
        }
        XCTAssertEqual(project.context, MusicalContext())
    }

    func testEveryContextParameterIsReachableFromAControl() throws {
        var project = Project()
        let descriptors = project.parameters.filter { $0.address.owner == .project && $0.address != .tempo }
        XCTAssertEqual(descriptors.map(\.address), [.keyRoot, .scale, .tuning, .concertPitch, .swing])
        for descriptor in descriptors {
            XCTAssertEqual(project.descriptor(for: descriptor.address), descriptor)
            let top = descriptor.value(forNormalized: 1)
            let command = try XCTUnwrap(Command.setParameter(descriptor.address, to: top))
            try command.apply(to: &project)
            XCTAssertEqual(project.value(of: descriptor.address), descriptor.range.upperBound, "\(descriptor.title)")
        }
        XCTAssertEqual(project.context.root, 11)
        XCTAssertEqual(project.context.scale, Scale.allCases.last)
        XCTAssertEqual(project.context.tuning, TuningSystem.library.last?.id)
        XCTAssertNil(Command.setParameter(.keyRoot, to: .nan))
    }

    func testTheSongWideFrameIsNotAutomated() {
        var project = Project()
        for address in [ParameterAddress.tempo, .keyRoot, .scale, .tuning, .concertPitch, .swing] {
            XCTAssertThrowsError(try Command.setAutomation(address, points: [AutomationPoint(tick: 0, value: 0)])
                .apply(to: &project), "\(address)")
        }
        XCTAssertTrue(project.automation.isEmpty)
    }

    func testASongFileKeepsAToneSystemThisBuildDoesNotKnowAndRefusesABrokenContext() throws {
        var project = Project()
        project.context.tuning = "from-a-later-build"
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)).context.tuning, "from-a-later-build")

        for broken in [MusicalContext(root: 12), MusicalContext(concertPitch: 1_000), MusicalContext(swing: 2)] {
            project.context = broken
            XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(project)))
        }
    }
}

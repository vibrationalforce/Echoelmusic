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

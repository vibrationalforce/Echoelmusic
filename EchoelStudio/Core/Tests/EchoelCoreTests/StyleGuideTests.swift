import Foundation
import XCTest
@testable import EchoelCore

/// "Use Style" (S2): a style's frame is a list of existing commands that the musician sends as one
/// undo step. It changes exactly the parts picked, never the key's root, and leaves a part the
/// song keeps as it is, saying why.
final class StyleGuideTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    func testTheHouseFrameOnAnEmptySongIsOneUndoStepThatRestoresTheSongExactly() async throws {
        let house = try guide("house")
        try await MainActor.run {
            let store = ProjectStore()
            let before = store.project
            let frame = house.frame(StyleChoice(swingPercent: 54), for: before)
            XCTAssertEqual(store.project, before, "a frame sets nothing by itself")
            XCTAssertEqual(frame.commands, [.setTempo(bpm: 124), .setTimeSignature(.common), .setScale(.minor),
                                            .setTuning(id: "edo12"), .setSwing(0.24)])
            XCTAssertEqual(frame.applied, [.tempo, .meter, .scale, .toneSystem, .swing])
            XCTAssertEqual(frame.kept, [:])

            try store.perform(frame.commands, title: frame.title)
            XCTAssertEqual(store.project.tempo, 124)
            XCTAssertEqual(store.project.timeSignature, .common)
            XCTAssertEqual(store.project.context.root, 0, "C, as the song had it")
            XCTAssertEqual(store.project.context.scale, .minor)
            XCTAssertEqual(store.project.context.tuning, "edo12")
            XCTAssertEqual(store.project.context.swing, 0.24, "54 % is exactly 3 · 4 / 50")
            XCTAssertEqual(store.undoStack.count, 1, "the whole frame is one step")
            XCTAssertEqual(store.undoTitle, "Use Style")

            let styled = store.project
            store.undo()
            XCTAssertEqual(store.project, before)
            store.redo()
            XCTAssertEqual(store.project, styled)
        }
    }

    func testAStyleChangesExactlyThePartsPickedAndNeverTheKeysRoot() async throws {
        let house = try guide("house")
        let song = Project(tempo: 97, timeSignature: TimeSignature(3, 4),
                           context: MusicalContext(root: 2, scale: .lydian, tuning: "just-major", concertPitch: 442, swing: 0.9),
                           markers: [Marker(tick: 0, name: "Start")])
        try await MainActor.run {
            let store = ProjectStore(project: song)
            let some = house.frame(StyleChoice(parts: [.tempo, .swing]), for: song)
            XCTAssertEqual(some.applied, [.tempo, .swing])
            try store.perform(some.commands, title: some.title)
            var expected = song
            expected.tempo = 124
            expected.context.swing = 0
            XCTAssertEqual(store.project, expected, "only tempo and swing moved; swing takes the low end of 50 … 58 %")
            store.undo()
            XCTAssertEqual(store.project, song)

            let whole = house.frame(for: song)
            try store.perform(whole.commands, title: whole.title)
            expected.timeSignature = .common
            expected.context.scale = .minor
            expected.context.tuning = "edo12"
            XCTAssertEqual(store.project, expected, "the whole frame; the root, concert pitch and markers stay the song's")
            XCTAssertEqual(store.project.context.root, 2)
            store.undo()
            XCTAssertEqual(store.project, song)
        }
    }

    func testASongAlreadyInTheStyleTakesNoStep() async throws {
        let house = try guide("house")
        try await MainActor.run {
            let store = ProjectStore()
            let first = house.frame(for: store.project)
            try store.perform(first.commands, title: first.title)
            let again = house.frame(for: store.project)
            try store.perform(again.commands, title: again.title)
            XCTAssertEqual(store.undoStack.count, 1, "the second frame changes nothing, so it adds no step")
        }
    }

    func testNoStyleEverSetsTheKeysRootAndEveryFrameAppliesToAFreshSong() async throws {
        let guides = StyleLibrary.standard.guides
        XCTAssertEqual(guides.count, 68)
        let song = Project(context: MusicalContext(root: 5))
        try await MainActor.run {
            for style in guides {
                let frame = style.frame(StyleChoice(parts: Set(StylePart.allCases)), for: song)
                let setsRoot = frame.commands.contains { (command: Command) -> Bool in
                    if case .setKeyRoot = command { return true }
                    return false
                }
                XCTAssertFalse(setsRoot, style.id)
                let store = ProjectStore(project: song)
                try store.perform(frame.commands, title: frame.title)
                XCTAssertEqual(store.project.context.root, 5, style.id)
                XCTAssertLessThanOrEqual(store.undoStack.count, 1, style.id)
                // On a fresh song only the build or a form without bars keeps a part, never the song:
                // every style's own swing is one the song plays.
                for (part, reason) in frame.kept {
                    switch reason {
                    case .notInThisBuild, .sectionsWithoutBars: break
                    case .notInTheStyle, .swingBeyondStudio, .markersStandThere, .refused:
                        XCTFail("\(style.id) \(part): \(reason)")
                    }
                }
                XCTAssertEqual(Set(frame.applied).union(frame.kept.keys), Set(StylePart.allCases), style.id)
            }
        }
    }

    // MARK: - Scale and tone system

    func testAScaleThisBuildDoesNotHaveLeavesTheSongsScaleAndSaysSo() async throws {
        let later = try guide("house", changing: { $0["scales"] = ["scaleOfALaterBuild", "minor"] })
        let song = Project(context: MusicalContext(root: 9, scale: .dorian))
        let frame = later.frame(for: song)
        XCTAssertEqual(frame.kept[.scale], .notInThisBuild("scaleOfALaterBuild"))
        XCTAssertFalse(frame.applied.contains(.scale))
        XCTAssertEqual(frame.applied, [.tempo, .meter, .toneSystem, .swing], "the other parts still apply")
        try await MainActor.run {
            let store = ProjectStore(project: song)
            try store.perform(frame.commands, title: frame.title)
            XCTAssertEqual(store.project.context.scale, .dorian)
            XCTAssertEqual(store.project.tempo, 124)
        }
        // The musician may pick another of the style's scales instead.
        XCTAssertEqual(later.frame(StyleChoice(parts: [.scale], scale: "minor"), for: song).commands, [.setScale(.minor)])

        // Every name of the table this build lacks reads the same way, before and after TH-4.
        for style in StyleLibrary.standard.guides {
            for name in style.scales where Scale(rawValue: name) == nil {
                let pending = style.frame(StyleChoice(parts: [.scale], scale: name), for: song)
                XCTAssertEqual(pending.kept[.scale], .notInThisBuild(name), "\(style.id) \(name)")
                XCTAssertTrue(pending.commands.isEmpty)
            }
            for id in style.toneSystems where !TuningSystem.library.contains(where: { $0.id == id }) {
                let pending = style.frame(StyleChoice(parts: [.toneSystem], toneSystem: id), for: song)
                XCTAssertEqual(pending.kept[.toneSystem], .notInThisBuild(id), "\(style.id) \(id)")
            }
        }
    }

    func testAToneSystemThisBuildDoesNotHaveLeavesTheSongsAndAnotherOfTheStylesApplies() throws {
        let later = try guide("hindustani_raga", changing: { $0["tunings"] = ["toneSystemOfALaterBuild", "edo12"] })
        let song = Project(context: MusicalContext(tuning: "edo24"))
        let frame = later.frame(StyleChoice(parts: [.toneSystem]), for: song)
        XCTAssertEqual(frame.kept[.toneSystem], .notInThisBuild("toneSystemOfALaterBuild"))
        XCTAssertTrue(frame.commands.isEmpty)
        let picked = later.frame(StyleChoice(parts: [.toneSystem], toneSystem: "edo12"), for: song)
        XCTAssertEqual(picked.commands, [.setTuning(id: "edo12")])
        let gamelan = try guide("gamelan")
        XCTAssertEqual(gamelan.frame(StyleChoice(parts: [.toneSystem], toneSystem: "gamelan-pelog"), for: song).commands,
                       [.setTuning(id: "gamelan-pelog")])
    }

    func testAValueTheStyleDoesNotOfferIsKept() throws {
        let house = try guide("house")
        let song = Project()
        let cases: [(StyleChoice, StylePart)] = [
            (StyleChoice(parts: [.tempo], tempo: 200), .tempo),
            (StyleChoice(parts: [.tempo], tempo: 117.99), .tempo),
            (StyleChoice(parts: [.tempo], tempo: .nan), .tempo),
            (StyleChoice(parts: [.scale], scale: "lydian"), .scale),
            (StyleChoice(parts: [.toneSystem], toneSystem: "edo24"), .toneSystem),
            (StyleChoice(parts: [.swing], swingPercent: 60), .swing),
            (StyleChoice(parts: [.swing], swingPercent: .infinity), .swing),
            (StyleChoice(parts: [.sections], firstSectionBar: 0), .sections),
        ]
        for (choice, part) in cases {
            let frame = house.frame(choice, for: song)
            XCTAssertEqual(frame.kept[part], .notInTheStyle, "\(choice)")
            XCTAssertTrue(frame.commands.isEmpty, "\(choice)")
        }
        XCTAssertEqual(house.frame(StyleChoice(parts: [.tempo], tempo: 130), for: song).commands, [.setTempo(bpm: 130)],
                       "the top of the window is in it")
    }

    // MARK: - Swing

    func testSwingIsStudiosExactAmountOfThePercent() {
        let pairs: [(percent: Double, amount: Double)] = [(50, 0), (52, 0.12), (54, 0.24), (55, 0.3), (56, 0.36),
                                                          (58, 0.48), (60, 0.6), (62, 0.72), (66, 0.96)]
        for pair in pairs {
            XCTAssertEqual(StyleGuide.SwingWindow.studioAmount(percent: pair.percent), pair.amount, "\(pair.percent) %")
        }
        XCTAssertEqual(StyleGuide.SwingWindow.studioAmount(percent: 200.0 / 3), 1, "the 2 : 1 triplet is Studio's full swing")
        let beyondTriplet: [Double] = [66.7, 69, 75, 49.9, -1, .nan, .infinity]
        for beyond in beyondTriplet {
            XCTAssertNil(StyleGuide.SwingWindow.studioAmount(percent: beyond), "\(beyond) %")
        }
    }

    func testTheSongsSwingForAPercentFollowsTheGrid() throws {
        let sixteenths = try guide("house").swing
        XCTAssertEqual(sixteenths.songSwing(atPercent: 54), 0.24, "16ths: Studio's exact amount")
        XCTAssertNil(try guide("uk_garage").swing.songSwing(atPercent: 69), "16ths past the triplet")
        XCTAssertEqual(try guide("trance").swing.songSwing(atPercent: 50), 0, "a straight style plays straight")
        let eighths = try guide("swing").swing
        let inTheNotes: [Double] = [50, 60, 200.0 / 3, 72, 75]
        for percent in inTheNotes {
            XCTAssertEqual(eighths.songSwing(atPercent: percent), 0, "8ths at \(percent) %: the swing is in the notes")
        }
        let noSwing: [Double] = [49.9, 100, .nan, .infinity, -.infinity]
        for percent in noSwing {
            XCTAssertNil(eighths.songSwing(atPercent: percent), "\(percent) %")
            XCTAssertNil(sixteenths.songSwing(atPercent: percent), "\(percent) %")
        }
    }

    func testSwingPastTheTripletIsKeptAndTheRestOfTheWindowApplies() throws {
        let song = Project()
        let garage = try guide("uk_garage")
        XCTAssertEqual(garage.frame(StyleChoice(parts: [.swing]), for: song).commands, [.setSwing(0.48)], "the low end, 58 %")
        XCTAssertEqual(garage.frame(StyleChoice(parts: [.swing], swingPercent: 66), for: song).commands, [.setSwing(0.96)])
        XCTAssertEqual(garage.frame(StyleChoice(parts: [.swing], swingPercent: 200.0 / 3), for: song).commands, [.setSwing(1)])
        let late = garage.frame(StyleChoice(parts: [.swing], swingPercent: 69), for: song)
        XCTAssertEqual(late.kept[.swing], .swingBeyondStudio, "68–69 % is programmed in the style, past the 2 : 1 Studio plays")
        XCTAssertTrue(late.commands.isEmpty)
        // A straight style sets straight time.
        let trance = try guide("trance")
        XCTAssertEqual(trance.frame(StyleChoice(parts: [.swing]), for: song).commands, [.setSwing(0)])
    }

    func testSwingOnTheEighthsGridIsInTheNotesSoTheFrameSetsTheSongStraight() async throws {
        // A song the musician swung: each style written on a triplet grid sets it straight.
        let song = Project(context: MusicalContext(swing: 0.5))
        for id in ["swing", "bebop", "blues"] {
            let style = try guide(id)
            XCTAssertEqual(style.swing.grid, .eighths, id)
            XCTAssertEqual(style.drums?.step, .eighthTriplet, "\(id) is written on a triplet grid")
            let own = style.frame(StyleChoice(parts: [.swing]), for: song)
            XCTAssertEqual(own.commands, [.setSwing(0)], id)
            XCTAssertEqual(own.applied, [.swing], id)
            XCTAssertEqual(own.kept, [:], id)
            let top = style.frame(StyleChoice(parts: [.swing], swingPercent: style.swing.percent.upperBound), for: song)
            XCTAssertEqual(top.commands, [.setSwing(0)], "\(id): every swing of its window is in the notes")
        }
        XCTAssertEqual(try guide("bebop").swing.percent.lowerBound, 50, "bebop's own swing is straight 8ths")
        let outside = try guide("swing").frame(StyleChoice(parts: [.swing], swingPercent: 75), for: song)
        XCTAssertEqual(outside.kept[.swing], .notInTheStyle, "the style's window is 60 … 72 %")
        XCTAssertTrue(outside.commands.isEmpty)

        // Why straight: the song's swing moves the triplet steps inside each 8th.
        XCTAssertEqual(Swing(0.5).position(of: 320), 320 + 80.0 / 3, accuracy: 1e-9)
        let blues = try guide("blues")
        let drums = try XCTUnwrap(blues.drums)
        let steps = (0..<(drums.stepsPerBar * drums.bars)).map { (index: Int) -> Tick in Tick(index) * drums.step.ticks }
        XCTAssertEqual(steps.count, 12)
        try await MainActor.run {
            let store = ProjectStore(project: song)
            let frame = blues.frame(for: song)
            XCTAssertTrue(frame.applied.contains(.swing))
            try store.perform(frame.commands, title: frame.title)
            XCTAssertEqual(store.project.context.swing, 0)
            let played = Swing(store.project.context.swing)
            for tick in steps {
                XCTAssertEqual(played.position(of: tick), Double(tick), "the step on \(tick) sounds where the style writes it")
            }
            store.undo()
            XCTAssertEqual(store.project, song)
        }
    }

    // MARK: - Meter and sections

    func testSectionMarkersLandOnTheBarsOfTheForm() throws {
        let house = try guide("house")
        let frame = house.frame(StyleChoice(parts: [.sections]), for: Project())
        XCTAssertEqual(frame.commands, [
            .addMarker(at: 0, name: "Intro"),
            .addMarker(at: 16 * bar, name: "Build"),
            .addMarker(at: 24 * bar, name: "Main"),
            .addMarker(at: 56 * bar, name: "Breakdown"),
            .addMarker(at: 72 * bar, name: "Main"),
            .addMarker(at: 104 * bar, name: "Outro"),
        ])
        XCTAssertEqual(frame.applied, [.sections])
        XCTAssertEqual(frame.occupiedBars, [])
        let later = house.frame(StyleChoice(parts: [.sections], firstSectionBar: 9), for: Project())
        XCTAssertEqual(later.commands.first, .addMarker(at: 8 * bar, name: "Intro"))
        XCTAssertEqual(try guide("pop").frame(StyleChoice(parts: [.sections]), for: Project()).commands[2],
                       .addMarker(at: 24 * bar, name: "Pre-chorus"), "the name with a capital first letter")
    }

    func testSectionMarkersCountTheMeterTheFrameSets() async throws {
        let aksak = try guide("balkan_aksak")
        let song = Project()
        let frame = aksak.frame(StyleChoice(parts: [.meter, .sections]), for: song)
        let sevenEight = MusicalTime.ticksPerBar(TimeSignature(7, 8))
        XCTAssertEqual(sevenEight, 3_360)
        XCTAssertEqual(frame.commands, [
            .setTimeSignature(TimeSignature(7, 8)),
            .addMarker(at: 0, name: "A"),
            .addMarker(at: 8 * sevenEight, name: "A"),
            .addMarker(at: 16 * sevenEight, name: "B"),
            .addMarker(at: 24 * sevenEight, name: "B"),
        ])
        try await MainActor.run {
            let store = ProjectStore(project: song)
            try store.perform(frame.commands, title: frame.title)
            XCTAssertEqual(store.project.markers.map(\.tick), [0, 26_880, 53_760, 80_640])
            XCTAssertTrue(store.project.markers.allSatisfy { store.project.meterMap.isBarLine($0.tick) })
            store.undo()
            XCTAssertEqual(store.project, song)
        }
    }

    func testSectionMarkersFollowTheSongsMeterChangesAndSkipABarThatHoldsOne() throws {
        let house = try guide("house")
        // 4/4 for eight bars, then 3/4; the musician's marker on bar 25.
        let threeFour = MusicalTime.ticksPerBar(TimeSignature(3, 4))
        let change = 8 * bar
        let mine = Marker(tick: change + 16 * threeFour, name: "My Verse")
        let song = Project(timeSignatureChanges: [TimeSignatureChange(tick: change, signature: TimeSignature(3, 4))],
                           markers: [mine])
        let frame = house.frame(StyleChoice(parts: [.sections]), for: song)
        XCTAssertEqual(frame.commands, [
            .addMarker(at: 0, name: "Intro"),
            .addMarker(at: change + 8 * threeFour, name: "Build"),
            .addMarker(at: change + 48 * threeFour, name: "Breakdown"),
            .addMarker(at: change + 64 * threeFour, name: "Main"),
            .addMarker(at: change + 96 * threeFour, name: "Outro"),
        ], "bar 17 is the ninth bar of 3/4; bar 25 holds the musician's marker")
        XCTAssertEqual(frame.occupiedBars, [25])
        for command in frame.commands {
            guard case let .addMarker(tick, _) = command else { continue }
            XCTAssertTrue(song.meterMap.isBarLine(tick), "\(tick)")
        }
        // Every bar already marked: nothing to add, and the song keeps its own markers.
        let full = Project(markers: [0, 16, 24, 56, 72, 104].map { (index: Tick) -> Marker in Marker(tick: index * bar, name: "Mine") })
        let none = house.frame(StyleChoice(parts: [.sections]), for: full)
        XCTAssertEqual(none.kept[.sections], .markersStandThere)
        XCTAssertEqual(none.occupiedBars, [1, 17, 25, 57, 73, 105])
        XCTAssertTrue(none.commands.isEmpty)
    }

    func testAFormWithoutBarCountsPlacesNoMarker() throws {
        for id in ["hindustani_raga", "maqam", "gamelan", "classical"] {
            let frame = try guide(id).frame(StyleChoice(parts: [.sections]), for: Project())
            XCTAssertEqual(frame.kept[.sections], .sectionsWithoutBars, id)
            XCTAssertTrue(frame.commands.isEmpty, id)
        }
    }

    func testAPartTheSongRefusesIsKeptAndTheOthersStillApply() async throws {
        let aksak = try guide("balkan_aksak")
        // A change to 3/4 on bar 2 is no bar line of 7/8 (3 840 ticks are not whole bars of 3 360).
        let song = Project(tempo: 100, timeSignatureChanges: [TimeSignatureChange(tick: bar, signature: TimeSignature(3, 4))])
        let frame = aksak.frame(StyleChoice(parts: [.tempo, .meter, .sections]), for: song)
        guard case .refused(let error)? = frame.kept[.meter] else {
            return XCTFail("the meter is refused: \(frame.kept)")
        }
        XCTAssertFalse(error.sentence.isEmpty)
        XCTAssertEqual(frame.applied, [.tempo, .sections])
        XCTAssertEqual(frame.commands.first, .setTempo(bpm: 180))
        XCTAssertEqual(frame.commands[1], .addMarker(at: 0, name: "A"))
        XCTAssertEqual(frame.commands[2], .addMarker(at: song.meterMap.tick(ofBar: 8), name: "A"), "markers count the song's own meter")
        try await MainActor.run {
            let store = ProjectStore(project: song)
            try store.perform(frame.commands, title: frame.title)
            XCTAssertEqual(store.project.timeSignature, .common)
            XCTAssertEqual(store.project.tempo, 180)
            XCTAssertEqual(store.undoStack.count, 1)
        }
        // Sections that run past the end of the song are refused whole, never cut off.
        let house = try guide("house")
        let late = house.frame(StyleChoice(parts: [.sections], firstSectionBar: 9_999), for: Project())
        guard case .refused? = late.kept[.sections] else { return XCTFail("\(late.kept)") }
        XCTAssertTrue(late.commands.isEmpty)
        let far = house.frame(StyleChoice(parts: [.sections], firstSectionBar: .max), for: Project())
        guard case .refused? = far.kept[.sections] else { return XCTFail("\(far.kept)") }
    }

    // MARK: - Helpers

    private func guide(_ id: String) throws -> StyleGuide {
        try XCTUnwrap(StyleLibrary.standard.guide(id), id)
    }

    /// The table's style `id` with one field changed, read as a style of its own.
    private func guide(_ id: String, changing change: (inout [String: Any]) -> Void) throws -> StyleGuide {
        let object = try JSONSerialization.jsonObject(with: Data(StyleLibraryData.json.utf8))
        let entries = try XCTUnwrap(object as? [[String: Any]])
        var entry = try XCTUnwrap(entries.first { $0["id"] as? String == id }, id)
        change(&entry)
        return try JSONDecoder().decode(StyleGuide.self, from: JSONSerialization.data(withJSONObject: entry))
    }
}

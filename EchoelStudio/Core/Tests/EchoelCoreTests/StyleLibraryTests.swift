import Foundation
import XCTest
@testable import EchoelCore

/// The reference table of styles and vibes (S1): it reads whole, every entry fits what Studio's
/// commands accept, a fault leaves one entry out and is named, and no text meant for the screen says
/// what Echoel never says. A § is a section of the research the table comes from,
/// `research_notes/2026-11-27_genres-and-vibes.md` in the private repo echoelmusic-intern.
final class StyleLibraryTests: XCTestCase {
    private var library: StyleLibrary { StyleLibrary.standard }

    func testTheTableReadsWholeWithNothingLeftOut() {
        XCTAssertEqual(library.problems, [])
        XCTAssertEqual(library.guides.count, 68)
        XCTAssertEqual(library.vibes.count, 13)
        let families = Dictionary(grouping: library.guides, by: \.family).mapValues(\.count)
        XCTAssertEqual(families[.electronic], 33)
        XCTAssertEqual(families[.band], 25)
        XCTAssertEqual(families[.tradition], 10)
        XCTAssertEqual(library.guide("house")?.name, "House")
        XCTAssertEqual(library.vibe("dark")?.name, "Dark")
        XCTAssertNil(library.guide("dark"), "a vibe is no style")
        XCTAssertNil(library.vibe("house"), "a style is no vibe")
    }

    func testEveryIdIsOneSnakeCaseNameOnce() {
        let ids = library.guides.map(\.id) + library.vibes.map(\.id)
        XCTAssertEqual(ids.count, 81)
        XCTAssertEqual(Set(ids).count, ids.count, "every id once, styles and vibes together")
        for id in ids {
            XCTAssertNotNil(id.range(of: "^[a-z][a-z0-9]*(_[a-z0-9]+)*$", options: .regularExpression), id)
        }
    }

    func testTheTableReadsAsTheResearchWroteIt() throws {
        let house = try XCTUnwrap(library.guide("house"))
        XCTAssertEqual(house.tempo.range, 118...130)
        XCTAssertEqual(house.tempo.typical, 124)
        XCTAssertEqual(house.meter.signature, .common)
        XCTAssertEqual(house.meter.groups, [1, 1, 1, 1])
        XCTAssertEqual(house.swing.grid, .sixteenths)
        XCTAssertEqual(house.swing.percent, 50...58)
        XCTAssertEqual(house.scales, ["minor", "dorian", "major"])
        XCTAssertEqual(house.toneSystems, ["edo12"])
        XCTAssertEqual(house.drums?.step, .sixteenth)
        XCTAssertEqual(house.drums?.lanes.first?.name, "kick")
        XCTAssertEqual(house.drums?.lanes.first?.note, 36)
        XCTAssertEqual(house.drums?.lanes.first?.steps, "x...|x...|x...|x...")
        XCTAssertEqual(house.drums?.verifiedBySource, true)
        XCTAssertEqual(house.sections.map(\.bars), [16, 8, 32, 16, 32, 16])
        XCTAssertEqual(house.uncertainty.level, .low)
        XCTAssertEqual(house.sources.count, 3)
        XCTAssertTrue(house.rhythmFigures.isEmpty, "absent in the table is none")
        XCTAssertNil(house.feltBeat)

        // A pulse that is not the quarter note still counts Studio BPM in quarter notes.
        let flamenco = try XCTUnwrap(library.guide("flamenco"))
        XCTAssertEqual(flamenco.meter.signature, TimeSignature(12, 8))
        XCTAssertEqual(flamenco.meter.groups, [3, 3, 2, 2, 2])
        let felt = try XCTUnwrap(flamenco.feltBeat)
        XCTAssertEqual(felt.note, "1/8")
        XCTAssertEqual(felt.quarters, 0.5)
        XCTAssertEqual(felt.typical * 0.5, flamenco.tempo.typical, "224 eighths a minute are 112 quarters")
        XCTAssertEqual(try XCTUnwrap(library.guide("west_african")).feltBeat?.quarters, 1.5, "a dotted quarter")
        XCTAssertEqual(try XCTUnwrap(library.guide("tango")).feltBeat?.quarters, 2)

        // Gongs are pitched and have no General MIDI drum; a free form has no bar counts.
        let gamelan = try XCTUnwrap(library.guide("gamelan"))
        XCTAssertEqual(gamelan.drums?.step, .quarter)
        XCTAssertEqual(gamelan.drums?.lanes.map(\.note), [nil, nil, nil])
        let raga = try XCTUnwrap(library.guide("hindustani_raga"))
        XCTAssertNil(raga.drums)
        XCTAssertEqual(raga.sections.map(\.bars), [nil, nil, nil, nil])
        XCTAssertEqual(raga.rhythmFigures.first?.steps, "X...|x...|....|x...")
        XCTAssertNil(raga.rhythmFigures.last?.steps, "a figure told in words only")

        // The one swing beyond what Studio plays, and the 8th-note swing Studio writes as triplets.
        XCTAssertEqual(try XCTUnwrap(library.guide("uk_garage")).swing.percent, 58...69)
        XCTAssertEqual(try XCTUnwrap(library.guide("swing")).swing.grid, .eighths)
        XCTAssertEqual(try XCTUnwrap(library.guide("swing")).drums?.step, .eighthTriplet)

        let hazy = try XCTUnwrap(library.vibe("hazy"))
        XCTAssertEqual(hazy.name, "Hazy")
        XCTAssertEqual(hazy.tempoFactor, 0.85...1)
        XCTAssertEqual(hazy.modes, ["lydian", "major", "majorPentatonic"])
        XCTAssertEqual(hazy.articulation, 0.75...1)
        XCTAssertEqual(hazy.instrumentMood, "Warm")
        XCTAssertEqual(hazy.evidence, .convention)
        XCTAssertEqual(library.vibe("repetitive")?.name, "Repetitive")
        // The research's `dreamy` and `hypnotic` took musical words before any id was named.
        XCTAssertNil(library.vibe("dreamy"))
        XCTAssertNil(library.vibe("hypnotic"))
        XCTAssertNil(try XCTUnwrap(library.vibe("raw")).instrumentMood)
    }

    func testEveryTempoWindowLiesInsideStudiosTempo() {
        for guide in library.guides {
            XCTAssertTrue(Tempo.range.contains(guide.tempo.range.lowerBound), guide.id)
            XCTAssertTrue(Tempo.range.contains(guide.tempo.range.upperBound), guide.id)
            XCTAssertTrue(guide.tempo.range.contains(guide.tempo.typical), guide.id)
        }
        for vibe in library.vibes {
            XCTAssertGreaterThan(vibe.tempoFactor.lowerBound, 0, vibe.id)
            XCTAssertTrue((0...1).contains(vibe.articulation.lowerBound) && (0...1).contains(vibe.articulation.upperBound), vibe.id)
        }
    }

    func testEveryMeterIsATimeSignatureStudioCountsAndItsGroupsFillTheBar() {
        for guide in library.guides {
            XCTAssertTrue(guide.meter.signature.isValid, guide.id)
            XCTAssertEqual(guide.meter.groups.reduce(0, +), guide.meter.signature.numerator, guide.id)
        }
        XCTAssertEqual(library.guide("balkan_aksak")?.meter.signature, TimeSignature(7, 8))
        XCTAssertEqual(library.guide("balkan_aksak")?.meter.groups, [2, 2, 3])
        XCTAssertEqual(library.guide("carnatic")?.meter.signature, TimeSignature(8, 4))
    }

    func testEveryStepStringIsOneTheAssistantWritesAndFillsItsBars() throws {
        var lanes = 0
        var figures = 0
        for guide in library.guides {
            if let drums = guide.drums {
                XCTAssertEqual(Tick(drums.stepsPerBar) * drums.step.ticks, MusicalTime.ticksPerBar(guide.meter.signature),
                               "\(guide.id): the steps fill one bar exactly")
                for lane in drums.lanes {
                    let steps = try AgentTools.pattern(lane.steps)
                    XCTAssertEqual(steps.count, drums.stepsPerBar * drums.bars, "\(guide.id) \(lane.name)")
                    if let note = lane.note { XCTAssertTrue(Note.pitchRange.contains(note), "\(guide.id) \(lane.name)") }
                    lanes += 1
                }
            }
            for figure in guide.rhythmFigures {
                guard let steps = figure.steps else { continue }
                XCTAssertFalse(try AgentTools.pattern(steps).isEmpty, "\(guide.id) \(figure.part)")
                figures += 1
            }
        }
        // Counted so that a loop over nothing cannot pass (the research's §14).
        XCTAssertEqual(lanes, 172)
        XCTAssertEqual(figures, 27)
        XCTAssertEqual(library.guides.filter { $0.drums == nil }.count, 12)
        XCTAssertEqual(library.guides.filter { $0.drums?.verifiedBySource == true }.count, 19)
        XCTAssertEqual(StyleGuide.DrumSkeleton.Step.allCases.map(\.ticks), [240, 320, 480, 960])
    }

    func testEveryScaleAndToneSystemIsOneOfThisBuildOrAKnownPendingOne() {
        var named = 0
        for guide in library.guides {
            for name in guide.scales {
                named += 1
                if let scale = Scale(rawValue: name) {
                    if let expected = StyleLibrary.pendingScales[name] {
                        XCTAssertEqual(scale.intervals, Set(expected), "\(name) in this build is the pitch set the table means")
                    }
                } else {
                    XCTAssertNotNil(StyleLibrary.pendingScales[name], "\(guide.id): \(name) is neither a scale nor pending")
                }
            }
            for id in guide.toneSystems {
                named += 1
                let known = TuningSystem.library.contains { $0.id == id }
                XCTAssertTrue(known || StyleLibrary.pendingToneSystems.contains(id), "\(guide.id): \(id)")
            }
        }
        for vibe in library.vibes {
            for name in vibe.modes {
                named += 1
                XCTAssertTrue(Scale(rawValue: name) != nil || StyleLibrary.pendingScales[name] != nil, "\(vibe.id): \(name)")
            }
            if let mood = vibe.instrumentMood {
                XCTAssertTrue(InstrumentMood.all.contains { $0.name == mood }, "\(vibe.id): \(mood)")
            }
        }
        XCTAssertGreaterThan(named, 81)
        // Nothing pending that no entry uses, and every pending pitch set a scale of its own.
        let used = Set(library.guides.flatMap(\.scales) + library.vibes.flatMap(\.modes))
        XCTAssertEqual(Set(StyleLibrary.pendingScales.keys).subtracting(used), [])
        XCTAssertEqual(StyleLibrary.pendingToneSystems.subtracting(Set(library.guides.flatMap(\.toneSystems))), [])
        for (name, steps) in StyleLibrary.pendingScales {
            XCTAssertEqual(steps.first, 0, name)
            XCTAssertEqual(steps, steps.sorted(), name)
            XCTAssertTrue(steps.allSatisfy { (0...11).contains($0) }, name)
        }
    }

    func testEveryStatedSwingIsStudiosExactAmount() {
        var eighths: [String] = []
        for guide in library.guides {
            let swing = guide.swing
            XCTAssertGreaterThanOrEqual(swing.percent.lowerBound, 50, guide.id)
            let ends = [swing.percent.lowerBound, swing.percent.upperBound]
            // The research states the formula's amount, none on the 8th grid, where it does not apply.
            let expected = ends.map { (percent: Double) -> Double? in
                swing.grid == .eighths ? nil : StyleGuide.SwingWindow.studioAmount(percent: percent)
            }
            XCTAssertEqual(swing.statedAmounts ?? [nil, nil], expected, guide.id)
            if swing.grid == .straight { XCTAssertEqual(swing.percent, 50...50, guide.id) }
            if swing.grid == .eighths {
                eighths.append(guide.id)
                // Written on a triplet grid with the song's swing straight, as the research's note says.
                XCTAssertEqual(ends.map { (percent: Double) -> Double? in swing.songSwing(atPercent: percent) }, [0, 0], guide.id)
                XCTAssertEqual(guide.drums?.step, .eighthTriplet, guide.id)
            }
        }
        XCTAssertEqual(eighths, ["swing", "bebop", "blues"])
        XCTAssertEqual(library.guide("house")?.swing.statedAmounts, [0, 0.48])
        XCTAssertEqual(library.guide("uk_garage")?.swing.statedAmounts, [0.48, nil])
    }

    func testEverySourceIsAnHTTPSLinkKeptAsData() throws {
        var links = 0
        let owners: [(id: String, sources: [URL])] = library.guides.map { ($0.id, $0.sources) }
            + library.vibes.map { ($0.id, $0.sources) }
        for (id, sources) in owners {
            XCTAssertFalse(sources.isEmpty, id)
            for url in sources {
                XCTAssertEqual(url.scheme, "https", id)
                XCTAssertFalse((url.host ?? "").isEmpty, id)
                links += 1
            }
        }
        XCTAssertEqual(links, 246, "the research's §14")
    }

    // MARK: - Language

    /// Words the language law forbids beyond the shared list (`LearnGuideTests.forbiddenWords`):
    /// the esoteric framing a style text could slip into.
    private static let esotericWords: Set<String> = [
        "esoteric", "spiritual", "spirituality", "mystic", "mystical", "aura", "auras", "hypnosis", "hypnotic",
        "cure", "cures", "curing", "wellbeing", "mindful", "mindfulness", "chakra", "vibrational",
    ]

    /// The research's mark for a claim no source confirmed: it stands in `uncertainty.notes`, with
    /// the other reasons, never in a text for the screen.
    private static let researchMarks: Set<String> = ["unverified"]

    /// Sources, makers, products and people a style text must not name: the magazines, schools and
    /// tools the research read, the makers producers name sounds after, and the artists and authors
    /// the research's notes mention. Compared as whole words, lower-cased.
    private static let brandNames: [String] = [
        "ableton", "attack magazine", "bandcamp", "berklee", "britannica", "chromatone", "compmusic",
        "dj mag", "drumeo", "edmprod", "fiveable", "folkworks", "goethe", "guitar player", "guitar world",
        "hooktheory", "landr", "libretexts", "maqamworld", "masterclass", "mixmag", "musicradar", "musical u",
        "native instruments", "newmusicbox", "orphiq", "perfect circuit", "piano with jonny", "pianogroove",
        "premier guitar", "red bull", "sound on sound", "soundbrenner", "soundtrap", "splice", "wikipedia",
        "wikibooks",
        "akai", "antares", "clavinet", "dx7", "eventide", "fabfilter", "fender", "gibson", "hammond",
        "izotope", "juno", "kontakt", "korg", "lexicon", "linn", "linndrum", "marshall", "mellotron",
        "melodyne", "moog", "mpc", "oberheim", "omnisphere", "rhodes", "roland", "serum", "soundtoys",
        "sp 1200", "sylenth", "tb 303", "tr 808", "tr 909", "303", "808", "909", "valhalla", "wurlitzer",
        "yamaha",
        "agawu", "amen", "d arienzo", "di sarli", "eerola", "eno", "friberg", "john adams", "king tubby",
        "kippen", "kooldrink", "pugliese", "toussaint",
    ]

    func testNoTextMeantForTheScreenSaysWhatEchoelNeverSays() throws {
        let texts = try screenTexts()
        XCTAssertGreaterThan(texts.count, 81 * 10, "the walk reaches every field")
        let forbidden = LearnGuideTests.forbiddenWords.union(Self.esotericWords).union(Self.researchMarks)
        for (id, text) in texts {
            let found = Set(words(text)).intersection(forbidden)
            XCTAssertTrue(found.isEmpty, "\(id): \(found.sorted()) in “\(text)”")
            for phrase in LearnGuideTests.forbiddenPhrases {
                XCTAssertFalse(text.lowercased().contains(phrase), "\(id): \(phrase) in “\(text)”")
            }
        }
    }

    func testNoTextMeantForTheScreenNamesABrandASourceOrAnArtist() throws {
        let texts = try screenTexts()
        for (id, text) in texts {
            let line = " " + words(text).joined(separator: " ") + " "
            for name in Self.brandNames {
                XCTAssertFalse(line.contains(" \(name) "), "\(id): “\(name)” in “\(text)”")
            }
        }
        // The research's notes do name them: the check reads only what a screen may show.
        let notes = library.guides.map(\.uncertainty.notes).joined(separator: " ")
        XCTAssertTrue(" \(words(notes).joined(separator: " ")) ".contains(" wikipedia "))
    }

    func testTheResearchMetadataIsKeptApartFromTheScreenText() throws {
        let texts = try screenTexts().map(\.text)
        XCTAssertFalse(texts.contains { $0.hasPrefix("https://") }, "sources are data, never shown")
        let notes = try XCTUnwrap(library.guide("house")).uncertainty.notes
        XCTAssertFalse(texts.contains(notes), "the research's reasons are not text for the screen")
        XCTAssertTrue(texts.contains("House"))
        XCTAssertTrue(texts.contains("soft, blurred and floating"), "a vibe's description is")
        // A claim no source confirmed keeps its mark among the reasons, where the screen never reads.
        let ethiopian = try XCTUnwrap(library.guide("ethiopian"))
        XCTAssertEqual(ethiopian.uncertainty.level, .high)
        XCTAssertTrue(words(ethiopian.uncertainty.notes).contains("unverified"))
        XCTAssertFalse(words(ethiopian.felt).contains("unverified"))
    }

    // MARK: - Faults

    func testAnEntryTheChecksRefuseIsLeftOutAndNamedNeverGuessed() throws {
        let faults: [(what: String, change: (inout [String: Any]) -> Void)] = [
            ("tempo below Studio's floor", { $0["tempo_bpm"] = ["min": 10, "max": 130, "typical": 124] as [String: Any] }),
            ("typical tempo outside its window", { $0["tempo_bpm"] = ["min": 118, "max": 130, "typical": 140] as [String: Any] }),
            ("a window upside down", { $0["tempo_bpm"] = ["min": 130, "max": 118, "typical": 124] as [String: Any] }),
            ("a meter Studio does not count", { $0["meter"] = ["signature": "4/3", "groups": [1, 1, 1, 1]] as [String: Any] }),
            ("a meter that is no fraction", { $0["meter"] = ["signature": "four", "groups": [1, 1, 1, 1]] as [String: Any] }),
            ("groups that do not fill the bar", { $0["meter"] = ["signature": "4/4", "groups": [2, 1]] as [String: Any] }),
            ("a step outside the grammar", { $0["drums"] = Self.oneLaneDrums(steps: "x..y|x...|x...|x...") }),
            ("a lane one step short", { $0["drums"] = Self.oneLaneDrums(steps: "x...|x...|x...|x..") }),
            ("steps that do not fill the bar", { $0["drums"] = Self.oneLaneDrums(steps: "x...|x...|x...|x...", stepsPerBar: 12) }),
            ("a drum note outside MIDI", { $0["drums"] = Self.oneLaneDrums(steps: "x...|x...|x...|x...", note: 200) }),
            ("a figure outside the grammar", { $0["rhythm_figures"] = [["part": "roll", "steps": "xxq", "note": "n"]] }),
            ("an unknown scale", { $0["scales"] = ["minor", "notAScaleAnywhere"] }),
            ("no scale at all", { $0["scales"] = [String]() }),
            ("an unknown tone system", { $0["tunings"] = ["edo13"] }),
            ("a swing amount off the formula", { $0["swing"] = ["grid": "1/16", "percent": [50, 58], "studio_amount": [0, 0.5]] as [String: Any] }),
            ("swing earlier than straight", { $0["swing"] = ["grid": "1/16", "percent": [40, 58], "studio_amount": [NSNull(), 0.48] as [Any]] as [String: Any] }),
            ("a straight grid that swings", { $0["swing"] = ["grid": "none", "percent": [50, 58], "studio_amount": [0, 0.48]] as [String: Any] }),
            ("an unknown swing grid", { $0["swing"] = ["grid": "1/32", "percent": [50, 50], "studio_amount": [0, 0]] as [String: Any] }),
            ("an id that is not snake_case", { $0["id"] = "Deep House" }),
            ("a section without a name", { $0["sections"] = [["name": "  ", "bars": 16] as [String: Any]] }),
            ("a section of no bars", { $0["sections"] = [["name": "intro", "bars": 0] as [String: Any]] }),
            ("no section at all", { $0["sections"] = [[String: Any]]() }),
            ("a source that is not https", { $0["sources"] = ["http://example.com/house"] }),
            ("no source at all", { $0["sources"] = [String]() }),
            ("no name", { $0["name"] = " " }),
            ("a field missing", { _ = $0.removeValue(forKey: "meter") }),
            ("a kind that is neither", { $0["kind"] = "mood" }),
        ]
        for fault in faults {
            let broken = try entry("house", changing: fault.change)
            let kept = try entry("techno")
            let parsed = StyleLibrary(json: try table([broken, kept]))
            XCTAssertEqual(parsed.guides.map(\.id), ["techno"], "\(fault.what): the faulty entry is left out, the next one stays")
            XCTAssertFalse(parsed.problems.isEmpty, "\(fault.what) is named")
            let id = broken["id"] as? String ?? ""
            XCTAssertTrue(parsed.problems.allSatisfy { $0.hasPrefix(id) }, "\(fault.what): \(parsed.problems)")
        }
    }

    func testAVibeTheChecksRefuseIsLeftOut() throws {
        let faults: [(what: String, change: (inout [String: Any]) -> Void)] = [
            ("an unknown mode", { $0["modes"] = ["notAModeAnywhere"] }),
            ("no mode", { $0["modes"] = [String]() }),
            ("an articulation longer than the note", { $0["articulation"] = [0.5, 1.5] }),
            ("a tempo factor of nothing", { $0["tempo_factor"] = [0, 1] }),
            ("a mood the Instrument page lacks", { $0["instrument_mood"] = "Gloomy" }),
            ("an unknown kind of evidence", { $0["evidence"] = "rumour" }),
            ("a blank description", { $0["description"] = "" }),
        ]
        for fault in faults {
            let parsed = StyleLibrary(json: try table([try entry("dark", changing: fault.change), try entry("warm")]))
            XCTAssertEqual(parsed.vibes.map(\.id), ["warm"], fault.what)
            XCTAssertFalse(parsed.problems.isEmpty, fault.what)
            XCTAssertTrue(parsed.problems.allSatisfy { $0.hasPrefix("dark") }, "\(fault.what): \(parsed.problems)")
        }
    }

    func testASecondEntryOfOneIdIsLeftOut() throws {
        let parsed = StyleLibrary(json: try table([try entry("house"), try entry("house", changing: { $0["name"] = "Other" })]))
        XCTAssertEqual(parsed.guides.map(\.name), ["House"], "the first stays")
        XCTAssertEqual(parsed.problems.count, 1)
        let vibe = StyleLibrary(json: try table([try entry("house"), try entry("dark", changing: { $0["id"] = "house" })]))
        XCTAssertTrue(vibe.vibes.isEmpty, "styles and vibes share one set of ids")
    }

    func testAPendingNameLoadsAndAnyOtherUnknownNameDoesNot() throws {
        // A name a later build brings (TH-4) loads today; the frame says it is not here yet.
        let waiting = StyleLibrary.pendingScales.keys.sorted().filter { Scale(rawValue: $0) == nil }
        for name in waiting {
            let parsed = StyleLibrary(json: try table([try entry("house", changing: { $0["scales"] = [name, "minor"] })]))
            XCTAssertEqual(parsed.problems, [], name)
            XCTAssertEqual(parsed.guides.first?.scales.first, name)
        }
        for id in StyleLibrary.pendingToneSystems where !TuningSystem.library.contains(where: { $0.id == id }) {
            let parsed = StyleLibrary(json: try table([try entry("house", changing: { $0["tunings"] = [id, "edo12"] })]))
            XCTAssertEqual(parsed.problems, [], id)
        }
        let unknown = StyleLibrary(json: try table([try entry("house", changing: { $0["scales"] = ["dorain"] })]))
        XCTAssertTrue(unknown.guides.isEmpty, "a misspelt scale is a fault, not a pending one")
    }

    func testATableThatIsNoListReadsAsEmptyAndSaysWhy() {
        for text in ["", "not json", "{\"id\": \"house\"}", "[1, 2]"] {
            let parsed = StyleLibrary(json: text)
            XCTAssertTrue(parsed.guides.isEmpty && parsed.vibes.isEmpty, text)
            XCTAssertFalse(parsed.problems.isEmpty, text)
        }
    }

    // MARK: - Helpers

    private func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// Every string of the table except the research's metadata, with the id of its entry: the
    /// sources, and the notes of `uncertainty`, which name the magazines, tools and people it read.
    private func screenTexts() throws -> [(id: String, text: String)] {
        var texts: [(id: String, text: String)] = []
        for item in try entries() {
            let id = item["id"] as? String ?? "?"
            var pending: [Any] = [item]
            while let next = pending.popLast() {
                if let text = next as? String {
                    texts.append((id, text))
                } else if let list = next as? [Any] {
                    pending += list
                } else if let object = next as? [String: Any] {
                    for (key, value) in object where key != "sources" {
                        if key == "uncertainty", let inner = value as? [String: Any] {
                            pending.append(inner["level"] ?? "")
                        } else {
                            pending.append(value)
                        }
                    }
                }
            }
        }
        return texts
    }

    /// The table that ships, as JSON objects.
    private func entries() throws -> [[String: Any]] {
        let object = try JSONSerialization.jsonObject(with: Data(StyleLibraryData.json.utf8))
        return try XCTUnwrap(object as? [[String: Any]])
    }

    /// The table's entry `id`, changed by `change`.
    private func entry(_ id: String, changing change: (inout [String: Any]) -> Void = { _ in }) throws -> [String: Any] {
        var found = try XCTUnwrap(try entries().first { $0["id"] as? String == id }, id)
        change(&found)
        return found
    }

    /// `entries` as the text of a table.
    private func table(_ entries: [[String: Any]]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: entries)
        return try XCTUnwrap(String(data: data, encoding: .utf8))
    }

    /// A one-lane drum skeleton for a 4/4 style.
    private static func oneLaneDrums(steps: String, stepsPerBar: Int = 16, note: Int = 36) -> [String: Any] {
        ["step": "1/16", "steps_per_bar": stepsPerBar, "bars": 1, "verified_by_source": false,
         "lanes": [["lane": "kick", "gm": note, "steps": steps]],
         "studio_kit": ["silent": [String](), "plays_as": [String]()]]
    }
}

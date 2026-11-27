import Foundation
import XCTest
@testable import EchoelCore

/// Learn (Recovery 8): every chapter is complete, says nothing the app may not say, names only
/// controls on the one list of names, and can be found by searching.
final class LearnGuideTests: XCTestCase {
    /// Words no Echoel text uses (ContentPipeline/CLAIMS.md §2 and the language law of the root
    /// CLAUDE.md), compared as whole words, lower-cased. Also read by `CycleToneTests`.
    static let forbiddenWords: Set<String> = [
        "wellness", "meditation", "meditate", "meditative", "relax", "relaxing", "relaxation",
        "sleep", "sleeping", "focus", "therapy", "therapeutic", "therapist", "medical", "medicine",
        "medicinal", "heal", "heals", "healing", "binaural", "solfeggio", "chakra", "chakras",
        "autotune", "stress", "longevity", "healthtech", "biohacking", "biohack", "entrainment",
        // "AI" belongs to the assistant alone, and Learn does not describe the assistant.
        "ai",
    ]
    /// Phrases no Echoel text uses.
    static let forbiddenPhrases = ["auto-tune", "40 hz", "healing frequenc"]

    private func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// Every text a chapter shows or searches by.
    private func texts(of chapter: LearnChapter) -> [String] {
        [chapter.title, chapter.summary] + chapter.paragraphs + chapter.keywords
            + chapter.paths.flatMap { $0.map(\.title) }
    }

    /// Where a path may start: a view of the bar at the bottom, the Song menu or a control of the
    /// transport — what is on screen wherever the musician is.
    private static let starts: Set<StudioPlace> = [
        .instrument, .tracks, .arrange, .session, .mixer, .field, .cycleTones,
        .songMenu, .play, .record, .loop, .keys, .click, .more,
    ]

    /// The exports the Song menu keeps in sight under Export, and the submenu that holds the others
    /// (SIMP-4, 2026-11-27): read off `SongMenu` by hand, as every title of the list is.
    private static let exportsInSight: Set<StudioPlace> = [.exportWAV, .exportStems, .exportMIDI, .exportVideo,
                                                           .moreFormats]

    /// What the Instrument page's one row for the body, “Body: Off”, holds while no body source is
    /// on, the Body Voice is off and the tempo is Fixed (SIMP-6, `InstrumentPage`): read off
    /// `InstrumentSurface` by hand, as every title of the list is.
    private static let underBodyOff: Set<StudioPlace> = [.bodySource, .bodyVoice, .tempo]

    private func guideChapter(_ id: String) throws -> LearnChapter {
        try XCTUnwrap(LearnGuide.chapters.first { $0.id == id }, "chapter \(id)")
    }

    func testEveryChapterHasATitleASummaryTextAndAPath() {
        XCTAssertFalse(LearnGuide.chapters.isEmpty)
        for chapter in LearnGuide.chapters {
            XCTAssertFalse(chapter.title.trimmingCharacters(in: .whitespaces).isEmpty, chapter.id)
            XCTAssertFalse(chapter.summary.trimmingCharacters(in: .whitespaces).isEmpty, chapter.id)
            XCTAssertFalse(chapter.paragraphs.isEmpty, chapter.id)
            for paragraph in chapter.paragraphs {
                XCTAssertGreaterThan(paragraph.count, 20, "\(chapter.id): a paragraph says something")
            }
            XCTAssertFalse(chapter.paths.isEmpty, "\(chapter.id) shows the way to its controls")
            for path in chapter.paths { XCTAssertFalse(path.isEmpty, chapter.id) }
        }
        let ids = LearnGuide.chapters.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "chapter ids are unique")
    }

    func testTheGuideCoversWhatTheAppDoesToday() {
        let ids = Set(LearnGuide.chapters.map(\.id))
        for required in ["firstTrack", "sixteenBars", "comping", "sound", "drums", "session", "effects", "body",
                         "instrumentBody", "field", "light", "export", "siri", "safety"] {
            XCTAssertTrue(ids.contains(required), "chapter \(required)")
        }
    }

    func testEveryPathStartsWhereTheMusicianCanStart() {
        for chapter in LearnGuide.chapters {
            for path in chapter.paths {
                guard let first = path.first else { continue }
                XCTAssertTrue(Self.starts.contains(first),
                              "\(chapter.id): “\(LearnChapter.line(path))” starts where nothing is on screen")
            }
        }
    }

    /// The Song menu keeps the everyday exports in sight and the other formats under “More
    /// Formats” (SIMP-4): the export chapter says so and shows the way there, and no path sends the
    /// musician to an export that is no longer straight under Export — Siri's way to Export Stems
    /// among them.
    func testThePathsIntoExportFollowWhatStaysInSight() throws {
        let export = try guideChapter("export")
        XCTAssertTrue(export.quotedNames.contains(StudioPlace.moreFormats.title), "the export chapter names More Formats")
        XCTAssertTrue(export.paths.contains([.songMenu, .exportSection, .moreFormats]))
        XCTAssertTrue(try guideChapter("siri").paths.contains([.songMenu, .exportSection, .exportStems]))
        for chapter in LearnGuide.chapters {
            for path in chapter.paths {
                for index in path.indices.dropLast() where path[index] == .exportSection {
                    XCTAssertTrue(Self.exportsInSight.contains(path[index + 1]),
                                  "\(chapter.id): “\(LearnChapter.line(path))” is under More Formats now")
                }
            }
        }
    }

    /// The Instrument page shows the body as one row, “Body: Off”, while nothing of it is on, and as
    /// cards once something is (SIMP-6): a chapter that shows the way to one of the row's controls on
    /// the page shows the way through the row beside it and names the row, and a way through the
    /// row starts on the page, leads to what the row holds and has the way past it beside it.
    func testThePathsToTheBodyOnTheInstrumentPageFollowWhatIsInSight() throws {
        let allOff = InstrumentPage.sections(bodySourceOn: false, bodyVoiceOn: false, flows: false)
        XCTAssertTrue(allOff.contains(.bodyRow), "the row stands while nothing of the body is on")
        XCTAssertFalse(allOff.contains(.bodyVoice) || allOff.contains(.tempo), "and the cards do not")
        let sourceOn = InstrumentPage.sections(bodySourceOn: true, bodyVoiceOn: false, flows: false)
        XCTAssertTrue(sourceOn.contains(.bodyVoice) && sourceOn.contains(.tempo), "the cards stand once a source is on")
        for chapter in LearnGuide.chapters {
            for path in chapter.paths {
                let way = LearnChapter.line(path)
                if path.count > 1, path[0] == .instrument, Self.underBodyOff.contains(path[1]) {
                    let throughTheRow: [StudioPlace] = [StudioPlace.instrument, .bodyOff] + Array(path.dropFirst())
                    XCTAssertTrue(chapter.paths.contains(throughTheRow),
                                  "\(chapter.id): “\(way)” is under “Body: Off” while nothing of the body is on")
                    XCTAssertTrue(chapter.quotedNames.contains(StudioPlace.bodyOff.title),
                                  "\(chapter.id) names the row")
                }
                guard let row = path.firstIndex(of: .bodyOff) else { continue }
                XCTAssertEqual(row, 1, "\(chapter.id): “\(way)”: the row is on the Instrument page")
                XCTAssertEqual(path.first, .instrument, "\(chapter.id): “\(way)”")
                XCTAssertTrue(path.count > 2 && Self.underBodyOff.contains(path[2]),
                              "\(chapter.id): “\(way)” leads to what the row holds")
                let pastTheRow: [StudioPlace] = [StudioPlace.instrument] + Array(path.dropFirst(2))
                XCTAssertTrue(chapter.paths.contains(pastTheRow),
                              "\(chapter.id): “\(way)”: the way once something of the body is on stands beside it")
            }
        }
        XCTAssertTrue(try guideChapter("instrumentBody").paths.contains([.instrument, .bodyOff, .bodyVoice]))
        XCTAssertTrue(try guideChapter("body").paths.contains([.instrument, .bodyOff, .tempo]))
    }

    /// The lengths the sixteen-bars chapter names are the ones the editor's length menu offers
    /// (`ClipLength.choices`), from one bar to sixteen.
    func testTheSixteenBarsChapterNamesTheLengthsTheEditorOffers() throws {
        let sixteen = try guideChapter("sixteenBars")
        let text = sixteen.paragraphs.joined(separator: " ")
        let longer: [String] = ClipLength.choices.filter { $0 > 1 }.map { String($0) }
        let named = longer.dropLast().joined(separator: ", ") + " or " + (longer.last ?? "")
        XCTAssertTrue(text.contains("\(named) bars"), "the lengths “Repeat the Clip to” offers: \(named)")
        XCTAssertEqual(ClipLength.choices.first, 1)
        XCTAssertEqual(ClipLength.choices.last, 16, "the chapter's title says sixteen")
        XCTAssertTrue(sixteen.title.lowercased().contains("sixteen"))
        for place in [StudioPlace.length, .repeatTheClipTo, .setTheLengthTo] {
            XCTAssertTrue(sixteen.quotedNames.contains(place.title), place.title)
        }
    }

    /// The session chapter shows its controls where they are, in Session, and names the ones that
    /// launch, stop and give the tracks back to the arrangement.
    func testTheSessionChapterShowsItsControlsInSession() throws {
        let session = try guideChapter("session")
        for path in session.paths {
            XCTAssertEqual(path.first, .session, LearnChapter.line(path))
        }
        for place in [StudioPlace.addScene, .stopAll, .backToArrangement, .launchQuantization] {
            XCTAssertTrue(session.quotedNames.contains(place.title), place.title)
        }
    }

    func testNoChapterUsesAForbiddenWord() {
        for chapter in LearnGuide.chapters {
            for text in texts(of: chapter) {
                let found = Set(words(text)).intersection(Self.forbiddenWords)
                XCTAssertTrue(found.isEmpty, "\(chapter.id): \(found.sorted()) in “\(text)”")
                for phrase in Self.forbiddenPhrases {
                    XCTAssertFalse(text.lowercased().contains(phrase), "\(chapter.id): \(phrase)")
                }
                // MPE only as the MPE output.
                let tokens = words(text)
                for (index, token) in tokens.enumerated() where token == "mpe" {
                    XCTAssertEqual(index + 1 < tokens.count ? tokens[index + 1] : "", "out", "\(chapter.id): MPE only as MPE Out")
                }
            }
        }
        for place in StudioPlace.allCases {
            XCTAssertTrue(Set(words(place.title)).intersection(Self.forbiddenWords).isEmpty, place.title)
        }
    }

    func testEveryQuotedNameIsOnTheListOfNames() {
        for chapter in LearnGuide.chapters {
            XCTAssertFalse(chapter.quotedNames.isEmpty, "\(chapter.id) names its controls")
            for name in chapter.quotedNames {
                XCTAssertNotNil(StudioPlace(title: name), "\(chapter.id) names “\(name)”, which the list does not hold")
            }
        }
    }

    func testTheListOfNamesHasOneTitlePerPlace() {
        let titles = StudioPlace.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count, "two places with one name could not be told apart")
        for place in StudioPlace.allCases {
            XCTAssertEqual(StudioPlace(title: place.title), place)
            XCTAssertEqual(place.title, place.title.trimmingCharacters(in: .whitespaces))
        }
        XCTAssertNil(StudioPlace(title: "Make It Sound Good"))
    }

    /// One word per function (SIMP-10b): the note editor's menu of Quantize and Humanize is called
    /// “Quantize”, as its sections are, and the word it had before names nothing.
    func testTheNoteEditorsTimingMenuIsCalledQuantize() {
        XCTAssertEqual(StudioPlace(title: "Quantize"), .quantize)
        XCTAssertNil(StudioPlace(title: "Timing"))
    }

    func testTheNamesTheModelCarriesAreSpelledAsTheModelSpellsThem() {
        let engines = SynthParameter.engine.choices
        XCTAssertTrue(engines.contains(StudioPlace.wavetable.title))
        XCTAssertTrue(engines.contains(StudioPlace.texture.title))
        XCTAssertEqual(StudioPlace.engine.title, SynthParameter.engine.title)
        XCTAssertEqual(StudioPlace.character.title, SynthParameter.character.title)
        XCTAssertEqual(StudioPlace.rule.title, SynthParameter.textureRule.title)
        XCTAssertEqual(StudioPlace.density.title, SynthParameter.textureDensity.title)
        XCTAssertEqual(StudioPlace.evolveRate.title, SynthParameter.textureRate.title)
        XCTAssertEqual(StudioPlace.seed.title, SynthParameter.textureSeed.title)
        XCTAssertEqual(StudioPlace.accent.title, SynthParameter.accent.title)
        XCTAssertEqual(StudioPlace.synth.title, InstrumentDevice.synth.title)
        XCTAssertEqual(StudioPlace.drums.title, InstrumentDevice.drums.title)
        XCTAssertEqual(StudioPlace.sampler.title, InstrumentDevice.sampler.title)
        XCTAssertEqual(StudioPlace.eq.title, StandardEffect.equalizer.title)
        XCTAssertEqual(StudioPlace.compressor.title, StandardEffect.compressor.title)
        XCTAssertEqual(StudioPlace.delay.title, StandardEffect.delay.title)
        XCTAssertEqual(StudioPlace.reverb.title, StandardEffect.reverb.title)
        XCTAssertEqual(StudioPlace.pitchCorrection.title, StandardEffect.pitchCorrection.title)
    }

    func testTheBodyChapterStatesItsLimits() throws {
        let body = try XCTUnwrap(LearnGuide.chapters.first { $0.id == "body" }).paragraphs.joined(separator: " ")
        XCTAssertTrue(body.contains("Apple Health arrives late"), "the Apple Health delay, with no figure Apple does not give")
        let freshMinutes = HealthPulse.freshSeconds / 60
        XCTAssertEqual(freshMinutes, freshMinutes.rounded(), "the Health window is whole minutes, as the text says it")
        XCTAssertGreaterThan(freshMinutes, 1, "the text says \"minutes\"")
        XCTAssertTrue(body.contains("older than \(Int(freshMinutes)) minutes moves nothing"),
                      "the age past which the Health source moves nothing")
        XCTAssertTrue(body.contains("never sets the beat"))
        XCTAssertTrue(body.contains("self-observation"))
        XCTAssertTrue(body.contains("not a diagnosis"))
        let safety = try XCTUnwrap(LearnGuide.chapters.first { $0.id == "safety" }).paragraphs.joined(separator: " ")
        XCTAssertTrue(safety.contains("3 Hz"))
        XCTAssertTrue(safety.contains("moderate level"))
        XCTAssertTrue(safety.contains("self-observation"))
    }

    func testSearchFindsChaptersByAnyWordWithoutRegardToCaseOrAccents() {
        XCTAssertEqual(LearnGuide.search("").map(\.id), LearnGuide.chapters.map(\.id))
        XCTAssertEqual(LearnGuide.search("   ").count, LearnGuide.chapters.count)
        XCTAssertEqual(LearnGuide.search("Resolve").map(\.id), ["export"])
        XCTAssertEqual(LearnGuide.search("RÉSOLVE").map(\.id), ["export"])
        XCTAssertTrue(LearnGuide.search("slice pads").map(\.id).contains("drums"))
        XCTAssertTrue(LearnGuide.search("body source").map(\.id).contains("body"), "a path's step is searched")
        XCTAssertTrue(LearnGuide.search("beamer").map(\.id).contains("field"), "a keyword is searched")
        XCTAssertEqual(LearnGuide.search("wavetable xylophone-quartz"), [])
    }

    func testAPathReadsAsOneLineAndAsSpokenSteps() {
        let path: [StudioPlace] = [.songMenu, .connectSection, .bodySource]
        XCTAssertEqual(LearnChapter.line(path), "Song menu › Connect › Body Source")
        XCTAssertEqual(LearnChapter.spoken(path), "Song menu, then Connect, then Body Source")
    }

    func testQuotedNamesAreReadBetweenTypographicQuotes() {
        XCTAssertEqual(LearnGuide.quotedNames(in: "Use “Loop”, then “Record”. A “dangling"), ["Loop", "Record"])
        XCTAssertEqual(LearnGuide.quotedNames(in: "nothing quoted"), [])
    }
}

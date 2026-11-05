import Foundation
import XCTest
@testable import EchoelCore

/// Learn (Recovery 8): every chapter is complete, says nothing the app may not say, names only
/// controls on the one list of names, and can be found by searching.
final class LearnGuideTests: XCTestCase {
    /// Words no Echoel text uses (ContentPipeline/CLAIMS.md §2 and the language law of the root
    /// CLAUDE.md), compared as whole words, lower-cased.
    private static let forbiddenWords: Set<String> = [
        "wellness", "meditation", "meditate", "meditative", "relax", "relaxing", "relaxation",
        "sleep", "sleeping", "focus", "therapy", "therapeutic", "therapist", "medical", "medicine",
        "medicinal", "heal", "heals", "healing", "binaural", "solfeggio", "chakra", "chakras",
        "autotune", "stress", "longevity", "healthtech", "biohacking", "biohack", "entrainment",
        // "AI" belongs to the assistant alone, and Learn does not describe the assistant.
        "ai",
    ]
    /// Phrases no Echoel text uses.
    private static let forbiddenPhrases = ["auto-tune", "40 hz", "healing frequenc"]

    private func words(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// Every text a chapter shows or searches by.
    private func texts(of chapter: LearnChapter) -> [String] {
        [chapter.title, chapter.summary] + chapter.paragraphs + chapter.keywords
            + chapter.paths.flatMap { $0.map(\.title) }
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
        for required in ["firstTrack", "comping", "sound", "drums", "effects", "body", "field", "light",
                         "export", "siri", "safety"] {
            XCTAssertTrue(ids.contains(required), "chapter \(required)")
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
        XCTAssertTrue(body.contains("4–5 seconds late"), "the Apple Health latency")
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

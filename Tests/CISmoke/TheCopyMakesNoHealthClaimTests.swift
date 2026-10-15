// TheCopyMakesNoHealthClaimTests.swift
// Echoel — the wording guard (founder 2026-10-15, tip 4: "red terms in CI"). Every sentence the
// app, the website or the store text says is read for the struck vocabulary — therapeutic,
// therapy, healing, wellbeing, wellness, Solfeggio, chakra, binaural beats, 40 Hz, and their German
// store-text forms (Therapie, Heilung, Wohlbefinden) — and a sentence
// that names one must DENY it ("not therapy", "no healing frequencies", "don't describe it as …"),
// be the mandated safety warning ("coordinate any therapeutic use with your provider"), or carry a
// proper name ("Super Natural Healing Killers", "self-healing" engine).
//
// ⛔ WHY NOT A PLAIN WORD BAN. `WebsitePagesAreFindableAndHonestTests` measured that one and
// declined it: every hit on the site was a negation, i.e. the site being correct. A word ban goes
// red on the repair and gets deleted (#364). Measured again 2026-10-15 over the three surfaces
// below: every hit was a denial, the mandated warning or a name. So the unit here is the SENTENCE.
//
// THE CLAIMS.
//   1. END-TO-END BEHAVIOUR (the rule on literals): an affirmative sentence is caught, the four
//      legitimate shapes pass, and "140 Hz" is not "40 Hz".
//   2. SOURCE-TEXT SCAN: `docs/*.html`, `fastlane/metadata/**/*.txt` and the string catalog (keys
//      and every localized value) carry no affirmative red term. Preconditions pin that each
//      surface was actually read, and that the mandated warning is still in the catalog.
//
// ⚠️ HONEST GRADING (#433). No new symbol: the file compiles on the parent and claim 2 is GREEN
// there — this is a forward fence, not a regression find. Transcribed in Python against the tree
// (0 findings over 23 pages, 16 store files, the whole catalog) and against thirteen mutants (two of them German).
//
// ⚠️ THE LIMITS, stated so a green is not read as more than it is:
//   · A negation ANYWHERE in the sentence admits it: "Not a toy — it supports your wellbeing"
//     passes. The guard catches the plain claim, not a crafted one; a reviewer still reads copy.
//   · Catalog comments are not scanned (not user-facing), nor plural variations, nor string
//     literals that never reach the catalog, nor `README.md` / `ContentPipeline/`.
//   · HTML is read with tags removed and seven entities decoded; anything else stays encoded.

import Foundation
import XCTest

final class TheCopyMakesNoHealthClaimTests: XCTestCase {

    private static let terms = ["therapeutic", "therapy", "healing", "wellbeing", "well-being", "wellness",
                                "solfeggio", "chakra", "binaural beat", "40 hz", "40hz",
                                // the German store text (`fastlane/metadata/de-DE`)
                                "therapie", "heilung", "heilend", "heilfrequen", "wohlbefinden"]
    /// Proper names and an engineering term that contain a red word and claim nothing.
    private static let names = ["super natural healing killers", "supernaturalhealingkillers", "self-healing"]
    /// Computed, not stored: a stored `NSRegularExpression` global is a Sendable question in Swift 6.
    private static var denial: NSRegularExpression? {
        try? NSRegularExpression(pattern: "\\b(not|no|never|nor|without)\\b|n't|n\u{2019}t|\\bcoordinate\\b|\\b(nicht|kein\\w*|nie|ohne|weder)\\b")
    }

    // MARK: the rule

    /// The affirmative sentences in `text`, each with the red term it names.
    static func affirmative(_ text: String) -> [(term: String, sentence: String)] {
        var low = text.lowercased()
        for name in names { low = low.replacingOccurrences(of: name, with: " ") }
        var found: [(term: String, sentence: String)] = []
        for sentence in low.components(separatedBy: CharacterSet(charactersIn: ".!?")) {
            let range = NSRange(sentence.startIndex..., in: sentence)
            for term in terms {
                let pattern = "(?<![a-z0-9])" + NSRegularExpression.escapedPattern(for: term)
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      regex.firstMatch(in: sentence, range: range) != nil else { continue }
                if denial?.firstMatch(in: sentence, range: range) == nil {
                    found.append((term, sentence.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
        }
        return found
    }

    // MARK: 1 — the rule on literals

    func testTheRuleCatchesAClaimAndPassesADenial() {
        XCTAssertNotNil(Self.denial, "the denial pattern compiles")
        for claim in ["Echoel supports your wellbeing.", "Healing frequencies at 528 Hz.", "Use Solfeggio tones.",
                      "A 40 Hz gamma session.", "Binaural beats for focus.", "Feel the therapy. It is not a toy.",
                      "Heilende Frequenzen für dich.", "Dein Wohlbefinden steigt."] {
            XCTAssertFalse(Self.affirmative(claim).isEmpty, "a claim must be caught: \(claim)")
        }
        for fine in ["Science for self-observation, not therapy.", "Coordinate any therapeutic use with your provider.",
                     "Super Natural Healing Killers", "The self-healing audio engine recovers.",
                     "Please don\u{2019}t describe it as a wellness product.", "A 140 Hz low-shelf.",
                     "Keine Therapie, ein Instrument."] {
            XCTAssertTrue(Self.affirmative(fine).isEmpty, "a denial, the warning, a name or a number passes: \(fine)")
        }
    }

    // MARK: 2 — the three surfaces

    func testNoSurfaceSaysARedTermAffirmatively() throws {
        let root = try repoRoot()
        var findings: [String] = []

        let docs = try FileManager.default.contentsOfDirectory(atPath: root.appendingPathComponent("docs").path)
            .filter { $0.hasSuffix(".html") }.sorted()
        XCTAssertGreaterThanOrEqual(docs.count, 10, "precondition: the site was read")
        for page in docs {
            let html = try String(contentsOf: root.appendingPathComponent("docs/" + page), encoding: .utf8)
            for hit in Self.affirmative(Self.visibleText(html)) { findings.append("docs/\(page): \(hit.term) — \(hit.sentence)") }
        }

        var storeFiles = 0
        let metadata = root.appendingPathComponent("fastlane/metadata")
        if let walk = FileManager.default.enumerator(at: metadata, includingPropertiesForKeys: nil) {
            for case let url as URL in walk where url.pathExtension == "txt" {
                storeFiles += 1
                for hit in Self.affirmative(try String(contentsOf: url, encoding: .utf8)) {
                    findings.append("\(url.lastPathComponent): \(hit.term) — \(hit.sentence)")
                }
            }
        }
        XCTAssertGreaterThan(storeFiles, 0, "precondition: the store text was read")

        let catalogURL = root.appendingPathComponent("Sources/Echoelmusic/Resources/Localizable.xcstrings")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        let strings = try XCTUnwrap(catalog?["strings"] as? [String: Any], "ANCHOR MISSING: the catalog's strings")
        XCTAssertGreaterThan(strings.count, 100, "precondition: the catalog was read")
        XCTAssertNotNil(strings["Coordinate any therapeutic use with your provider."],
                        "the mandated safety warning is still in the app")
        for (key, entry) in strings {
            var said = [key]
            let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            for case let localization as [String: Any] in localizations.values {
                if let value = (localization["stringUnit"] as? [String: Any])?["value"] as? String { said.append(value) }
            }
            for text in said {
                for hit in Self.affirmative(text) { findings.append("catalog: \(hit.term) — \(hit.sentence)") }
            }
        }

        XCTAssertEqual(findings, [], """
            A sentence names a struck term without denying it. Echoel is an instrument, not a \
            wellness, therapy or esoteric product (CLAUDE.md BRAND) — reword the sentence, or deny \
            the term in it.
            """)
    }

    // MARK: helpers

    /// The page as a reader sees it: scripts and styles dropped, tags removed, the entities the
    /// site uses around these words decoded.
    static func visibleText(_ html: String) -> String {
        var text = html
        for pattern in ["<script[\\s\\S]*?</script>", "<style[\\s\\S]*?</style>", "<[^>]*>"] {
            text = text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        for (entity, character) in [("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"), ("&rsquo;", "\u{2019}"),
                                    ("&#x27;", "'"), ("&#39;", "'"), ("&nbsp;", " "), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        return text
    }

    private func repoRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 where !FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) {
            dir = dir.deletingLastPathComponent()
        }
        guard FileManager.default.fileExists(atPath: dir.appendingPathComponent("docs").path) else {
            throw XCTSkip("docs/ not on disk — this run has no source tree")
        }
        return dir
    }
}

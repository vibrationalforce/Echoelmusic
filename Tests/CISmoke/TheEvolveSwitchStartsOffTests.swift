// TheEvolveSwitchStartsOffTests.swift
// Echoel — E3 remainder. Founder inbox 2026-09-30, row E3, verbatim: "Ja; Evolve bekommt
// einen Schalter, Standard aus".
//
// WHAT THIS GUARDS. `evolveShouldReseed()` decides whether the take's ~30 s timer
// recomposes the loop from the body. For three months it returned a hard `true`, so the
// only way to keep a phrase was to stop the take. It now returns the player's switch,
// "Keep evolving", which sits under "Bar variation" in the mood panel and is OFF on a
// fresh install. Four claims, one decision:
//   · the key is declared ONCE, in the keystore, defaulting to `false` (H15-KEYSTORE);
//   · the instrument reads that key and owns exactly one switch for it, with a caption
//     that says what each position does;
//   · the timer's verdict IS the switch — no hard `true` left in the function;
//   · the three new chrome strings carry translated German units (E4 law).
//
// ⚠️ LIMIT — SOURCE-TEXT SCAN. Nothing here plays a take or proves the recomposition is
// audible or held on device; whether "off" FEELS like a held phrase is the founder's ear.
// The timer itself keeps running while the switch is off (its else-branch writes the
// "evolve: HOLD (switch off)" breadcrumb), so the diag log still shows every boundary.
//
// ⚠️ HONEST GRADING — transcribed in Python against the parent tree and this tree
// (#433/#464). On the parent the keystore entry, the switch and the catalog units are all
// absent and the function returns `true`: ONE finding (#486), every assertion FORWARD,
// born with this commit; zero regressions claimed. `SourceText.codeOnly` matters for
// claim 3: the function's own doc comment quotes the old hard `true`, and the raw text
// would make the absence needle hit the comment instead of the code (#491).

import Foundation
import XCTest

final class TheEvolveSwitchStartsOffTests: XCTestCase {

    private static let keys = "Sources/Echoelmusic/Core/StudioDefaultKeys.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"

    // MARK: - claim 1 — one key, in the keystore, OFF

    func testTheEvolveKeyLivesInTheKeystoreAndStartsOff() throws {
        let keys = try source(Self.keys)
        XCTAssertTrue(keys.contains("public static let evolveTake = StudioDefault(key: \"studio.evolveTake\", value: false)"), """
            The evolve switch's key left the keystore, or its default moved off `false`. The \
            founder's answer was "Standard aus": a fresh install holds its phrase until the \
            player asks for evolution. If the founder flips it, update this needle in the \
            same commit.
            """)
        let studio = try source(Self.studio)
        XCTAssertFalse(studio.contains("\"studio.evolveTake\""), """
            `EchoelStudioView` re-types the evolve key as a string literal. H15-KEYSTORE: \
            read `StudioDefaultKeys.evolveTake.key`, never a copy of its spelling.
            """)
    }

    // MARK: - claim 2 — the instrument reads the key and owns ONE switch

    func testTheMoodPanelOwnsOneEvolveSwitch() throws {
        let studio = try source(Self.studio)
        XCTAssertTrue(studio.contains("@AppStorage(StudioDefaultKeys.evolveTake.key) private var evolveTake: Bool = StudioDefaultKeys.evolveTake.value"),
                      "the instrument no longer reads the shared evolve key")
        XCTAssertEqual(studio.components(separatedBy: "Toggle(isOn: $evolveTake)").count - 1, 1, """
            There must be exactly ONE evolve switch. None is the old hard-wired evolution the \
            founder asked to make optional; two are two doors for one decision.
            """)
        XCTAssertTrue(studio.contains("Text(\"Keep evolving\")"), "the switch lost its visible word")
        XCTAssertTrue(studio.contains("String(localized: \"About every eight bars the loop is recomposed from your body — same piece, new phrase.\")")
                      && studio.contains("String(localized: \"The loop holds its phrase until you change something.\")"), """
            The caption under the switch no longer says what each position does. A switch \
            whose effect is a timing behaviour needs the sentence; the word alone does not \
            tell the player that "off" holds the phrase.
            """)
    }

    // MARK: - claim 3 — the timer's verdict IS the switch

    func testTheTimerAsksTheSwitch() throws {
        let studio = try source(Self.studio)
        let head = "private func evolveShouldReseed() -> Bool {"
        guard let start = studio.range(of: head),
              let end = studio.range(of: "\n    }\n", range: start.upperBound..<studio.endIndex) else {
            throw AnchorMissing(reason: "`evolveShouldReseed()` not found — renamed? Re-anchor this scan.")
        }
        let body = String(studio[start.upperBound..<end.lowerBound])
        XCTAssertTrue(body.contains("return evolveTake"), "the timer no longer asks the evolve switch")
        XCTAssertFalse(body.contains("return true"), """
            `evolveShouldReseed()` returns a hard `true` again — the switch would be a control \
            that does nothing (#164/#227), and the phrase could only be kept by stopping the take.
            """)
    }

    // MARK: - claim 4 — the new chrome speaks German

    func testTheSwitchAndItsCaptionSpeakGerman() throws {
        let url = try repoRoot().appendingPathComponent(Self.catalog)
        let data = try Data(contentsOf: url)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = object["strings"] as? [String: Any] else {
            throw XCTSkip("Localizable.xcstrings is not the JSON shape this guard reads — re-anchor (#454)")
        }
        let words = ["Keep evolving",
                     "About every eight bars the loop is recomposed from your body — same piece, new phrase.",
                     "The loop holds its phrase until you change something."]
        for word in words {
            guard let entry = strings[word] as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let de = localizations["de"] as? [String: Any],
                  let unit = de["stringUnit"] as? [String: Any],
                  let state = unit["state"] as? String,
                  let value = unit["value"] as? String else {
                XCTFail("\"\(word)\" has no German unit in Localizable.xcstrings — the catalog holds the German (#416)")
                continue
            }
            XCTAssertEqual(state, "translated", "\"\(word)\": a `new` unit ships nothing")
            XCTAssertNotEqual(value, word, "\"\(word)\": the German unit repeats the English")
        }
    }

    // MARK: - helpers

    private struct AnchorMissing: Error, CustomStringConvertible {
        let reason: String
        var description: String { reason }
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — renamed or moved. \
                Re-anchor this scan; do not let it skip.
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}

// TheRecordRouteHasNoClaimantTests.swift
// Echoel — #1336. `AudioConfiguration`'s record-route machinery has had ZERO callers since
// #1302 removed the audio input. The enum's own doc says so and was the one place #1302
// updated; FIVE other prose sites in the SAME file went on describing a live call graph in the
// present tense — "it is reachable today: voice capture can run while input monitoring holds
// the route", "every one of the seven real claim/release sites lives in a `@MainActor` type",
// "nine of the twelve release call sites are `try?`", "Today: all three CHECK, two configure,
// one refuses".
//
// ⭐ THE FINDING IS #456, NOT A TYPO: a repair travels to EVERY home. #1302 edited the
// declaration it was deleting cases from and stopped there. One founder deletion, five
// sentences left standing, all of them in the file a session opens when it is debugging the
// A2DP→HFP degradation this whole file exists to prevent.
//
// ⭐ AND THE `try?` SENTENCE IS THE THIRD GENERATION OF ONE NUMBER. #902 argued from a count;
// #903 found both its figures invented and replaced them with a measured "14 hits = 12 call
// sites … nine are `try?`"; #1302 deleted all twelve and nobody re-read the ⛔ note. **A
// CORRECTION AGES EXACTLY LIKE THE CLAIM IT CORRECTED** (#1326) — nothing re-checks a ⛔ block
// the way it re-checks an original sentence. The repair keeps the ARGUMENT (which never needed
// a count) and ships the command instead of the output.
//
// ⚠️ THIS GUARD DOES NOT FORBID A NEW CLAIMANT (#364) — it is the OPPOSITE of a freeze. The day
// anything records again, claim 1 goes red, and its message is the instruction: the five prose
// sites in `AudioConfiguration.swift` move in that same commit. That is precisely the event
// that went unnoticed in reverse.
// ⚠️ AND IT DOES NOT ALLOW DELETING THE MACHINERY. Claim 2 pins the empty enum and both
// functions, because CLAUDE.md keeps them on purpose: the #299 defect was a refcount two owners
// could unbalance, holding the phone in `.playAndRecord` for the rest of the session. A tidy-up
// that removes "unused" code here re-opens it.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **8 assertions across three claims**
// (claim 1 = 3, claim 2 = 3, claim 3 = 2), transcribed in Python and driven against BOTH trees.
// On the parent (`c73ea92`): **2 red, and they are FORWARD guards, not regressions** — claim 3
// names prose THIS commit writes, so it could not have been red for any other reason. Booking
// them as regressions is the flattering direction (#433/#464). **The other 6 are COUNTERWEIGHTS**
// (#343), green on BOTH trees — and that is the honest shape of this slice: the CODE was correct
// all along, only its description was wrong, so there is nothing here for a code assertion to
// have caught. Claims 1 and 2 earn their place by what they catch NEXT, not by what they catch
// now: claim 1 is the tripwire for a returning claimant, claim 2 for a tidy-up deletion.
// LIMITS (§1): SOURCE-TEXT SCAN throughout. `AudioConfiguration` is a `@MainActor` enum of
// statics touching `AVAudioSession`; that the route actually stays down on a phone is a DEVICE
// PROBE and is NOT claimed here.

import Foundation
import XCTest

final class TheRecordRouteHasNoClaimantTests: XCTestCase {

    private static let config = "Sources/Echoelmusic/Audio/AudioConfiguration.swift"

    /// Claim 1 — no call site anywhere in `Sources/`. Counted as "occurrences minus
    /// declarations", so the declaring line cannot be mistaken for a caller (#408).
    func testNothingClaimsOrReleasesTheRecordRoute() throws {
        let code = try Self.allSourceCode()
        XCTAssertFalse(code.isEmpty, "ANCHOR MISSING: could not walk `Sources/` (#454).")
        for name in ["claimRecordRoute", "releaseRecordRoute"] {
            let all = Self.occurrences(of: name + "(", in: code)
            let declarations = Self.occurrences(of: "func " + name + "(", in: code)
            XCTAssertEqual(
                all - declarations, 0,
                "`\(name)` has a caller again. That is legal and probably good (#364) — but "
                + "FIVE prose blocks in `AudioConfiguration.swift` describe the record route "
                + "in the PAST tense on the strength of there being none, and they are marked "
                + "#1336. Move them in this same commit, and give the returning owner a case in "
                + "`RecordRouteOwner` rather than a counter (#299). Measure: "
                + "`git grep -n \"\(name)(\" -- Sources`.")
        }
    }

    /// Claim 2 — counterweight: the machinery is kept, exactly as CLAUDE.md requires.
    /// Without this, claim 1 is green on a tree that DELETED the route handling outright —
    /// the tidy-up that re-opens #299.
    func testTheMachineryIsStillThere() throws {
        let code = SourceText.codeOnly(try Self.text(Self.config))
        XCTAssertTrue(code.contains("enum RecordRouteOwner: Hashable, CaseIterable, Sendable {}"),
                      "the owner enum is gone or has grown a case. It is deliberately EMPTY "
                      + "(#1302) and deliberately KEPT (#299): a Set of named owners is what "
                      + "makes a double claim and a double release both harmless, and an empty "
                      + "enum is what makes adding a case the obvious move later.")
        XCTAssertTrue(code.contains("static func claimRecordRoute("),
                      "`claimRecordRoute` was deleted as unused. Callerless is not dead (#527) "
                      + "— this is the answer to a shipped defect that cost a session of wrong "
                      + "Bluetooth routing.")
        XCTAssertTrue(code.contains("static func releaseRecordRoute("),
                      "`releaseRecordRoute` was deleted as unused — same argument.")
    }

    /// Claim 3 — FORWARD guards (§3): the two sentences that were flatly false now read in the
    /// past tense. Read RAW, not through `codeOnly`: these are comments, and stripping them
    /// would make both assertions vacuous (#926).
    func testTheProseNoLongerClaimsALiveRoute() throws {
        let raw = try Self.text(Self.config)
        XCTAssertFalse(
            raw.contains("is reachable today: voice capture"),
            "`AudioConfiguration` claims the two-owner breadcrumb is reachable today. Both "
            + "features it names — `microphoneManager` and input monitoring — are deleted "
            + "files. A doc asserting present reachability invites the next session to debug a "
            + "race no build can produce. (Safe as a NEGATIVE scan: the #1336 retraction quotes "
            + "the struck phrase in CAPITALS, so this needle cannot match its own retraction — "
            + "the #491 trap.)")
        XCTAssertTrue(
            raw.contains("could run while input monitoring holds the route"),
            "the past-tense replacement is gone. The sentence is kept, not deleted: it records "
            + "WHY the breadcrumb exists, which is what a later recorder will need.")
    }

    // MARK: - Helpers

    private static func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var i = text.startIndex
        while let r = text.range(of: needle, range: i..<text.endIndex) {
            count += 1
            i = r.upperBound
        }
        return count
    }

    private static func allSourceCode() throws -> String {
        let sources = Self.root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else { return "" }
        var joined = ""
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            if let body = try? String(contentsOf: sources.appendingPathComponent(relative),
                                      encoding: .utf8) {
                joined += SourceText.codeOnly(body) + "\n"
            }
        }
        return joined
    }

    private static func root() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func text(_ relativePath: String) throws -> String {
        try String(contentsOf: root().appendingPathComponent(relativePath), encoding: .utf8)
    }
}

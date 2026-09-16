// TheAlwaysLoadedMemoryNamesLivingTypesTests.swift
// Echoel — #1341. The SessionStart hook `cat`s five `memory/` files WHOLE at every session
// start: `people` · `user` · `vision` · `project_knowledge` · `preferences`. They are the most
// expensive prose in the repo after `CLAUDE.md`, and nothing was checking them.
//
// ⭐ WHAT WAS FOUND, and it is the reason this guard is GENERAL rather than three more pins.
// Four days after the founder deletions (#1301/#1302/#1305), `memory/vision.md` still listed an
// "**AUDIOVISUAL VOCODER (flagship)** — pure cores built (`VocoderCore`/`FeedbackGuard`), wiring
// next", and `memory/user.md` still called Granular on the voice "die benannte NÄCHSTE SCHEIBE".
// Both are build instructions. Both point at files that no longer exist. Both were being read
// aloud to every future session. A wrong register is bad; a wrong register with an imperative in
// it is a work order.
//
// ⭐ THE RULE THIS PINS: **a backtick-quoted CapitalizedName in those five files must resolve to
// something that exists under `Sources/`** — a declared type OR a file basename — *unless* a ⛔
// appears EARLIER IN ITS OWN BULLET, which is how this repo strikes a claim (#491/#1318). That
// escape is what makes the guard compatible with its own subject: the retraction that fixes the
// defect QUOTES the dead name, so a flat scan would go red on the repair.
//
// ⚠️ MEASURED BEFORE SHIPPING, because a checker with false alarms is worse than none (#665) —
// and the measurement moved the design TWICE, which is the part worth reading. Four narrowings:
//   · **declarations OR filenames**, not filenames alone — `BioModulation` is a FILE that declares
//     `ClockSource` and `BoundParameter` and no type of its own; a filename-only lookup flags it.
//   · **Apple prefixes skipped** — `AVAudioEngine` is named in `project_knowledge.md` and is not
//     ours to declare.
//   · ⛔ **paragraph scope was WRONG and the first transcription proved it.** Blank-line blocks
//     make an entire markdown bullet LIST one unit, so the ⛔ opening the RTMP bullet excused the
//     dead names three bullets below it — the guard came back GREEN on the parent, on the exact
//     defect it was written for (#937, from the inside). The unit is the **bullet**: a `- `/`1. `/
//     `#`/`>` line plus its indented continuation lines.
//   · ⛔ **and a marker must only excuse what FOLLOWS it.** Even at bullet scope, a ⛔ further down
//     a long bullet would license a bare claim above it. Position is compared, not presence.
// **THE LESSON, stated because it is not about markdown:** a guard's design is not verified by
// reading it. Both bugs survived a careful read and died the moment the transcription ran against
// the PARENT — which is what §0 grading is FOR. A guard that is green on the tree it was written
// to catch is worth less than none, because it also reports that the class is covered.
//
// ⚠️ AND IT IS HONEST ABOUT WHAT IT CANNOT SEE. Of the two instances found this cycle it catches
// ONE. `memory/user.md` called Granular on the voice "die benannte NÄCHSTE SCHEIBE" in **plain
// prose with no backticks** — nothing for a backtick scan to match. That is the #1338 shape again:
// a scan on a FORM cannot see the same defect written in another form. Claim 1 pins that one by
// name, because that is the only instrument available for it.
// ⚠️ AND IT FORBIDS NOTHING (#364). Naming a new type before it exists is legal; put the sentence
// in a ⛔ paragraph, or write the type. What is not legal is a bare present-tense name for
// something deleted, in a file every session reads before it thinks.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **6 assertions across three claims**
// (claim 1 = 2, claim 2 = 1 anchor + 1 over the scan, claim 3 = 2), transcribed in Python and
// driven against BOTH trees. On the parent (`2788ea3`) **3 are red**, and they are **TWO findings,
// not three** (#486): claim 2's scan is ONE failure listing `VocoderCore` and `FeedbackGuard` from
// `memory/vision.md` (`BioModulation` is correctly excused — it is a live FILE), and claim 1's two
// pins are the two prose repairs. The other **3 are COUNTERWEIGHTS** (#343), green on both trees:
// without the parser-sanity pins, an extractor that silently matched nothing would make claim 2
// vacuously green — the exact "a parser that matches nothing is a finding, never a pass" trap in
// `.claude/rules/context.md` §2. ⛔ An earlier draft of this paragraph claimed claim 2 also
// reported `EchoelHarmonizer`/`EchoelGranular`; it does not, and cannot — see the ⚠️ above.
// SOURCE-TEXT SCAN (§1). It reads prose and Swift text; it runs no app code.

import Foundation
import XCTest

final class TheAlwaysLoadedMemoryNamesLivingTypesTests: XCTestCase {

    /// The hook's own `cat` list. Kept here rather than parsed out of `.claude/settings.json`
    /// on purpose: if the hook drops a file, this guard should keep checking it until someone
    /// decides otherwise — a shrinking cat list is not a reason to stop being honest.
    private static let hookLoaded = [
        "memory/people.md", "memory/user.md", "memory/vision.md",
        "memory/project_knowledge.md", "memory/preferences.md",
    ]

    /// Names Apple owns. A repo file will never declare these, and naming one is not a claim.
    private static let foreignPrefixes = ["AV", "NS", "UI", "CA", "CG", "CM", "CL", "CB",
                                          "HK", "SK", "MTL", "WC", "CK", "MIDI", "OS", "XC"]

    /// Claim 1 — the two #1340/#1341 retractions are recorded, not quietly swapped. Positive
    /// pins: a negative scan for the dead names would hit these very paragraphs (#491).
    func testTheTwoBuildOrdersAreStruckInWriting() throws {
        let vision = try Self.text("memory/vision.md")
        XCTAssertTrue(
            vision.contains("AUDIOVISUAL VOCODER \u{2014} CUT, not roadmap"),
            "`memory/vision.md` no longer records that the flagship vocoder is CUT. It stood in "
            + "TIER 2 — ROADMAP with the words \"wiring next\", naming two deleted files, in a "
            + "document the hook reads aloud at every session start.")
        let user = try Self.text("memory/user.md")
        XCTAssertTrue(
            user.contains("Die Vokal-Ketten-Zeile ist gestrichen"),
            "`memory/user.md` no longer records that the vocal-chain line is struck. It called "
            + "Granular on the voice \"die benannte NÄCHSTE SCHEIBE\" after #1305 removed it — a "
            + "next-slice instruction pointing at a deleted file.")
    }

    /// Claim 2 — THE GENERAL RULE, which is the point of this file: no bare present-tense name
    /// for something that is not in the tree.
    func testNoHookLoadedFileNamesATypeThatIsGone() throws {
        let known = try Self.namesUnderSources()
        XCTAssertGreaterThan(
            known.count, 500,
            "ANCHOR MISSING: only \(known.count) names harvested from `Sources/`. A harvest that "
            + "comes back thin makes every name below look unknown and floods the report; a "
            + "harvest that came back EMPTY would instead make the rule flag everything. Either "
            + "way the number, not the verdict, is the finding (#454, context.md §2).")
        var offences: [String] = []
        for path in Self.hookLoaded {
            for block in Self.bullets(in: try Self.text(path)) {
                // A strike excuses only what FOLLOWS it, inside its own bullet.
                let strike = block.range(of: "\u{26D4}")
                for (offset, name) in Self.backtickedTypeNames(in: block) {
                    if let strike, strike.lowerBound < offset { continue }
                    if known.contains(name) { continue }
                    if Self.foreignPrefixes.contains(where: { name.hasPrefix($0) }) { continue }
                    offences.append("\(path): `\(name)`")
                }
            }
        }
        XCTAssertTrue(
            offences.isEmpty,
            "a file the SessionStart hook reads WHOLE names something that is not under "
            + "`Sources/`:\n  \(offences.joined(separator: "\n  "))\n"
            + "That is legal if it is a plan or a retraction (#364) — put the sentence in a "
            + "paragraph carrying ⛔, the way this repo strikes every other claim, and this guard "
            + "steps aside. It is NOT legal bare and in the present tense: #1301/#1302/#1305 "
            + "deleted a microphone, a vocoder and a harmonizer, and these files went on naming "
            + "them as the flagship and as the next slice to build, to every session, for days. "
            + "Measured before shipping: on a clean tree this list is EMPTY (#665).")
    }

    /// Claim 3 — counterweight: the two halves of claim 2's parser must actually match something.
    /// A regex that silently matches nothing turns claim 2 into a vacuous green (#926).
    func testTheParserMatchesWhatItIsPointedAt() throws {
        let known = try Self.namesUnderSources()
        XCTAssertTrue(
            known.contains("EngineBus"),
            "the `Sources/` harvest does not contain `EngineBus`, the one real coupling spine. "
            + "The declaration regex has stopped matching — claim 2 would then report every name "
            + "in every file, or (with the anchor loosened) none at all.")
        let probe = "some prose naming `VocoderCore` and `EngineBus` and `AVAudioEngine`."
        XCTAssertEqual(
            Self.backtickedTypeNames(in: probe).map { $0.1 }.sorted(),
            ["AVAudioEngine", "EngineBus", "VocoderCore"],
            "the backtick extractor no longer selects the names it is meant to select. It is "
            + "deliberately blind to lowercase members (`voiceProfileTaps`) and to three-letter "
            + "noise; if it goes blind to type names too, claim 2 passes on any tree.")
    }

    // MARK: - measurement

    /// Backticked names that LOOK like a type, each with the index of its opening backtick so a
    /// strike marker can be compared by POSITION rather than by mere presence.
    private static func backtickedTypeNames(in block: String) -> [(String.Index, String)] {
        var out: [(String.Index, String)] = []
        var opening: String.Index?
        var current = ""
        var i = block.startIndex
        while i < block.endIndex {
            let ch = block[i]
            if ch == "`" {
                if let open = opening {
                    let ok = current.count >= 4
                        && (current.first?.isUppercase ?? false)
                        && current.allSatisfy { $0.isLetter || $0.isNumber }
                    if ok { out.append((open, current)) }
                    opening = nil
                } else {
                    opening = i
                }
                current = ""
            } else if opening != nil {
                current.append(ch)
            }
            i = block.index(after: i)
        }
        return out
    }

    /// One markdown ITEM: a `- ` / `1. ` / `#` / `>` line plus its indented continuation lines.
    /// ⛔ NOT a blank-line paragraph — that made a whole bullet LIST one unit, and the first
    /// bullet's strike marker then excused every bullet below it. See the header.
    private static func bullets(in text: String) -> [String] {
        var out: [String] = []
        var current: [String] = []
        func flush() {
            if !current.isEmpty { out.append(current.joined(separator: "\n")); current = [] }
        }
        for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { flush(); continue }
            let head = line.drop { $0 == " " || $0 == "\t" }
            let startsItem = head.hasPrefix("- ") || head.hasPrefix("* ") || head.hasPrefix("+ ")
                || head.hasPrefix("#") || head.hasPrefix(">")
                || (head.first?.isNumber == true && head.contains(". "))
            if startsItem { flush() }
            current.append(line)
        }
        flush()
        return out
    }

    private static func namesUnderSources() throws -> Set<String> {
        let base = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            throw NSError(domain: "AlwaysLoadedMemory", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "cannot walk Sources/"])
        }
        let keywords = ["class ", "struct ", "enum ", "protocol ", "actor ", "typealias "]
        var known = Set<String>()
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            known.insert(((rel as NSString).lastPathComponent as NSString).deletingPathExtension)
            let text = try String(contentsOf: base.appendingPathComponent(rel), encoding: .utf8)
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                for kw in keywords {
                    guard let r = line.range(of: kw) else { continue }
                    var name = ""
                    for ch in line[r.upperBound...] {
                        if ch.isLetter || ch.isNumber || ch == "_" { name.append(ch) } else { break }
                    }
                    if name.count >= 4, name.first?.isUppercase == true { known.insert(name) }
                }
            }
        }
        return known
    }

    private static func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private static func text(_ relativePath: String) throws -> String {
        try String(contentsOf: try repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}

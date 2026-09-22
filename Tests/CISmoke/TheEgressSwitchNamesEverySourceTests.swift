// TheEgressSwitchNamesEverySourceTests.swift
// Echoel — #E5. Two enums answer "where did this bio reading come from", and only ONE of
// them is load-bearing. This pins the property that makes the load-bearing one safe, and
// records the other so nobody extends the wrong side of the pair.
//
// THE PAIR, measured comment-stripped over `Sources/` on 2026-09-22:
//   · `BioSource` (Core/EngineBus.swift) — 6 cases, rides on `BioSampleFrame`, four real
//     producers, and it is what `BioEgressPolicy` switches on. CANONICAL.
//   · `BioDataSource` (Bio/EchoelBioEngine.swift) — 8 cases, reaches only
//     `EchoelBioEngine.dataSource` and `BioSnapshot.source`, and has exactly TWO producers
//     (`.healthKit`, `.fallback`). Five of its cases occur NOWHERE in `Sources/`.
//
// ⭐ THE ASYMMETRY IS THE WHOLE POINT, and it is what makes the canonical one canonical:
// `BioEgressPolicy.allowsEgress(_ source: BioSource)` is an EXHAUSTIVE switch with no
// `default:`, so adding a case to `BioSource` is a COMPILE ERROR there — the decision
// "may this source leave the device" cannot be forgotten. Adding a case to `BioDataSource`
// compiles silently everywhere.
//
// ⛔ AND THE RISK OF THE PAIR IS SMALLER THAN THE FIRST VERSION OF THIS NOTE SAID. I wrote
// that a source added to the wrong enum "gets a value the egress policy has never seen".
// That OVERSTATES it: such a source cannot leak, because `BioDataSource` has no reader at
// all beyond one `== .healthKit` gate and never reaches the bus. The real cost is a wrong
// mental model and wasted work, not a data leak. Stated the smaller way on purpose — an
// overstated privacy claim in a privacy guard is the shape that gets it ignored.
//
// ⚠️ ONE CASE IS DELIBERATELY NOT SCANNED, and the reason cost a measurement: `.camera`.
// A word-bounded needle for it still matches `BioSourceKind.camera`, `BioSourceOption.camera`
// and `SignalRouting`'s `.camera` — three OTHER enums, all live. Worse, my first sweep used
// an unbounded `.camera` and matched `source: .cameraPPG`, i.e. a case of `BioSource`, and
// reported four producers that do not exist. Parallel taxonomies overlap by construction, so
// a bare case name is never a sound needle for one of them (#1376: cite the TYPE). The five
// cases below are scanned only because they are unambiguous — no other enum in `Sources/`
// declares them.
//
// This file builds only in the CI/CD `Build for Testing` step.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheEgressSwitchNamesEverySourceTests: XCTestCase {

    private static let policy = "Sources/Echoelmusic/Core/BioEgressPolicy.swift"
    private static let bus = "Sources/Echoelmusic/Core/EngineBus.swift"
    private static let engine = "Sources/Echoelmusic/Bio/EchoelBioEngine.swift"
    /// The signature the exhaustiveness claim is about. Written out in full so a SECOND
    /// `allowsEgress` overload (there are four) cannot be mistaken for this one.
    private static let sourceOverload = "static func allowsEgress(_ source: BioSource) -> Bool"

    // MARK: - 1. The property the compiler cannot enforce

    func testTheSourceEgressSwitchHasNoDefaultCase() throws {
        let lines: [String] = SourceText.codeOnly(try read(Self.policy))
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { $0.contains(Self.sourceOverload) }) else {
            XCTFail("""
                `\(Self.sourceOverload)` is gone from \(Self.policy). Either it was renamed — \
                move this guard with it — or the source-level egress decision moved somewhere \
                else, in which case find it and point this there. Do not delete this claim \
                without finding its new home: it protects a privacy decision.
                """)
            return
        }
        guard let (lo, hi) = span(of: lines[start], in: lines, from: start) else {
            XCTFail("`\(Self.sourceOverload)` found but its body could not be delimited")
            return
        }
        let body: String = lines[lo..<hi].joined(separator: "\n")
        let hasDefault: Bool = body.contains("default:")
        XCTAssertFalse(hasDefault, """
            `allowsEgress(_ source: BioSource)` now has a `default:` case, and that quietly \
            removes the only thing making this decision impossible to forget.
            WITHOUT a default, adding a case to `BioSource` is a COMPILE ERROR right here, so \
            whoever adds a bio source is forced to say whether it may leave the device \
            (App Store 5.1.3 — HealthKit-derived data may not be shared with third parties).
            WITH a default, a new source silently inherits whatever the default returns. If \
            that default is `true`, a future Health-derived source leaks the day it is added, \
            and nothing goes red.
            This is not a style rule. If you need shared handling, list the cases explicitly \
            (`case .ble, .cameraPPG, .fallback:`) — that is what the code does today.
            Body scanned:
            \(body)
            """)
    }

    func testTheEgressSwitchStillNamesTheSourceEnum() throws {
        // COUNTERWEIGHT (#343). The claim above is green for free if the needle stops matching
        // — a renamed overload, a reformatted signature, or `SourceText.codeOnly` eating the
        // line all look exactly like "no default found". This asserts the scan had a subject.
        let text: String = SourceText.codeOnly(try read(Self.policy))
        XCTAssertTrue(text.contains(Self.sourceOverload), """
            \(Self.policy) no longer contains `\(Self.sourceOverload)` in code, so the \
            no-`default:` claim above is scanning nothing. Re-anchor it before trusting it.
            """)
        XCTAssertTrue(text.contains("case .healthKit"), """
            The egress switch no longer names `.healthKit` explicitly. That case returning \
            FALSE is the App Store 5.1.3 rule itself — Health-store data stays on the device. \
            If it moved, say where; if it was folded into a default, the claim above should \
            already be red and this says why it matters.
            """)
    }

    // MARK: - 2. Which enum is canonical

    func testTheBusSourceIsTheOneWithProducers() throws {
        // The canonical half, asserted POSITIVELY so "BioDataSource is not canonical" rests on
        // a measurement rather than on this file's opinion.
        let producers: [String] = try filesUnderSources(containing: "source: .cameraPPG")
            + filesUnderSources(containing: "source: .healthKit")
            + filesUnderSources(containing: "source: .fallback")
        XCTAssertGreaterThanOrEqual(Set(producers).count, 2, """
            `BioSource` values are no longer constructed in at least two files. It is the \
            provenance that rides on `BioSampleFrame` and the one `BioEgressPolicy` switches \
            on, so if its producers vanished, either the bus changed shape or the needles \
            here are stale. Files found: \(Set(producers).sorted()).
            """)
        let policyText: String = SourceText.codeOnly(try read(Self.policy))
        XCTAssertFalse(policyText.contains("BioDataSource"), """
            `BioEgressPolicy` now mentions `BioDataSource`. Only ONE provenance type may \
            decide egress, and it is `BioSource` — the bus type, with an exhaustive switch \
            and real producers. Two egress vocabularies is the shape where a source is \
            classified in one and read from the other.
            """)
    }

    func testTheEngineLocalSourceEnumHasNoProducerForItsRetiredCases() throws {
        // ⚠️ FIVE cases, not eight. `.healthKit` and `.fallback` ARE produced (that is the
        // point), and `.camera` cannot be scanned by name at all — see the file header.
        let retired: [String] = ["appleWatch", "chestStrap", "ouraRing", "arkit", "microphone"]
        var produced: [String] = []
        for name in retired {
            let hits: [String] = try filesUnderSources(containingWord: ".\(name)")
            if !hits.isEmpty {
                produced.append("\(name) in \(hits.joined(separator: ", "))")
            }
        }
        XCTAssertTrue(produced.isEmpty, """
            One of `BioDataSource`'s producerless cases now occurs in `Sources/`: \
            \(produced.joined(separator: " | ")).
            That is NOT forbidden (#364) — but read the enum's note first. `BioDataSource` is \
            the ENGINE-LOCAL provenance type; it reaches only `EchoelBioEngine.dataSource` \
            and `BioSnapshot.source`, and nothing downstream reads it except one \
            `== .healthKit` gate. A bio source wired there does not reach the bus, is not \
            seen by `BioEgressPolicy`, and changes no behaviour.
            If you are adding a bio SOURCE, the enum you want is `BioSource` in \
            \(Self.bus) — adding a case there is a compile error in the egress switch, which \
            is how the privacy decision gets made. If you really meant this enum, take the \
            name out of this list and say why at the case.
            """)
    }

    func testTheEngineEnumSaysWhichOneIsCanonical() throws {
        // The prose home (#456). Without this, the two measurements above live only here, in
        // a file nobody opens while editing the enum.
        let text: String = try read(Self.engine)
        XCTAssertTrue(text.contains("BioSource"), """
            \(Self.engine) no longer mentions `BioSource` at all, so a reader landing on \
            `BioDataSource` has nothing telling them it is the engine-local one and that the \
            bus type is elsewhere. That note is what stops the next session extending the \
            enum that changes nothing.
            """)
    }

    // MARK: - Helpers

    private func span(of opener: String, in lines: [String], from: Int? = nil) -> (Int, Int)? {
        guard let start = from ?? lines.firstIndex(where: { $0.contains(opener) }) else { return nil }
        let indent = lines[start].prefix { $0 == " " }.count
        let close = lines[(start + 1)...].firstIndex {
            $0.trimmingCharacters(in: .whitespaces) == "}"
                && $0.prefix { c in c == " " }.count == indent
        } ?? lines.endIndex
        return (start, close)
    }

    private func isWordChar(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }

    /// Relative paths under `Sources/Echoelmusic` whose CODE contains `needle`.
    private func filesUnderSources(containing needle: String) throws -> [String] {
        try scanSources { $0.contains(needle) }
    }

    /// As above, but the character after `needle` must not continue an identifier — so
    /// `.camera` does not match `.cameraPPG`. That exact substring collision produced four
    /// phantom producers in this file's first measurement.
    private func filesUnderSources(containingWord needle: String) throws -> [String] {
        try scanSources { text in
            var rest = text[...]
            while let range = rest.range(of: needle) {
                let after = rest[range.upperBound...].first
                if after == nil || !self.isWordChar(after ?? " ") { return true }
                rest = rest[range.upperBound...]
            }
            return false
        }
    }

    private func scanSources(_ matches: (String) -> Bool) throws -> [String] {
        let root = sourcesRoot()
        guard let all = FileManager.default.enumerator(atPath: root.path) else { return [] }
        var found: [String] = []
        for case let relative as String in all where relative.hasSuffix(".swift") {
            let url = root.appendingPathComponent(relative)
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if matches(SourceText.codeOnly(raw)) { found.append(relative) }
        }
        return found.sorted()
    }

    private func sourcesRoot() -> URL {
        let here = URL(fileURLWithPath: #filePath)
        return here.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Echoelmusic")
    }

    private func read(_ relative: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: sourcesRoot().path) else {
            throw XCTSkip("""
                Sources/ is not reachable from this file's path — the checkout layout changed. \
                Skipping rather than failing: this guard reads source text, and an unreadable \
                tree is not evidence that the code is wrong.
                """)
        }
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }
}

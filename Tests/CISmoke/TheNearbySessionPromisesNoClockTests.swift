// TheNearbySessionPromisesNoClockTests.swift
// Echoel — #1414. Two copy claims that named capabilities the app does not have.
//
// WHAT WAS THERE, both measured before the repair rather than remembered:
//
// 1. The Live Colabo door's VoiceOver hint read "Opens the nearby-session sheet to play
//    together on one tempo". `MultipeerSession` shares a Codable `Project` snapshot and, behind
//    an opt-in toggle, each peer's own bio for a side-by-side readout. There is no shared
//    transport and no clock sync — its own header says so, `Package.swift` carries an EMPTY
//    `dependencies` array, and nothing under `Sources/` names Ableton Link or LinkKit. The
//    SHEET's visible paragraph was honest the whole time ("share your session both ways — a
//    starting point to jam from together"); only the door over-promised, and the door is the
//    half no sighted user can read (#480).
//
// 2. HRV → picture. `BioVisualParams` has six fields; measured comment-stripped across the
//    whole of `Sources/`, the renderer reads exactly ONE of them — `vp.pulseHz`, heart rate.
//    `complexity` is the app's only HRV→picture path and it has no consumer (#1131). The
//    website's four driver enumerations were already exact (HR→pulse, tone→hue, breath→spread,
//    coherence→sharpness) and this guard is what keeps HRV out of them while that stays true.
//
// ⭐ WHAT THIS GUARD DELIBERATELY DOES **NOT** DO (#364). It does not pin the replacement
// wording and it does not forbid wiring `complexity`. Claim 5 is CONDITIONAL on the
// measurement: the moment the renderer reads a second `BioVisualParams` field, the HRV
// assertions skip themselves and say, in the skip message, that the copy is now the thing to
// re-read. A guard that made the honest copy permanent would make the honest fix illegal.
//
// ⚠️ ONE SURFACE IS EXCLUDED ON PURPOSE, AND IT IS THE ONE THAT STILL CARRIES THE CLAIM:
// `fastlane/metadata/{en-US,de-DE}/description.txt` opens with "Heart rate, HRV and breath
// drive a synthesizer, a live visual and your light rig". Eight of those nine arrows hold
// (HRV→light is real — `ArtNetSender` sends `hrvNormalized` as a DMX channel); the ninth,
// HRV→visual, does not. App Store wording is the founder's, so it is REPORTED, not edited —
// and a guard over it would be red on a tree he has not approved changing, which is the one
// thing #488 says never to ship. When he decides, add the path here in the same commit.
//
// Grading (§0, no Swift toolchain in a web session): every claim is a text assertion over
// files on disk, transcribed into Python and driven against BOTH trees — RED on `05a14ca99`
// (claims 1 and 2 fail: the hint and the label), GREEN on this tree. Claims 3, 4, 5 and 6 are
// COUNTERWEIGHTS and are green on both, which is the point of them (#343). NOT compile-verified:
// a transcription does not run Swift's type checker.

import Foundation
import XCTest

final class TheNearbySessionPromisesNoClockTests: XCTestCase {

    private static let studio  = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let sheet   = "Sources/Echoelmusic/Studio/LiveColaboView.swift"
    private static let session = "Sources/Echoelmusic/Sync/MultipeerSession.swift"
    private static let metal   = "Sources/Echoelmusic/Views/MetalBioView.swift"

    /// Affirmative promises of a shared clock. Deliberately NOT the bare words "sync" or
    /// "synced": the repaired hint says "are not clock-synced", and a needle that reds the
    /// honest sentence is the #425 trap — a slice containing a claim and its own refutation.
    private static let clockPromises = [
        "on one tempo", "on the same tempo", "to one tempo", "in sync",
        "stay in time", "same beat", "tempo lock", "phase lock", "locked together"
    ]

    private func source(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        let url = dir.appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath). A guard that cannot find its "
                    + "subject is not a pass — re-anchor it rather than letting it stay green "
                    + "(#454).")
            return ""
        }
        return text
    }

    /// The `quickDoorRow` declaration body, comments blanked.
    ///
    /// ⚠️ The stripping is LOAD-BEARING here, not prophylactic: the retraction block this slice
    /// wrote into that very declaration QUOTES the removed promise verbatim, so a raw scan
    /// would match its own correction. That is #491 one file over.
    private func doorRowCode() throws -> String {
        let code = SourceText.codeOnly(try source(Self.studio))
        guard let start = code.range(of: "private var quickDoorRow: some View {") else {
            XCTFail("ANCHOR MISSING: no `quickDoorRow` declaration in \(Self.studio). The door "
                    + "row moved or was renamed — re-anchor this walk (#454).")
            return ""
        }
        return Self.bracedBody(of: code, from: start.lowerBound)
    }

    /// The `{ … }` body that opens at or after `start`, brace-matched.
    ///
    /// ⚠️ Deliberately NOT `SourceText.codeWindow(_:from:lines:)`: that takes a LINE BUDGET,
    /// and a budget that overshoots the declaration silently starts scanning the neighbour —
    /// an absence claim then fails for a sentence that is not its subject. §2 prefers a
    /// brace match over a fixed window for exactly this reason. Its one limit, stated rather
    /// than hidden: a brace inside a string literal would miscount. None of the copy in this
    /// declaration contains one, and the input is comment-blanked before it arrives here.
    private static func bracedBody(of code: String, from start: String.Index) -> String {
        guard let open = code[start...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var i = open
        while i < code.endIndex {
            if code[i] == "{" { depth += 1 }
            if code[i] == "}" {
                depth -= 1
                if depth == 0 { return String(code[open...i]) }
            }
            i = code.index(after: i)
        }
        return String(code[open...])
    }

    // 1 — THE RULE, door half. The spoken copy promises no shared clock.
    func testTheDoorPromisesNoSharedClock() throws {
        let doors = try doorRowCode()
        XCTAssertFalse(doors.isEmpty, "empty door row — the anchor above already failed")
        let hits = Self.clockPromises.filter { doors.localizedCaseInsensitiveContains($0) }
        XCTAssertTrue(hits.isEmpty, """
            The Live Colabo door's spoken copy contains \(hits.joined(separator: ", ")).

            `MultipeerSession` shares a session SNAPSHOT; it does not sync a transport. Loading
            a shared session sets your BPM to theirs once, and from the next bar the two devices
            drift, because each one runs its own transport. Every needle here is a different way
            of promising the same absent capability, so they are reported as ONE finding (#486).

            If a shared clock has actually been built, this guard is the wrong thing to edit
            first: show the transport, then move the needle in the same commit.
            """)
    }

    // 2 — THE RULE, sheet half. #1378's lesson: two homes for one fact, only one kept current.
    func testTheSheetPromisesNoSharedClock() throws {
        let code = SourceText.codeOnly(try source(Self.sheet))
        XCTAssertFalse(code.isEmpty, "empty sheet source — the read above already failed")
        let hits = Self.clockPromises.filter { code.localizedCaseInsensitiveContains($0) }
        XCTAssertTrue(hits.isEmpty, """
            \(Self.sheet) contains \(hits.joined(separator: ", ")).

            The door and the sheet must describe the SAME capability. The sheet's paragraph was
            the honest one throughout — it says the two devices find each other and share a
            session — and the repair pulled the door up to it rather than the other way round.
            """)
    }

    // 3 — COUNTERWEIGHT, and the one that stops claim 1 from passing by deletion. Claims 1 and 2
    // are satisfied by a door that says nothing at all, or by removing the feature.
    func testTheDoorStillSpeaksAndTheFeatureStillExists() throws {
        let doors = try doorRowCode()
        for needle in [".accessibilityLabel(\"Live Colabo", ".accessibilityHint("] {
            XCTAssertTrue(doors.contains(needle), """
                The Live Colabo door no longer carries `\(needle)`. Its whole visible content is
                an SF Symbol, so without these VoiceOver names the button after the glyph (#489).
                Claim 1 of this file forbids a false promise in that copy; it must not be
                satisfiable by having no copy.
                """)
        }
        let session = try source(Self.session)
        XCTAssertTrue(session.contains("public static let serviceType"), """
            \(Self.session) no longer declares the Multipeer service. If nearby collaboration
            was removed, remove this file's claims in the same commit rather than leaving a
            guard that is green because its subject is gone (#472).
            """)
    }

    // 4 — COUNTERWEIGHT. The publisher must keep SAYING what it does not do. This sentence is
    // the evidence the repair was built on; losing it would leave the next reader to re-derive
    // "is there a clock in here?" from scratch, which is how the hint got written in the first
    // place.
    func testThePublisherStillNamesTheMissingClock() throws {
        let session = try source(Self.session)
        // ⚠️ ANCHORED ON THE SECOND LINE OF THE SENTENCE, not on the sentence. The header wraps
        // as "Real-time tempo/" / "// phase lock (Ableton Link) is a separate…", so the needle
        // that reads naturally — the whole phrase — spans a line break and a comment marker and
        // can NEVER match. The transcription caught it; nothing else would have, because a
        // needle that matches nothing is a silent green here (#808, #367).
        XCTAssertTrue(session.contains("phase lock (Ableton Link) is a separate"), """
            \(Self.session) no longer states that real-time tempo/phase lock is a separate,
            unbuilt step. Either it was built — then this whole file needs re-reading, starting
            with claim 1 — or a true limitation was deleted while it still applies, which is
            worse than never having written it down.
            """)
    }

    // 5 — HRV → PICTURE, and it is CONDITIONAL on the measurement rather than on my memory of
    // it. The condition is the renderer's own read set: `BioVisualParams` has six fields and
    // `MetalBioView` reads one. While that holds, no driver enumeration may name HRV.
    func testNoDriverListNamesHRVWhileItsOnlyPathIsDead() throws {
        let renderer = SourceText.codeOnly(try source(Self.metal))
        XCTAssertFalse(renderer.isEmpty, "empty renderer source — the read above already failed")
        XCTAssertTrue(renderer.contains("vp.pulseHz"), """
            \(Self.metal) no longer reads `vp.pulseHz`. That read IS the bio→picture path; if it
            is gone the picture is no longer bio-reactive and every enumeration this claim scans
            is wrong for a bigger reason than HRV.
            """)
        // The field whose absence makes the HRV claim false. Its presence is the OPPOSITE of a
        // failure — it means somebody did the work, so this claim stands down (#364).
        let hrvFieldIsWired = renderer.contains("vp.complexity")
        try XCTSkipIf(hrvFieldIsWired, """
            `MetalBioView` now reads `vp.complexity` — the HRV→picture path. This claim asserted
            the copy must NOT name HRV; that reason has expired. Re-read the four driver
            enumerations it scans and add HRV to them, then replace this skip with the positive
            assertion in the same commit.
            """)

        for (path, anchor) in Self.driverEnumerations {
            let text = try source(path)
            var searchStart = text.startIndex
            var found = 0
            while let hit = text.range(of: anchor, range: searchStart..<text.endIndex) {
                found += 1
                let lower = text.index(hit.lowerBound, offsetBy: -240,
                                       limitedBy: text.startIndex) ?? text.startIndex
                let upper = text.index(hit.upperBound, offsetBy: 120,
                                       limitedBy: text.endIndex) ?? text.endIndex
                let window = String(text[lower..<upper])
                XCTAssertFalse(window.contains("HRV"), """
                    A visual driver enumeration in \(path), around "\(anchor)", names HRV.

                    Measured comment-stripped over the whole of `Sources/`: the renderer reads
                    exactly one `BioVisualParams` field, `vp.pulseHz`. HRV's single path into the
                    picture is `complexity`, and it has no consumer (#1131). Heart rate, breath
                    and coherence DO reach the picture — the first through this field, the other
                    two through the shader's own terms — so the honest list is the one that was
                    already there.
                    """)
                XCTAssertTrue(window.localizedCaseInsensitiveContains("coherence"), """
                    The driver enumeration in \(path) around "\(anchor)" no longer names a live
                    driver. This claim must not be satisfiable by emptying the list — an
                    enumeration that says nothing cannot name HRV either.
                    """)
                searchStart = hit.upperBound
            }
            XCTAssertGreaterThan(found, 0, """
                ANCHOR MISSING: "\(anchor)" does not occur in \(path). An absence claim read
                through a missed anchor is a vacuous green (#926) — re-anchor rather than
                letting this pass.
                """)
        }
    }

    /// The four places that enumerate what drives the picture. Anchored on a phrase from inside
    /// each list rather than on a line number: a quoted phrase survives an insertion, a line
    /// number does not.
    private static let driverEnumerations: [(String, String)] = [
        ("docs/architecture.html", "drives the hue"),
        ("docs/architecture.html", "coherence&rarr;sharpness"),
        ("docs/index.html", "coherence to sharpness"),
        ("Sources/Echoelmusic/Studio/LearnLibrary.swift", "pulse, breath and coherence drive its")
    ]
}

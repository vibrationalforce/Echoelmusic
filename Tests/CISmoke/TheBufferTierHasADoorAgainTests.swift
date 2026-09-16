// TheBufferTierHasADoorAgainTests.swift
// Echoel — #1331. `StudioDefaultKeys.audioLatencyMode` is PERSISTED and re-applied at launch,
// and since #1302 nothing on screen could change it.
//
// ⭐ THE DEFECT IS THE ONE THIS REPO ALREADY NAMED AS A LAW AND THEN COMMITTED ANYWAY.
// CLAUDE.md: "Vor dem Löschen eines UI-Blocks prüfen, welche Modelle er als EINZIGER schreibt
// — ein Toggle mit persistiertem Flag hinterlässt beim Löschen einen unwiderruflichen Zustand,
// keine Lücke." The buffer tier's only control was MASTER → "Audio input" (`StudioDefaultKeys`
// says so in its own doc), and #1302 deleted that surface with the microphone. What was left
// is not an absent feature — it is a SETTING WITH NO OFF-SWITCH: a player who had chosen Ultra
// kept getting Ultra on every launch, and a player whose play surface lagged could not get
// down from the shipped 512 (~10.7 ms, already outside this repo's own <10 ms target). The
// same repair was needed once before, for the persisted Apple-Health opt-in (`083cec8`).
//
// ⚠️ WHY `@State` AND NOT `@AppStorage`, since that looks like the obvious binding: because
// `setLatencyMode` PERSISTS LAST, only after the session GRANTS the request — the whole
// #674/#675 repair. An `@AppStorage` binding would write the preference first and bring back
// exactly the defect those cycles removed, one layer up: a tier the hardware refused
// reappearing next launch as though it had worked. Claim 3 pins that, because it is the half
// a later "simplification" would undo while everything still looked right.
//
// ⚠️ A NAMED CHOICE IS A PICKER. The parameter-row law is about NUMERIC parameters; the tiers
// have names, so `EchoelValueField` would be obeying its letter against its purpose (the law
// states that exception itself). Claim 2 pins the Picker.
//
// ⚠️ NOT PROVEN (§1). That a chosen tier audibly lowers latency, and that iOS grants it on a
// given route, is a DEVICE PROBE and is registered as open at the row
// (`NEEDS-FOUNDER-VERIFY`). What is proven here is that the control exists, is mounted, drives
// the one owner, and does not write the preference itself.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **10 assertions across four claims**
// (claim 1 = 2, claim 2 = 4 including its anchor check, claim 3 = 2, claim 4 = 2), transcribed
// in Python and driven against BOTH trees. On the parent (`bf72b7f`) **6 are red and they are
// ONE finding** (#486): the row did not exist, so every assertion naming it went red together.
// ⚠️ Of the four that were GREEN there, only claim 4's two are real counterweights (#343) —
// the launch path and the single-owner persistence, correct all along, and the premises
// without which claim 3 could be satisfied by a row that writes the buffer itself. The other
// two, claim 2's `EchoelValueField` ban and claim 3's key ban, passed VACUOUSLY: they are
// negatives over an extraction that found nothing, which is why `c2`'s anchor check is an
// assertion of its own and not a comment (#926, and the same nuance #1320 had to record).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheBufferTierHasADoorAgainTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let config = "Sources/Echoelmusic/Audio/AudioConfiguration.swift"

    /// Claim 1 — the row exists and is MOUNTED. A declared-but-unmounted view is the doorless
    /// shape this whole slice is undoing (`doctor.py --section C`'s register).
    func testTheRowExistsAndIsMounted() throws {
        let code = SourceText.codeOnly(try Self.text(Self.studio))
        XCTAssertTrue(code.contains("private struct AudioLatencyRow: View {"),
                      "`AudioLatencyRow` is gone. `StudioDefaultKeys.audioLatencyMode` is "
                      + "persisted and re-applied at launch; without this row it is a stored "
                      + "audio setting with no reachable control again (#1302/#1331).")
        XCTAssertEqual(
            code.components(separatedBy: "AudioLatencyRow()").count - 1, 1,
            "expected exactly one mount of `AudioLatencyRow()`. Zero = declared but doorless, "
            + "which is the defect. Two = two controls for one session-wide buffer, which can "
            + "disagree.")
    }

    /// Claim 2 — a NAMED choice renders as a Picker, and the tier list comes from the one enum.
    func testTheTiersAreANamedChoice() throws {
        let row = try Self.member("private struct AudioLatencyRow: View",
                                  in: SourceText.codeOnly(try Self.text(Self.studio)))
        XCTAssertFalse(row.isEmpty, "ANCHOR MISSING: `AudioLatencyRow` did not extract (#454).")
        XCTAssertTrue(row.contains("ForEach(AudioConfiguration.LatencyMode.allCases)"),
                      "the tier list is no longer drawn from `AudioConfiguration.LatencyMode` — "
                      + "a hand-written list would be a second spelling of the buffer tiers "
                      + "(#416), and the sizes live on that enum.")
        XCTAssertTrue(row.contains("Picker(\"Audio latency\", selection: $selected)"),
                      "the tier row is no longer a Picker. The parameter-row law is about "
                      + "NUMERIC parameters; these values have names, and turning a named "
                      + "choice into a raw frame count obeys the letter against the purpose.")
        XCTAssertFalse(row.contains("EchoelValueField("),
                       "an `EchoelValueField` on the tier row would put a raw buffer size on "
                       + "screen — see the law's own \"READ THE WORD NUMERIC\" paragraph.")
    }

    /// Claim 3 — the row drives the ONE owner and does NOT persist the preference itself.
    /// This is the half a later "just use @AppStorage" would quietly undo.
    func testTheRowDrivesTheOwnerAndPersistsNothingItself() throws {
        let row = try Self.member("private struct AudioLatencyRow: View",
                                  in: SourceText.codeOnly(try Self.text(Self.studio)))
        XCTAssertTrue(row.contains("try AudioConfiguration.setLatencyMode(mode)"),
                      "the row no longer goes through `setLatencyMode`, the documented ONLY "
                      + "producer of `currentBufferSize` after launch. A direct write would "
                      + "move the constant the measurement, the breadcrumb and the on-screen "
                      + "floor all read, before any request the session granted (#675).")
        XCTAssertFalse(row.contains("audioLatencyMode"),
                       "the row names the persistence key. It must not: `setLatencyMode` "
                       + "persists LAST, after the session grants the tier, so that a refused "
                       + "tier cannot return next launch as though it had worked (#674/#675). "
                       + "A binding that writes the key first reinstates that defect.")
    }

    /// Claim 4 — counterweight: the launch path and the single-owner persistence are unchanged.
    /// Without these, claim 3 would pass against a row that simply wrote the buffer itself.
    func testTheLaunchPathAndTheSingleOwnerSurvive() throws {
        let config = SourceText.codeOnly(try Self.text(Self.config))
        XCTAssertTrue(config.contains("static func applyStoredLatencyMode()"),
                      "the launch re-apply is gone — the persisted tier would stop surviving a "
                      + "relaunch, which is the property the stored key exists for (#1004).")
        XCTAssertTrue(
            config.contains("UserDefaults.standard.set(mode.rawValue, forKey: StudioDefaultKeys.audioLatencyMode.key)"),
            "`setLatencyMode` no longer persists the granted tier. It is the ONE writer of "
            + "that key by design; if persistence moved to a view binding, claim 3's negative "
            + "is now wrong and both must move together.")
    }

    // MARK: - helpers

    private static func member(_ marker: String, in src: String) throws -> String {
        let hits = src.components(separatedBy: marker).count - 1
        guard hits == 1, let start = src.range(of: marker) else {
            throw XCTSkip("anchor `\(marker)` occurs \(hits)× — re-anchor before trusting a zero (#408)")
        }
        guard let open = src[start.upperBound...].firstIndex(of: "{") else { return "" }
        var depth = 0
        var i = open
        while i < src.endIndex {
            let c = src[i]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(src[open...i]) } }
            i = src.index(after: i)
        }
        return String(src[open...])
    }

    private static func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

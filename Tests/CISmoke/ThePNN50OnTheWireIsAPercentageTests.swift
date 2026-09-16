// ThePNN50OnTheWireIsAPercentageTests.swift
// Echoel — #1329. `/echoelmusic/bio/heart/pnn50` has always carried a PERCENTAGE, and three
// integrator-facing documents said 0–1.
//
// ⭐ THE MEASUREMENT, and why the WIRE was the correct half. Four witnesses say percent:
// `HRVMetrics.pnn50` ends in `* 100.0` (both overloads), `BioSampleFrame.hrvPNN50`'s own doc
// says "percentage [0…100]", `BioMetricInfo` renders its unit as "%", and the address sits in
// the clinical trio beside `/rmssd` and `/sdnn`, which are MILLISECONDS — the docs' own next
// sentence calls all three "time-domain statistics in medical units". Three said 0–1:
// `OSCSender`'s address table, `BioEgressPolicy.FieldClass.clinical` ("as a proportion", which
// in a UNIT sentence reads as 0–1) and `docs/integrations.html`. So the prose moved and the
// contract did not: changing a shipped wire value to match a wrong comment would break every
// integrator who read the actual numbers instead of the docs.
//
// ⚠️ THE FAILURE IT CAUSED IS NOT HYPOTHETICAL IN SHAPE. An integrator who trusted the table
// and normalised by 1 pinned every pNN50 above 1 % at full scale — a healthy resting subject
// sits in the tens. That is a silent saturation, the kind nothing in a lighting rig reports.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **7 assertions across three claims**
// (claim 1 = 3 END-TO-END, claim 2 = 3, claim 3 = 1), transcribed in Python and driven against
// BOTH trees. On the parent (`49f4922`) **3 are red and they are ONE finding** (#486): the
// three prose repairs did not exist. Claims 1 and 3 are COUNTERWEIGHTS (#343), green on both
// trees, and claim 1 is the important one: it drives the SHIPPED arithmetic, so the guard
// cannot drift away from the wire the way a prose-only pin would. Claim 3 pins that the
// sender still reads the frame field unscaled — without it, a later "fix" could divide by 100
// in the sender and leave every document here green while the contract silently changed.
//
// ⚠️ NOT PROVEN (§1). That a receiver reads what we send is a DEVICE probe over UDP and stays
// open. What is proven is the arithmetic and the four documents agreeing on its scale.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePNN50OnTheWireIsAPercentageTests: XCTestCase {

    /// Claim 1 — END-TO-END on the shipped statistic: the value is a percentage, and both
    /// overloads agree. A series whose every successive difference exceeds 50 ms is 100 %,
    /// not 1.0.
    func testTheStatisticIsAPercentage() throws {
        let alternating = [600.0, 800.0, 600.0, 800.0, 600.0]
        XCTAssertEqual(
            HRVMetrics.pnn50(rrMs: alternating), 100.0, accuracy: 0.001,
            "every successive |RR difference| here is 200 ms, so pNN50 is 100 % by definition. "
            + "A result of 1.0 would mean the scale had been changed to a proportion — which "
            + "would silently rescale `/echoelmusic/bio/heart/pnn50` for every integrator.")
        XCTAssertEqual(
            HRVMetrics.pnn50(segments: [alternating]), 100.0, accuracy: 0.001,
            "the segment-aware overload disagrees with the flat one on SCALE. They feed the "
            + "same frame field from different sources (camera vs strap); a scale split there "
            + "would make the wire value depend on which sensor is attached.")
        XCTAssertEqual(
            HRVMetrics.pnn50(rrMs: [600.0, 610.0, 620.0]), 0.0, accuracy: 0.001,
            "no successive difference exceeds 50 ms, so pNN50 is 0 — the counterweight that "
            + "keeps the two assertions above from passing on a function that returns a "
            + "constant.")
    }

    /// Claim 2 — the three documents that said 0–1 now say percent.
    func testTheThreeDocumentsSayPercent() throws {
        XCTAssertTrue(
            try text("Sources/Echoelmusic/Sync/OSCSender.swift")
                .contains("/echoelmusic/bio/heart/pnn50   float [0..100] %"),
            "OSCSender's address table no longer states the percentage scale. That table is "
            + "the source of truth CLAUDE.md's OSC section points at.")
        XCTAssertTrue(
            try text("Sources/Echoelmusic/Core/BioEgressPolicy.swift")
                .contains("pNN50 as a PERCENTAGE [0…100] of successive NN intervals"),
            "`FieldClass.clinical` no longer states the scale. It says \"medical units\" in the "
            + "same sentence, so a vague word there reads as 0–1 by contrast with the two "
            + "millisecond fields beside it.")
        XCTAssertTrue(
            try text("docs/integrations.html").contains("<td>0–100 (%)</td>"),
            "the published integration table no longer states the percentage scale. This is "
            + "the one document an external integrator actually reads.")
    }

    /// Claim 3 — counterweight: the sender still puts the frame field on the wire UNSCALED.
    /// Without this, a later "repair" could divide by 100 here and leave claim 2 green while
    /// the contract changed under it.
    func testTheSenderPutsTheFieldOnTheWireUnscaled() throws {
        let code = SourceText.codeOnly(try text("Sources/Echoelmusic/Sync/OSCSender.swift"))
        XCTAssertTrue(
            code.contains("msgs.append((\"/echoelmusic/bio/heart/pnn50\", [frame.hrvPNN50]))"),
            "the pnn50 send no longer passes `frame.hrvPNN50` verbatim. If it is being scaled, "
            + "the four percent witnesses (`HRVMetrics.pnn50`, `BioSampleFrame.hrvPNN50`'s doc, "
            + "`BioMetricInfo`'s \"%\" unit, and the two millisecond siblings) must move in the "
            + "same commit — and so must the three documents claim 2 pins.")
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

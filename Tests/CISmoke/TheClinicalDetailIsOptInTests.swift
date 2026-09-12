// TheClinicalDetailIsOptInTests.swift
// Echoel — #1292. The egress policy could say WHOSE numbers may leave and never WHICH,
// so the three time-domain HRV statistics in medical units — `/heart/rmssd` and
// `/heart/sdnn` in milliseconds, `/heart/pnn50` — shipped on the DEFAULT wire beside the
// musical controls. One gate answering two questions is how the second goes unasked.
//
// THE RULE, one sentence: what the instrument PLAYS may leave; what a CLINICIAN would
// read off may not, unless the player asks for it. Clinical detail is now opt-in
// (`StudioDefaultKeys.oscClinicalDetail`, OFF), with a door in the routing card.
//
// ⚠️ THE RAW HALF IS A TYPE FACT, NOT A POLICY, and claim 5 is the one that proves it:
// `BioSampleFrame` declares no array, no buffer, no `Data` — so an RR-interval series, a
// PPG waveform or a camera frame CANNOT reach an encoder, whatever any switch says.
// `FieldClass.raw` exists so a future field that could has somewhere to be classified.
//
// KIND (§1): END-TO-END BEHAVIOUR for claims 1–4 and 6 (`BioEgressPolicy`,
// `StudioDefaultKeys` and `OSCSender.bioMessages` are shipped Foundation-only value
// types driven directly). SOURCE-TEXT SCAN for 5 and 7–10. What an OSC monitor SEES is a
// DEVICE PROBE — NEEDS-FOUNDER-VERIFY at `StudioDefaultKeys.oscClinicalDetail`.
//
// ⚠️ HONEST GRADING (§3) — TRANSCRIBED (§0) against the parent (`3e04e93`) and this tree,
// every claim driven, not only the changed ones (§3's delta-blindness note):
//   · Claims 1–4 and 6: the file does NOT COMPILE against the parent — `FieldClass`,
//     `fieldClass(ofOSCAddress:)`, `allowsEgress(fieldClass:…)`, `allowsEgress(address:…)`
//     and `oscClinicalDetail` are created by this commit. No assertion has a verdict
//     there; that is ONE absence (#486), not five findings, and it is NOT a regression —
//     they are FORWARD guards and are booked as such.
//   · Claim 5 is a genuine COUNTERWEIGHT: green on both trees. It is the point of the
//     file. It reddens the day someone adds `public let rrIntervals: [Float]` to the
//     frame — which is exactly the event HARD RULE 5 exists to prevent, and which no
//     gate in this repo could otherwise see.
//   · Claims 7–8 are RED on the parent by ANCHOR ABSENCE (the toggle and the applier do
//     not exist) — one finding.
//   · Claims 9–10 are COUNTERWEIGHTS, green on both: the 5.1.3 source gate is unchanged,
//     and `bioMessages(for:)` still takes exactly one argument, so the seven guard call
//     sites that drive it keep compiling (#666 — a required parameter there would have
//     broken every one of them in this commit).
// Stripper: PROPHYLAKTISCH (0 of 3 scan verdicts flip raw-vs-stripped), MEASURED, not
// assumed. The draft of this header claimed TRAGEND on the reasoning that the field docs
// say "[0..1]" and "range [40..200]" and a raw scan would read those as array types. It
// would not: claim 5 only inspects lines containing `public let ` / `public var `, and a
// doc-comment line contains neither. Recorded rather than quietly corrected, because §2
// keeps retracting exactly this — a load-bearing claim that sounded right and was never run.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheClinicalDetailIsOptInTests: XCTestCase {

    private static let clinical = ["/echoelmusic/bio/heart/rmssd",
                                   "/echoelmusic/bio/heart/pnn50",
                                   "/echoelmusic/bio/heart/sdnn"]
    private static let musical = ["/echoelmusic/bio/heart/bpm",
                                  "/echoelmusic/bio/heart/hrv",
                                  "/echoelmusic/bio/coherence",
                                  "/echoelmusic/bio/breath/rate"]

    /// A frame that opens every heart gate: a real pulse plus all three RR statistics.
    private func clinicalFrame(_ source: BioSource = .cameraPPG) -> BioSampleFrame {
        BioSampleFrame(timestamp: 1000, heartRateBPM: 64, hrvNormalized: 0.45,
                       breathRate: 12, breathPhase: 0.3, coherence: 0.62,
                       motionEnergy: 0, source: source,
                       hrvRMSSDms: 42, hrvSDNNms: 55, hrvPNN50: 0.18)
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Brace-matched member extraction (#408) — the bundle's idiom, copied not re-invented.
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

    // MARK: - 1–4  the policy itself

    /// Claim 1 — FORWARD. `.raw` is refused under EVERY setting. This is the assertion the
    /// case exists for: not a stricter default, a value with no permitting configuration.
    func testTheRawClassIsRefusedUnderEverySetting() {
        for enabled in [false, true] {
            XCTAssertFalse(
                BioEgressPolicy.allowsEgress(fieldClass: .raw, clinicalDetailEnabled: enabled),
                """
                `.raw` became permitted with clinicalDetail=\(enabled). HARD RULE 5: the \
                un-derived signal — an RR series, a PPG waveform, camera frames — never \
                leaves, and no switch may admit it. If a real need appears, it is a founder \
                decision and a new class, never a `true` here.
                """)
        }
    }

    /// Claim 2 — FORWARD, and the one that makes failing CLOSED safe. Every address
    /// `bioMessages` can emit must classify; an unknown address is dropped by
    /// `send(frame:)`, so an unclassified new address would go silent. This names it.
    func testEveryEmittableAddressIsClassified() {
        var addresses = Set<String>()
        for source in [BioSource.cameraPPG, .ble, .faceCam, .fallback] {
            for a in OSCSender.bioMessages(for: clinicalFrame(source)).map(\.address) {
                addresses.insert(a)
            }
        }
        // `BioEvent.Kind` is not `CaseIterable`, so the sweep goes through the raw values:
        // a case added later is covered automatically, where a hand-written list would rot
        // silently (#818) and take the exhaustiveness claim down with it.
        var kinds: [BioEvent.Kind] = []
        for raw in UInt8(0)...32 {
            if let k = BioEvent.Kind(rawValue: raw) { kinds.append(k) }
        }
        XCTAssertGreaterThanOrEqual(kinds.count, 6, "the kind sweep found \(kinds.count) — re-anchor (#926)")
        let events = kinds.map {
            BioEvent(timestamp: 1000, kind: $0, confidence: 0.9, aux: 0.1, source: .cameraPPG)
        }
        for a in OSCSender.eventMessages(for: events, lastAnnounced: nil).messages.map(\.address) {
            addresses.insert(a)
        }
        XCTAssertGreaterThanOrEqual(addresses.count, 12,
                                    "the sweep collected \(addresses.count) addresses — too few to be a sweep (#926)")
        for a in addresses.sorted() {
            XCTAssertNotNil(BioEgressPolicy.fieldClass(ofOSCAddress: a), """
                `\(a)` has no FieldClass, so `OSCSender.send(frame:)` DROPS it — the gate \
                fails closed on purpose (#1292). Classify it in `BioEgressPolicy`: \
                `.derived` for a bounded musical control, `.clinical` for a medical-unit \
                statistic. Do not widen a prefix to silence this without reading what the \
                address carries.
                """)
        }
    }

    /// Claim 3 — FORWARD. The split itself: three clinical, the musical ones derived.
    func testTheSplitPutsMedicalUnitsOnOneSideAndMusicOnTheOther() {
        for a in Self.clinical {
            XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: a), .clinical,
                           "`\(a)` is a time-domain statistic in medical units (#1292)")
        }
        for a in Self.musical {
            XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: a), .derived, """
                `\(a)` was reclassified away from `.derived`. It drives a light, an object \
                position or a sound — withholding it does not protect a body, it breaks the \
                thing Echoel is for.
                """)
        }
        XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/gesture/faceSmile"), .derived)
        XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/mod/seq.tempo"), .derived)
        XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/bio/event/heartbeat"), .derived)
        XCTAssertNil(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/bio/heart/rrSeries"),
                     "an address nobody classified must read as unknown, never as permitted")
    }

    /// Claim 4 — FORWARD. The composed gate: source AND field, in both switch positions.
    func testTheComposedGateHoldsBothHalves() {
        for a in Self.musical + Self.clinical {
            XCTAssertFalse(BioEgressPolicy.allowsEgress(address: a, source: .healthKit,
                                                        clinicalDetailEnabled: true), """
                `\(a)` left a HealthKit-sourced frame. 5.1.3 is not negotiable by a \
                convenience switch — the source gate runs FIRST and alone.
                """)
        }
        for a in Self.clinical {
            XCTAssertFalse(BioEgressPolicy.allowsEgress(address: a, source: .cameraPPG,
                                                        clinicalDetailEnabled: false),
                           "`\(a)` is on the default wire again (#1292)")
            XCTAssertTrue(BioEgressPolicy.allowsEgress(address: a, source: .cameraPPG,
                                                       clinicalDetailEnabled: true), """
                `\(a)` no longer returns with the switch ON. The opt-in is the reason this \
                is a switch and not a deletion — TouchDesigner/Max analysis is a real use.
                """)
        }
        for a in Self.musical {
            for enabled in [false, true] {
                XCTAssertTrue(BioEgressPolicy.allowsEgress(address: a, source: .cameraPPG,
                                                           clinicalDetailEnabled: enabled),
                              "`\(a)` must flow in both switch positions (#1292)")
            }
        }
    }

    // MARK: - 5  the raw half, proven at the type

    /// Claim 5 — COUNTERWEIGHT, green on both trees, and the point of this file. The
    /// transport type is scalar-only, so no reconstructible signal can reach an encoder.
    /// This is the "fails if a raw field is ever serialized" test, in the strongest form
    /// available without a device: it fails at the moment such a field is DECLARED.
    func testTheFrameCannotCarryASignal() throws {
        let bus = SourceText.codeOnly(try text("Sources/Echoelmusic/Core/EngineBus.swift"))
        let frame = try Self.member("public struct BioSampleFrame: Sendable, Equatable", in: bus)
        var offenders: [String] = []
        for line in frame.components(separatedBy: "\n") {
            guard line.contains("public let ") || line.contains("public var ") else { continue }
            guard let colon = line.firstIndex(of: ":") else { continue }
            let type = line[line.index(after: colon)...]
                .trimmingCharacters(in: .whitespaces)
            if type.hasPrefix("[") || type.hasPrefix("Data") || type.hasPrefix("Array<")
                || type.hasPrefix("Unsafe") || type.hasPrefix("ContiguousArray") {
                offenders.append(line.trimmingCharacters(in: .whitespaces))
            }
        }
        XCTAssertTrue(offenders.isEmpty, """
            `BioSampleFrame` now declares a collection field: \(offenders)

            That is the moment HARD RULE 5 stops being structural. Until now the frame was \
            scalar-only, so an RR-interval series, a PPG waveform or a camera buffer could \
            not reach `OSCSender.encode` at all — the type refused, not a policy. A \
            collection here can be serialized, so before this line lands: classify it in \
            `BioEgressPolicy.FieldClass` (almost certainly `.raw`), and make sure \
            `fieldClass(ofOSCAddress:)` does not fall into a `.derived` prefix.
            """)
    }

    // MARK: - 6–8  the default, the door, the one owner

    /// Claim 6 — FORWARD. The default IS the decision, so it is pinned as a value.
    func testTheDefaultIsOff() {
        XCTAssertEqual(StudioDefaultKeys.oscClinicalDetail.key, "net.osc.clinicalDetail")
        XCTAssertFalse(StudioDefaultKeys.oscClinicalDetail.value, """
            a fresh install must not stream medical-unit HRV to a user-typed UDP host \
            (#1292). Flipping this default is a founder decision, not a tidy-up.
            """)
    }

    /// Claim 7 — the door. A persisted flag with no reachable off-switch is the thing
    /// CLAUDE.md's register forbids; and a switch that stores but never applies lies (#485).
    func testTheRoutingCardHasTheSwitch() throws {
        let view = SourceText.codeOnly(try text("Sources/Echoelmusic/Studio/PatchbayView.swift"))
        let section = try Self.member("private var networkOutSection: some View", in: view)
        XCTAssertTrue(section.contains("Toggle(isOn: $oscClinicalDetail)"),
                      "the opt-in has no door — the flag would be unreachable (#1292)")
        XCTAssertTrue(view.contains(".onChange(of: oscClinicalDetail) { _, _ in osc.applyEgressPreferences() }"),
                      "a switch that stores but never applies is a control that lies (#485)")
        XCTAssertTrue(view.contains("@AppStorage(StudioDefaultKeys.oscClinicalDetail.key)"),
                      "the key string must not be retyped at the use site (H15-KEYSTORE)")
    }

    /// Claim 8 — ONE owner for the cached flag, the `applyOutputPreferences` shape. A
    /// second writer is how a live edit and a relaunch come to disagree.
    func testTheCacheHasOneOwner() throws {
        let sender = SourceText.codeOnly(try text("Sources/Echoelmusic/Sync/OSCSender.swift"))
        let applier = try Self.member("public func applyEgressPreferences()", in: sender)
        // ⚠️ COUNTING `sendsClinicalDetail =` WOULD BE GREEN FOR THE WRONG REASON (#367):
        // the DECLARATION's initializer is one such occurrence, so the count is 2 whether or
        // not the single assignment still lives in the applier. Ask the question directly —
        // remove the applier's body, and what remains may hold the declaration and nothing else.
        let elsewhere = sender.replacingOccurrences(of: applier, with: "")
        let strays = elsewhere.components(separatedBy: "sendsClinicalDetail =").count - 1
        XCTAssertEqual(strays, 1, """
            `sendsClinicalDetail` is assigned \(strays)× outside `applyEgressPreferences()`; \
            exactly one occurrence is expected there — the `private var` declaration itself. \
            A second writer is how the toggle and the next launch come to disagree about what \
            is on the wire, and it is invisible in a diff that only reads the applier.
            """)
        XCTAssertTrue(elsewhere.contains("private var sendsClinicalDetail = false"),
                      "the surviving occurrence must be the declaration, not a stray assignment")
        XCTAssertTrue(applier.contains("StudioDefaultKeys.oscClinicalDetail.key"),
                      "the applier must read the shared key, not a retyped string (#416)")
        let start = try Self.member("public func start(subscribing bus: EngineBus)", in: sender)
        XCTAssertTrue(start.contains("applyEgressPreferences()"), """
            the persisted opt-in is not applied on start — the wire would carry the \
            previous process's setting until someone touched the toggle (#1292).
            """)
    }

    // MARK: - 9–10  counterweights

    /// Claim 9 — COUNTERWEIGHT. This slice narrowed WHICH fields leave; it must not have
    /// loosened WHOSE. The 5.1.3 source gate is unchanged in both directions.
    func testTheSourceGateIsUnchanged() {
        for s in [BioSource.ble, .cameraPPG, .faceCam, .fallback] {
            XCTAssertTrue(BioEgressPolicy.allowsEgress(s), "\(s) is one of Echoel's own measurements")
        }
        for s in [BioSource.healthKit, .watch, .oura] {
            XCTAssertFalse(BioEgressPolicy.allowsEgress(s), "\(s) is Health-store data — 5.1.3")
        }
    }

    /// Claim 10 — COUNTERWEIGHT, and the reason the filter sits in `send(frame:)` rather
    /// than in `bioMessages`. That function is driven by seven guards in this bundle; a
    /// required parameter on it would have reddened every one of them (#666).
    func testTheMessageBuilderKeptItsSignature() throws {
        let sender = SourceText.codeOnly(try text("Sources/Echoelmusic/Sync/OSCSender.swift"))
        XCTAssertTrue(sender.contains("nonisolated static func bioMessages(for frame: BioSampleFrame) -> [(address: String, floats: [Float])]"),
                      "bioMessages' signature moved — every guard that drives it breaks (#666)")
        let send = try Self.member("private func send(frame: BioSampleFrame)", in: sender)
        XCTAssertTrue(send.contains("BioEgressPolicy.allowsEgress(address: m.address"),
                      "the field gate left the one place a message becomes a datagram (#1292)")
        // The filter can never empty a non-empty batch: all three clinical addresses are
        // gated on a measured pulse, which emits `/heart/bpm`. Driven, not asserted in prose.
        let emitted = OSCSender.bioMessages(for: clinicalFrame()).map(\.address)
        let survivors = emitted.filter {
            BioEgressPolicy.allowsEgress(address: $0, source: .cameraPPG, clinicalDetailEnabled: false)
        }
        XCTAssertTrue(survivors.contains("/echoelmusic/bio/synthetic"), """
            the provenance flag did not survive the filter — a receiver would lose the one \
            signal telling it whether a real body is on the wire (#639).
            """)
        XCTAssertEqual(emitted.count - survivors.count, Self.clinical.count,
                       "exactly the three clinical addresses are withheld, no more and no fewer")
    }
}

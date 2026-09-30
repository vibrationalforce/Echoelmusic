// ThePowerRowSaysWhyDetailStepsDownTests.swift
// Echoel — interface audit 2026-09-30, Zug 3 ("Status-Leiter in Worten für jeden Hardware-Pfad"),
// the last path — the quality governor ("Sparmodus"): the Field panel gets a "Power" row.
//
// WHAT IT GUARDS. `ResourceGovernor` steps visual detail and the bio egress ceiling down on heat,
// Low Power Mode, a low battery and dropped frames — silently since 2026-06-23. Now
// `AdaptiveQuality.pressure(…)` names the ONE condition holding the tier below `.balanced`,
// `ResourceGovernor.pressure` carries it beside `settings`, `PowerRung` (Full / Reduced / Saving)
// and `QualityPressure.cause`/`remedy` give both their words, and `EchoelStudioView.PowerStatusRow`
// renders them under the Field panel's two buttons.
//
// §1 LIMIT: claims 1–3 are END-TO-END BEHAVIOUR on pure types (`AdaptiveQuality`, the enums).
// Claims 4–6 are SOURCE-TEXT SCANS: the cause is derived where the tier is and written beside
// it; the row is a leaf, mounted once, names no pin property; the Full caption's two promises
// (detail follows the tier, the frame rate is pinned at 60) still have their producers. Whether a
// hot phone reads "Reduced · the phone is hot" is a DEVICE PROBE — NEEDS-FOUNDER-VERIFY on the row.
//
// §3 HONEST GRADING. Names NEW symbols (`QualityPressure`, `PowerRung`, `pressure`), so it does
// not compile against the parent: NO assertion has a verdict there. Hand-transcribed in Python
// against both trees: claims 1–3 FORWARD; claim 4 red on the parent for its named reason (no
// `pressure` field, `apply` took one argument); claims 5 red by ANCHOR ABSENCE (no
// `PowerStatusRow`, zero mounts — one absence, #486); claim 6 is a COUNTERWEIGHT green on both.
// ZERO regressions claimed. Stripper measured in the transcription, reported in the commit.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePowerRowSaysWhyDetailStepsDownTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let governor = "Sources/Echoelmusic/Core/ResourceGovernor.swift"
    private static let quality = "Sources/Echoelmusic/Core/AdaptiveQuality.swift"
    private static let metal = "Sources/Echoelmusic/Views/MetalBioView.swift"
    private static let leafOpening = "private struct PowerStatusRow: View {"

    // MARK: - claim 1 (E2E) — the cause is the BINDING condition, every case reached

    func testThePressureNamesTheBindingConditionNotTheLoudestOne() {
        typealias Row = (thermal: ThermalLevel, lowPower: Bool, battery: Float, charging: Bool, fps: Double, expect: QualityPressure)
        let table: [Row] = [
            (.nominal, false, 0.80, false, 0, .none),        // balanced, nothing held back
            (.nominal, false, 0.80, true, 0, .none),         // high (charging, cool, full)
            (.fair, false, 0.80, true, 0, .none),            // fair caps at balanced — still Full, so no cause
            (.serious, false, 0.80, false, 0, .thermal),
            (.critical, false, 0.80, true, 0, .thermal),
            (.nominal, true, 0.80, false, 0, .lowPowerMode),
            (.nominal, true, 0.80, true, 0, .lowPowerMode),  // charging does not lift Low Power Mode's cap
            (.fair, true, 0.80, false, 0, .lowPowerMode),    // fair (balanced cap) does not bind at low; LPM does
            (.nominal, false, 0.15, false, 0, .battery),
            (.nominal, false, 0.05, false, 0, .battery),
            (.serious, false, 0.05, false, 0, .battery),     // minimal: thermal caps at low, battery at minimal
            (.nominal, false, 0.15, true, 0, .none),         // charging lifts the battery cap → balanced
            (.nominal, false, 0.80, false, 20, .frameRate),  // balanced target 60, 20 fps → stepped to low
            (.nominal, true, 0.80, false, 10, .frameRate),   // low (LPM) → minimal by frames: the marginal cause
        ]
        for row in table {
            XCTAssertEqual(AdaptiveQuality.pressure(thermal: row.thermal, lowPower: row.lowPower,
                                                    batteryLevel: row.battery, charging: row.charging,
                                                    measuredFPS: row.fps),
                           row.expect, "thermal=\(row.thermal) lpm=\(row.lowPower) battery=\(row.battery) charging=\(row.charging) fps=\(row.fps)")
        }
        XCTAssertEqual(Set(table.map { $0.expect }).count, QualityPressure.allCases.count,
                       "the table must reach every cause, or a cause has no proof")
        // The cause agrees with the tier it explains: `.none` iff the tier is at or above balanced.
        for row in table {
            let tier = AdaptiveQuality.settings(thermal: row.thermal, lowPower: row.lowPower,
                                                batteryLevel: row.battery, charging: row.charging,
                                                measuredFPS: row.fps).tier
            XCTAssertEqual(row.expect == .none, tier >= .balanced, "cause and tier disagree for \(row)")
        }
    }

    // MARK: - claim 2 (E2E) — the rung is a total function of the tier

    func testEveryTierHasARungAndBothFullTiersReadFull() {
        XCTAssertEqual(PowerRung.rung(tier: .high), .full)
        XCTAssertEqual(PowerRung.rung(tier: .balanced), .full,
                       "balanced and high differ only in the bio ceiling — both are Full to a person")
        XCTAssertEqual(PowerRung.rung(tier: .low), .reduced)
        XCTAssertEqual(PowerRung.rung(tier: .minimal), .saving)
        XCTAssertEqual(Set(QualityTier.allCases.map { PowerRung.rung(tier: $0) }).count, PowerRung.allCases.count)
    }

    // MARK: - claim 3 (E2E) — the words: word-led, a remedy per cause, no struck or recipe word

    func testEveryRungLeadsWithItsWordAndEveryCauseHasARemedy() {
        let forbidden = ["session", "then", "first", "take", "lane", "fps", "tier"]
        var texts: [String] = []
        for rung in PowerRung.allCases {
            for pressure in QualityPressure.allCases {
                let line = rung.line(pressure: pressure)
                XCTAssertTrue(line.hasPrefix(rung.word + " · "), "\(rung)/\(pressure): '\(line)'")
                XCTAssertFalse(rung.caption(pressure: pressure).isEmpty)
                XCTAssertTrue(rung.spoken(pressure: pressure).hasPrefix("Power "))
                texts += [line, rung.caption(pressure: pressure)]
            }
        }
        XCTAssertFalse(PowerRung.full.line(pressure: .thermal).contains("hot"),
                       "Full names no cause — a Full tier has nothing held back, whatever the inputs say")
        for pressure in QualityPressure.allCases where pressure != .none {
            XCTAssertTrue(PowerRung.reduced.line(pressure: pressure).hasSuffix(pressure.cause))
            XCTAssertEqual(PowerRung.reduced.caption(pressure: pressure), pressure.remedy)
            XCTAssertFalse(pressure.remedy.isEmpty)
        }
        XCTAssertEqual(Set(QualityPressure.allCases.map { $0.cause }).count, QualityPressure.allCases.count, "two causes read the same")
        XCTAssertTrue(PowerRung.full.caption(pressure: .none).contains("60"), "the Full caption states the pinned frame rate")
        XCTAssertTrue(QualityPressure.lowPowerMode.remedy.contains("Low Power Mode"))
        XCTAssertTrue(QualityPressure.battery.remedy.contains("Charge"))
        for text in texts {
            let tokens = Set(text.lowercased().split { !$0.isLetter }.map(String.init))
            for word in forbidden {
                XCTAssertFalse(tokens.contains(word), "'\(word)' in '\(text)' — struck word, recipe word or engine jargon")
            }
        }
    }

    // MARK: - claim 4 (SCAN) — the cause is derived where the tier is and written beside it

    func testTheGovernorDerivesTheCauseWithTheTierAndWritesItInApply() throws {
        let gov = try source(Self.governor)
        for needle in ["public private(set) var pressure: QualityPressure = .none",
                       "let cause = AdaptiveQuality.pressure(thermal: thermal, lowPower: lowPower,",
                       "apply(raw, cause: cause)",
                       "apply(AdaptiveQuality.settings(for: manualTier), cause: .none)",
                       "private func apply(_ next: QualitySettings, cause: QualityPressure) {",
                       "if cause != pressure { pressure = cause }"] {
            XCTAssertTrue(gov.contains(needle), "`ResourceGovernor` lost `\(needle)` — the cause must travel WITH the settings it explains")
        }
        XCTAssertEqual(gov.components(separatedBy: "pressure = cause").count - 1, 1,
                       "`pressure` is written exactly once, in `apply` — a second writer could disagree with the tier")
        XCTAssertFalse(gov.contains("pressure = ."), "no literal assignment to `pressure` outside `apply`")
        let q = try source(Self.quality)
        XCTAssertTrue(q.contains("public static func pressure(thermal: ThermalLevel, lowPower: Bool,"), "the derivation is pure, in `AdaptiveQuality`")
        XCTAssertTrue(q.contains("guard t < .balanced else { return .none }"), "`.none` iff the tier is at or above balanced — claim 1 pins it E2E")
    }

    // MARK: - claim 5 (SCAN) — a leaf, mounted once in the Field panel, that reads and never drives

    func testTheRowIsALeafMountedOnceInTheFieldPanel() throws {
        let code = try source(Self.studio)
        let body = try member(Self.leafOpening, in: code)
        for needle in ["@Environment(ResourceGovernor.self) private var governor",
                       "PowerRung.rung(tier: governor.settings.tier)", "governor.pressure",
                       ".accessibilityLabel(\"Power\")", ".accessibilityValue(rung.spoken(pressure: pressure))"] {
            XCTAssertTrue(body.contains(needle), "the Power row lost `\(needle)`")
        }
        for banned in ["recordFrame", "refresh(", "settings =", "Timer.", "Task {", ".isAutomatic", ".manualTier"] {
            XCTAssertFalse(body.contains(banned), "`\(banned)` in the Power row — it reads the governor, it never drives or pins it")
        }
        XCTAssertEqual(code.components(separatedBy: "PowerStatusRow()").count - 1, 1, "mounted exactly once")
        let panel = try member("private var visualPanel: some View {", in: code)
        guard let mount = panel.range(of: "PowerStatusRow()"),
              let fullscreen = panel.range(of: "Text(\"Full screen\")"),
              let look = panel.range(of: "collapsibleGroupHeader(\"Look\"") else {
            return XCTFail("ANCHOR MISSING in `visualPanel`: PowerStatusRow(), the Full screen button or the Look header — re-anchor")
        }
        XCTAssertTrue(fullscreen.upperBound <= mount.lowerBound && mount.upperBound <= look.lowerBound,
                      "the row sits under the panel's two buttons and above the Look group")
        // The host reads no governor state outside the leaf: every `governor.` read in the file is inside the row.
        XCTAssertEqual(code.components(separatedBy: "governor.").count - 1,
                       body.components(separatedBy: "governor.").count - 1,
                       "a `governor.` read appeared OUTSIDE `PowerStatusRow` — the Field panel body would observe the governor (the 10.76.41/50 law)")
    }

    // MARK: - claim 6 (SCAN, COUNTERWEIGHT) — the Full caption's two promises still have producers

    func testTheCaptionsPromisesStillHaveTheirProducers() throws {
        let metal = try source(Self.metal)
        XCTAssertTrue(metal.contains("view.preferredFramesPerSecond = 60"), "\"The frame rate stays at 60\" — the pin is gone from `MetalBioView`")
        XCTAssertTrue(metal.contains("governor?.settings.visualDetailScale"), "\"Visual detail steps down\" — `MetalBioView` no longer reads the tier's detail scale")
        let gov = try source(Self.governor)
        XCTAssertTrue(gov.contains("PollingRateCeiling.setBioHz(next.bioHz)"), "\"bio stream\" — the tier no longer reaches the egress ceiling")
    }

    // MARK: - helpers

    private func member(_ opening: String, in code: String) throws -> String {
        guard code.components(separatedBy: opening).count == 2, let start = code.range(of: opening) else {
            throw AnchorMissing(reason: "`\(opening)` must occur exactly once")
        }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[start.lowerBound...index]) } }
            index = code.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(opening)`")
    }

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}

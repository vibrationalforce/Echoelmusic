// TheWorkstationShowsTheMixLevelTests.swift
// Design slice 13 (mockup vs. shipped Workstation, 2026-09-27): the transport shows the mix level
// beside the song position while the song plays. The mockup's transport read "position · time ·
// level"; D1 built the position, this builds the level. Time is deliberately NOT built (a tick
// clock under a body-following tempo would be a guess).
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claim 1 is END-TO-END on shipped, Foundation-only functions (`MixLevelMeter`).
//   · Claims 2–4 are SOURCE-TEXT SCANS: the leaf is a SwiftUI `View` no test bundle can render.
//     They prove where the text sits, not that a bar moves.
//   · DEVICE PROBE, open: that the bars move with the music on glass, and that VoiceOver reads
//     "Mix level, Left −12.0 dB, right −14.0 dB". NEEDS-FOUNDER-VERIFY.
//
// HONEST GRADING against the parent (27f48341e, §3): the file does not COMPILE there — claim 1
// names `MixLevelMeter`, which this commit creates — so no assertion has a verdict on the parent.
// Hand-transcribed in Python against both trees instead: claims 1–3 and claim 4's shared-bar half
// are FORWARD guards (one absence — the leaf file, its mount and the shared bar do not exist
// there — reported once, #486; the parent's Master panel still carries its own `> 0.9`); claim
// 4's two premises (the engine still publishes `masterLevelR`, the app still injects the engine)
// are COUNTERWEIGHTS, green on both trees. Mutants driven, each red for its named reason: the
// meter moved outside the playing branch, the leaf reading `masterVolume` (also under a renamed
// binding), `WorkstationView` reading the engine, the Master panel's own threshold, one bar.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheWorkstationShowsTheMixLevelTests: XCTestCase {

    private static let leaf = "Sources/Echoelmusic/Studio/WorkstationMixMeter.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let masterGrid = "Sources/Echoelmusic/Studio/MasterLoudnessGrid.swift"
    private static let engine = "Sources/Echoelmusic/Audio/AudioEngine.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    // MARK: 1 — the bar's rules, pure

    func testTheBarFillsHonestlyAndWarnsNearClipping() {
        XCTAssertEqual(MixLevelMeter.fill(0), 0)
        XCTAssertEqual(MixLevelMeter.fill(0.5), 0.5, accuracy: 1e-9)
        XCTAssertEqual(MixLevelMeter.fill(2), 1, "a level above full scale fills the bar, never past it")
        for bad: Float in [.nan, .infinity, -.infinity, -1] {
            XCTAssertEqual(MixLevelMeter.fill(bad), 0, "\(bad) draws nothing — never a NaN or negative width")
            XCTAssertFalse(MixLevelMeter.warns(bad), "\(bad) is not a clip")
        }
        // The switch sits AT the one threshold, whatever a designer sets it to (#364: the name is
        // pinned, not the number).
        let edge = MixLevelMeter.warnLevel
        XCTAssertFalse(MixLevelMeter.warns(edge), "the threshold itself is still the ordinary colour")
        XCTAssertTrue(MixLevelMeter.warns(edge.nextUp), "just above it is the danger colour")
        XCTAssertTrue(edge > 0 && edge <= 1, "the threshold is a level inside the bar")
    }

    func testTheLevelIsSpokenInDecibelsThroughTheOneRule() {
        XCTAssertEqual(MixLevelMeter.spokenText(left: 0.5, right: 0),
                       "Left \(TrackMix.decibelText(0.5)), right \(TrackMix.decibelText(0))")
        XCTAssertEqual(TrackMix.decibelText(0.5), "−6.0 dB", "20·log10(0.5) = −6.02, one decimal")
        XCTAssertTrue(MixLevelMeter.spokenText(left: .nan, right: 1).hasPrefix("Left −∞ dB"),
                      "a non-finite reading is silence, not a number")
    }

    // MARK: 2 — the leaf reads the two meters and nothing else off the engine

    func testTheLeafReadsOnlyTheTwoMixMeters() throws {
        let code = try source(Self.leaf)
        guard let start = code.range(of: "struct WorkstationMixMeter: View {") else {
            return XCTFail("ANCHOR MISSING: `struct WorkstationMixMeter: View {` (#454)")
        }
        let body = String(code[start.upperBound...])
        // The receiver is DERIVED from the declaration, never assumed (#408).
        let declaration = "@Environment(AudioEngine.self) private var "
        guard let decl = body.range(of: declaration) else {
            return XCTFail("the leaf no longer resolves the ONE engine the app injects through `@Environment(AudioEngine.self)` (#454)")
        }
        let receiver = String(body[decl.upperBound...].prefix { $0.isLetter || $0.isNumber || $0 == "_" })
        XCTAssertFalse(receiver.isEmpty, "the engine binding has a name")
        XCTAssertFalse(body.contains("@Bindable"), "the leaf binds nothing — a Bindable alias hides its reads")
        XCTAssertFalse(body.contains("= \(receiver)\n") || body.contains("= \(receiver) "),
                       "the engine is not aliased to a second name")
        var members: Set<String> = []
        var rest = body[...]
        while let hit = rest.range(of: "\(receiver).") {
            let tail = rest[hit.upperBound...]
            members.insert(String(tail.prefix { $0.isLetter || $0.isNumber || $0 == "_" }))
            rest = tail
        }
        XCTAssertEqual(members, ["masterLevel", "masterLevelR"], """
            `WorkstationMixMeter` touches \(members.sorted()) on the engine — only the two mix \
            meters belong here. Anything else hot (the R128 readouts, `masterVolume`) is its own \
            leaf, and nothing here may WRITE to the engine.
            """)
        XCTAssertEqual(body.components(separatedBy: "MixLevelBar(level:").count - 1, 2,
                       "two bars, left and right, drawn by the one shared bar")
        XCTAssertTrue(body.contains(".frame(minHeight: 44)"), "it sits on the 44 pt row beside Play")
        XCTAssertTrue(body.contains(".accessibilityElement(children: .ignore)"), "one element for VoiceOver")
        XCTAssertTrue(body.contains(".accessibilityLabel(\"Mix level\")"), "named for what it is")
        XCTAssertTrue(body.contains(".accessibilityValue(MixLevelMeter.spokenText(left: left, right: right))"),
                      "the value is the one pure sentence (claim 1)")
        XCTAssertTrue(body.contains(".accessibilityAddTraits(.updatesFrequently)"),
                      "VoiceOver is told the value moves")
        XCTAssertTrue(body.contains("before the master chain"),
                      "the hint says WHERE it is measured — it is not the output loudness")
    }

    // MARK: 3 — the Workstation mounts it once, while playing, and names no engine

    func testTheTransportRowMountsTheMeterBesideThePosition() throws {
        let code = try source(Self.workstation)
        guard let row = code.range(of: "private var transportRow: some View {"),
              let next = code.range(of: "private var addTrackRow: some View {", range: row.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: `transportRow` before `addTrackRow` (#454)")
        }
        let transport = String(code[row.upperBound..<next.lowerBound])
        XCTAssertEqual(code.components(separatedBy: "WorkstationMixMeter()").count - 1, 1,
                       "one mix meter on the plate")
        guard let readout = transport.range(of: "SongPositionReadout()"),
              let mount = transport.range(of: "WorkstationMixMeter()"),
              let gate = transport.range(of: "if playing {", options: .backwards,
                                         range: transport.startIndex..<readout.lowerBound) else {
            return XCTFail("the transport row no longer mounts the position readout and the meter")
        }
        XCTAssertLessThan(readout.upperBound, mount.lowerBound, "the meter follows the position")
        // Balanced braces from the `if playing {` to the mount: +1 means still inside that branch.
        // 0 would put the meter after the branch closed — shown while stopped, over silence.
        let lead = transport[gate.lowerBound..<mount.lowerBound]
        XCTAssertEqual(lead.filter { $0 == "{" }.count - lead.filter { $0 == "}" }.count, 1,
                       "the meter sits INSIDE the playing branch, beside the position")
        for name in ["AudioEngine", "audioEngine", "masterLevel"] {
            XCTAssertFalse(code.contains(name), """
                `WorkstationView` names `\(name)` — the view names no engine; the 60 Hz level is \
                read only in its own leaf (`WorkstationMixMeter`), or the whole Workstation — its \
                Pickers included — re-renders sixty times a second (10.76.41/50).
                """)
        }
    }

    // MARK: 4 — one bar for both meters, and the premises the leaf stands on

    func testTheMasterPanelDrawsTheSameBar() throws {
        let grid = try source(Self.masterGrid)
        XCTAssertTrue(grid.contains("MixLevelBar(level: level)"),
                      "the Master panel's level bars are drawn by the shared bar (#416)")
        XCTAssertFalse(grid.contains("> 0.9"), """
            the Master panel carries its own warn threshold again — the Workstation's meter and \
            the Master panel's would then disagree about the same signal. Use `MixLevelMeter`.
            """)
        let engine = try source(Self.engine)
        XCTAssertTrue(engine.contains("var masterLevelR: Float"),
                      "the engine still publishes the right-channel mix level the leaf reads")
        let app = try source(Self.app)
        XCTAssertTrue(app.contains(".environment(audioEngine)"),
                      "the app injects the one engine the leaf resolves — without it the leaf traps at runtime")
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}

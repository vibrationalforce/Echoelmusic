// TheWorkstationShowsTheMixLevelTests.swift
// Design slice 13 (mockup vs. shipped Workstation, 2026-09-27): the transport shows the mix level
// beside the song position while the song plays. The mockup's transport read "position · time ·
// level"; D1 built the position, this builds the level. Time is deliberately NOT built (a tick
// clock under a body-following tempo would be a guess).
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claim 1 is END-TO-END on shipped pure functions (`MixLevelMeter`). Not Foundation-only: the
//     enum sits in a SwiftUI file, which the Xcode-built bundle compiles anyway.
//   · Claims 2–4 are SOURCE-TEXT SCANS: the leaf is a SwiftUI `View` no test bundle can render.
//     They prove where the text sits, not that a bar moves.
//   · DEVICE PROBE, open: that the bars move with the music on glass, and that VoiceOver reads
//     "Mix level, Left 30 percent, right 28 percent", and that the song position beside it is
//     not truncated on a 375 pt phone. NEEDS-FOUNDER-VERIFY.
//
// ⛔ REVIEW OF dfe9525e6 (HIGH): the first version spoke the level in decibels through
// `TrackMix.decibelText`, and claim 1b PINNED that. The meter is `min(3 · RMS, 1)` with a
// peak-hold — not a dB level — so VoiceOver said ≈ 9.5 dB too much and froze at "0.0 dB" on any
// loud mix. It now speaks the share of the meter, and claim 1b pins THAT, plus the absence of "dB".
//
// HONEST GRADING against the parent (27f48341e, §3): the file does not COMPILE there — claim 1
// names `MixLevelMeter`, which this commit creates — so no assertion has a verdict on the parent.
// The review repair is graded against dfe9525e6 instead: claim 1b is red there (the dB sentence),
// every other claim green on both.
// Hand-transcribed in Python against both trees instead: claims 1–3 and claim 4's shared-bar half
// are FORWARD guards (one absence — the leaf file, its mount and the shared bar do not exist
// there — reported once, #486; the parent's Master panel still carries its own `> 0.9`); claim
// 4's two premises (the engine still publishes `masterLevelR`, the app still injects the engine)
// are COUNTERWEIGHTS, green on both trees. Mutants driven, each red for its named reason: the
// meter moved outside the playing branch, the leaf reading `masterVolume` (also under a renamed
// binding), `WorkstationView` resolving the engine, the Master panel drawing its own bar, one bar,
// the spoken text back in decibels.

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

    func testTheLevelIsSpokenAsAShareOfTheMeterNeverInDecibels() {
        XCTAssertEqual(MixLevelMeter.spokenText(left: 0.3, right: 0.28), "Left 30 percent, right 28 percent")
        XCTAssertEqual(MixLevelMeter.spokenText(left: 2, right: 0), "Left 100 percent, right 0 percent",
                       "the spoken share is the drawn share — capped at a full bar")
        XCTAssertEqual(MixLevelMeter.spokenText(left: .nan, right: -.infinity), "Left 0 percent, right 0 percent",
                       "a non-finite reading is an empty bar, not a number")
        for level: Float in [0, 0.1, 0.5, 0.9, 1] {
            XCTAssertFalse(MixLevelMeter.spokenText(left: level, right: level).contains("dB"), """
                the meter is min(3 · RMS, 1) with a peak-hold, not a decibel level — spoken as dB it \
                reads ≈ 9.5 dB too loud and freezes at "0.0 dB" on any loud mix (review of dfe9525e6)
                """)
        }
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
            meters belong here. Anything else hot (the R128 readouts, `masterVolume`) is its own leaf.
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
        // Balanced braces from the `if playing {` to the mount: ≥ 1 means still inside that branch
        // (a wrapping stack or a further condition adds one; that is fine). 0 would put the meter
        // after the branch closed — shown while stopped, over silence.
        let lead = transport[gate.lowerBound..<mount.lowerBound]
        XCTAssertGreaterThanOrEqual(lead.filter { $0 == "{" }.count - lead.filter { $0 == "}" }.count, 1,
                                    "the meter sits INSIDE the playing branch")
        // The freeze law is about a 60 Hz READ in the host body. The host cannot read the meter
        // without resolving the engine, so the ban is on resolving it — not on the word.
        for needle in ["AudioEngine.self", "audioEngine.masterLevel"] {
            XCTAssertFalse(code.contains(needle), """
                `WorkstationView` contains `\(needle)` — the 60 Hz level is read only in its own \
                leaf (`WorkstationMixMeter`), or the whole Workstation — its Pickers included — \
                re-renders sixty times a second (10.76.41/50).
                """)
        }
    }

    // MARK: 4 — one bar for both meters, and the premises the leaf stands on

    func testTheMasterPanelDrawsTheSameBar() throws {
        let grid = try source(Self.masterGrid)
        XCTAssertTrue(grid.contains("MixLevelBar(level: level)"),
                      "the Master panel's level bars are drawn by the shared bar (#416)")
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

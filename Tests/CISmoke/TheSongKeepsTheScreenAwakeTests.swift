// TheSongKeepsTheScreenAwakeTests.swift
// Echoel — modes census 2026-09-26 (Performance D2): a song playing holds the screen awake.
//
// WHAT THIS PINS. `updateKeepAwake()` held the screen for the instrument, a breathing guide,
// a projection and a watched fullscreen picture — never for the SONG. A song played from the
// Workstation with no body take and no projector made every term false, so iOS dimmed and
// locked the phone mid-set, and a lock tears down the foreground scene.
//
// 1. SOURCE: the method's OR carries `timelinePlayer.isPlaying`.
// 2. COUNTERWEIGHT (the freeze law, 10.76.41/50): the term is COLD — `isPlaying` flips on play
//    and on stop — and the root never reads the song POSITION (`currentTick`), which is the
//    hot half of the same object. The trigger expression that re-reads the method is pinned
//    whole in `TheBreathingPracticeIsInTheMainViewTests` (moved in the same commit).
//
// Grading (§0, no Swift toolchain): transcribed against this tree — claim 1 red on the parent
// (`4884c7a47`), green here; claim 2 green on both. SOURCE-TEXT scan: it proves the expression
// is written this way, never that a device stays awake — a device look.
// NEEDS-FOUNDER-VERIFY: Workstation, a song with a part, no body take, no projector — press
// Play and leave the phone untouched past its auto-lock time: the screen stays on; Stop, and
// it dims normally.

import Foundation
import XCTest

final class TheSongKeepsTheScreenAwakeTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    func testKeepAwakeCountsAPlayingSong() throws {
        let studio = try code(of: Self.studio)
        guard let head = studio.range(of: "private func updateKeepAwake() {"),
              let end = studio.range(of: "#endif", range: head.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: `private func updateKeepAwake() {` … `#endif` (#454)")
        }
        let method = studio[head.upperBound..<end.lowerBound]
        XCTAssertTrue(method.contains("|| timelinePlayer.isPlaying"), """
            `updateKeepAwake()` no longer counts a playing song. With no body take and no \
            projector every other term is false, so the phone locks mid-set. If keep-awake \
            moved to another mechanism, move `TheBreathingPracticeIsInTheMainViewTests`' \
            trigger pin with it (#456).
            """)
    }

    func testTheRootNeverReadsTheSongPosition() throws {
        let studio = try code(of: Self.studio)
        XCTAssertFalse(studio.contains("timelinePlayer.currentTick"), """
            `EchoelStudioView` reads the song POSITION. That is the hot half of the player — \
            it moves while the song plays — and a read in the root body rebuilds everything \
            below it and tears down an open `.menu` Picker (10.76.41/50). Read it in a leaf \
            (`ArrangePlayheadView` is the pattern).
            """)
    }

    private func code(of relativePath: String) throws -> String {
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

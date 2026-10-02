// TheWorkstationIconsScaleWithTheTextTests.swift
// Echoel — modes census 2026-09-26, UX D: the Workstation's button icons grow with Dynamic Type.
//
// WHAT THIS PINS. Seven buttons in `WorkstationView` (Play/Stop, Add Audio Track, the import and
// new-part doors among them) drew their SF Symbol with `.system(size: 13)` and
// their label with `EchoelTheme.font(13, …)`. The label scales with Dynamic Type, the absolute
// system size does not — at large text sizes the icon stayed 13 pt beside a much larger word.
// The icon now takes the label's own font, so both scale together.
//
// 1. SOURCE: `WorkstationView.swift` and the leaves it hosts (a NAMED list, grown slice by slice
//    since the review of 0c2e7b908) contain no `.system(size:` — scoped on purpose (#364): other files keep legitimate fixed icons (`CoachingTextScalesTests` names
//    `infoButton` as one), and this guard does not reach them.
// 2. COUNTERWEIGHTS (#343): the file still draws SF Symbols (a scan over a file with no icons
//    would pass for nothing), and `EchoelTheme.font` is still the scaling face
//    (`relativeTo: .body`) — the premise that makes the swap a fix.
//
// 3. SOURCE: the icons that now grow must still FIT. The Save/Open pair shares one row with a
//    92 pt minimum per door; at AX4–AX5 that row outgrew a phone (review of 0c2e7b908, MEDIUM),
//    so it sits in a `ViewThatFits` whose fallback STACKS the two doors.
//
// ⭐ DAW SHELL S3 (2026-10-02): claim 3's row is deleted (Save and Open are ≡ menu entries); the
//    claim now pins the row ABSENT and the two menu entries present — red on f4b4f006d (the row
//    exists there), green here.
// Grading (§0, no Swift toolchain): transcribed against both trees — claim 1 red on the parent
// (`e84bc229d`, seven `.system(size: 13, weight: .semibold)`), green here; claim 2 green on both;
// claim 3 red on `0c2e7b908` (a bare `HStack`), green here — a regression pin for the review.
// SOURCE-TEXT scan: it proves the font is written this way, never how it reads on glass.
// NEEDS-FOUNDER-VERIFY: Settings → Accessibility → Larger Text at the largest size → Workstation:
// the Play / Add Audio Track / Import icons grow with their labels and nothing clips.

import Foundation
import XCTest

final class TheWorkstationIconsScaleWithTheTextTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let theme = "Sources/Echoelmusic/Studio/EchoelTheme.swift"
    /// The plate and the leaves it hosts (review of 0c2e7b908, LOW: the same defect sat one
    /// file over, in the editors the Workstation opens). A NAMED list, not a directory walk
    /// (#364): other surfaces keep legitimate fixed icons.
    private static let plate = [workstation] + [
        "PartNoteEditor", "SelectedPartBar", "SongHistoryRow",
        "SessionLaunchView", "SongAutomationEditor", "TrackInspectorView",
        "MediaBrowserView", "RecordTakeControls",
    ].map { "Sources/Echoelmusic/Studio/\($0).swift" }

    func testTheWorkstationHasNoFixedSizeFont() throws {
        for path in Self.plate {
            let code = try source(path)
            XCTAssertFalse(code.contains(".system(size:"), """
                `\(path)` sets an absolute `.system(size:)` again. It does not scale with Dynamic \
                Type, so the icon stays small beside a label that grows. Use the label's own \
                `EchoelTheme.font(_:_:)` on the `Image(systemName:)`.
                """)
        }
    }

    func testTheIconsStillExistAndTheFaceStillScales() throws {
        for path in Self.plate {
            XCTAssertTrue(try source(path).contains("Image(systemName:"),
                          "the scan above only means something while `\(path)` draws icons")
        }
        let theme = try source(Self.theme)
        XCTAssertTrue(theme.contains("return .custom(faceName(weight), size: size, relativeTo: .body)"),
                      "`EchoelTheme.font` must stay the Dynamic-Type-scaling face, or the swap fixed nothing")
    }

    /// ⛔ UNTIL DAW SHELL S3 (2026-10-02) THIS PINNED THE `ViewThatFits` OF `WorkstationProjectRow`:
    /// two 92 pt Save/Open doors whose icons grow with the text outgrew a phone row at AX4–AX5, so
    /// the fallback stacked them. S3 deleted the row — Save and Open are entries of the ≡ menu,
    /// which the system lays out as one row per entry at every text size. The defect this claim
    /// held shut can only come back as a NEW fixed-width door row on the plate, so that is what is
    /// pinned now: no row, no `door(` helper, and the two words reachable as menu entries instead.
    func testTheSaveAndOpenDoorsStackWhenTheyNoLongerFit() throws {
        let code = try source(Self.workstation)
        XCTAssertFalse(code.contains("struct WorkstationProjectRow"), """
            the Piece stage builds its own Save/Open row again — a second door to each, next to \
            the ≡ menu, and a fixed-width pair that outgrows a phone row at the largest text sizes
            """)
        XCTAssertFalse(code.contains("private func door("), "the deleted row's door helper is back on the plate")
        let workspace = try source("Sources/Echoelmusic/Studio/WorkspaceView.swift")
        for entry in ["Label(\"Save\", systemImage:", "Label(\"Open\", systemImage:"] {
            XCTAssertEqual(workspace.components(separatedBy: entry).count - 1, 1, """
                `\(entry)` is not built exactly once in the ≡ menu — the one place Save and Open \
                live since S3, and a system menu row reflows at every text size
                """)
        }
    }

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

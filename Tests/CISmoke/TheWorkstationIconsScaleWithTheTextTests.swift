// TheWorkstationIconsScaleWithTheTextTests.swift
// Echoel — modes census 2026-09-26, UX D: the Workstation's button icons grow with Dynamic Type.
//
// WHAT THIS PINS. Seven buttons in `WorkstationView` (Play/Stop, Add Audio Track, the import and
// new-part doors among them) drew their SF Symbol with `.system(size: 13)` and
// their label with `EchoelTheme.font(13, …)`. The label scales with Dynamic Type, the absolute
// system size does not — at large text sizes the icon stayed 13 pt beside a much larger word.
// The icon now takes the label's own font, so both scale together.
//
// 1. SOURCE: `WorkstationView.swift` contains no `.system(size:` — scoped to this ONE file on
//    purpose (#364): other files keep legitimate fixed icons (`CoachingTextScalesTests` names
//    `infoButton` as one), and this guard does not reach them.
// 2. COUNTERWEIGHTS (#343): the file still draws SF Symbols (a scan over a file with no icons
//    would pass for nothing), and `EchoelTheme.font` is still the scaling face
//    (`relativeTo: .body`) — the premise that makes the swap a fix.
//
// Grading (§0, no Swift toolchain): transcribed against both trees — claim 1 red on the parent
// (`e84bc229d`, seven `.system(size: 13, weight: .semibold)`), green here; claim 2 green on both.
// SOURCE-TEXT scan: it proves the font is written this way, never how it reads on glass.
// NEEDS-FOUNDER-VERIFY: Settings → Accessibility → Larger Text at the largest size → Workstation:
// the Play / Add Audio Track / Import icons grow with their labels and nothing clips.

import Foundation
import XCTest

final class TheWorkstationIconsScaleWithTheTextTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let theme = "Sources/Echoelmusic/Studio/EchoelTheme.swift"

    func testTheWorkstationHasNoFixedSizeFont() throws {
        let code = try source(Self.workstation)
        XCTAssertFalse(code.contains(".system(size:"), """
            `WorkstationView` sets an absolute `.system(size:)` again. It does not scale with \
            Dynamic Type, so the icon stays small beside a label that grows. Use the label's own \
            `EchoelTheme.font(_:_:)` on the `Image(systemName:)`.
            """)
    }

    func testTheIconsStillExistAndTheFaceStillScales() throws {
        let code = try source(Self.workstation)
        XCTAssertTrue(code.contains("Image(systemName:"), "the scan above only means something while the file draws icons")
        let theme = try source(Self.theme)
        XCTAssertTrue(theme.contains("return .custom(faceName(weight), size: size, relativeTo: .body)"),
                      "`EchoelTheme.font` must stay the Dynamic-Type-scaling face, or the swap fixed nothing")
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

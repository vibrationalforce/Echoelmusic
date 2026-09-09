// TheLaunchScreenIsTheSystemDefaultTests.swift
// Echoel — #1156. Blocking bundle. SOURCE-TEXT SCAN (`Tests/CISmoke/CLAUDE.md` §1): it proves
// what the plist and the asset catalogue SAY, never what a device draws in its first frame.
//
// ⭐ WHY THIS FILE EXISTS. Two artefacts in this repo point at a branded launch screen and
// NEITHER is wired: `LaunchScreenView` (a black SwiftUI brand screen, built only inside
// `#if DEBUG`) and `Assets.xcassets/LaunchScreenBackground.colorset` (pure black in both
// appearances, referenced nowhere). `Resources/iOS/Info.plist` declares `UILaunchScreen` as an
// EMPTY dictionary, so iOS uses its default background. On a light-appearance device the cold
// launch is therefore a bright window first and the app's black surface second.
//
// ⚠️ THE SWIFT HALF IS A DEAD END BY CONSTRUCTION, and that is the part worth pinning: iOS
// draws the launch screen BEFORE any Swift runs, so no amount of wiring `LaunchScreenView` can
// change it. A session that finds the doorless view and "fixes" it by mounting it somewhere
// would ship a change that does nothing and believe the gap closed.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does NOT forbid the repair. `Info.plist` is
// founder-gated (report, do not edit — `.claude/rules/context.md` §3); the day the founder adds
// `UIColorName` → `LaunchScreenBackground`, claim 2 goes red BY DESIGN and its message names the
// prose that must move in the same commit. Red here means the gap was closed, not broken.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **9 `XCTAssert*` across 5 claims**, plus 2
// `XCTFail` guards that turn an unreadable file or a moved anchor into a loud failure instead of
// a quiet zero. Counts re-derived, not remembered: `grep -c XCTAssert` = 9, `grep -c XCTFail` =
// 2, `grep -c '^    func test'` = 5. All scans are POSITIVE — each must FIND its needle, so a
// broken read fails loudly (the C1c law: a scan that matches nothing is a finding, never a
// pass). Every needle was transcribed against today's tree BEFORE it was written, and four
// mutants were driven against the logic: a filled `UILaunchScreen` dict (claim 2 red), a
// recoloured asset (claim 1 red), the note deleted (claim 5 red), and the brand screen mounted
// outside the DEBUG block (claim 3 — which did NOT go red on the first draft, see the ⛔ at that
// claim). They are green on today's tree and green on the tree before this slice except claim 5,
// i.e. **0 regression catches, 5 COUNTERWEIGHTS + 1 pin of the new prose (#343)**. Booking the
// counterweights as catches would be the flattering direction (#433/#464): they buy the day
// someone changes one of these four files, not today.

import Foundation
import XCTest

final class TheLaunchScreenIsTheSystemDefaultTests: XCTestCase {

    private static let plistFile = "Resources/iOS/Info.plist"
    private static let colorFile =
        "Sources/Echoelmusic/Resources/Assets.xcassets/LaunchScreenBackground.colorset/Contents.json"
    private static let viewFile = "Sources/Echoelmusic/Resources/AppIcon.swift"

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func read(_ rel: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(rel)
        let text = try String(contentsOf: url, encoding: .utf8)
        guard !text.isEmpty else {
            XCTFail("\(rel) read as empty — the scan found nothing, not nothing wrong.")
            return ""
        }
        return text
    }

    /// claim 1 — the black launch colour EXISTS and is genuinely black in both appearances.
    /// Without this, claim 2's "the asset is one plist key away" would be a guess about a file
    /// nobody checked.
    func testTheBlackLaunchColourExistsInBothAppearances() throws {
        let json = try read(Self.colorFile)
        let zeros = json.components(separatedBy: "\"0.000\"").count - 1
        // 2 colours x { alpha=1.000, red, green, blue } -> six "0.000" components in total.
        XCTAssertEqual(zeros, 6, """
            LaunchScreenBackground.colorset no longer holds two all-zero (black) sRGB colours \
            (found \(zeros) zero components). If it was recoloured, the note in \
            \(Self.viewFile) that calls it "pure black in BOTH appearances" must move with it.
            """)
        XCTAssertTrue(json.contains("\"appearance\" : \"luminosity\""), """
            The colorset lost its light/dark split. The note in \(Self.viewFile) says the asset \
            is black in BOTH appearances — re-anchor both together.
            """)
    }

    /// claim 2 — and the plist does NOT use it. This is the whole finding, and the assertion
    /// that goes red on the day the founder closes the gap.
    func testTheLaunchScreenDictionaryIsStillEmpty() throws {
        let plist = try read(Self.plistFile)
        XCTAssertTrue(plist.contains("<key>UILaunchScreen</key>"), """
            Info.plist no longer declares UILaunchScreen at all. That is a bigger change than \
            this guard describes — read the file before assuming it is only this test's problem.
            """)
        let empty = plist.components(separatedBy: "<key>UILaunchScreen</key>")
            .dropFirst().first?.trimmingCharacters(in: .whitespacesAndNewlines)
            .hasPrefix("<dict/>") ?? false
        XCTAssertTrue(empty, """
            UILaunchScreen is no longer an empty <dict/> — the branded launch screen was wired, \
            which is the REPAIR this guard deliberately does not forbid (#364). Move the ⛔ note \
            on LaunchScreenView in \(Self.viewFile) in this commit: it states as fact that the \
            dictionary is empty and that the launch window uses the system default background.
            """)
    }

    /// claim 3 — the SwiftUI brand screen is still preview-only, so nobody has "fixed" the gap
    /// by mounting a view that iOS cannot use for this.
    ///
    /// ⛔ IT READS COMMENT-STRIPPED TEXT, AND THE FIRST DRAFT DID NOT — which made it unable to
    /// fire at all. It anchored on the first occurrence of the literal `#if DEBUG`, and the ⛔
    /// note this same slice added to `LaunchScreenView` QUOTES that directive in prose, two
    /// hundred lines above the real one. So "everything before the DEBUG block" became
    /// "everything before my own paragraph", the declaration fell outside the window, and the
    /// count was zero for a reason that had nothing to do with the code. Caught by driving the
    /// mutant (#762 is the same defect one file over: a note ABOUT a view read as a call).
    func testTheSwiftUIBrandScreenIsStillDebugOnly() throws {
        let file = SourceText.codeOnly(try read(Self.viewFile))
        guard let debugRange = file.range(of: "#if DEBUG") else {
            XCTFail("\(Self.viewFile) no longer has a #if DEBUG block; re-anchor claim 3.")
            return
        }
        let beforeDebug = String(file[file.startIndex..<debugRange.lowerBound])
        XCTAssertTrue(beforeDebug.contains("struct LaunchScreenView"), """
            The declaration no longer sits above the #if DEBUG block, so this window measures \
            the wrong span. Re-anchor claim 3 before trusting its zero.
            """)
        let sites = beforeDebug.components(separatedBy: "LaunchScreenView()").count - 1
        XCTAssertEqual(sites, 0, """
            LaunchScreenView is now constructed OUTSIDE the #if DEBUG block (\(sites) sites). \
            iOS draws the launch screen before Swift runs, so this cannot be what a user sees at \
            launch — check whether the change was made in the belief that it closes the gap.
            """)
    }

    /// claim 4 — the shipped icon really does come from the catalogue, which is what makes
    /// AppIconView's preview-only parking legitimate rather than a lost door.
    func testTheShippedIconComesFromTheAssetCatalogue() throws {
        let root = try repoRoot()
        let iconSet = root.appendingPathComponent(
            "Sources/Echoelmusic/Resources/Assets.xcassets/AppIcon.appiconset")
        XCTAssertTrue(FileManager.default.fileExists(atPath: iconSet.path), """
            AppIcon.appiconset is gone. The note on AppIconView calls the catalogue the shipped \
            icon and this view merely its renderer — that reasoning needs the set to exist.
            """)
    }

    /// claim 5 — both notes are actually at their declarations. #1147: a register entry does not
    /// reach the line a session reads first.
    func testBothDeclarationsCarryTheirNote() throws {
        let file = try read(Self.viewFile)
        XCTAssertTrue(file.contains("PREVIEW-ONLY, AND THAT IS CORRECT (#1156"),
                      "AppIconView lost its #1156 note; it is the only place that says the "
                      + "catalogue ships the icon and this view only renders it.")
        XCTAssertTrue(file.contains("CANNOT BECOME ONE FROM SWIFT (#1156"),
                      "LaunchScreenView lost its #1156 note; it is the only place that says iOS "
                      + "draws the launch screen before Swift runs.")
    }
}

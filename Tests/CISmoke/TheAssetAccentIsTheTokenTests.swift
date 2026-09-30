// TheAssetAccentIsTheTokenTests.swift
// Echoel — Zug 4 „Klarheit" (2026-09-30): the asset catalog's accent IS the theme's accent.
//
// WHAT THIS PINS. Two definitions of "the bio-green" existed. `EchoelTheme.accent` — the token
// every explicit `.tint(EchoelTheme.accent)` and every signal bar draws — and
// `Assets.xcassets/AccentColor.colorset`, which `project.yml` names as the GLOBAL accent
// (`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor`). Every system control that
// is not explicitly tinted draws the ASSET: a `Toggle` whose `.tint` sits four lines below its
// label closure or is absent, an `.alert` button, a `TextField` cursor, a `Slider` track.
// Measured 2026-09-30: asset light #22C55E, asset dark #34D381, token #4CD98C — three greens for
// one word. One definition per decision (#416): the asset now carries the token's components
// in BOTH appearances, so nothing has to remember to tint.
//
// 1. END-TO-END over shipped files: each colour in the colorset equals the token's `Color(red:
//    green: blue:)` components, read from `EchoelTheme.swift` — never a literal here (#364/#416;
//    change the token and the asset must follow, the number itself is the designer's).
// 2. COUNTERWEIGHTS (#343): the colorset still holds TWO colours (the light/dark split is kept
//    on purpose — a future light appearance may want its own value, and then this guard names
//    the place), and `project.yml` still names `AccentColor` as the global accent — without that
//    the asset is decoration and aligning it proved nothing. ⚠️ `project.yml` is READ here, never
//    edited (founder-gated).
//
// Grading (§0, no Swift toolchain; transcribed in Python against both trees): claim 1 red on
// the parent for both colours (0.133/0.773/0.369 and 0.204/0.827/0.506 against 0.30/0.85/0.55 —
// six components, ONE finding, #486), green here; claim 2 green on both.
// DEVICE PROBE open: an untinted Toggle (Routing → "Network MIDI") shows the same green as the
// pulse dot — NEEDS-FOUNDER-VERIFY.

import Foundation
import XCTest

final class TheAssetAccentIsTheTokenTests: XCTestCase {

    private static let colorset =
        "Sources/Echoelmusic/Resources/Assets.xcassets/AccentColor.colorset/Contents.json"
    private static let theme = "Sources/Echoelmusic/Studio/EchoelTheme.swift"
    private static let project = "project.yml"

    // MARK: 1 — the asset carries the token

    func testEveryAssetColourEqualsTheThemeAccent() throws {
        let token = try themeAccent()
        let colours = try assetColours()
        XCTAssertFalse(colours.isEmpty, "ANCHOR MISSING: no colours in \(Self.colorset) (#454)")
        for (i, c) in colours.enumerated() {
            for (channel, want) in [("red", token.r), ("green", token.g), ("blue", token.b)] {
                let got = c[channel] ?? .nan
                XCTAssertEqual(got, want, accuracy: 0.0005, """
                    AccentColor.colorset colour \(i) has \(channel) = \(got); `EchoelTheme.accent` \
                    says \(want). Untinted system controls (a Toggle, an alert button, a text \
                    cursor) draw the ASSET, so this is a second bio-green on screen. Write the \
                    token's components into the colorset — or change the token, and the asset \
                    follows in the same commit.
                    """)
            }
            XCTAssertEqual(c["alpha"] ?? .nan, 1.0, accuracy: 0.0005, "the accent is opaque")
        }
    }

    // MARK: 2 — counterweights

    func testTheColorsetKeepsItsTwoAppearancesAndIsTheGlobalAccent() throws {
        XCTAssertEqual(try assetColours().count, 2, """
            The colorset no longer holds exactly two colours (universal + dark). The split is \
            kept on purpose so a future light appearance has its own slot; if it was collapsed, \
            update the header of this file with the reason.
            """)
        let yml = try text(Self.project)
        XCTAssertTrue(yml.contains("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor"), """
            project.yml no longer names `AccentColor` as the global accent, so the asset this \
            file aligns is not what untinted controls draw any more. Point this guard at the \
            new name (project.yml itself is founder-gated — report, do not edit).
            """)
    }

    // MARK: helpers

    private struct RGB { let r: Double; let g: Double; let b: Double }

    private func themeAccent() throws -> RGB {
        let code = SourceText.codeOnly(try text(Self.theme))
        let pattern = #"static let accent\s*=\s*Color\(red: ([0-9.]+), green: ([0-9.]+), blue: ([0-9.]+)\)"#
        guard let m = code.range(of: pattern, options: .regularExpression) else {
            throw XCTSkip("ANCHOR MISSING: `static let accent = Color(red:green:blue:)` in EchoelTheme — re-anchor this guard with the token's new spelling (#454)")
        }
        let nums = code[m].components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .compactMap(Double.init)
        guard nums.count == 3 else { throw XCTSkip("ANCHOR MISSING: three components expected, got \(nums.count)") }
        return RGB(r: nums[0], g: nums[1], b: nums[2])
    }

    /// Each colour's components as doubles: the catalog stores them as strings ("0.300").
    private func assetColours() throws -> [[String: Double]] {
        let data = Data(try text(Self.colorset).utf8)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let colours = root?["colors"] as? [[String: Any]] ?? []
        return colours.map { entry in
            let comps = (entry["color"] as? [String: Any])?["components"] as? [String: String] ?? [:]
            var out: [String: Double] = [:]
            for (k, v) in comps { out[k] = Double(v) }
            return out
        }
    }

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let s = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            throw XCTSkip("ANCHOR MISSING: cannot read \(relativePath) (#454)")
        }
        return s
    }
}

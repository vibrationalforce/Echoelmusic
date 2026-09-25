// TheAUv3SlidersReadTheTreeRangeTests.swift
// Echoel — overnight P8 (2026-09-25). Blocking bundle. SOURCE-TEXT SCAN
// (`Tests/CISmoke/CLAUDE.md` §1): the AUv3 extension is its own module, which this bundle
// cannot import, so the view is read, not driven.
//
// ⭐ THE DEFECT (#416, latent). Since WA3.2 the AUv3 parameter tree is BUILT from the canonical
// descriptors (`EchoelBodyVibeAUv3Mapping.resolve()`): every host-visible range, default and
// address comes from one table. The plug-in's own SwiftUI view did not follow: it restated all
// eight slider ranges (`range: 0...1`, `range: 40...440`) and all eight addresses
// (`address: 0` … `address: 7`) as literals. Today they agree with the table. Nothing tied
// them to it — a descriptor range change would have left the in-plug-in slider sweeping the
// OLD range while the host's automation lane showed the new one, and a reordered address
// would have moved a different knob than its label names.
// The view now reads each range from the tree (`AUv3ViewModel.range(for:)`) and names each
// address by its `ParameterAddress` case. Nothing a user sees changes today.
//
// ⚠️ HONEST GRADING (transcribed in Python against both trees; no toolchain, §0).
//   · claim 1 is a REGRESSION: on the parent the view body carries eight `range:` literals and
//     eight numeric addresses. One finding — one mapping spelled twice (#486), not sixteen.
//   · claim 2 is a FORWARD guard: `range(for:)` is created by this commit and could never have
//     been red for its own reason on the parent (it is absent there — one absence).
//   · claim 3 is a COUNTERWEIGHT: the tree is still built from the resolved descriptor's
//     `min`/`max`, i.e. the range the slider now reads IS the canonical one. Green on both.
//   · Not executed. The extension is a dependency of the app target (`project.yml`), so BOTH
//     gates compile it: `Xcode Compile Check` (Release, device) and `Build for Testing` (Debug,
//     Simulator). (⛔ The first version of this header, and the message of 6ffd8cfbd, said
//     "never in Build for Testing". Review 4 refuted that.) DEVICE PROBE open: the plug-in UI in
//     a host (AUM), each slider sweeping its full host-visible range.

import XCTest

final class TheAUv3SlidersReadTheTreeRangeTests: XCTestCase {

    private static let view = "Sources/EchoelmusicAUv3/AudioUnitViewController.swift"
    private static let unit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    /// claim 1 — the plug-in view restates no range and no numeric address.
    func testThePluginViewRestatesNoRangeOrAddress() throws {
        let code = try source(Self.view)
        guard let head = code.range(of: "struct AUv3PluginView: View {") else {
            XCTFail("`AUv3PluginView` moved — re-anchor (#454).")
            return
        }
        let body = String(code[head.upperBound...])
        XCTAssertFalse(body.contains("range: "), """
            `AUv3PluginView` passes a `range:` literal again. The tree is built from the canonical \
            descriptors; the slider must read its range from the tree (`viewModel.range(for:)`), \
            or a descriptor change leaves the plug-in's slider sweeping the old range (#416).
            """)
        let numericAddress = body.range(of: #"address:\s*[0-9]"#, options: .regularExpression)
        XCTAssertNil(numericAddress, """
            `AUv3PluginView` names a parameter by a numeric address again. Use its \
            `EchoelmusicAudioUnit.ParameterAddress` case, so a reordered table cannot move a \
            different knob than the label names.
            """)
        XCTAssertTrue(body.contains("in: viewModel.range(for: address)"), """
            The slider no longer takes its range from `viewModel.range(for:)`.
            """)
    }

    /// claim 2 — the range comes from the tree parameter the host sees.
    func testTheRangeIsTheTreeParametersRange() throws {
        let code = try source(Self.view)
        guard let head = code.range(of: "func range(for address: EchoelmusicAudioUnit.ParameterAddress) -> ClosedRange<Float> {"),
              let tail = code.range(of: "struct AUv3PluginView: View {", range: head.upperBound..<code.endIndex) else {
            XCTFail("`AUv3ViewModel.range(for:)` or the view declared after it moved — re-anchor (#454).")
            return
        }
        let body = code[head.upperBound..<tail.lowerBound]
        XCTAssertTrue(body.contains("parameterTree.parameter(withAddress: address.rawValue)"), """
            `range(for:)` no longer reads the tree parameter at that address.
            """)
        XCTAssertTrue(body.contains("return p.minValue...p.maxValue"), """
            `range(for:)` no longer returns the tree parameter's own min…max.
            """)
    }

    /// claim 3 — COUNTERWEIGHT: the tree's range is still the resolved descriptor's range.
    func testTheTreeIsStillBuiltFromTheDescriptorRange() throws {
        let code = try source(Self.unit)
        XCTAssertTrue(code.contains("min: r.min, max: r.max, unit: Self.auUnit(r.unit)"), """
            `setupParameterTree()` no longer builds each parameter from the resolved descriptor's \
            `min`/`max`. The slider reads the TREE's range; that is only the canonical range while \
            the tree is built from the table.
            """)
    }

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let path = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("source tree not present at \(path.path)")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}

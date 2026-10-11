// TheUniformMirrorHasNoCompilerTests.swift
// Echoel — the GPU uniform block, in the BLOCKING bundle.
//
// WHY THIS EXISTS. `MetalBioView` hands the GPU one struct, and that struct is declared
// TWICE in the same file: once in Swift as `private struct BioUniforms`, once as
// `struct Uniforms { float time; float hr; … }` inside the runtime-compiled Metal source.
// The two are matched by BYTE LAYOUT — `MemoryLayout<BioUniforms>.stride` is what
// `setFragmentBytes` uploads — and NOTHING CHECKS THAT. Not the Swift compiler, which never
// sees the Metal string; not `TheShippedShaderActuallyCompilesTests`, which proves the MSL
// parses and says nothing about what Swift sends it.
//
// The failure mode is the nastiest kind: insert or remove ONE field on one side and every
// uniform after it shifts by four bytes. `coherence` is read as `breath`, `breath` as
// `aspect`, and so on down about a hundred fields (run the parser, do not quote a count — it
// moved 98 → 99 → 108 between #1119 and VV-5a). Nothing crashes and nothing fails to build — the
// picture simply renders wrongly, with the cause a thousand lines from the symptom.
//
// #1119 found the first live reason to care: `hr` is uploaded, sanitised and eased every
// frame and NO shader reads it (`u.hr` occurs zero times in the MSL source). The obvious
// tidy-up is to delete it — and doing that on one side only is exactly the catastrophe
// above. The field's declaration now says so, and this file is the enforcement.
//
// ⚠️ WHAT IT PROVES AND WHAT IT DOES NOT. Same names, same order, all `Float` ⇒ the two
// declarations describe the same 4-byte-per-field layout. It does NOT prove Swift's actual
// `stride` equals the MSL struct's size: Metal's default alignment rules could in principle
// pad differently. For an all-`float` struct with no vectors they do not, which is exactly
// why claim 2 (nothing but `Float`) is load-bearing rather than decorative — a single
// `simd_float3` or `Double` on either side would break that argument, and claim 2 is what
// goes red.
//
// ⛔ A NEEDLE NOTE, because it cost a measurement DURING this slice. Two traps, both real:
//   · The Swift-side regex must NOT be line-anchored. Several lines declare THREE fields at
//     once (`var cc0r: Float = 0; var cc0g: Float = 0; var cc0b: Float = 0`), and a
//     `^\s*var` pattern silently counts 48 instead of 98 — then reports a divergence that
//     does not exist.
//   · The MSL needle must not be satisfiable by the PROSE about it. `#1119` added a comment
//     at `hr`'s declaration quoting `struct Uniforms { float time; float hr; … }`, and a
//     needle of that shape then matches the comment instead of the code — the
//     `EchoelModalBank` trap: writing about a thing falsifies the grep that measures it.
//     Anchoring on the THIRD field, which the comment elides, is what fixes it.
//
// ⭐ VV-5a (GMMW) appended nine footage floats on both sides and added claims 4 and 5. Claim 4
// is the MSL half of claim 2's premise (until now only the Swift side was checked for `Float`):
// it reads the TYPE of every declaration in the block, not a list of banned words — a banned-word
// regex (`\bu?int\w*`) was drafted and would have been red on a correct tree, because a field is
// called `intensity`. Claim 5 pins the footage gate: every `u.foot…` the shader reads is a Swift
// field, and the two plane samples sit behind the one gate. GRADING (§3), transcribed (§0)
// against the parent (`500491409`) and this tree: claims 1–3 counterweights (99 = 99 there,
// 108 = 108 here); claim 4 a counterweight (all `float` on both); claim 5 FORWARD — on the
// parent the gate does not exist, one anchor absence (#486). All SOURCE-TEXT SCANS (§1); whether
// the GPU reads the bytes as declared is a device question no scan answers.

import Foundation
import XCTest

final class TheUniformMirrorHasNoCompilerTests: XCTestCase {

    private static let renderer = "Sources/Echoelmusic/Views/MetalBioView.swift"

    private func source() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(Self.renderer), encoding: .utf8)
    }

    /// (name, type) per Swift field, in declaration order.
    private func swiftFields(_ s: String) -> [(name: String, type: String)] {
        guard let open = s.range(of: "private struct BioUniforms {"),
              let close = s.range(of: "\n}", range: open.upperBound ..< s.endIndex) else { return [] }
        let block = String(s[open.upperBound ..< close.lowerBound])
        return matches(in: block, pattern: #"\bvar\s+(\w+)\s*:\s*(\w+)"#, groups: 2)
            .map { (name: $0[0], type: $0[1]) }
    }

    /// Field names of the MSL mirror, in declaration order.
    private func metalFields(_ s: String) -> [String] {
        // Third field in the needle on purpose — see the needle note in the header.
        guard let open = s.range(of: "struct Uniforms { float time; float hr; float coherence;"),
              let close = s.range(of: "};", range: open.lowerBound ..< s.endIndex) else { return [] }
        let block = String(s[open.lowerBound ..< close.lowerBound])
        return matches(in: block, pattern: #"\bfloat\s+(\w+)\s*;"#, groups: 1).map { $0[0] }
    }

    private func matches(in text: String, pattern: String, groups: Int) -> [[String]] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { m in
            (1 ... groups).map { ns.substring(with: m.range(at: $0)) }
        }
    }

    // MARK: - 3 · The parser cannot silently cover less than it claims (stated FIRST because
    //            claims 1 and 2 are worthless if the blocks were not found)

    func testBothDeclarationsWereActuallyFound() throws {
        let s = try source()
        let swift = swiftFields(s), metal = metalFields(s)
        XCTAssertGreaterThan(swift.count, 90, """
            Only \(swift.count) Swift uniform fields were parsed. There are about a hundred. Either the \
            struct shrank dramatically or — far more likely — the needle stopped matching: \
            `private struct BioUniforms {` was renamed, or the field regex became \
            line-anchored and is now missing the lines that declare three fields at once. \
            Fix the parser, do NOT lower this bound (#1114's claim-3 lesson).
            """)
        XCTAssertGreaterThan(metal.count, 90, """
            Only \(metal.count) Metal uniform fields were parsed. Check the needle first: it \
            anchors on `float coherence;`, the third field, precisely so a doc COMMENT that \
            quotes the first two cannot satisfy it. If the mirror was reformatted (one field \
            per line, say), point the parser at the new shape in the same commit.
            """)
    }

    // MARK: - 1 · Same fields, same order

    func testTheSwiftAndMetalUniformBlocksAgreeFieldForField() throws {
        let s = try source()
        let swift = swiftFields(s).map(\.name), metal = metalFields(s)
        guard swift.count > 90, metal.count > 90 else { return }   // claim 3 already failed

        XCTAssertEqual(swift.count, metal.count, """
            The uniform block has \(swift.count) fields in Swift and \(metal.count) in Metal. \
            The GPU is handed `MemoryLayout<BioUniforms>.stride` bytes and reads them \
            POSITIONALLY, so a count mismatch means every field past the difference is read \
            as its neighbour — no crash, no build error, just a wrong picture. Add or remove \
            the field on BOTH sides in ONE commit.
            """)
        for (index, pair) in zip(swift, metal).enumerated() where pair.0 != pair.1 {
            XCTFail("""
                Uniform field \(index) is `\(pair.0)` in Swift and `\(pair.1)` in Metal. From \
                here on the two declarations describe different memory: everything after this \
                offset is read as the wrong quantity. This is the FIRST divergence — later \
                ones are consequences, so fix this one and re-run. Both declarations live in \
                \(Self.renderer); they must move together, always.
                """)
            break
        }
    }

    // MARK: - 4 · Nothing but `float` on the METAL side — the other half of claim 2's premise

    func testTheMetalSideDeclaresNothingButScalarFloats() throws {
        let s = try source()
        guard let open = s.range(of: "struct Uniforms { float time; float hr; float coherence;"),
              let close = s.range(of: "};", range: open.lowerBound ..< s.endIndex) else {
            return XCTFail("the MSL `Uniforms` block was not found — see claim 3")
        }
        let block = String(s[open.lowerBound ..< close.lowerBound])
        let declarations = matches(in: block, pattern: #"([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*;"#, groups: 2)
        XCTAssertEqual(declarations.count, metalFields(s).count, """
            The MSL block holds \(declarations.count) declarations but only \(metalFields(s).count) \
            `float` fields. Something in it is not a plain `float` — a `float3`, `half`, `int` or \
            `packed_…` member brings its own size and alignment, and claim 1's name-for-name \
            comparison stops proving the layout.
            """)
        for declaration in declarations where declaration[0] != "float" {
            XCTFail("""
                MSL uniform `\(declaration[1])` is a `\(declaration[0])`. Swift uploads \
                `MemoryLayout<BioUniforms>.stride` bytes of scalar `Float`s; a vector or a narrower \
                type on the Metal side shifts every field after it. Mirror the type exactly on both \
                sides and rewrite claims 2 and 4 to check alignment, or keep it `float`.
                """)
        }
    }

    // MARK: - 5 · The footage gate reads twin fields, and only it samples (VV-5a)

    func testTheFootageGateReadsTwinFieldsAndOnlyItSamples() throws {
        let s = try source()
        let swift = Set(swiftFields(s).map(\.name))
        let read = Set(matches(in: s, pattern: #"\bu\.(foot\w+)"#, groups: 1).map { $0[0] })
        XCTAssertGreaterThanOrEqual(read.count, 2, """
            The shader reads \(read.count) `u.foot…` field(s). The footage layer needs at least \
            the presence and the opacity; fewer means the scan matched nothing and every \
            assertion below would be vacuous (#926).
            """)
        XCTAssertTrue(read.isSubset(of: swift), """
            The shader reads \(read.subtracting(swift).sorted()) from `u`, which `BioUniforms` does \
            not declare. The MSL would not compile, or worse, reads a neighbour's bytes.
            """)
        let gate = "if (u.footPresent > 0.5 && u.footOpacity > 0.001) {"
        XCTAssertEqual(s.components(separatedBy: gate).count - 1, 1,
                       "expected exactly one footage gate in the shader (VV-5a)")
        guard let gateAt = s.range(of: gate),
              let ripple = s.range(of: "outCol += rippleLight(uv, u)"),
              let luma = s.range(of: "footY.sample("),
              let chroma = s.range(of: "footCbCr.sample("),
              let firstClamp = s.range(of: "outCol = clamp(outCol, 0.0, 1.0);") else {
            return XCTFail("the footage gate, its two samples, the ripple line or the field clamp is gone — re-anchor (VV-5a)")
        }
        XCTAssertEqual(s.components(separatedBy: "footY.sample(").count - 1, 1, "the luma plane is sampled more than once (VV-5a)")
        XCTAssertEqual(s.components(separatedBy: "footCbCr.sample(").count - 1, 1, "the chroma plane is sampled more than once (VV-5a)")
        // CONTAINMENT, brace-matched from the gate's own `{` — not "between the gate and the
        // ripple line", which a sample placed after the gate's `}` would also satisfy (review).
        guard let gated = Self.braceBody(in: s, openingAt: s.index(before: gateAt.upperBound)) else {
            return XCTFail("the footage gate's block does not close — re-anchor (VV-5a)")
        }
        XCTAssertTrue(gated.contains("footY.sample(") && gated.contains("footCbCr.sample("), """
            A footage plane is sampled outside the gate's block. With no pair bound the slots hold \
            1x1 placeholders that must never be read (VV-5a).
            """)
        XCTAssertTrue(luma.upperBound < ripple.lowerBound && chroma.upperBound < ripple.lowerBound
                      && gateAt.upperBound < ripple.lowerBound, """
            The footage layer now composites after the touch ripples. The ripple's screen blend \
            needs the composite under it to be finished and <= 1 (VV-5a).
            """)
        XCTAssertTrue(firstClamp.upperBound < gateAt.lowerBound,
                      "the footage layer now composites before the field's own clamp — its screen blend needs outCol <= 1 (VV-5a)")
    }

    /// The text from the `{` at `open` through its matching `}`; nil when it never closes.
    private static func braceBody(in text: String, openingAt open: String.Index) -> String? {
        guard text[open] == "{" else { return nil }
        var depth = 0
        var index = open
        while index < text.endIndex {
            if text[index] == "{" { depth += 1 }
            if text[index] == "}" {
                depth -= 1
                if depth == 0 { return String(text[open ... index]) }
            }
            index = text.index(after: index)
        }
        return nil
    }

    // MARK: - 2 · Nothing but Float — the premise claim 1 rests on

    func testEveryUniformIsAFloatOnTheSwiftSide() throws {
        let s = try source()
        let swift = swiftFields(s)
        guard swift.count > 90 else { return }
        for field in swift where field.type != "Float" {
            XCTFail("""
                Uniform `\(field.name)` is a `\(field.type)`, not a `Float`. Matching NAMES \
                then stop proving matching LAYOUT: a `Double` is 8 bytes against Metal's \
                4-byte `float`, and a `simd_float3` carries 16-byte alignment that a plain \
                run of scalars does not. Everything after it shifts. If a vector type is \
                genuinely wanted, mirror it exactly on the Metal side and rewrite this claim \
                to check alignment rather than deleting it — it is the reason claim 1 is \
                allowed to reason about layout from names.
                """)
        }
    }
}

// TheCellularRuleIsOneByteTests.swift
// Echoel — 2026-09-24 (overnight P8): `EchoelCellular.CARule` is one byte with no heap storage,
// because the control thread replaces it while the render thread reads it. Blocking bundle.
//
// THE DEFECT (measured before the repair). The AUv3's value observer writes
// `texture.coherence` on the CONTROL thread for every host write to its Coherence parameter,
// and calls that write safe because coherence is a Float. But `coherence.didSet` →
// `updateRuleFromCoherence()` → `rule = CARule(…)` (`bioReactiveEnabled` defaults to `true`, the
// AUv3 never clears it), and `CARule` carried a private `[UInt8]` lookup table. So each host
// write built a new heap array and RELEASED the old one while `evolve1D()`, on the render
// thread, reads `rule` once per cell — a data race on a reference, i.e. a render read that can
// land on a freed buffer. Rare (the swap is short, the evolution runs 8×/s), not reproducible
// by a unit test, and a crash inside a host when it lands.
//
// THE REPAIR. Wolfram's rule number IS the lookup table: bit `i` is the output for the
// neighbourhood whose three cells spell `i`. `evaluate` reads that bit and the table is gone,
// so a `CARule` is a single `UInt8` and replacing it is a one-byte store, like every other
// scalar the AUv3 writes across threads. The output is bit-identical (claim 2 proves it over
// all 256 × 8 cases).
//
// WHAT KIND OF GREEN (§1): claims 1–2 are END-TO-END BEHAVIOUR of the public type
// (`MemoryLayout` and `evaluate`). The RACE itself is not observable in a unit test; claim 1
// pins the layout that makes it impossible. DEVICE/HOST: nothing audible changes.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not freeze the struct at one field. A new
// SCALAR field changes the size — update claim 1 to the new width in the same commit. What it
// forbids is a REFERENCE (array, string, class) inside a value the render thread reads while
// another thread replaces it.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `25690cf96`: claim 1 is a
// REGRESSION (a `UInt8` plus an array reference is 16 bytes on a 64-bit target, not 1); claim 2
// is a COUNTERWEIGHT, green on both trees — the table held exactly these bits, which is why the
// repair changes no sound. Both claims name only symbols that exist on the parent.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheCellularRuleIsOneByteTests: XCTestCase {

    private typealias Rule = EchoelCellular.CARule

    // MARK: - claim 1

    func testARuleIsASingleByteWithNothingOnTheHeap() {
        XCTAssertEqual(MemoryLayout<Rule>.size, MemoryLayout<UInt8>.size, """
            `CARule` is \(MemoryLayout<Rule>.size) bytes. The control thread replaces \
            `EchoelCellular.rule` on every coherence write while `evolve1D()` reads it on the \
            render thread; a reference inside it (the old `[UInt8]` table) is released under a \
            live read. Keep it scalar. If you added a SCALAR field, update this width.
            """)
    }

    // MARK: - claim 2 (COUNTERWEIGHT)

    func testEveryRuleEvaluatesToItsWolframBit() {
        var mismatches: [String] = []
        for number in 0...255 {
            let rule = Rule(UInt8(number))
            XCTAssertEqual(Int(rule.number), number)
            for index in 0..<8 {
                let left = UInt8((index >> 2) & 1)
                let center = UInt8((index >> 1) & 1)
                let right = UInt8(index & 1)
                let expected = UInt8((number >> index) & 1)
                let got = rule.evaluate(left: left, center: center, right: right)
                if got != expected { mismatches.append("rule \(number) n\(index): \(got)") }
            }
        }
        XCTAssertEqual(mismatches, [], """
            `evaluate` no longer returns Wolfram's bit for every neighbourhood — the texture \
            would sound different from every build before it: \(mismatches.prefix(8)).
            """)
        // The rules the texture actually selects (by coherence) are all constructible.
        XCTAssertEqual(Rule.harmonicRules.count, 8)
        XCTAssertEqual(Rule.rule90.evaluate(left: 1, center: 0, right: 0), 1)
        XCTAssertEqual(Rule.rule90.evaluate(left: 1, center: 0, right: 1), 0)
    }
}

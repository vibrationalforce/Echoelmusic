// EveryLayerStackHasAFlashBudgetTests.swift
// Echoel — an N-layer field stack keeps the 3 Hz flash law, in the BLOCKING bundle (GMMW VV-16).
//
// WHY IT EXISTS. `TheBlendUnionStaysUnderTheCeilingTests` proves the A↔B slider: two looks
// mixed into one pixel add their flash counts, and `FlashGuard.blendPhaseDamping` slows the
// field phase until the sum is back under the ceiling. An abstract-visual compositor stacks
// MORE than two looks, and the two-look law says nothing about a third. `FlashGuard
// .layerUnionHz` / `.layerPhaseDamping` generalise it to N, and this file is the gate any such
// compositor must pass BEFORE it ships. Nothing renders a stack today — the functions have no
// production caller yet, and that is said here so a green does not read as "the compositor is
// safe": there is no compositor.
//
// WHAT KIND OF GREEN. END-TO-END BEHAVIOUR for every claim: each drives the shipped, public,
// Foundation-only `FlashGuard` and the real `LookBlendMap.library`. No source text is read.
// DEVICE PROBE (does a stack LOOK calm at 3 Hz) is impossible here and stays open — the model
// is a worst-case bound on flash COUNT, not a measurement of a rendered picture.
//
// GRADING (Tests/CISmoke/CLAUDE.md §3). The file names three symbols this commit creates
// (`FlashGuard.FieldLayer`, `layerUnionHz`, `layerPhaseDamping`), so it does NOT compile
// against the parent and no assertion has a verdict there. All six claims are FORWARD
// guards. Hand-transcribed in Python against the worktree before the push: claim 1's largest
// difference over 5 × 5 pairs × 21 slider positions is 2.2e-16; claim 2 checks 620 stacks
// (2–4 layers, with repetition; 4, 6 and 5 weight patterns per size) and the largest
// UNdamped union is 7.5 Hz (four Rings weighted 0.5/0.5/0/0 — under the tie rule a silent
// Rings counts in full and both visible ones are added), every one damped to ≤ 3.0;
// claims 3–5 match their
// hand-derived values; claim 6 (order independence) is 4.375 vs 5.625 Hz on the first
// draft and 5.625 for both orders after the tie rule — found by the mandatory review.

import Foundation
import XCTest
@testable import Echoelmusic

final class EveryLayerStackHasAFlashBudgetTests: XCTestCase {

    private var looks: [Int] { LookBlendMap.library.map { $0.index } }

    /// Every multiset of `count` library looks (a look may repeat — a stack of the same look
    /// twice is still two oscillations in one pixel).
    private func stacks(of count: Int) -> [[Int]] {
        guard count > 0 else { return [[]] }
        var result: [[Int]] = []
        func extend(_ prefix: [Int], from start: Int) {
            if prefix.count == count { result.append(prefix); return }
            for position in start..<looks.count {
                extend(prefix + [looks[position]], from: position)
            }
        }
        extend([], from: 0)
        return result
    }

    private func layers(_ styles: [Int], _ weights: [Double]) -> [FlashGuard.FieldLayer] {
        zip(styles, weights).map { FlashGuard.FieldLayer(styleIndex: $0.0, weight: $0.1) }
    }

    // MARK: - 1 · Two layers ARE the two-look slider

    func testTwoLayersReduceToTheBlendSlider() {
        XCTAssertFalse(looks.isEmpty, "the look library is empty — nothing was checked")
        for first in looks {
            for second in looks {
                for step in 0...20 {
                    let t: Double = Double(step) * 0.05
                    let stack = [FlashGuard.FieldLayer(styleIndex: first, weight: 1 - t),
                                 FlashGuard.FieldLayer(styleIndex: second, weight: t)]
                    let general = FlashGuard.layerPhaseDamping(stack)
                    let slider = FlashGuard.blendPhaseDamping(styleA: first, styleB: second, blend: t)
                    XCTAssertEqual(general, slider, accuracy: 1e-12, """
                        Styles \(first)↔\(second) at blend \(t): the N-layer damping is \
                        \(general), the slider's is \(slider). The N-layer model must BE the \
                        two-look model for two layers — otherwise a compositor and the slider \
                        would disagree about the same picture, and one of them is wrong about \
                        the epilepsy law.
                        """)
                }
            }
        }
    }

    // MARK: - 2 · No stack of up to four looks exceeds the ceiling once damped

    func testNoStackOfLooksExceedsTheWCAGCeiling() {
        let patterns: [Int: [[Double]]] = [
            2: [[1, 1], [1, 0], [1, 3], [0.5, 0.5]],
            3: [[1, 1, 1], [1, 0, 0], [2, 1, 1], [1, 1, 2], [0.25, 0.5, 0.25], [5, 1, 1]],
            4: [[1, 1, 1, 1], [1, 0, 0, 0], [3, 1, 1, 1], [1, 1, 1, 5], [0.5, 0.5, 0, 0]],
        ]
        var checked = 0
        for count in 2...4 {
            for styles in stacks(of: count) {
                for weights in patterns[count] ?? [] {
                    let stack = layers(styles, weights)
                    let union = FlashGuard.layerUnionHz(stack)
                    let damping = FlashGuard.layerPhaseDamping(stack)
                    XCTAssertLessThanOrEqual(union * damping, FlashGuard.maxFlashHz + 1e-9, """
                        Stack \(styles) weighted \(weights) still reaches \(union * damping) Hz \
                        after damping, over the WCAG ceiling of \(FlashGuard.maxFlashHz). \
                        Layers mixed into one pixel ADD their flash counts. Do not raise the \
                        ceiling — the epilepsy limit is not a tuning knob.
                        """)
                    XCTAssertTrue(damping > 0 && damping <= 1, """
                        Damping for \(styles) weighted \(weights) is \(damping), outside (0, 1]. \
                        Above 1 would SPEED the field up; at or below 0 would freeze it.
                        """)
                    checked += 1
                }
            }
        }
        XCTAssertGreaterThan(checked, 0, "no stack was checked — the sweep is vacuous")
    }

    // MARK: - 3 · One visible layer changes nothing — the bit-identical promise

    func testAStackWithOneVisibleLayerIsUnaffected() {
        for count in 1...4 {
            for styles in stacks(of: count) {
                let weights: [Double] = [1] + Array(repeating: 0, count: count - 1)
                let damping = FlashGuard.layerPhaseDamping(layers(styles, weights))
                XCTAssertEqual(damping, 1.0, """
                    Stack \(styles) with only its first layer visible is damped by \(damping), \
                    not exactly 1. Nothing is superposed, so nothing may change: a renderer \
                    multiplies the phase increment by this factor, and only × 1.0 leaves the \
                    picture bit-identical. (Every library row is under 3 Hz on its own, which \
                    is what makes this exact.)
                    """)
            }
        }
    }

    // MARK: - 4 · An unreadable stack is the WORST stack, never a calm one

    func testAnUnreadableStackCountsEveryLayerInFull() throws {
        let aurora = try XCTUnwrap(FlashGuard.fieldBudget(forStyle: 5)?.effectiveHz,
                                   "Aurora lost its row; this claim needs two budgeted looks")
        let water = try XCTUnwrap(FlashGuard.fieldBudget(forStyle: 3)?.effectiveHz,
                                  "Water lost its row; this claim needs two budgeted looks")
        let full = aurora + water
        let unreadable: [(label: String, weight: Double)] = [
            ("NaN", .nan), ("infinity", .infinity), ("negative", -1),
        ]
        for bad in unreadable {
            let union = FlashGuard.layerUnionHz([
                FlashGuard.FieldLayer(styleIndex: 5, weight: bad.weight),
                FlashGuard.FieldLayer(styleIndex: 3, weight: 1),
            ])
            XCTAssertEqual(union, full, accuracy: 1e-12, """
                A \(bad.label) weight produced a union of \(union) Hz, not the full \(full). A \
                stack nobody can read must count every layer in full — reading it as a calm \
                stack would make the one case nobody can measure the one case never damped.
                """)
        }
        let silent = FlashGuard.layerUnionHz([
            FlashGuard.FieldLayer(styleIndex: 5, weight: 0),
            FlashGuard.FieldLayer(styleIndex: 3, weight: 0),
        ])
        XCTAssertEqual(silent, full, accuracy: 1e-12, """
            A stack whose weights sum to zero produced \(silent) Hz, not the full \(full). \
            Zero total weight has no shares to divide by; the safe reading is every layer \
            in full.
            """)
    }

    // MARK: - 6 · The bound is a property of the STACK, not of its order

    func testTheUnionDoesNotDependOnLayerOrder() {
        // Four Rings layers: every layer ties on the fastest rate, so a rule that counted
        // "the first fastest layer" in full would read a different bound per ordering.
        let rings = LookBlendMap.ringsStyleIndex
        let forward = layers([rings, rings, rings, rings], [1, 1, 1, 5])
        let reversed = Array(forward.reversed())
        XCTAssertEqual(FlashGuard.layerUnionHz(forward), FlashGuard.layerUnionHz(reversed),
                       accuracy: 1e-12, """
            The same four-layer stack gave \(FlashGuard.layerUnionHz(forward)) Hz in one order \
            and \(FlashGuard.layerUnionHz(reversed)) Hz reversed. An additive mix does not \
            depend on layer order, so the flash bound must not either — the lower reading \
            would damp the field LESS than the picture needs.
            """)
        for count in 2...4 {
            for styles in stacks(of: count) {
                let weights: [Double] = (0..<count).map { Double($0 + 1) }
                let stack = layers(styles, weights)
                XCTAssertEqual(FlashGuard.layerUnionHz(stack),
                               FlashGuard.layerUnionHz(Array(stack.reversed())),
                               accuracy: 1e-12, "stack \(styles) weighted \(weights) is order-dependent")
            }
        }
    }

    // MARK: - 5 · COUNTERWEIGHTS — the unknown look and the empty stack

    func testAnUnbudgetedLayerCostsTheCeilingAndAnEmptyStackCostsNothing() throws {
        // 4 is Prism: compiled in the shader, retired from the UI, deliberately unbudgeted.
        let unknown = 4
        XCTAssertNil(FlashGuard.fieldBudget(forStyle: unknown),
                     "style \(unknown) gained a budget row — pick another unbudgeted style for this claim")
        let aurora = try XCTUnwrap(FlashGuard.fieldBudget(forStyle: 5)?.effectiveHz)
        let alone = FlashGuard.layerUnionHz([FlashGuard.FieldLayer(styleIndex: unknown, weight: 1)])
        XCTAssertEqual(alone, FlashGuard.maxFlashHz, """
            An unbudgeted layer alone counted \(alone) Hz, not the ceiling. `nil` from \
            `fieldBudget(forStyle:)` means UNKNOWN, not FREE.
            """)
        let mixed = FlashGuard.layerPhaseDamping([
            FlashGuard.FieldLayer(styleIndex: unknown, weight: 1),
            FlashGuard.FieldLayer(styleIndex: 5, weight: 1),
        ])
        let expected = FlashGuard.maxFlashHz / (FlashGuard.maxFlashHz + aurora)
        XCTAssertEqual(mixed, expected, accuracy: 1e-12, """
            An unbudgeted layer beside Aurora at equal weight was damped by \(mixed), not the \
            worst-case \(expected) — the same value the two-look slider gives at mid-blend.
            """)
        XCTAssertEqual(FlashGuard.layerUnionHz([]), 0, "an empty stack must cost 0 Hz")
        XCTAssertEqual(FlashGuard.layerPhaseDamping([]), 1, "an empty stack must not be damped")
    }
}

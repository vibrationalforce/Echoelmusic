// TheFluidSurfaceKeepsItsEnergyBoundedTests.swift
// Echoel — Fluid F1 (2026-10-13): a water surface that answers a finger must never blow up.
//
// WHAT THIS GUARDS. `Studio/FluidSurfaceMath.swift` is the CPU reference of the disturbed
// surface the Fluid Field plan builds under the playing area (F3 gives it a GPU twin, F4 its
// controls, F5 the body). A 2-D wave equation is one wrong constant away from exponential growth,
// and on a Metal texture exponential growth is a full-screen flash — the ≤3 Hz law broken by a
// bug rather than by a design. So the laws pinned here are the ones a picture cannot lose and
// still be safe: every value stays finite and inside the clamp, a touch decays instead of
// accumulating, the rim absorbs, thicker water settles sooner, a held finger grows smoothly.
//
// KIND (§1): **END-TO-END BEHAVIOUR** — every claim drives the shipped, Foundation-only value
// type; the two scans at the end are SOURCE-TEXT and say so. §3 grading: this file does NOT
// compile against the parent tree (the type is new there), so no assertion has a verdict on the
// parent; every number below was measured by the Python transcription of the same algorithm
// (same constants, same two substeps, same sponge, same clamp — the twin that produced them is
// named in the session log), and pins carry tolerances wide enough for Double-vs-Double
// summation order, never for a different law.
//
// ⭐ IT PINS LAWS, NOT FEEL. `contactBaseAmp`, the growth rate, the damping slope and the grid
// range are feel decisions the founder may retune after a device session; none of them is pinned
// as a literal (#364). What is pinned is boundedness, decay, symmetry, absorption, ordering and
// the stability bound on `waveSpeedSquared` — the things that make the surface a surface.
//
// ⚠️ HONEST LIMIT. Nothing here renders a pixel or reads a finger. Whether the ring LOOKS like
// water, and whether "Ruhe dämpft sie" is felt rather than read, are device probes that arrive
// with F3 as a NEEDS-FOUNDER-VERIFY at the construction site.
//
// `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheFluidSurfaceKeepsItsEnergyBoundedTests: XCTestCase {

    private typealias F = FluidSurfaceMath

    private func touched(size n: Int = 32, viscosity: Double, amplitude: Double, at cell: (Int, Int)? = nil) -> F.Grid {
        var grid = F.Grid(size: n)
        let c = cell ?? (n / 2, n / 2)
        grid.step(viscosity: viscosity, impulses: [F.Impulse(i: c.0, j: c.1, amplitude: amplitude)])
        return grid
    }

    private func maxAbsHeight(_ grid: F.Grid) -> Double {
        grid.height.reduce(0.0) { Swift.max($0, abs($1)) }
    }

    // MARK: - 1 · Bounded, always

    /// A touch of any size, even a non-finite one, leaves every cell finite and inside the clamp.
    func testEveryStoredValueStaysFiniteAndInsideTheClamp() {
        for amplitude in [1e9, -1e9, .infinity, -.infinity, .nan] as [Double] {
            var grid = touched(viscosity: 0, amplitude: amplitude)
            for _ in 0..<20 { grid.step(viscosity: 0, impulses: []) }
            for x in grid.height + grid.velocity {
                XCTAssertTrue(x.isFinite, """
                    A stored value went non-finite after an impulse of \(amplitude). `sanitize` is \
                    the fence between a wave equation and a full-screen flash; every write into the \
                    grid must pass it.
                    """)
                XCTAssertLessThanOrEqual(abs(x), F.heightClamp + 1e-12, """
                    |\(x)| exceeds `heightClamp` after an impulse of \(amplitude). The clamp is the \
                    second fence behind the stability bound; a value past it on the CPU reference \
                    means the shader twin would saturate too.
                    """)
            }
        }
        XCTAssertEqual(F.sanitize(.nan), 0)
        XCTAssertEqual(F.sanitize(.infinity), 0)
        XCTAssertEqual(F.sanitize(-.infinity), 0)
        XCTAssertEqual(F.sanitize(7), F.heightClamp)
        XCTAssertEqual(F.sanitize(-7), -F.heightClamp)
        XCTAssertEqual(F.sanitize(0.25), 0.25)
    }

    /// `c²·dt²` must stay under the 2-D five-point stability bound for every viscosity, or the
    /// clamp is doing the physics instead of fencing it.
    func testTheWaveSpeedStaysUnderTheStabilityBound() {
        for v in stride(from: -1.0, through: 2.0, by: 0.05) {
            let c2 = F.waveSpeedSquared(viscosity: v)
            XCTAssertGreaterThan(c2, 0, "c² must be positive at viscosity \(v) or nothing propagates")
            XCTAssertLessThan(c2, 0.5, """
                c²·dt² = \(c2) at viscosity \(v) is at or past the 0.5 bound of the explicit 2-D \
                scheme — the grid would grow without bound and only the clamp would hide it.
                """)
            let d = F.damping(viscosity: v)
            XCTAssertGreaterThan(d, 0.9, "damping \(d) at viscosity \(v) would kill a ring within a frame")
            XCTAssertLessThan(d, 1, "damping \(d) at viscosity \(v) would never let the surface settle")
        }
        XCTAssertEqual(F.waveSpeedSquared(viscosity: .nan), F.waveSpeedSquared(viscosity: 0),
                       "a non-finite viscosity must read as the thinnest water, never as NaN in the scheme")
    }

    // MARK: - 2 · A touch decays

    /// One touch, then sixty free frames: the energy is a small fraction of what the touch put in,
    /// the peak never ran away, and the whole field is nearly flat again.
    func testASingleTouchDecaysInsteadOfAccumulating() {
        var grid = touched(viscosity: 0.42, amplitude: F.contactAmp(age: 0, pressure: 1))
        let e0 = grid.energy
        XCTAssertGreaterThan(e0, 0, "a full-pressure touch must put energy into the field")
        var peak = e0
        for _ in 0..<60 {
            grid.step(viscosity: 0.42, impulses: [])
            peak = Swift.max(peak, grid.energy)
        }
        // Measured by the twin: ratio 0.000537, peak/e0 1.28 (h lags v by half a substep, so the
        // sum of squares rises briefly before the damping wins — the law is the bound, not monotony).
        XCTAssertLessThan(grid.energy / e0, 0.01, """
            Sixty frames after one touch the field still holds \(grid.energy / e0) of its energy. \
            The surface would never settle under a held finger — that is the "stops answering" \
            failure, not a stylistic one.
            """)
        XCTAssertLessThan(peak / e0, 2.0, """
            The energy peaked at \(peak / e0)× the injected energy. A transient overshoot from the \
            staggered update is expected (the twin measures ~1.28×); a doubling means the scheme \
            is pumping, not propagating.
            """)
        XCTAssertLessThan(maxAbsHeight(grid), 0.01, "the surface is not nearly flat again after 60 frames")
    }

    /// Thicker water settles sooner: the same touch keeps less energy at viscosity 1 than at 0.
    func testThickerWaterSettlesSooner() {
        func remaining(viscosity: Double) -> Double {
            var grid = touched(viscosity: viscosity, amplitude: 1)
            let e0 = grid.energy
            for _ in 0..<40 { grid.step(viscosity: viscosity, impulses: []) }
            return grid.energy / e0
        }
        let thin = remaining(viscosity: 0)
        let thick = remaining(viscosity: 1)
        XCTAssertLessThan(thick, thin, """
            Viscosity 1 kept \(thick) of the energy, viscosity 0 kept \(thin). "Ruhe dämpft sie" is \
            this ordering — if thicker water rings longer, the body's calm would make the surface \
            livelier, the inverse of the law.
            """)
        // Twin: thin 0.02576, thick 0.00106 — a clear order of magnitude apart.
        XCTAssertLessThan(thick * 5, thin, "the two viscosities barely differ (\(thick) vs \(thin)); the slider would do nothing")
    }

    // MARK: - 3 · Shape

    /// A centred touch spreads the same in all four directions.
    func testACentredTouchSpreadsSymmetrically() {
        let n = 32
        let grid = touched(size: n, viscosity: 0.42, amplitude: 1)
        let c = n / 2
        let up = grid.heightAt(i: c - 1, j: c), down = grid.heightAt(i: c + 1, j: c)
        let left = grid.heightAt(i: c, j: c - 1), right = grid.heightAt(i: c, j: c + 1)
        XCTAssertNotEqual(up, 0, "the touch did not reach its neighbours after one frame")
        for (side, value) in [("down", down), ("left", left), ("right", right)] {
            XCTAssertEqual(value, up, accuracy: 1e-12, """
                The \(side) neighbour (\(value)) differs from the upper one (\(up)). The five-point \
                Laplacian is isotropic; an asymmetry means an index is off by one somewhere.
                """)
        }
    }

    /// The rim absorbs: a touch next to the edge loses energy far faster than one in the middle.
    func testTheRimAbsorbsInsteadOfReflecting() {
        func remaining(at cell: (Int, Int)) -> Double {
            var grid = touched(viscosity: 0.3, amplitude: 1, at: cell)
            let e0 = grid.energy
            for _ in 0..<20 { grid.step(viscosity: 0.3, impulses: []) }
            return grid.energy / e0
        }
        let centre = remaining(at: (16, 16))
        let edge = remaining(at: (1, 1))
        // Twin: centre 0.0581, edge 0.00196.
        XCTAssertLessThan(edge * 10, centre, """
            A touch at the rim kept \(edge) of its energy, one in the middle \(centre). The sponge \
            exists so a ring dies at the edge instead of reflecting into a standing pattern; a rim \
            that keeps energy like the interior is a reflecting rim.
            """)
        XCTAssertEqual(F.spongeGain(i: 16, j: 16, n: 32), 1)
        XCTAssertEqual(F.spongeGain(i: 0, j: 16, n: 32), 0)
        XCTAssertEqual(F.spongeGain(i: 16, j: 31, n: 32), 0)
        XCTAssertEqual(F.spongeGain(i: 4, j: 16, n: 32), 0.5, accuracy: 1e-12)
        XCTAssertEqual(F.spongeGain(i: -1, j: 0, n: 32), 0, "an out-of-range cell has no gain")
    }

    // MARK: - 4 · Contact

    /// A held finger grows smoothly from its first-frame amplitude and saturates.
    func testAHeldContactGrowsSmoothlyAndSaturates() {
        XCTAssertEqual(F.contactGrowth(age: 0), 1, accuracy: 1e-12)
        XCTAssertEqual(F.contactGrowth(age: .nan), 1, accuracy: 1e-12, "a non-finite age is a fresh touch")
        XCTAssertEqual(F.contactGrowth(age: -3), 1, accuracy: 1e-12, "a negative age is a fresh touch")
        var previous = F.contactGrowth(age: 0)
        for step in 1...50 {
            let g = F.contactGrowth(age: Double(step) * 0.1)
            XCTAssertGreaterThan(g, previous, "growth fell between \(Double(step - 1) * 0.1) s and \(Double(step) * 0.1) s")
            XCTAssertLessThanOrEqual(g, 1 + F.contactGrowthGain, "growth passed its asymptote at \(Double(step) * 0.1) s")
            previous = g
        }
        // Twin: growth(3) = 3.13016; amp(0, 1) = 0.35.
        XCTAssertEqual(F.contactGrowth(age: 3), 1 + F.contactGrowthGain * (1 - exp(-3 * F.contactGrowthRate)), accuracy: 1e-9)
        XCTAssertEqual(F.contactAmp(age: 0, pressure: 1), F.contactBaseAmp, accuracy: 1e-12)
        XCTAssertEqual(F.contactAmp(age: 0, pressure: 0.5), F.contactBaseAmp / 2, accuracy: 1e-12)
        XCTAssertEqual(F.contactAmp(age: 0, pressure: 7), F.contactBaseAmp, accuracy: 1e-12, "pressure is clamped to 1")
        XCTAssertEqual(F.contactAmp(age: 0, pressure: .nan), 0, "a non-finite pressure injects nothing")
        XCTAssertLessThan(F.contactAmp(age: 100, pressure: 1), F.heightClamp,
                          "even a fully grown contact must inject less than the clamp, or the clamp does the shaping")
    }

    /// Coherence nudges viscosity by at most ±0.075, inside 0…1, and an unmeasured body is neutral.
    func testCoherenceOnlyNudgesTheViscosity() {
        XCTAssertEqual(F.effectiveViscosity(0.5, coherence: 0.5), 0.5, accuracy: 1e-12)
        XCTAssertEqual(F.effectiveViscosity(0.5, coherence: 1), 0.575, accuracy: 1e-12)
        XCTAssertEqual(F.effectiveViscosity(0.5, coherence: 0), 0.425, accuracy: 1e-12)
        XCTAssertEqual(F.effectiveViscosity(0.9, coherence: 1), 0.975, accuracy: 1e-12)
        XCTAssertEqual(F.effectiveViscosity(0.05, coherence: 0), 0, accuracy: 1e-12, "clamped at 0")
        XCTAssertEqual(F.effectiveViscosity(1, coherence: 1), 1, accuracy: 1e-12, "clamped at 1")
        XCTAssertEqual(F.effectiveViscosity(0.3, coherence: .nan), 0.3, accuracy: 1e-12,
                       "an unmeasured body must not move the surface")
        XCTAssertGreaterThan(F.effectiveViscosity(0.5, coherence: 1), F.effectiveViscosity(0.5, coherence: 0),
                             "calm must make the water HEAVIER, never lighter")
    }

    // MARK: - 5 · Grid geometry and cache key

    /// The grid size follows detail, stays inside its range, and is always even.
    func testTheGridSizeFollowsDetailInsideItsRange() {
        XCTAssertEqual(F.gridSize(detail: 1), F.baseGridSize)
        XCTAssertEqual(F.gridSize(detail: 0.5), F.gridSizeRange.lowerBound)
        XCTAssertEqual(F.gridSize(detail: 2), F.gridSizeRange.upperBound)
        XCTAssertEqual(F.gridSize(detail: .nan), F.baseGridSize, "a non-finite detail is the base size")
        XCTAssertEqual(F.gridSize(detail: 0), F.baseGridSize, "a zero detail is the base size, not an empty grid")
        for d in stride(from: 0.3, through: 1.6, by: 0.01) {
            let n = F.gridSize(detail: d)
            XCTAssertEqual(n % 2, 0, "grid size \(n) at detail \(d) is odd — the ping-pong textures would not tile")
            XCTAssertTrue(F.gridSizeRange.contains(n), "grid size \(n) at detail \(d) left the range")
        }
        XCTAssertEqual(F.baseGridSize % 2, 0, "the base size itself must be even")
        XCTAssertEqual(F.Grid(size: 0).n, 2, "a degenerate size yields the smallest legal grid, never an empty one")
    }

    /// The pipeline cache key separates devices AND shader generations.
    func testTheCacheKeyNamesDeviceAndGeneration() {
        let a = F.cacheKey(deviceID: "gpu-A")
        XCTAssertNotEqual(a, F.cacheKey(deviceID: "gpu-B"), "two devices must never share a pipeline")
        XCTAssertNotEqual(a, F.cacheKey(deviceID: "gpu-A", generation: F.shaderGeneration + 1),
                          "a shader edit that bumps the generation must retire the cached pipeline")
        XCTAssertEqual(a, F.cacheKey(deviceID: "gpu-A", generation: F.shaderGeneration), "the default is the current generation")
        XCTAssertGreaterThanOrEqual(F.shaderGeneration, 1)
    }

    // MARK: - 6 · Source scans (SOURCE-TEXT)

    private static func treeRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Sources").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("No source tree next to the test bundle — nothing to scan.")
    }

    /// The core imports Foundation only: no SwiftUI, no Metal, no clock. F3 may depend on it;
    /// it must never depend on F3.
    func testTheCoreImportsFoundationOnly() throws {
        let path = "Sources/Echoelmusic/Studio/FluidSurfaceMath.swift"
        let text = try String(contentsOf: Self.treeRoot().appendingPathComponent(path), encoding: .utf8)
        let imports = SourceText.codeOnly(text).split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("import ") }
        XCTAssertEqual(Set(imports), ["import Foundation"], """
            \(path) imports \(imports). The CPU reference is the thing the shader is checked \
            AGAINST; the moment it imports Metal or SwiftUI it can no longer be driven in the \
            blocking bundle, and the laws above lose their only runner.
            """)
        for forbidden in ["Date()", "DispatchQueue", "Task {", "CACurrentMediaTime"] {
            XCTAssertFalse(SourceText.codeOnly(text).contains(forbidden), """
                \(path) contains `\(forbidden)`. The core has no clock and no thread of its own — the \
                view supplies dt and the GPU supplies the frame.
                """)
        }
    }

    /// Every write into the grid passes `sanitize` — the stored arrays are not assignable from outside.
    func testEveryGridWriteGoesThroughSanitize() throws {
        let path = "Sources/Echoelmusic/Studio/FluidSurfaceMath.swift"
        let code = SourceText.codeOnly(try String(contentsOf: Self.treeRoot().appendingPathComponent(path), encoding: .utf8))
        XCTAssertTrue(code.contains("public private(set) var height: [Double]"), "the height field must not be writable from outside the core")
        XCTAssertTrue(code.contains("public private(set) var velocity: [Double]"), "the velocity field must not be writable from outside the core")
        let writes = code.components(separatedBy: "\n").filter {
            let t = $0.trimmingCharacters(in: .whitespaces)
            return (t.hasPrefix("velocity[k] =") || t.hasPrefix("newVelocity[k] =") || t.hasPrefix("newHeight[k] ="))
        }
        XCTAssertEqual(writes.count, 3, "expected the three cell writes (impulse, substep velocity, substep height); found \(writes.count)")
        for w in writes {
            XCTAssertTrue(w.contains("sanitize("), "a grid write bypasses `sanitize`: \(w.trimmingCharacters(in: .whitespaces))")
        }
    }
}

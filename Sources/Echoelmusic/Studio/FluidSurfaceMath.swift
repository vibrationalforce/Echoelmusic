import Foundation

// FluidSurfaceMath.swift
// Echoel — Fluid F1 (2026-10-13). The arithmetic of a disturbed water surface, as a pure core.
//
// WHAT THIS IS. `Core/FaradayDish.swift` answers "how does a dish of water STAND on a speaker at
// this pitch" — a standing lattice, lit by `fieldDish`/`fieldWater`. This file answers the other
// half of the picture: how the same surface MOVES when a finger lands on it. A touch is an impulse
// into a 2-D wave equation on an N×N height field; the ring runs outward, loses energy to a
// viscosity the performer sets, and is swallowed at the rim instead of bouncing back. The two
// cores are deliberately separate — the dish is the illumination, this is the disturbance under
// it (`scratchpads/PLAN_FLUID_SURFACE_2026-10-13.md`, correction 1).
//
// ⚠️ NO CALLER YET, ON PURPOSE. F3 of that plan gives this core its GPU twin (`fluid_step`) and
// its contact channel; until then it is a tested orphan, and the plan says so in advance ("F1
// legt genau einen an, bis F3 ihn ruft"). The CPU grid here is the REFERENCE the shader is
// checked against, not the per-frame path — nothing in a `draw` should ever step a 160×160 grid
// on the main thread.
//
// ⚠️ THE FOUR SAFETY LAWS, each a decision and each pinned by
// `TheFluidSurfaceKeepsItsEnergyBoundedTests`:
//
// 1. BOUNDED. Every stored value passes `sanitize` — non-finite becomes 0, the rest is clamped to
//    ±`heightClamp`. A wave equation with the wrong `c²·dt²` ratio blows up exponentially; a texture
//    of `inf` draws as a full-screen flash, which is the ≤3 Hz law broken by a bug. The clamp is
//    the second fence behind a stable `waveSpeedSquared` (always < 0.5, the 2-D stability bound).
//
// 2. ABSORBING RIM. `spongeGain` ramps velocity down over the outer `spongeCells` cells so a ring
//    dies at the edge instead of reflecting. A reflecting rim turns one touch into a standing
//    chequerboard that never settles — the picture would stop answering the finger.
//
// 3. CALM DAMPS. `damping` and `waveSpeedSquared` both fall with viscosity, and F5 lets coherence
//    nudge viscosity (`effectiveViscosity`) — never the other way round, and never the amplitude:
//    a calm body makes the water heavier, it does not make the finger weaker.
//
// 4. THE CONTACT GROWS, NEVER JUMPS. `contactAmp` starts at `contactBaseAmp·pressure` on the first
//    frame and saturates toward ~3.2× over about two seconds (`contactGrowth`), so a held finger
//    swells into a wave rather than hammering the same impulse every frame.
//
// PURE VALUE TYPE: Foundation only, no SwiftUI, no Metal, no clock of its own. Every entry point
// is NaN-safe at the boundary (`.claude/rules/engineering.md` §3).

/// The disturbed-surface model behind the Fluid Field (F1 of the fluid-surface plan).
public enum FluidSurfaceMath {

    // MARK: - Constants (the ones that set the feel)

    /// Cells of absorbing rim on every side. Eight is wide enough that a ring at full speed
    /// loses its reflection, narrow enough on a 96-cell grid to leave the playable middle alone.
    public static let spongeCells: Int = 8

    /// Hard bound on any stored height or velocity, in field units. ±2.5 is well past anything a
    /// contact can inject (`contactAmp` tops out near 1.1) and far below anything a shader would
    /// turn into a saturated flash.
    public static let heightClamp: Double = 2.5

    /// Impulse amplitude of a fresh touch at full pressure, before growth.
    public static let contactBaseAmp: Double = 0.35

    /// How far a held contact grows beyond its first-frame amplitude (1 + this, asymptotically).
    public static let contactGrowthGain: Double = 2.2

    /// Rate of that growth, per second of contact age. ~63 % of the way at 0.87 s, ~90 % at 2 s.
    public static let contactGrowthRate: Double = 1.15

    /// Cells per side at `detail` 1.0, before the even-size rounding.
    public static let baseGridSize: Int = 160

    /// Smallest and largest grid a quality tier may ask for.
    public static let gridSizeRange: ClosedRange<Int> = 96...224

    /// Bumped whenever `fluid_step` (F3) changes its uniforms or texture format, so a pipeline
    /// cached for an older shader is never reused for a newer one. `cacheKey` folds it in.
    public static let shaderGeneration: Int = 1

    // MARK: - Parameters from viscosity

    /// `c²·dt²` of the discrete wave equation for a viscosity in 0…1. Thinner water runs faster.
    ///
    /// Stays in 0.18…0.44, always under the 0.5 bound that keeps the 2-D five-point scheme stable.
    public static func waveSpeedSquared(viscosity: Double) -> Double {
        let v = unitClamped(viscosity)
        return 0.18 + (1 - v) * 0.26
    }

    /// Per-substep velocity retention for a viscosity in 0…1. Thicker water settles sooner.
    public static func damping(viscosity: Double) -> Double {
        let v = unitClamped(viscosity)
        return 0.985 - v * 0.06
    }

    /// The viscosity the surface actually uses once the body is in the loop (F5): coherence
    /// above neutral makes the water heavier, below neutral lighter, by at most ±0.075.
    ///
    /// Non-finite coherence counts as neutral — an unmeasured body must not move the surface.
    public static func effectiveViscosity(_ viscosity: Double, coherence: Double) -> Double {
        let c = coherence.isFinite ? coherence : 0.5
        return unitClamped(unitClamped(viscosity) + 0.15 * (c - 0.5))
    }

    // MARK: - Contact

    /// Growth factor of a contact `age` seconds old: 1 on the first frame, saturating toward
    /// `1 + contactGrowthGain`. Non-finite or negative age reads as a fresh touch.
    public static func contactGrowth(age: Double) -> Double {
        let a = (age.isFinite && age > 0) ? age : 0
        return 1 + contactGrowthGain * (1 - exp(-a * contactGrowthRate))
    }

    /// Impulse a contact injects this frame, from its age and its pressure in 0…1.
    public static func contactAmp(age: Double, pressure: Double) -> Double {
        contactBaseAmp * contactGrowth(age: age) * unitClamped(pressure)
    }

    // MARK: - Grid geometry

    /// Cells per side for a quality `detail` (1.0 = the base size), clamped to `gridSizeRange`
    /// and rounded to an even number so the GPU ping-pong textures tile cleanly.
    public static func gridSize(detail: Double) -> Int {
        let d = (detail.isFinite && detail > 0) ? detail : 1
        let raw = Double(baseGridSize) * d
        let clamped = Swift.min(Double(gridSizeRange.upperBound),
                                Swift.max(Double(gridSizeRange.lowerBound), raw))
        return Int((clamped / 2).rounded()) * 2
    }

    /// Velocity retention at cell (i, j) of an n×n grid: 1 in the interior, ramping to 0 at the
    /// outermost cell across `spongeCells`.
    public static func spongeGain(i: Int, j: Int, n: Int) -> Double {
        guard n > 0, i >= 0, j >= 0, i < n, j < n else { return 0 }
        let d = Swift.min(Swift.min(i, j), Swift.min(n - 1 - i, n - 1 - j))
        return d >= spongeCells ? 1 : Double(d) / Double(spongeCells)
    }

    /// The one bound every stored value passes: non-finite → 0, otherwise ±`heightClamp`.
    public static func sanitize(_ x: Double) -> Double {
        guard x.isFinite else { return 0 }
        return Swift.min(heightClamp, Swift.max(-heightClamp, x))
    }

    /// Key under which F3 caches its compute pipeline — per Metal device AND per shader
    /// generation, so neither a device swap nor a shader edit serves a stale pipeline.
    public static func cacheKey(deviceID: String, generation: Int = FluidSurfaceMath.shaderGeneration) -> String {
        "fluid:\(deviceID)#\(generation)"
    }

    // MARK: - The CPU reference grid

    /// One touch's contribution for one frame: a cell and the velocity it adds.
    public struct Impulse: Equatable, Sendable {
        public var i: Int
        public var j: Int
        public var amplitude: Double
        public init(i: Int, j: Int, amplitude: Double) {
            self.i = i; self.j = j; self.amplitude = amplitude
        }
    }

    /// An n×n height/velocity field stepped on the CPU. The reference the shader is checked
    /// against; never the per-frame path.
    public struct Grid: Sendable {
        public let n: Int
        public private(set) var height: [Double]
        public private(set) var velocity: [Double]

        /// Zero-filled grid; a non-positive size yields the smallest legal grid rather than an
        /// empty one, so every index below is in range.
        public init(size: Int) {
            let side = Swift.max(2, size)
            n = side
            height = Array(repeating: 0, count: side * side)
            velocity = Array(repeating: 0, count: side * side)
        }

        public func heightAt(i: Int, j: Int) -> Double {
            guard i >= 0, j >= 0, i < n, j < n else { return 0 }
            return height[i * n + j]
        }

        /// Sum of squares of every stored value — the bound the guard watches.
        public var energy: Double {
            var e = 0.0
            for x in height { e += x * x }
            for x in velocity { e += x * x }
            return e
        }

        /// One frame: inject the impulses, then run TWO substeps of the wave equation. Impulses
        /// land only before the first substep, so a frame's touches are not double-counted.
        public mutating func step(viscosity: Double, impulses: [Impulse]) {
            for imp in impulses where imp.i >= 0 && imp.j >= 0 && imp.i < n && imp.j < n {
                let k = imp.i * n + imp.j
                velocity[k] = FluidSurfaceMath.sanitize(velocity[k] + imp.amplitude)
            }
            substep(viscosity: viscosity)
            substep(viscosity: viscosity)
        }

        private mutating func substep(viscosity: Double) {
            let c2 = FluidSurfaceMath.waveSpeedSquared(viscosity: viscosity)
            let retain = FluidSurfaceMath.damping(viscosity: viscosity)
            var newHeight = height
            var newVelocity = velocity
            for i in 0..<n {
                for j in 0..<n {
                    let k = i * n + j
                    var lap = -4 * height[k]
                    if i > 0 { lap += height[k - n] }
                    if i < n - 1 { lap += height[k + n] }
                    if j > 0 { lap += height[k - 1] }
                    if j < n - 1 { lap += height[k + 1] }
                    let gain = FluidSurfaceMath.spongeGain(i: i, j: j, n: n)
                    newVelocity[k] = FluidSurfaceMath.sanitize((velocity[k] + c2 * lap) * retain * gain)
                    newHeight[k] = FluidSurfaceMath.sanitize(height[k] + newVelocity[k])
                }
            }
            height = newHeight
            velocity = newVelocity
        }
    }

    // MARK: - Private

    private static func unitClamped(_ x: Double) -> Double {
        guard x.isFinite else { return 0 }
        return Swift.min(1, Swift.max(0, x))
    }
}

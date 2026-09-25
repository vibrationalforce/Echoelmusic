// TheSpectralGridEvolvesInPlaceTests.swift
// Echoel — overnight P8 (2026-09-25). Blocking bundle.
//
// ⭐ THE DEFECT (found by review 4, then measured in the source). `EchoelCellular.evolve2D()`,
// the Game-of-Life step of the `.spectral2D` texture mode, runs on the RENDER THREAD. It began
// with `var newGrid = grid2D` and wrote the next generation into that copy. A nested Swift
// array copy shares every buffer, so the first write to each row copied it: 65 heap allocations
// per generation (the outer array plus 64 rows), plus one free each when the old grid was
// released. This breaks the audio-thread law (no malloc/free) in a file compiled into the AUv3.
// The repair keeps a preallocated `grid2DNext`, writes every cell of it, and swaps the grids.
// `swap` exchanges two buffer references and allocates nothing.
//
// ⚠️ LATENT, NOT LIVE — measured, not assumed. The one production construction is the AUv3's
// texture, and it sets `synthMode = .additive`. `.spectral2D` is unreachable in the product
// today; this closes the path for the next caller (#1385: a revived caller re-arms latent
// defects in the callee).
//
// ⚠️ HONEST GRADING (transcribed in Python against both trees; no toolchain, §0).
//   · claim 1 is a SOURCE-TEXT SCAN and a REGRESSION: on the parent `evolve2D()` copies
//     `grid2D` and never swaps. An allocation on a private path is not observable from a test,
//     so the scan pins the form that decides it (as `TheCellularSeedSharesNoBufferTests` does).
//   · claim 2 is a SOURCE-TEXT SCAN and a FORWARD guard: `grid2DNext` is created by this
//     commit. It pins DISTINCT rows. `Array(repeating: row, count:)` would share one row 64
//     times, and the first evolution would copy each of them on the render thread.
//   · claim 3 is END-TO-END BEHAVIOUR on the shipped public type and a COUNTERWEIGHT. Five
//     generations from the R-pentomino seed must match an independent Game-of-Life reference
//     (toroidal, B3/S23), and the grid must actually change. Green on both trees. The double
//     buffer must not change a single cell of the evolution.
//   · Not executed (no toolchain); what `Build for Testing` proves is compilation only.

import XCTest
@testable import Echoelmusic

final class TheSpectralGridEvolvesInPlaceTests: XCTestCase {

    private static let cellular = "Sources/Echoelmusic/DSP/EchoelCellular.swift"

    /// claim 1 — the step writes into the preallocated grid and swaps; it copies nothing.
    func testTheStepWritesThePreallocatedGridAndSwaps() throws {
        let code = try source(Self.cellular)
        let body = try XCTUnwrap(Self.body(startingWith: "private func evolve2D() {", in: code),
                                 "`evolve2D()` not found — re-anchor (#454).")
        XCTAssertFalse(body.contains("= grid2D\n"), """
            `evolve2D()` copies `grid2D` as a whole again. The copy shares every row, so the \
            first write to each row allocates — 65 times per generation, on the render thread.
            """)
        XCTAssertTrue(body.contains("grid2DNext[y][x] ="), """
            `evolve2D()` no longer writes the next generation into `grid2DNext`.
            """)
        XCTAssertTrue(body.contains("swap(&grid2D, &grid2DNext)"), """
            `evolve2D()` no longer swaps the two grids. Assigning one to the other shares a \
            buffer, and the next write copies it on the render thread.
            """)
    }

    /// claim 2 — the preallocated grid is built from 64 DISTINCT rows.
    func testThePreallocatedGridHasDistinctRows() throws {
        let code = try source(Self.cellular)
        XCTAssertTrue(code.contains(
            "self.grid2DNext = (0..<grid2DSize).map { _ in [UInt8](repeating: 0, count: grid2DSize) }"),
            """
            `grid2DNext` is no longer built row by row. `Array(repeating: row, count:)` shares \
            ONE row buffer 64 times, and the first evolution would copy each on the render thread.
            """)
    }

    /// claim 3 — COUNTERWEIGHT: the evolution is exactly Conway's rule, generation by generation.
    func testTheEvolutionIsUnchanged() {
        let texture = EchoelCellular(cellCount: 128, sampleRate: 48000)
        texture.synthMode = .spectral2D
        texture.evolutionRate = 60                    // 48000 / 60 = 800 frames per generation, exact
        let framesPerGeneration = 800
        var expected = texture.getGrid2D()
        let start = expected
        XCTAssertGreaterThan(start.joined().reduce(0, +), 0, "premise: the seed has live cells")

        var buffer = [Float](repeating: 0, count: framesPerGeneration)
        for generation in 1...5 {
            texture.render(buffer: &buffer, frameCount: framesPerGeneration)
            expected = Self.conwayStep(expected)
            XCTAssertEqual(texture.getGrid2D(), expected, """
                Generation \(generation) of the spectral grid differs from Conway's rule \
                (toroidal, B3/S23). The double buffer must not change the evolution.
                """)
        }
        XCTAssertNotEqual(texture.getGrid2D(), start, "premise: five generations changed the grid")
    }

    // MARK: - helpers

    /// An independent reference step: toroidal Game of Life, born on 3, survives on 2 or 3.
    private static func conwayStep(_ grid: [[Float]]) -> [[Float]] {
        let n = grid.count
        var next = grid
        for y in 0..<n {
            for x in 0..<n {
                var neighbours = 0
                for dy in -1...1 {
                    for dx in -1...1 where !(dx == 0 && dy == 0) {
                        if grid[(y + dy + n) % n][(x + dx + n) % n] == 1 { neighbours += 1 }
                    }
                }
                let alive = grid[y][x] == 1
                next[y][x] = (alive ? (neighbours == 2 || neighbours == 3) : neighbours == 3) ? 1 : 0
            }
        }
        return next
    }

    private static func body(startingWith anchor: String, in code: String) -> String? {
        guard let start = code.range(of: anchor) else { return nil }
        var depth = 0
        var out = ""
        for ch in code[start.lowerBound...] {
            if ch == "{" { depth += 1 }
            if depth > 0 { out.append(ch) }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
        }
        return nil
    }

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — source-text claim cannot run (#454)")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}

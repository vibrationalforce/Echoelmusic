// TheGrainCloudAllocatesOnlyInPrepareTests.swift
// Echoel — GMMW GA-9 ("Echoel Grain kernel"). `DSP/GrainCloud` reads short raised-cosine grains from a
// source buffer — position · size · density · spray · pitch · spread — ported from `EchoelGranular`
// (#1305 took it with the microphone; `docs/dev/HISTORY_ARCHIVE.md` B5: "PORT ALGORITHM — the source
// must become a buffer"). No caller yet: GA-10 renders it as an insert on an audio track.
//
// WHAT IT PINS (Tests/CISmoke/CLAUDE.md §1):
// 1. END-TO-END: with no source, or an empty one, `process` WRITES silence (over a buffer prefilled
//    with garbage, so "wrote nothing" cannot pass for "wrote zeros"); a silent source renders silence.
// 2. END-TO-END: from density 0.5 up, density is not a volume control. At overlap 2 and 3
//    (density 0.5 and 5/6) Hann at a uniform hop is exactly flat (COLA), and every steady-state
//    sample of a 0.5 DC source sits at 0.5 × √0.5 (the centre pan gain) within 1 %; at density 1
//    the steady MEAN holds within 0.5 % (its ripple is ±1.6 %). At every density the output stays
//    under the algebraic bound A · (overlap + 1) · norm. And the first grain sounds within 2 ms.
// 3. END-TO-END: a source with NaN/∞ renders BIT-IDENTICALLY to the same source with zeros there
//    (`prepare` cleans it — the per-frame output sanitiser alone would also give finite output, by
//    silencing whole frames, so "finite" could not tell the two apart); NaN/∞ parameters fall back
//    to their defaults and the cloud still sounds; a +24 st, 500 ms grain on a 3000-frame source is
//    shortened AND spawned at its own hop, so the cloud holds the level within 1 %; a two-frame
//    source is silent; a non-finite or absurd rate is 48 kHz.
// 4. END-TO-END: the same seed and source render the same output, `reset()` renders what a fresh cloud
//    does, another seed renders something else. The window is 0 at both ends and outside 0…1.
// 5. SOURCE: `process`, `spawn`, `read`, `window`, `bounded`, `mixed` and `next01` contain no
//    allocating or blocking token; `prepare` is where the source buffer is allocated; the file
//    imports Foundation only.
//
// Grading (§0, no Swift toolchain): the file does NOT compile on its parent (`f09b9b6`) — it names
// `GrainCloud`, created by this commit — so no assertion has a verdict there (ONE absence, #486);
// claims 1–4 are FORWARD guards. They were transcribed into a Python port of the kernel (Float
// rounding kept on the accumulator, the window and the sums) and every expectation was driven
// through it; the 1 % and the bound were MEASURED there (density 0.5: min = max = 0.35355; density
// 1: 0.34785 … 0.35915 under a bound of 1.2857), not chosen. Claim 5 was grepped against the worktree.
// The review fix (audio-thread-reviewer, GA-9), graded against ITS parent (`a3f965f`) in the same
// port: the file compiles there. REGRESSIONS for their named reason: the first grain (1921 frames
// late), the shortened cloud's level (95 % silence there). The tightened checks — density 5/6 flat,
// density 1's mean, dirty == clean — are green on both trees, and that is their point: each was
// driven against the MUTATION it names (no normalisation: +50 % at 5/6, ×1.75 mean at 1; no
// cleaning in `prepare`: whole frames zeroed, so the two renders differ). The old pool assertion is
// gone: `activeGrainCount` walks exactly `maxGrains` slots, so it could not fail.
// NOT covered: how it SOUNDS, CPU on device — GA-10 and a device probe.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheGrainCloudAllocatesOnlyInPrepareTests: XCTestCase {

    private static let rate: Float = 48_000

    private func render(_ cloud: GrainCloud, frames: Int) -> (left: [Float], right: [Float]) {
        var left = [Float](repeating: 9, count: frames)
        var right = [Float](repeating: 9, count: frames)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                cloud.process(left: lp, right: rp, frameCount: frames)
            }
        }
        return (left, right)
    }

    // MARK: 1 — nothing to read is silence

    func testNoSourceAndASilentSourceRenderSilence() {
        let unprepared = GrainCloud(sampleRate: Self.rate)
        let none = render(unprepared, frames: 512)
        XCTAssertTrue((none.left + none.right).allSatisfy { $0 == 0 }, "no source: silence is WRITTEN")

        let empty = GrainCloud(sampleRate: Self.rate)
        empty.prepare(source: [])
        XCTAssertFalse(empty.isPrepared)
        let emptyOut = render(empty, frames: 512)
        XCTAssertTrue((emptyOut.left + emptyOut.right).allSatisfy { $0 == 0 })

        let silent = GrainCloud(sampleRate: Self.rate)
        silent.prepare(source: [Float](repeating: 0, count: 48_000))
        let quiet = render(silent, frames: 48_000)
        XCTAssertEqual((quiet.left + quiet.right).map(\.magnitude).max(), 0, "a silent source renders silence")
    }

    // MARK: 2 — density is not a volume control

    func testTheCloudHoldsTheSourceLevel() {
        let amplitude: Float = 0.5
        let centreGain = Float(0.5).squareRoot()
        let fiveSixths: Float = 5.0 / 6.0   // overlap 3
        for density: Float in [0, 0.5, fiveSixths, 1] {
            let cloud = GrainCloud(sampleRate: Self.rate)
            cloud.prepare(source: [Float](repeating: amplitude, count: 96_000))
            cloud.position = 0.5
            cloud.stereoSpread = 0
            cloud.density = density
            let out = render(cloud, frames: 96_000)
            let overlap = 0.5 + 3 * density
            let norm = 1 / Swift.max(1, overlap * 0.5)
            let bound = amplitude * (overlap + 1) * norm
            let peak = (out.left + out.right).map(\.magnitude).max() ?? 0
            XCTAssertLessThanOrEqual(peak, bound, "density \(density): \(peak) over the bound \(bound)")
            let target = amplitude * centreGain
            let steady = out.left[4_800...]
            if density == 0.5 || density == fiveSixths {
                let worst = steady.map { abs($0 - target) }.max() ?? .infinity
                XCTAssertLessThanOrEqual(worst, target * 0.01,
                                         "overlap \(overlap) is COLA: every steady sample holds the source level")
            }
            if density == 1 {
                let mean = steady.reduce(0, +) / Float(steady.count)
                XCTAssertEqual(mean, target, accuracy: target * 0.005, "density 1 keeps the source's mean level")
            }
            if density == 0.5 {
                let first = out.left.firstIndex { $0 != 0 } ?? out.left.count
                XCTAssertLessThanOrEqual(first, 96, "the first grain sounds within 2 ms, not one hop later")
            }
        }
    }

    // MARK: 3 — non-finite input, short sources, the pool

    func testNonFiniteInputAndShortSourcesStaySafe() {
        var source: [Float] = (0..<48_000).map { i in
            Float(0.3 * Foundation.sin(2 * Double.pi * 330 * Double(i) / 48_000))
        }
        for frame in [100, 2_000, 30_000] { source[frame] = .nan }
        source[500] = .infinity

        var cleaned = source
        for frame in [100, 500, 2_000, 30_000] { cleaned[frame] = 0 }
        let dirty = GrainCloud(sampleRate: Self.rate)
        dirty.prepare(source: source)
        let clean = GrainCloud(sampleRate: Self.rate)
        clean.prepare(source: cleaned)
        let a = render(dirty, frames: 48_000)
        let b0 = render(clean, frames: 48_000)
        XCTAssertTrue((a.left + a.right).allSatisfy(\.isFinite))
        XCTAssertEqual(a.left, b0.left, "NaN and ∞ in the source play as the zeros prepare made of them")
        XCTAssertEqual(a.right, b0.right)

        let wild = GrainCloud(sampleRate: Self.rate)
        wild.prepare(source: source)
        wild.position = .nan
        wild.grainMilliseconds = .infinity
        wild.density = .nan
        wild.spraySeconds = -.infinity
        wild.pitchSemitones = .nan
        wild.stereoSpread = .nan
        let b = render(wild, frames: 48_000)
        XCTAssertTrue((b.left + b.right).allSatisfy(\.isFinite))
        XCTAssertGreaterThan((b.left + b.right).map(\.magnitude).max() ?? 0, 0, "non-finite parameters fall back; the cloud still sounds")

        let short = GrainCloud(sampleRate: Self.rate)
        short.prepare(source: [Float](repeating: 0.4, count: 3_000))
        short.pitchSemitones = 24
        short.grainMilliseconds = 500
        short.position = 0.5
        short.stereoSpread = 0
        let c = render(short, frames: 48_000)
        XCTAssertTrue((c.left + c.right).allSatisfy(\.isFinite), "a grain longer than the source at +24 st is shortened")
        let level = Float(0.4) * Float(0.5).squareRoot()
        let worst = c.left[4_800...].map { abs($0 - level) }.max() ?? .infinity
        XCTAssertLessThanOrEqual(worst, level * 0.01,
                                 "shortened grains are spawned at their own hop: the cloud holds the level, not 95 % silence")

        let tiny = GrainCloud(sampleRate: Self.rate)
        tiny.prepare(source: [0.4, 0.4])
        XCTAssertEqual((render(tiny, frames: 4_800).left).map(\.magnitude).max(), 0,
                       "COUNTERWEIGHT: a source too short for a two-frame grain is silent, and says so in the doc")

        for bad: Float in [.nan, .infinity, 0, -1, 1e12] {
            XCTAssertEqual(GrainCloud(sampleRate: bad).sampleRate, 48_000, "rate \(bad)")
        }
    }

    // MARK: 4 — the seed pins the pattern; the window cannot click

    func testTheSeedPinsTheCloudAndTheWindowEndsAtZero() {
        let source: [Float] = (0..<48_000).map { i in Float(Foundation.sin(Double(i) * 0.05)) * 0.3 }
        let a = GrainCloud(sampleRate: Self.rate)
        let b = GrainCloud(sampleRate: Self.rate)
        a.prepare(source: source)
        b.prepare(source: source)
        let first = render(a, frames: 24_000)
        let second = render(b, frames: 24_000)
        XCTAssertEqual(first.left, second.left)
        XCTAssertEqual(first.right, second.right)
        a.reset()
        XCTAssertEqual(render(a, frames: 24_000).left, second.left, "reset renders what a fresh cloud does")
        let other = GrainCloud(sampleRate: Self.rate, seed: 7)
        other.prepare(source: source)
        XCTAssertNotEqual(render(other, frames: 24_000).left, second.left, "another seed, another cloud")

        XCTAssertEqual(GrainCloud.window(0), 0)
        XCTAssertEqual(GrainCloud.window(1), 0, accuracy: 1e-6)
        XCTAssertEqual(GrainCloud.window(0.5), 1, accuracy: 1e-6)
        for outside: Float in [-0.1, 1.1, .nan, .infinity] {
            XCTAssertEqual(GrainCloud.window(outside), 0, "window(\(outside))")
        }
    }

    // MARK: 5 — the render path allocates nothing

    func testOnlyPrepareAllocates() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let text = try String(contentsOf: root.appendingPathComponent("Sources/Echoelmusic/DSP/GrainCloud.swift"),
                              encoding: .utf8)
        let code = SourceText.codeOnly(text)
        // Tokens, not prefixes of member names: `.map(` does not match the pure `.mapped(` helper,
        // `.filter(` not a `filterL` stage (GA-9 review, #364).
        let banned = ["append(", "Array(", "[Float](", "[Grain](", ".allocate(", "String(", "\\(",
                      "DispatchQueue", "DispatchSemaphore", "os_unfair_lock", "Task", "os_log", "NSLog",
                      "print(", "NSLock", ".map(", ".map {", ".filter(", ".filter {", ".compactMap",
                      ".flatMap", ".reduce", "firstIndex", "log."]
        for head in ["public func process(left:", "private func spawn(length:",
                     "private static func read(_ src:", "public static func window(_ position01:",
                     "private static func bounded(_ value:", "private static func mixed(_ seed:",
                     "private func next01()"] {
            let body = try member(head, in: code)
            for token in banned {
                XCTAssertFalse(body.contains(token), "`\(token)` in `\(head)` — the render path must not allocate or block")
            }
        }
        let prepare = try member("public func prepare(source samples: [Float]) {", in: code)
        XCTAssertTrue(prepare.contains("UnsafeMutablePointer<Float>.allocate(capacity: count)"),
                      "COUNTERWEIGHT: the source buffer is allocated where the contract says — in prepare")
        let imports = code.split(separator: "\n").filter { $0.hasPrefix("import ") }.map(String.init)
        XCTAssertEqual(imports, ["import Foundation"], "DSP/ is Foundation and Accelerate only, and this needs neither more")
    }

    private struct AnchorMissing: Error {}

    /// The text inside the braces that open at the first `{` from `head` on (#408 — never a window).
    private func member(_ head: String, in text: String) throws -> String {
        guard let start = text.range(of: head),
              let open = text[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `\(head)` (#454)")
            throw AnchorMissing()
        }
        var depth = 1
        var index = text.index(after: open)
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: open)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED: `\(head)` never closes (#454)")
        throw AnchorMissing()
    }
}

// TheTimebaseConvertsWithoutBecomingAClockTests.swift
// Echoel — #1416 (DMMW M1). The conversion authority answers questions about time and never
// moves it, and every conversion is total on input a document can actually carry.
//
// ⚠️ GRADING, AND IT IS THE UNUSUAL CASE §3 NAMES EXPLICITLY. This file names symbols that
// this same commit creates (`Timebase`, `TempoMap`, `MeterMap`, `SampleTime`, …), so it DOES
// NOT COMPILE against the parent tree: **no assertion has a verdict there.** All eight claims
// are therefore FORWARD guards — zero regressions, zero anchor-absences, zero counterweights
// in the usual sense — and booking any of them as a regression would be the flattering
// direction of #433. What was graded instead, because a forward guard's numbers are the one
// thing CI will not check for you (#686/#943b): every arithmetic claim below was transcribed
// into Python from the SHIPPED Swift and driven before this file existed. Round-trip over a
// four-entry map with two ramps and a seam, sampled every 7th tick across 40 bars: worst
// delta **0 ticks**. Monotonicity across the seam: holds. Hostile input: no trap, no NaN out.
//
// ⚠️ NOT COMPILE-VERIFIED BY ME — a transcription does not run Swift's type checker; that is
// `Build for Testing` (§5, and `Xcode Compile Check` cannot answer it, it builds `Sources/`
// alone). NOT device-verified, and there is nothing on a device to verify: M1 has ZERO
// production call sites by definition, and if it had needed one the slice would be wrong.
//
// ⭐ WHY A TRAP IS THE FAILURE MODE THIS FILE IS MOST AFRAID OF. `Int64(someDouble)` traps on
// NaN, on ±infinity and past `Int64.max`; an `Int64` multiply traps on overflow. A trap in
// this bundle kills the simulator clone, which from outside is INDISTINGUISHABLE from #396
// (#1174) — a silent green over a dead run. Claim 4 is the one that would fire, so it is the
// one whose expectations were derived rather than observed.
//
// Kinds, per §1: claims 1–6 are END-TO-END BEHAVIOUR (public Foundation-only value types the
// bundle can instantiate — the strong kind). Claims 7–8 are SOURCE-TEXT SCANS and say so.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTimebaseConvertsWithoutBecomingAClockTests: XCTestCase {

    private static let ppq = 480          // `Note.ticksPerQuarter`, passed rather than assumed
    private static let tempoPath = "Sources/Echoelmusic/Core/TempoMap.swift"
    private static let timebasePath = "Sources/Echoelmusic/Core/Timebase.swift"

    private func source(_ relativePath: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        let url = dir.appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath). A guard that cannot find its "
                    + "subject is not a pass — re-anchor it rather than letting it stay green "
                    + "(#454).")
            return ""
        }
        return text
    }

    /// A map with a ramp, a seam, a flat stretch, a second ramp and a hard drop — the shape
    /// every claim below is exercised against, so a change in ONE place changes all of them.
    private var mixedMap: TempoMap {
        TempoMap(entries: [
            .init(atTick: 0, bpm: 90, curve: .linear),
            .init(atTick: Int64(8 * Self.ppq), bpm: 150, curve: .step),
            .init(atTick: Int64(20 * Self.ppq), bpm: 150, curve: .linear),
            .init(atTick: Int64(28 * Self.ppq), bpm: 60, curve: .step)
        ])
    }

    // 1 — END-TO-END. The two directions are inverses, not approximations of each other.
    // A DMMW project stores MIDI in ticks and media in seconds; the moment those disagree by
    // more than the grid itself, an edit made at one tempo lands somewhere else at another —
    // which is the exact failure `TimelineRegion`'s two parallel trims already work around.
    func testTheMusicalToWallRoundTripStaysWithinOneTick() {
        let map = mixedMap
        var worst: Int64 = 0
        for tick in stride(from: Int64(0), to: Int64(40 * Self.ppq), by: 7) {
            let seconds = map.seconds(atTick: tick, ppq: Self.ppq)
            XCTAssertTrue(seconds.isFinite, "non-finite seconds at tick \(tick)")
            let back = map.tick(atSeconds: seconds, ppq: Self.ppq)
            worst = Swift.max(worst, abs(back - tick))
        }
        XCTAssertLessThanOrEqual(worst, 1, """
            musical → wall → musical drifted by \(worst) ticks. Driven in Python against the
            shipped arithmetic before this file existed, the worst delta over exactly this
            sweep is ZERO, so anything above 1 is a real inversion error and not float noise.
            The `.linear` branch of `tick(atSeconds:ppq:)` must keep SOLVING the ramp integral
            — replacing it with a mean BPM passes claim 2 by 4 % and this one by a bar.
            """)
    }

    // 2 — END-TO-END, and the number is ALGEBRA, not a printed value (#442). Seconds over a
    // ramp are ∫60/(bpm(t)·ppq)dt, which over one quarter from 60 to 120 BPM closes to
    // exactly ln 2. Averaging the endpoints gives 60/90 = 0.667 s — wrong by 4 %, and wrong
    // in a way that only shows on long ramps, i.e. invisible until a show.
    func testTheLinearRampIntegratesRatherThanAverages() {
        let ramp = TempoMap(entries: [
            .init(atTick: 0, bpm: 60, curve: .linear),
            .init(atTick: Int64(Self.ppq), bpm: 120, curve: .step)
        ])
        let seconds = ramp.seconds(atTick: Int64(Self.ppq), ppq: Self.ppq)
        XCTAssertEqual(seconds, Foundation.log(2.0), accuracy: 1e-12, """
            A 60 → 120 BPM quarter must take ln 2 ≈ 0.693 s. Got \(seconds).
            """)
        XCTAssertGreaterThan(abs(seconds - 60.0 / 90.0), 0.02, """
            The ramp is being AVERAGED rather than integrated: \(seconds) is within 2 % of
            the endpoint mean 60/90. The two answers differ by about 4 % here and by more the
            longer the ramp, which is why this is asserted as a distance and not as a `!=`.
            """)

        // Counterweight (#343): the flat case must stay EXACT, or claim 2 could be satisfied
        // by a ramp formula that quietly perturbs constant tempo everywhere else.
        let flat = TempoMap.constant(120)
        XCTAssertEqual(flat.seconds(atTick: Int64(4 * Self.ppq), ppq: Self.ppq), 2.0,
                       accuracy: 0.0,
                       "four quarters at 120 BPM is 2 s exactly — 1920·60/(120·480) has no "
                       + "rounding in it at all")
    }

    // 3 — END-TO-END. Property 2 of the slice: later never reads earlier. The seam between a
    // ramp and the next entry is where a per-segment solve most easily steps backwards.
    func testTheSecondsWalkIsMonotoneAcrossEverySeam() {
        let map = mixedMap
        var previous = -Double.greatestFiniteMagnitude
        for tick in stride(from: Int64(-2 * Self.ppq), to: Int64(40 * Self.ppq), by: 13) {
            let seconds = map.seconds(atTick: tick, ppq: Self.ppq)
            XCTAssertGreaterThanOrEqual(seconds, previous - 1e-9,
                                        "time ran backwards at tick \(tick)")
            previous = seconds
        }
    }

    // 4 — END-TO-END, and the one that must never be relaxed. These types are DECODED from
    // persisted documents, including ones written by older builds and ones edited by hand, so
    // "a caller would never pass that" is not an argument available here.
    func testEveryConversionIsTotalOnHostileInput() {
        let hostile: [Double] = [.nan, .infinity, -.infinity, 0, -1, 1e308, -1e308]

        for bad in hostile {
            let map = TempoMap(entries: [.init(atTick: 0, bpm: bad, curve: .linear),
                                         .init(atTick: Int64(Self.ppq), bpm: bad, curve: .step)])
            for entry in map.entries {
                XCTAssertTrue(TempoMap.bpmRange.contains(entry.bpm),
                              "a \(bad) BPM survived normalisation as \(entry.bpm)")
            }
            for badPPQ in [0, -1, Int.max] {
                XCTAssertTrue(map.seconds(atTick: 96, ppq: badPPQ).isFinite)
                _ = map.tick(atSeconds: bad, ppq: badPPQ)
            }
            XCTAssertTrue(WallTime(seconds: bad).seconds.isFinite,
                          "WallTime let a non-finite through")
            XCTAssertTrue(SampleTime.rateRange.contains(SampleTime(frames: 1,
                                                                   sampleRate: bad).sampleRate))
        }

        // The extremes of the tick space, where a narrowing conversion would trap.
        let map = mixedMap
        for tick in [Int64.min, Int64.max, -(1 << 62), 1 << 62, 0] {
            XCTAssertTrue(map.seconds(atTick: tick, ppq: Self.ppq).isFinite,
                          "non-finite seconds at tick \(tick)")
            _ = MeterMap.fourFour.barBeat(atTick: tick, ppq: Self.ppq)
        }
        XCTAssertEqual(TempoMap(entries: []).entries.count, 1,
                       "an empty map must normalise to one seeded entry, not to nothing — "
                       + "every walk in the file reads `entries.first`")
        let unsorted = TempoMap(entries: [.init(atTick: Int64(5 * Self.ppq), bpm: 90),
                                          .init(atTick: Int64(Self.ppq), bpm: 150)])
        XCTAssertEqual(unsorted.entries.map(\.atTick),
                       [0, Int64(Self.ppq), Int64(5 * Self.ppq)],
                       "an unsorted map must come back sorted AND seeded at tick 0")
        XCTAssertEqual(unsorted.entries.first?.bpm, 150,
                       "the seed takes the FIRST DECLARED tempo, not a default: a map that "
                       + "starts at bar 2 still describes bar 1, and inventing 120 there "
                       + "would write a tempo change the user never made")
    }

    // 5 — END-TO-END plus SOURCE-TEXT SCAN. Property 5: a sample position is read at ITS OWN
    // rate. 48 000 and 44 100 with the same frame count are different instants, and the
    // places that get this wrong — punch points, loop ends, recording offsets — are the ones
    // where being quietly wrong costs a take rather than raising anything.
    func testASamplePositionIsReadAtItsOwnRate() {
        let oneSecondAt44k = SampleTime(frames: 44_100, sampleRate: 44_100)
        let oneSecondAt48k = SampleTime(frames: 48_000, sampleRate: 48_000)
        XCTAssertEqual(oneSecondAt44k.seconds.seconds, 1.0, accuracy: 1e-12)
        XCTAssertEqual(oneSecondAt48k.seconds.seconds, 1.0, accuracy: 1e-12)

        // The timebase renders at 48 k and must STILL read the 44.1 k position correctly.
        let timebase = Timebase(ppq: Self.ppq, sampleRate: 48_000,
                                tempoMap: .constant(120))
        XCTAssertEqual(timebase.seconds(at: oneSecondAt44k).seconds, 1.0, accuracy: 1e-12, """
            `Timebase.seconds(at: SampleTime)` divided by its OWN sample rate instead of the
            position's. That is the whole reason `SampleTime` carries one.
            """)
        XCTAssertEqual(oneSecondAt44k.converted(to: 48_000).frames, 48_000,
                       "converting rates must resample, not reinterpret the frame count")

        let code = SourceText.codeOnly((try? source(Self.timebasePath)) ?? "")
        let comparable = code.range(of: "SampleTime[^\n{]*Comparable",
                                    options: .regularExpression)
        XCTAssertNil(comparable, """
            `SampleTime` has been made `Comparable`. It must not be: a frame-count `<` between
            two different rates is silently wrong, and the type exists to force the rate into
            the reader's hands. If a total order is genuinely needed, compare `.seconds`.
            """)
    }

    // 6 — END-TO-END. A meter change is the other thing a bare tick cannot survive.
    func testTheBarBeatRoundTripSurvivesAMeterChange() {
        let meter = MeterMap(entries: [
            .init(atBar: 0, signature: .fourFour),
            .init(atBar: 8, signature: TimeSignature(beatsPerBar: 7, beatUnit: 8))
        ])
        XCTAssertEqual(meter.tick(atBarBeat: BarBeat(bar: 8, beat: 0, tick: 0), ppq: Self.ppq),
                       Int64(8 * 4 * Self.ppq),
                       "the first eight bars are 4/4, so bar 8 starts at 8·4·ppq")

        for bar in 0...16 {
            for beat in 0..<3 {
                let position = BarBeat(bar: bar, beat: beat, tick: 37)
                let tick = meter.tick(atBarBeat: position, ppq: Self.ppq)
                XCTAssertEqual(meter.barBeat(atTick: tick, ppq: Self.ppq), position,
                               "bar/beat round trip broke at \(position)")
            }
        }
        XCTAssertEqual(TimeSignature(beatsPerBar: 7, beatUnit: 8).ticksPerBar(ppq: Self.ppq),
                       Int64(7 * Self.ppq / 2),
                       "an eighth is half a quarter, so 7/8 is 7·ppq/2 ticks")
        XCTAssertEqual(TimeSignature(beatsPerBar: 4, beatUnit: 3).beatUnit, 4,
                       "a non-power-of-two beat unit has no tick length and must fall back, "
                       + "not divide")
    }

    // 7 — SOURCE-TEXT SCAN, and it pins a FOUNDER CONSTRAINT rather than a preference:
    // `PatternEngine` is the musical clock authority and `Transport` is the fan-out. A second
    // thing in this repo that ADVANCES time would be a second master, and this repo already
    // keeps `Core/BioTempoDirector` — a finished twin of the live inline tempo servo — in the
    // register of unwired cores for exactly that reason. These types answer questions.
    //
    // ⚠️ Read COMMENT-STRIPPED on purpose: the headers of both files quote the words this
    // claim forbids, so a raw scan would match its own explanation (#491, one file over).
    func testTheTimebaseHoldsNoClock() throws {
        for path in [Self.tempoPath, Self.timebasePath] {
            let code = SourceText.codeOnly(try source(path))
            XCTAssertFalse(code.isEmpty, "empty source for \(path) — the anchor above failed")
            let clockShapes = ["Timer", "DispatchQueue", "DispatchSource", "Task {", "Task<",
                               "@Observable", "@MainActor", "async ", "await ",
                               "Date()", "CACurrentMediaTime", "mach_absolute_time",
                               "class ", "actor "]
            let hits = clockShapes.filter { code.contains($0) }
            XCTAssertTrue(hits.isEmpty, """
                \(path) contains \(hits.joined(separator: ", ")). M1 is a pure value layer: it
                converts between coordinate spaces and holds no state that advances. Whatever
                needs to tick already exists — `PatternEngine` owns the musical clock and
                `Transport` fans it out. Reported as ONE finding rather than \(hits.count)
                (#486): they are the same defect wearing different shapes.
                """)
        }
    }

    // 8 — SOURCE-TEXT SCAN. The portability property, in the shape
    // `TheDSPLayerStaysFoundationOnlyTests` already uses for `DSP/`, plus the ONE deliberate
    // coupling written down so it cannot grow silently.
    func testTheTwoFilesImportFoundationOnlyAndNameOneForeignType() throws {
        for path in [Self.tempoPath, Self.timebasePath] {
            let code = SourceText.codeOnly(try source(path))
            let imports = code.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("import ") }
                .map { String($0.dropFirst("import ".count)) }
            XCTAssertEqual(Set(imports), ["Foundation"], """
                \(path) imports \(imports.sorted().joined(separator: ", ")). The conversion
                authority is the one layer that must survive being lifted into a
                Foundation-only target, and an import is how that stops being true.
                """)
        }

        // The ONE foreign type either file may name, and only for constants it does not own.
        // Asked for, never restated (#416): `Transport` owns the app's tempo bounds and bar
        // shape, and `PatternEngine.defaultTempo` already delegates in exactly this shape.
        // ⚠️ A SET, not a count (#903: count pins rot while the fact they guard does not).
        let all = [Self.tempoPath, Self.timebasePath]
            .map { SourceText.codeOnly((try? source($0)) ?? "") }.joined(separator: "\n")
        var members: Set<String> = []
        var search = all.startIndex
        while let hit = all.range(of: "Transport.", range: search..<all.endIndex) {
            let tail = all[hit.upperBound...].prefix { $0.isLetter || $0.isNumber }
            members.insert(String(tail))
            search = hit.upperBound
        }
        XCTAssertEqual(members, ["minTempo", "maxTempo", "defaultTempo", "beatsPerBar"], """
            The coupling to `Transport` changed: \(members.sorted().joined(separator: ", ")).
            Four constants is the deal — they are ASKED FOR rather than restated, and when
            this layer is eventually lifted into its own target the direction inverts and
            `Transport` reads them from here. Anything beyond a constant means the pure layer
            has started depending on the control plane.
            """)

        let timebase = SourceText.codeOnly(try source(Self.timebasePath))
        XCTAssertFalse(timebase.contains("ppq: Int = "), """
            `ppq` has been given a default. It must not have one: the app's song grid is
            `Note.ticksPerQuarter` and MIDI import already has to rescale a foreign file's own
            division, so a second hard-coded grid would be the #416 defect inside the type
            built to end it. Callers pass it.
            """)
        let tempo = SourceText.codeOnly(try source(Self.tempoPath))
        for foreign in ["EngineBus", "PatternEngine", "AudioEngine", "AVAudio", "SwiftUI",
                        "BioSampleFrame", "MusicalFrame", "Note.ticksPerQuarter"] {
            XCTAssertFalse(timebase.contains(foreign) || tempo.contains(foreign), """
                The conversion layer now names `\(foreign)`. It is meant to be the thing
                everything else converts THROUGH, which only works while it depends on
                nothing above it. `Note.ticksPerQuarter` is in this list for the opposite
                reason to the others: not because it is too heavy, but because reaching for
                it here would re-create the single hard-coded grid this type exists to end.
                """)
        }
    }
}

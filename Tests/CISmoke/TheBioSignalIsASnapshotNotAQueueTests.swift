// TheBioSignalIsASnapshotNotAQueueTests.swift
// Echoel — 2026-09-24 (overnight P5): the continuous bio signal travels over ONE path, the
// `latestBio` snapshot. The `EngineBus.bioFrames` queue that stood beside it had no consumer
// and is removed. Blocking bundle.
//
// THE DEFECT (measured before the repair). `EngineBus.publish(bio:)` enqueued every frame into
// `bioFrames: SPSCQueue<BioSampleFrame>` (capacity 32) and ALSO updated `latestBio`. Nothing in
// `Sources/` ever dequeued `bioFrames` — comment-stripped, the name occurred exactly three times,
// all in `EngineBus.swift`: the declaration, the init and the enqueue — so the ring filled with the first 31 frames of the
// process and then refused every later one (the queue drops the NEW element when full). The
// file header advertised "audio-side consumers see it immediately"; there were none. Four docs
// and two memory files described it as "reserved/undrained", i.e. as a feature waiting for a
// reader rather than a write with no reader.
//
// THE REPAIR. The property, its `bioCapacity` init parameter and the enqueue are gone;
// `publish(bio:)` only updates the snapshot. Nothing was drained into nothing — a queue comes
// back only TOGETHER with the consumer that reads it. `BioSampleFrame` stays: it is the payload
// of the snapshot. The two queues that DO have a consumer are untouched.
//
// WHAT KIND OF GREEN (§1), PER CLAIM:
// · claims 1–2 are SOURCE-TEXT SCANS (comment-stripped): the bus declares no bio-frame queue
//   and no code under `Sources/` names one.
// · claim 3 is RUNTIME BEHAVIOUR on the real `EngineBus`: a bio publish reaches the snapshot
//   and touches neither remaining queue.
// · claim 4 is SOURCE-TEXT COUNTERWEIGHTS: the two real consumers still dequeue their queues.
// · DEVICE — nothing to probe: no reader existed, so no audible or visible behaviour changed.
//
// ⚠️ WHAT MUST NOT BE READ INTO THIS (#364). It does not forbid a full-rate bio path. It forbids
// a bio-frame QUEUE WITHOUT A READER. A future slice that adds a queue together with its
// consumer rewrites claims 1–2 in the same commit and names the consumer here.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0), no local toolchain. Parent `1a9ec0dbb`: claims 1 and 2
// are REGRESSIONS (the declaration, the enqueue and the `bioFrames` identifier are all present
// in `EngineBus.swift` code there) — ONE finding, reported by both claims (#486). Claims 3 and 4
// are COUNTERWEIGHTS, green on both trees; claim 3 compiles against the parent because it names
// no removed symbol.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheBioSignalIsASnapshotNotAQueueTests: XCTestCase {

    private static let bus = "Sources/Echoelmusic/Core/EngineBus.swift"
    private static let publishAnchor = "nonisolated public func publish(bio frame: BioSampleFrame) {"

    // MARK: - claim 1

    func testTheBusDeclaresNoBioFrameQueue() throws {
        let code = SourceText.codeOnly(try text(Self.bus))
        XCTAssertFalse(code.contains("SPSCQueue<BioSampleFrame>"), """
            `EngineBus` declares a queue of `BioSampleFrame` again. Every consumer of the \
            continuous bio signal reads the `latestBio` snapshot; a queue nobody drains fills \
            with the first frames of the process and then drops every later one. Add the queue \
            only together with its consumer, and rewrite this claim in the same commit.
            """)
        let publish = try XCTUnwrap(Self.body(startingWith: Self.publishAnchor, in: code),
                                    "`publish(bio:)` not found — re-anchor this guard (#456)")
        XCTAssertFalse(publish.contains(".enqueue("), """
            `publish(bio:)` enqueues again. The continuous bio signal has ONE path, the \
            `latestBio` snapshot.
            """)
        XCTAssertTrue(publish.contains("latestBio = frame"), """
            `publish(bio:)` no longer writes the snapshot — then no bio frame reaches any \
            synth, composer, OSC sender or visual.
            """)
    }

    // MARK: - claim 2

    func testNoCodeNamesTheRemovedQueue() throws {
        let root = Self.repoRoot.appendingPathComponent("Sources")
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw XCTSkip("Sources/ is not present — source-text claim cannot run (#454)")
        }
        let files = (FileManager.default.enumerator(atPath: root.path)?.allObjects as? [String] ?? [])
            .filter { $0.hasSuffix(".swift") }
        XCTAssertGreaterThan(files.count, 100, "the Sources walk found almost nothing — the scan is vacuous")
        var hits: [String] = []
        for relative in files {
            let url = root.appendingPathComponent(relative)
            guard let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if SourceText.codeOnly(source).contains("bioFrames") { hits.append(relative) }
        }
        XCTAssertEqual(hits, [], """
            Code names `bioFrames` again: \(hits). The queue was removed because nothing read it; \
            a reader or a writer alone brings the defect back.
            """)
    }

    // MARK: - claim 3 (COUNTERWEIGHT, RUNTIME)

    func testABioPublishReachesTheSnapshotAndNoQueue() async {
        let bus = EngineBus()
        let frame = BioSampleFrame(timestamp: 7, heartRateBPM: 64, hrvNormalized: 0.4,
                                   breathRate: 12, breathPhase: 0.25, coherence: 0.5,
                                   motionEnergy: 0, source: .cameraPPG)
        bus.publish(bio: frame)
        for _ in 0..<40 where bus.latestBio == nil { await Task.yield() }
        XCTAssertEqual(bus.latestBio?.timestamp, frame.timestamp,
                       "a published bio frame never reached `latestBio` — the one path it has")
        XCTAssertTrue(bus.controllerEvents.isEmpty, "a bio publish landed in the MIDI queue")
        XCTAssertTrue(bus.bioEvents.isEmpty, "a bio publish landed in the onset queue")
    }

    // MARK: - claim 4 (COUNTERWEIGHTS)

    func testTheTwoRealConsumersStillDrainTheirQueues() throws {
        let osc = SourceText.codeOnly(try text("Sources/Echoelmusic/Sync/OSCSender.swift"))
        XCTAssertTrue(osc.contains("bus.bioEvents.dequeue()"), """
            `OSCSender` no longer drains `bioEvents`. It is that queue's sole consumer; without \
            it the onset queue is the same readerless write this guard exists to prevent.
            """)
        let voice = SourceText.codeOnly(
            try text("Sources/Echoelmusic/Tools/BioReactiveSynthVoice.swift"))
        XCTAssertTrue(voice.contains("bus.controllerEvents.dequeue()"), """
            `BioReactiveSynthVoice` no longer drains `controllerEvents` — MIDI input would \
            reach no voice.
            """)
        let busCode = SourceText.codeOnly(try text(Self.bus))
        XCTAssertTrue(busCode.contains("public struct BioSampleFrame"), """
            `BioSampleFrame` is gone. Removing the queue was never meant to remove the payload \
            of the snapshot.
            """)
    }

    // MARK: - helpers

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
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

    private func text(_ relative: String) throws -> String {
        let url = Self.repoRoot.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(relative) is not present — source-text claim cannot run (#454)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

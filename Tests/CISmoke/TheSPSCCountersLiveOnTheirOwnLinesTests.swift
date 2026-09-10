// TheSPSCCountersLiveOnTheirOwnLinesTests.swift
// Echoel — #1237 (audit 2026-09-10 `sequencer-core-4`). The one lock-free spine keeps its
// padding promise for the counters too, and bumps them without a fence.
//
// THE DEFECT. `SPSCQueue`'s header promises "cache-line aligned to prevent false sharing". True
// for `head`/`tail` (64-byte stride), false for the three diagnostic counters: `allocate(
// capacity: 1)` each — 16-byte malloc quanta, so typically ONE line that the producer
// (dropped/enqueue) and the consumer (dequeue) both wrote, with a full `dmb ish` fence per
// increment (`OSAtomicIncrement64Barrier`) on a word nobody races on. And `enqueue()` read
// `head` via `OSAtomicAdd64Barrier(0, …)` — an atomic RMW, i.e. a STORE to the consumer's
// padded line on every enqueue. Tens of commands per second today; still the render thread's
// spine (`PolySynthVoice` dequeues in its render block), and a header that lies about it.
//
// (5, #1239) LET: the six ring pointers are `let` — assigned once in `init` — so a render-thread
// index read carries no `swift_beginAccess`; the #1237 review named it, one slice later.
//
// WHAT THIS PINS. (1) STRIDE, by text: no `allocate(capacity: 1)` in the file — every word is
// allocated with `paddedWordCapacity`. (2) NO FENCED COUNTERS, by text: no `OSAtomic*` call
// remains; the ordering the ring needs lives in the FIVE `OSMemoryBarrier()` fences (release
// before each tail publish ×2, acquire after the tail load in `dequeue`/`peek`, release before
// the head publish), which must still be there. (3) COUNTS, by behaviour: an overflow-then-
// drain sequence reports exactly the right dropped/enqueue/dequeue totals — the counters lost
// their fences, not their meaning. (4) FIFO ACROSS THREADS, by behaviour: one producer thread,
// one consumer thread, every element delivered once and in order, and the three counters
// reconcile to the number produced — the pairing claim 2 says survives the plain loads.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) for claims 1 and 2 against the parent (`60bf1bf`) and
// this tree: both RED there, GREEN here. Claims 3 and 4 are behavioural and were NOT run in
// this web session (no toolchain); their logic mirrors `SPSCQueueOverflowTests`, which pins
// the same ring, and the CI/CD `Build for Testing` step is where they first execute.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSPSCCountersLiveOnTheirOwnLinesTests: XCTestCase {

    /// Claim 1 — every word the ring allocates is padded to its own line.
    func testNoWordIsAllocatedWithoutPadding() throws {
        let src = try text("Sources/Echoelmusic/Core/SPSCQueue.swift")
        let code = src.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
        XCTAssertFalse(code.contains("allocate(capacity: 1)"),
                       "a counter is back on a shared 16-byte quantum — the header's false-sharing promise is false again (#1237)")
        XCTAssertEqual(code.components(separatedBy: "allocate(capacity: SPSCQueue.paddedWordCapacity)").count - 1, 5,
                       "expected five padded words (head, tail, three counters) — a word was added or lost its stride (#1237)")
    }

    /// Claim 2 — no fenced counter, and the ring's five fences are still where the ordering lives.
    func testTheCountersAreNotFencedAndTheRingStillIs() throws {
        let src = try text("Sources/Echoelmusic/Core/SPSCQueue.swift")
        let code = src.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") && !$0.trimmingCharacters(in: .whitespaces).hasPrefix("///") }.joined(separator: "\n")
        XCTAssertFalse(code.contains("OSAtomicIncrement64Barrier("),
                       "a counter increment is a full fence again — each counter has ONE writer, the fence buys nothing on the render thread (#1237)")
        XCTAssertFalse(code.contains("OSAtomicAdd64Barrier("),
                       "`enqueue()` reads an index by atomic RMW again — that is a store to the consumer's line on every enqueue (#1237)")
        XCTAssertEqual(code.components(separatedBy: ".pointee &+= 1").count - 1, 4,
                       "a counter increment is checked (`+=`) or fenced again — the old atomic wrapped; a trap on the render thread is the one outcome worse than a stale diagnostic (#1237)")
        XCTAssertEqual(code.components(separatedBy: "OSMemoryBarrier()").count - 1, 5,
                       "the ring's fence count changed — #1237 removed fences from COUNTERS only; the release/acquire pairing on tail/head is not to be touched from this test's premise (#1237)")
    }

    /// Claim 3 — the counters still mean what they say after an overflow and a drain.
    func testTheCountersReconcileAcrossAnOverflowAndADrain() {
        let q = SPSCQueue<Int>(capacity: 4)   // usable slots: 3
        var accepted = 0
        for i in 0..<10 where q.enqueue(i) { accepted += 1 }
        XCTAssertEqual(accepted, 3)
        XCTAssertEqual(q.enqueueCount, 3, "a rejected element is not an enqueue (#1237)")
        XCTAssertEqual(q.droppedCount, 7, "every rejected element is a drop (#1237)")
        var drained: [Int] = []
        while let e = q.dequeue() { drained.append(e) }
        XCTAssertEqual(drained, [0, 1, 2], "FIFO broke across the overflow (#1237)")
        XCTAssertEqual(q.dequeueCount, 3)
        q.resetMetrics()
        XCTAssertEqual(q.enqueueCount + q.droppedCount + q.dequeueCount, 0)
    }

    /// Claim 4 — one producer thread, one consumer thread: every element once, in order, counters reconciled.
    ///
    /// `SPSCQueue` is deliberately not `Sendable` (its contract is "one producer, one consumer",
    /// not "share freely"), so the two threads reach it through a box that states that contract
    /// — the same shape the render path uses (#213 `LockedBox` for the closure, raw pointers
    /// for the words). Nothing here is on an audio thread; this is a plain XCTest.
    func testOneProducerOneConsumerKeepFIFOAndTheCountersReconcile() {
        final class Harness: @unchecked Sendable {
            let q = SPSCQueue<Int>(capacity: 64)
            let total = 200_000
            var produced = 0                 // producer thread writes, main reads after join
            var received: [Int] = []         // consumer thread writes, main reads after join
            let producerFinished = UnsafeMutablePointer<Bool>.allocate(capacity: 1)
            init() { producerFinished.initialize(to: false); received.reserveCapacity(total) }
            deinit { producerFinished.deallocate() }
        }
        let h = Harness()
        let done = DispatchGroup()

        done.enter()
        Thread.detachNewThread {
            for i in 0..<h.total {
                while !h.q.tryEnqueue(i) { /* spin: the consumer is draining */ }
                h.produced += 1
            }
            OSMemoryBarrier()
            h.producerFinished.pointee = true
            done.leave()
        }
        done.enter()
        Thread.detachNewThread {
            while true {
                if let e = h.q.dequeue() {
                    h.received.append(e)
                } else if h.producerFinished.pointee {
                    OSMemoryBarrier()
                    while let e = h.q.dequeue() { h.received.append(e) }
                    break
                }
            }
            done.leave()
        }
        XCTAssertEqual(done.wait(timeout: .now() + 30), .success, "the two threads did not finish in 30 s (#1237)")
        XCTAssertEqual(h.produced, h.total)
        XCTAssertEqual(h.received.count, h.total, "an element was lost or duplicated across threads (#1237)")
        XCTAssertTrue(h.received.elementsEqual(0..<h.total), "FIFO order broke across threads (#1237)")
        XCTAssertEqual(h.q.enqueueCount, h.total)
        XCTAssertEqual(h.q.dequeueCount, h.total)
        XCTAssertEqual(h.q.droppedCount, 0, "`tryEnqueue` never counts a drop (#1237)")
    }

    /// Claim 5 (#1239) — the six ring pointers are `let`, so no index read carries a dynamic
    /// exclusivity check on the render thread. Each is assigned once in `init`; a `var` here
    /// is a `swift_beginAccess` per `self.head`/`self.tail` read in `dequeue()`.
    func testTheRingPointersAreLetSoReadsCarryNoExclusivityCheck() throws {
        let src = try text("Sources/Echoelmusic/Core/SPSCQueue.swift")
        for name in ["buffer", "head", "tail", "_droppedCount", "_enqueueCount", "_dequeueCount"] {
            XCTAssertTrue(src.contains("    private let \(name): UnsafeMutablePointer<"),
                          "`\(name)` is no longer a `let` — a `var` stored property reintroduces the dynamic exclusivity check on every render-thread read (#1239)")
            XCTAssertFalse(src.contains("    private var \(name): UnsafeMutablePointer<"),
                           "`\(name)` is declared `var` again (#1239)")
        }
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

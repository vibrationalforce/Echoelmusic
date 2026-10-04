// TheBroadcastHasNoDoorWithoutAnEngineTests.swift
// Echoel — modes census 2026-09-26 (Stream S1): streaming is absent, and the app must say so.
//
// WHAT THIS PINS. The founder asked about a Stream mode. Measured: nothing in this build can
// stream — `BroadcastPublisher.engineAvailable` is `BroadcastEngineFactory.make() != nil`, i.e.
// `#if canImport(RTMPHaishinKit)` since Broadcast B1 (2026-10-04; it read `canImport(HaishinKit)`
// before — the premise is unchanged, only the product name moved), HaishinKit is
// not a dependency (`Package.swift` `dependencies: []`), the RTMP/SRT transports are
// `.roadmap`, and `BroadcastView` has no construction site. A door onto a dead endpoint is an
// App Store 2.1 rejection and a promise the instrument cannot keep on stage.
//
// ⚠️ BOUND, NOT BANNED (#364). This guard does NOT forbid streaming. It binds the three facts
// together: WHILE the engine is absent, the stream transports stay `.roadmap` and the stream
// surface stays doorless. Link the engine (a founder decision — new dependency) and the
// binding releases; flip a transport to `.live` or door `BroadcastView` WITHOUT an engine and
// this goes red with the list of what has to move together.
//
// 1. PURE: without an engine, `.rtmp` and `.srt` report `.roadmap`. ⚠️ `.ndi` is deliberately
//    NOT bound here: HaishinKit carries RTMP and SRT, never NDI — NDI needs its own SDK (product
//    law: integrate, never rebuild), so binding it to THIS engine would send a future NDI slice
//    to the wrong dependency.
// 2. SOURCE: without an engine, no `BroadcastView(` construction site exists in `Sources/`
//    (comment-stripped: several files NAME the view in prose).
//
// When an engine IS linked, both claims throw `XCTSkip` rather than returning: a released
// binding must show up in the log as a skip, never read as a pass (#806).
//
// Grading (§0, no Swift toolchain in a web session): transcribed against this tree — both
// claims green today; flipping `.rtmp` to the `.live` arm or adding a construction site makes
// them red. A pin on existing behaviour, not a forward guard.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheBroadcastHasNoDoorWithoutAnEngineTests: XCTestCase {

    private static let streamTransports: [SignalTransport] = [.rtmp, .srt]   // HaishinKit's two; NDI is another engine

    // MARK: 1 — no engine, no live stream transport

    func testWithoutAnEngineTheStreamTransportsAreRoadmap() throws {
        guard !BroadcastPublisher().engineAvailable else {
            // PRECONDITION-SKIP: runtime engine state, not a text anchor — a linked streaming
            // engine releases this binding by founder decision (#1240 ratchet, class 2).
            throw XCTSkip("streaming engine linked — the binding releases (founder decision)")
        }
        for transport in Self.streamTransports {
            XCTAssertEqual(transport.status, .roadmap, """
                `\(transport)` reports `.live`, but this build has no streaming engine \
                (`BroadcastPublisher.engineAvailable` is false). A live stream transport with \
                nothing behind it offers a route that carries nothing. Link the engine first \
                (founder decision: new dependency), or keep the transport `.roadmap`.
                """)
        }
    }

    // MARK: 2 — no engine, no door

    func testWithoutAnEngineTheBroadcastSurfaceHasNoDoor() throws {
        guard !BroadcastPublisher().engineAvailable else {
            // PRECONDITION-SKIP: runtime engine state, not a text anchor — a linked streaming
            // engine releases this binding by founder decision (#1240 ratchet, class 2).
            throw XCTSkip("streaming engine linked — the binding releases (founder decision)")
        }
        let sites = try sourcesContaining("BroadcastView(")
        XCTAssertEqual(sites, [], """
            `BroadcastView(` is constructed in \(sites) while no streaming engine is linked. \
            The view says "engine not installed" honestly, but a door onto it is still a \
            dead endpoint (App Store 2.1). Move together: link the engine, flip `.rtmp`/`.srt` \
            to live, update `docs/dev/FEATURE_STATUS.md` and `ContentPipeline/CLAIMS.md`.
            """)
    }

    // MARK: helpers

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { dir.deleteLastPathComponent() }
        return dir
    }

    /// Relative paths under `Sources/` whose CODE (comments blanked) contains `needle`.
    private func sourcesContaining(_ needle: String) throws -> [String] {
        let root = repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate Sources — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var scanned = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative),
                                         encoding: .utf8) else { continue }
            scanned += 1
            if SourceText.codeOnly(text).contains(needle) { hits.append(relative) }
        }
        XCTAssertGreaterThan(scanned, 100, "the walker must actually see the sources (#454)")
        return hits.sorted()
    }
}

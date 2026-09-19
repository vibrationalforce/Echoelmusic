//
//  TheEventAddressesNameTheirProducerTests.swift
//  Echoelmusic — CISmoke (BLOCKING bundle)
//
//  WHY THIS EXISTS (#1377, Deep Function Check 2026-09-19).
//
//  The OSC section of `CLAUDE.md` is the integrator contract — it is where a spoke page, a
//  store line and a VJ's patch all get their address list. It carried:
//
//      /echoelmusic/bio/event/heartbeat | breath/inhale | breath/exhale | coherence
//                                          (discrete events, ADRESSEN MIT PRODUZENT)
//
//  Two lines below, the SAME file correctly states that `motion` and `eeg` have no producer.
//  `coherence` sat on the wrong side of that split, and `heartbeat` sat there without the
//  condition that decides whether a player ever sees it. Measured:
//
//    · `.coherenceShift` — three occurrences in `Sources/`: the enum case, the address mapping
//      in `OSCSender`, and one consumer `switch`. ZERO constructions. Identical to `.eegBurst`,
//      which the same file already lists as dead.
//    · `.heartbeat` — exactly ONE production producer, `PolarH10BioPublisher` (per RR from the
//      BLE strap). `BioEventGraph`'s own detector CANNOT fire, because `BioEventPublisher`
//      calls `graph.process(cleanedHeart: 0, …)` — the raw cardiac waveform is not on the bus,
//      and that file's own comment says so. On the FLAGSHIP source (camera rPPG) this address
//      therefore never arrives.
//
//  Why no guard caught it: the only test that names `coherenceShift` at all
//  (`Tests/EchoelmusicTests/OSCSenderTests.swift`) asserts the address STRING, not that anything
//  can ever send it — and it lives in the non-blocking suite, which #396 makes unreadable as a
//  signal anyway. An address table is a promise about PRODUCERS; pinning the string is pinning
//  the spelling of the promise.
//
//  ⚠️ WHAT THIS GUARD DOES NOT DO (#364):
//  · It does NOT forbid giving any of these a producer. Wiring `.coherenceShift`, `.eegBurst`,
//    `.motionPeak`, or a camera-side heartbeat is exactly the work this documents; the guard
//    then goes red and NAMES the prose that must move in the same commit (#456).
//  · It does NOT text-scan `CLAUDE.md` for the retracted wording — that file quotes retractions
//    on purpose and a negative scan would strike its own correction (#491).
//  · It does NOT require `OSCSender` to keep mapping the dead kinds. Deleting an address is a
//    contract change, and claim 4 makes that conscious rather than forbidden.
//
//  GRADED BY TRANSCRIPTION (`Tests/CISmoke/CLAUDE.md` §0) — no Swift toolchain in a web session.
//

import XCTest

final class TheEventAddressesNameTheirProducerTests: XCTestCase {

    private struct AnchorMissing: Error { let reason: String }

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // CISmoke
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // repo root
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// Every `.swift` under `Sources/`, comments blanked. An EMPTY walk throws (#454): a guard
    /// whose corpus silently became nothing would pass every absence claim below vacuously,
    /// which is the exact failure mode this whole file is about.
    private func allProductionCode() throws -> [(name: String, code: String)] {
        let sources = repoRoot.appendingPathComponent("Sources")
        guard let walk = FileManager.default.enumerator(at: sources,
                                                        includingPropertiesForKeys: nil) else {
            throw AnchorMissing(reason: "Sources/ is not enumerable — re-anchor, do not skip.")
        }
        let files = walk.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        guard files.count > 50 else {
            throw AnchorMissing(reason: """
                Only \(files.count) Swift files found under Sources/. The tree moved or the walk \
                broke; an absence claim over an empty corpus is not a measurement.
                """)
        }
        return try files.map { ($0.lastPathComponent,
                                SourceText.codeOnly(try String(contentsOf: $0, encoding: .utf8))) }
    }

    // MARK: - Claim 1 — the two dead event kinds are constructed nowhere

    /// A `BioEvent` is only ever produced by naming its `kind:`. If a construction appears, the
    /// address becomes real — and the CLAUDE.md line that calls it dead is then the false one.
    func testTheCoherenceAndEEGEventsHaveNoProducer() throws {
        let corpus = try allProductionCode()

        for kind in ["coherenceShift", "eegBurst"] {
            let producers = corpus.filter { $0.code.contains("kind: .\(kind)") }
            XCTAssertTrue(producers.isEmpty, """
                `.\(kind)` is now CONSTRUCTED in: \(producers.map(\.name).joined(separator: ", ")).
                That is good work, not a defect — but `/echoelmusic/bio/event/\
                \(kind == "coherenceShift" ? "coherence" : "eeg")` is documented as an address \
                that can never be sent, and three homes move in the SAME commit (#456):
                  1. `CLAUDE.md`, the OSC block — the entry says "Adresse existiert, wird nie \
                gesendet"; it has to become a producing address with its gate named.
                  2. `Sync/OSCSender.swift` — check the kind actually reaches `eventMessages`.
                  3. `docs/dev/VJ_BRIDGE.md` and any spoke page that lists what an integrator \
                may subscribe to (`docs/resolume-osc.html`, `docs/touchdesigner-osc.html`).
                """)
        }
    }

    // MARK: - Claim 2 — the heartbeat event has exactly one producer, and it is the strap

    func testTheHeartbeatEventIsProducedOnlyByTheStrap() throws {
        let corpus = try allProductionCode()
        let producers = corpus.filter { $0.code.contains("kind: .heartbeat") }.map(\.name).sorted()

        XCTAssertEqual(producers, ["BioEventGraph.swift", "PolarH10BioPublisher.swift"], """
            The producers of `.heartbeat` changed: \(producers).
            Expected exactly two sites, and they are NOT equal in reach:
              · `PolarH10BioPublisher` — the live one, per RR interval from the BLE strap.
              · `BioEventGraph` — structurally unreachable, see claim 3.
            If a THIRD appeared (a camera-side beat detector is the obvious one), that is the \
            work this guard exists to notice: `/echoelmusic/bio/event/heartbeat` stops being \
            strap-only, and the CLAUDE.md OSC entry saying so must be corrected with it.
            """)
    }

    // MARK: - Claim 3 — the reason the graph's detector cannot fire

    /// This is the half nobody wrote down. The detector EXISTS and is correct; it is fed a
    /// constant, so it can never cross a threshold.
    func testTheEventGraphIsFedAConstantHeartSignal() throws {
        let publisher = try source("Sources/Echoelmusic/Bio/BioEventPublisher.swift")
        let code = SourceText.codeOnly(publisher)

        XCTAssertTrue(code.contains("cleanedHeart: 0"), """
            `BioEventPublisher` no longer passes `cleanedHeart: 0` to `graph.process`.
            If a real cardiac waveform now reaches the graph, its heartbeat detector can fire — \
            which means `/echoelmusic/bio/event/heartbeat` is no longer strap-only and the \
            CLAUDE.md OSC entry must be re-measured. Also re-read `BioEventPublisher`'s own \
            comment about the first beat after a reset reporting `aux = 0`: it is written as \
            "unreachable only because `cleanedHeart` is passed as 0 below", and that escape \
            hatch closes at the same moment.
            """)

        let graph = try source("Sources/Echoelmusic/Bio/BioEventGraph.swift")
        XCTAssertTrue(SourceText.codeOnly(graph).contains("kind: .heartbeat"), """
            `BioEventGraph` no longer constructs a `.heartbeat` event. It is one of the three \
            PROTECTED Rausch types — changing it needs explicit founder approval, and claim 2 \
            above expects it in the producer list.
            """)
    }

    // MARK: - Claim 4 — the addresses still exist, so a wiring cycle has somewhere to land

    /// Counterweight. Without this, the cheapest way to make claims 1–3 "true forever" would be
    /// to delete the mappings — turning a documented, wire-able gap into a silent absence.
    func testTheMappingsForTheDeadKindsSurvive() throws {
        let sender = SourceText.codeOnly(try source("Sources/Echoelmusic/Sync/OSCSender.swift"))

        for (kind, address) in [("coherenceShift", "/echoelmusic/bio/event/coherence"),
                                ("eegBurst", "/echoelmusic/bio/event/eeg"),
                                ("motionPeak", "/echoelmusic/bio/event/motion"),
                                ("heartbeat", "/echoelmusic/bio/event/heartbeat")] {
            XCTAssertTrue(sender.contains(address), """
                `OSCSender` no longer maps `\(address)`.
                Removing an address is a CONTRACT change with every integrator, not a cleanup — \
                the published spoke pages (`docs/resolume-osc.html`, \
                `docs/touchdesigner-osc.html`) and `docs/dev/VJ_BRIDGE.md` list what may be \
                subscribed to. If `.\(kind)` is genuinely being retired rather than wired, say \
                so in the CLAUDE.md OSC block and on those pages in the same commit.
                """)
        }
    }
}

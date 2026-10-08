// ARemoteLookCannotBeOneTheSliderHidesTests.swift
// Echoel — found by the review of GMMW VV-4 (2026-10-08): the OSC control input
// (`/echoelmusic/ctrl/visualStyle`, #1255) accepted any look 0…9 and the app wrote it into the
// look key unchecked. Three of those indices are retired looks with no `FlashGuard` budget row,
// and 8 Scope derives to 3.90 Hz — over the 3 Hz epilepsy law (`FlashGuard.maxFlashHz`) — while
// `blendPhaseDamping` cannot damp a look it has no row for. The launch snap removed such an
// index only at the NEXT launch. `LookBlendMap.remoteLook` now refuses it at the door, by the
// launch snap's own rule: the look must be one the player's slider offers.
//
// ⚠️ THE LIMITS FIRST. Claims 1–2 are END-TO-END BEHAVIOUR on the pure rule and the shipped
// parser. Claim 3 is a SOURCE-TEXT SCAN that the dispatch asks the rule before it writes (the
// closure lives inside `EchoelmusicApp`, which no test can drive). The input is opt-in and
// allowlisted, so reaching this needed a configured controller; whether a refused cue reads
// clearly to a VJ is a DEVICE PROBE, open.
//
// ⚠️ HONEST GRADING (#433/#486): this file names `LookBlendMap.remoteLook`, which this commit
// adds — it does not compile against the parent, so no assertion has a verdict there.
// Transcribed: on the parent the dispatch writes any 0…9 (claim 1 and claim 3 red for their
// named reason — ONE finding, the missing door). Claim 2 is the COUNTERWEIGHT, green on both:
// the wire still delivers 8, so the door is what refuses it, and an offered look still lands.
// Mutants driven in the transcription: the rule returning `requested` for any library look, or
// for any 0…9, or the dispatch writing `look` instead of the checked value — each red here.
//
// Guard of `Sources/Echoelmusic/Studio/LookBlendMap.swift` and the `.visualStyle` case in
// `Sources/Echoelmusic/EchoelmusicApp.swift`.

import XCTest
@testable import Echoelmusic

private struct RemoteLookAnchorMissing: Error, CustomStringConvertible {
    let reason: String
    var description: String { reason }
}

final class ARemoteLookCannotBeOneTheSliderHidesTests: XCTestCase {

    /// Slider strings a player can hold: the default, every library look, one with retired
    /// indices in it (the parser drops them), and garbage (the parser falls back).
    private let sliders = [
        LookBlendMap.string(from: LookBlendMap.defaultSequence),
        LookBlendMap.string(from: LookBlendMap.library.map(\.index)),
        "0,2,3,5,7,8,9,6,1,4",
        "not a sequence",
    ]

    // MARK: - 1. No remote look can be one without a legal flash budget

    func testNoRemoteLookCanOutrunTheFlashLaw() throws {
        var accepted = 0
        for slider in sliders {
            for requested in -1...10 {
                guard let look = LookBlendMap.remoteLook(requested, sliderLooksRaw: slider) else { continue }
                accepted += 1
                let budget = try XCTUnwrap(FlashGuard.fieldBudget(forStyle: look), """
                    a remote controller set look \(look) (slider "\(slider)"), which has no flash budget \
                    row — nothing can damp it
                    """)
                XCTAssertLessThanOrEqual(budget.effectiveHz, FlashGuard.maxFlashHz,
                                         "look \(look) flashes at \(budget.effectiveHz) Hz")
            }
        }
        XCTAssertGreaterThan(accepted, 0, "precondition: some remote look is accepted at all")
        for slider in sliders {
            XCTAssertNil(LookBlendMap.remoteLook(8, sliderLooksRaw: slider), """
                Scope (8) derives to 3.90 Hz — no slider string may let a remote cue set it
                """)
        }
    }

    // MARK: - 2. COUNTERWEIGHT — the wire still delivers it, and an offered look still lands

    func testTheDoorRefusesWhatTheWireDelivers() {
        let address = OSCControlCommand.prefix + "visualStyle"
        XCTAssertEqual(OSCControlCommand.parse(.init(address: address, arguments: [.int(8)])), .visualStyle(8), """
            premise: the parser accepts 8 — the refusal is the dispatch's, and without that this \
            file would prove nothing about it
            """)
        let standard = LookBlendMap.string(from: LookBlendMap.defaultSequence)
        for look in LookBlendMap.defaultSequence {
            XCTAssertEqual(LookBlendMap.remoteLook(look, sliderLooksRaw: standard), look,
                           "a look the slider offers must still be settable remotely")
        }
        XCTAssertNil(LookBlendMap.remoteLook(2, sliderLooksRaw: standard), """
            Dish is a library look, but this slider does not offer it — the launch snap would put \
            it back, so the door must not set it either (one rule)
            """)
        XCTAssertEqual(LookBlendMap.remoteLook(2, sliderLooksRaw: "2,3"), 2)
    }

    // MARK: - 3. SOURCE-TEXT SCAN — the dispatch asks the rule before it writes

    func testTheDispatchAsksTheRuleBeforeItWrites() throws {
        let code = try source("Sources/Echoelmusic/EchoelmusicApp.swift")
        let start = try XCTUnwrap(code.range(of: "case .visualStyle(let look):"), "the dispatch's look case")
        let end = try XCTUnwrap(code.range(of: "case .blackout(", range: start.upperBound..<code.endIndex),
                                "the case after it")
        let branch = code[start.upperBound..<end.lowerBound]
        let ask = try XCTUnwrap(branch.range(of: "LookBlendMap.remoteLook(look"), "the look case asks the rule")
        let write = try XCTUnwrap(branch.range(of: "StudioDefaultKeys.visualStyle.key"), "the look case writes the key")
        XCTAssertLessThan(ask.lowerBound, write.lowerBound, "the rule is asked BEFORE the key is written")
        XCTAssertFalse(branch.contains("d.set(look,"), "the unchecked value must never be the one written")
        XCTAssertTrue(branch.contains("LookBlendMap.storageKey"), "the rule reads the player's own slider")
    }

    // MARK: - Source access

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw RemoteLookAnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor (#454)")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}

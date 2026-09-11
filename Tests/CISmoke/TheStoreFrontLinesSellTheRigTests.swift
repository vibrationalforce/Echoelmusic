// TheStoreFrontLinesSellTheRigTests.swift
// Echoel — #1256 (ultraplan row 10 = Marketing action 3 + audit `docs-claims-4`; copy
// decided by Council, `deliver` stays the founder's hand: no workflow uploads metadata —
// `testflight.yml` uses fastlane for `upload_to_testflight` ONLY, measured).
//
// WHAT MOVED. The two keyword fields (customer words: `synthesizer`, `ambient`, `techno`,
// `heart`, `rate`, `breath`, `light`, `VJ` in place of `coherence`/`rPPG`/`immersive`, which
// nobody types into a store search), the promotional text, the three VISIBLE lines of both
// descriptions (the rig sentence now sits above the fold), `colour` → `color` (the store's
// language is American English), the wellness word "Meditativ" out of the de-DE release
// notes (CLAIMS §2 — the in-app shelf keeps its label; the STORE does not sell a mood), and
// ONE new CONNECT bullet for the external display (CLAIMS ✅ #206).
//
// NOT MOVED, and why: `en-GB` (a new ASC localisation is the founder's to create, and the
// critic struck three of its proposed terms — `sequencer`, `MPE`, `visualizer`), the title and
// subtitle (ASC, review-costing), and the full description rewrite (its coherence-trend line
// waits on the founder's ear, `CoherenceTrend` NEEDS-FOUNDER-VERIFY).
//
// SOURCE-TEXT SCAN throughout (`fastlane/metadata/**` is prose, read raw — no stripper).
// ⚠️ HONEST GRADING — TRANSCRIBED (§0) against the parent (`8d31354`) and this tree: claims
// 1, 2, 4, 5, 6 RED on the parent for their named reason (four `colour`, one `Meditativ`, no rig
// sentence above the fold, `coherence`/`rPPG` in the field, no external-display bullet); claim 3
// (limits, no banned term, no subtitle duplicate) GREEN on both; claim 7 (the sACN unicast
// sentence, the MPE-input disclaimer, the medical sentence — what the other store guards already
// own) GREEN on both, counterweights only; claim 8 (the 4000-character ceiling) GREEN on both
// and PREVENTIVE — booked as catching nothing on either tree. Measured: the parent sat at
// 3977 (en-US) / 3998 (de-DE), TWO characters under the ceiling in German, and nothing had
// ever counted it. The fold plus the new bullet took this slice's first draft to 4266 / 4324 —
// App Store Connect refuses both — and the trims that bring it back to 3979 / 3996 are in the
// same commit. The claim exists so the NEXT bullet is measured before `deliver` measures it;
// the floor (3000) keeps a later "trim" from emptying the surface.

import Foundation
import XCTest

final class TheStoreFrontLinesSellTheRigTests: XCTestCase {

    private static let locales = ["en-US", "de-DE"]
    private static let leaves = ["description.txt", "promotional_text.txt", "subtitle.txt",
                                 "keywords.txt", "release_notes.txt"]

    /// Claim 1 — the store's language is American English: no `colour` anywhere in en-US.
    func testTheEnglishCopyIsAmerican() throws {
        for leaf in Self.leaves {
            let t = try text("fastlane/metadata/en-US/\(leaf)").lowercased()
            XCTAssertFalse(t.contains("colour"), "en-US/\(leaf) spells colour the British way (#1256)")
        }
    }

    /// Claim 2 — the store sells no mood: the wellness word is out of the German copy.
    func testTheGermanCopySellsNoShelfAsAMood() throws {
        for leaf in Self.leaves {
            let t = try text("fastlane/metadata/de-DE/\(leaf)")
            XCTAssertFalse(t.contains("Meditativ"), "de-DE/\(leaf) sells a meditative shelf — CLAIMS §2 (#1256)")
            XCTAssertFalse(t.lowercased().contains("meditation"), "de-DE/\(leaf) names meditation (#1256)")
        }
    }

    /// Claim 3 — the keyword fields obey the platform: ≤100 bytes, comma-separated, no spaces,
    /// no term the critic struck, no term the subtitle already indexes.
    func testTheKeywordFieldsObeyThePlatform() throws {
        for locale in Self.locales {
            let raw = try text("fastlane/metadata/\(locale)/keywords.txt").trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertLessThanOrEqual(raw.utf8.count, 100, "\(locale) keywords exceed Apple's 100 bytes (#1256)")
            XCTAssertFalse(raw.contains(" "), "\(locale) keywords carry a space — Apple counts every byte (#1256)")
            let terms = raw.split(separator: ",").map { $0.lowercased() }
            XCTAssertEqual(Set(terms).count, terms.count, "\(locale) repeats a keyword (#1256)")
            for banned in ["mpe", "sequencer", "visualizer", "meditation", "wellness"] {
                XCTAssertFalse(terms.contains(banned), "\(locale) keywords carry `\(banned)` — struck by the critic / CLAIMS (#1256)")
            }
            let subtitleWords = try text("fastlane/metadata/\(locale)/subtitle.txt").lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            for term in terms where subtitleWords.contains(term) {
                XCTFail("\(locale) keyword `\(term)` is already indexed by the subtitle — a wasted byte (#1256)")
            }
        }
    }

    /// Claim 4 — the three lines above the fold sell the body AND the rig: the camera lock, the
    /// playable picture, and the outputs with the MPE direction word.
    func testTheFirstThreeLinesSellTheRig() throws {
        for (locale, needles) in [("en-US", ["your body plays it", "finger on the camera", "touch the visual", "osc, midi and mpe out", "art-net and sacn"]),
                                  ("de-DE", ["dein körper spielt es", "finger auf die kamera", "berühre das visual", "osc, midi und mpe out", "art-net- und sacn"])] {
            let lines = try text("fastlane/metadata/\(locale)/description.txt").split(separator: "\n", omittingEmptySubsequences: false)
            let fold = lines.prefix(3).joined(separator: "\n").lowercased()
            for needle in needles {
                XCTAssertTrue(fold.contains(needle), "\(locale): `\(needle)` is no longer above the fold (#1256)")
            }
        }
    }

    /// Claim 5 — the promotional text fits Apple's 170 characters and names the rig protocols.
    func testThePromotionalTextFitsAndNamesTheRig() throws {
        for locale in Self.locales {
            let promo = try text("fastlane/metadata/\(locale)/promotional_text.txt").trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertLessThanOrEqual(promo.count, 170, "\(locale) promotional text exceeds 170 characters (#1256)")
            for proto in ["OSC", "MIDI", "Art-Net", "sACN", "ADM-OSC"] {
                XCTAssertTrue(promo.contains(proto), "\(locale) promo no longer names \(proto) (#1256)")
            }
            XCTAssertFalse(promo.lowercased().contains("colour"))
        }
    }

    /// Claim 6 — the external display is sold, with both of its transports (CLAIMS ✅ #206).
    func testTheExternalDisplayIsSoldWithItsTransports() throws {
        let en = try text("fastlane/metadata/en-US/description.txt")
        let de = try text("fastlane/metadata/de-DE/description.txt")
        XCTAssertTrue(en.contains("External display: the visual plays on a connected screen or projector (USB-C/HDMI or AirPlay)"),
                      "the external-display bullet (CLAIMS ✅ #206) is gone or lost its transports (#1256)")
        XCTAssertTrue(de.contains("Externer Bildschirm: das Visual bespielt Monitor oder Beamer (USB-C/HDMI oder AirPlay)"),
                      "die Externer-Bildschirm-Zeile fehlt oder hat ihre Transporte verloren (#1256)")
    }

    /// Claim 7 — counterweights: what the other store guards own is still here — the sACN
    /// unicast limit, the MPE-input disclaimer, the medical sentence. GREEN on both trees.
    func testTheRestOfTheCopyIsUntouched() throws {
        let en = try text("fastlane/metadata/en-US/description.txt")
        let de = try text("fastlane/metadata/de-DE/description.txt")
        XCTAssertTrue(en.contains("multicast is not available on iOS"))
        XCTAssertTrue(de.contains("kein Multicast unter iOS"))
        XCTAssertTrue(en.contains("the input side stays plain MIDI notes"), "the MPE-input disclaimer must stay (#1256)")
        XCTAssertTrue(en.contains("This is not a medical device."))
        XCTAssertTrue(de.contains("Dies ist kein medizinisches Gerät."))
    }

    /// Claim 8 — both descriptions fit Apple's 4000-character ceiling and keep a floor.
    ///
    /// ⚠️ PREVENTIVE (#464): GREEN on the parent (3977 / 3998) and on this tree (3979 / 3996).
    /// What it would have caught is this slice's own first draft — 4266 / 4324 after the fold
    /// and the external-display bullet — which App Store Connect refuses and which nothing in
    /// the repo measured; the German copy had two characters of headroom and no one knew.
    /// The count is CHARACTERS, as Apple counts (`String.count`), not bytes — the German copy
    /// carries umlauts and every `—` is three bytes.
    func testTheDescriptionsFitAppleCeiling() throws {
        for locale in Self.locales {
            let n = try text("fastlane/metadata/\(locale)/description.txt").count
            XCTAssertLessThanOrEqual(n, 4000, "\(locale) description is \(n) characters — App Store Connect refuses it (#1256)")
            XCTAssertGreaterThan(n, 3000, "\(locale) description shrank to \(n) characters — a trim emptied the surface (#1256)")
        }
    }

    private func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

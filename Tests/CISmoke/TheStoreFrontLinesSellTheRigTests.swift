// TheStoreFrontLinesSellTheRigTests.swift
// Echoel — #1256 (ultraplan row 10 = Marketing action 3 + audit `docs-claims-4`; copy
// decided by Council, `deliver` stays the founder's hand: no workflow uploads metadata —
// `testflight.yml` uses fastlane for `upload_to_testflight` ONLY, measured).
//
// ⭐ 2026-10-29 (GM28, W6 STORE): `fastlane/metadata/{en-US,de-DE}` DESCRIBES ECHOEL STUDIO 11.0.0
// NOW. Builds 10004–10017 on the same App Store record are the Studio, and the text that stood
// here — camera pulse, the playable picture, OSC/MIDI/MPE out, Art-Net and sACN, the external
// display — described the earlier bio instrument, which the Studio build does not contain. The
// file name is kept so that `ContentPipeline/CLAIMS.md`, `decisions.csv` and the ledger still
// resolve; what "the rig" means has changed: the rig is now the musician's — Audio Unit plugins,
// MIDI keyboards, a Bluetooth heart-rate strap — and claims 4 to 7 pin THAT text. Claims 1, 2, 3
// and 8 are platform rules and were kept word for word (claim 3 lost one banned keyword, see its
// doc). Rewritten rather than struck: 4 (the fold sells the workstation, not the camera), 5 (the
// promo names the Studio's instruments and exports, not the light protocols), 6 (the export bullet
// carries its measured numbers — the external-display bullet it replaced names a feature the
// Studio does not have), 7 (the honesty sentences: no account, takes stay on the device, earlier
// songs are not imported — the multicast and MPE-input sentences it replaced describe outputs the
// Studio does not have). Nothing here is device-verified; the text is measured against
// `EchoelStudio/` code (`ContentPipeline/CLAIMS.md`, Nachtrag 5), never against a device.
//
// ⚠️ HONEST GRADING FOR 2026-10-29 (§0, transcribed in Python against BOTH texts — the earlier
// app's at `77dc08f` and the Studio's at `4fbe256`): claims 4, 5, 6, 7 are RED on the earlier
// text for their named reason (no "music workstation" above the fold, no "synth engines" in the
// promo, no 24-bit/48 kHz export bullet, no "Songs from earlier versions" line) and GREEN on the
// Studio text; claims 1, 2, 8 GREEN on both; claim 3 GREEN on both after the one lifted ban.
//
// WHAT MOVED IN #1256 (history, kept because the lessons are general). The two keyword fields
// (customer words in place of `coherence`/`rPPG`/`immersive`, which nobody types into a store
// search), the promotional text, the three VISIBLE lines of both descriptions, `colour` → `color`
// (the store's language is American English), the wellness word "Meditativ" out of the de-DE
// release notes (CLAIMS §2 — the in-app shelf keeps its label; the STORE does not sell a mood),
// and ONE new CONNECT bullet for the external display (CLAIMS ✅ #206).
//
// SOURCE-TEXT SCAN throughout (`fastlane/metadata/**` is prose, read raw — no stripper).
// ⚠️ HONEST GRADING FOR #1256 — TRANSCRIBED (§0) against the parent (`8d31354`) and that tree:
// claims 1, 2, 4, 5, 6 RED on the parent for their named reason; claim 3 GREEN on both; claim 7
// GREEN on both, counterweights only; claim 8 (the 4000-character ceiling) GREEN on both and
// PREVENTIVE. Measured then: the parent sat at 3977 (en-US) / 3998 (de-DE), TWO characters under
// the ceiling in German, and nothing had ever counted it. The claim exists so the NEXT bullet is
// measured before `deliver` measures it; the floor (3000) keeps a later "trim" from emptying the
// surface. 2026-10-29: the Studio text measures 3972 / 3967 (`python3 -c "print(len(open(p,
// encoding='utf-8').read()))"`).

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
    ///
    /// ⛔ 2026-10-29: `sequencer` LEFT THE BANNED LIST. The critic struck it for the earlier app,
    /// which had no sequencer a buyer could reach; Echoel Studio ships a piano roll, a drum step
    /// grid and a session grid, so the word is honest and a ban on it would forbid correct copy
    /// (#364). `mpe` stays (no MPE in the Studio build, in either direction), `visualizer` stays
    /// (the Studio text sells no visual), `meditation` and `wellness` stay (CLAIMS §2, permanent).
    func testTheKeywordFieldsObeyThePlatform() throws {
        for locale in Self.locales {
            let raw = try text("fastlane/metadata/\(locale)/keywords.txt").trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertLessThanOrEqual(raw.utf8.count, 100, "\(locale) keywords exceed Apple's 100 bytes (#1256)")
            XCTAssertFalse(raw.contains(" "), "\(locale) keywords carry a space — Apple counts every byte (#1256)")
            let terms = raw.split(separator: ",").map { $0.lowercased() }
            XCTAssertEqual(Set(terms).count, terms.count, "\(locale) repeats a keyword (#1256)")
            for banned in ["mpe", "visualizer", "meditation", "wellness"] {
                XCTAssertFalse(terms.contains(banned), "\(locale) keywords carry `\(banned)` — struck by the critic / CLAIMS (#1256)")
            }
            let subtitleWords = try text("fastlane/metadata/\(locale)/subtitle.txt").lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
            for term in terms where subtitleWords.contains(term) {
                XCTFail("\(locale) keyword `\(term)` is already indexed by the subtitle — a wasted byte (#1256)")
            }
        }
    }

    /// Claim 4 — the lines above the fold sell the workstation: what the app IS, the devices it
    /// runs on, two of its surfaces, and that it needs no account. The fold is the first three
    /// lines of the description, which is what App Store Connect shows before "more".
    ///
    /// ⛔ 2026-10-29: this claim pinned "your body plays it", "finger on the camera", "touch the
    /// visual", "osc, midi and mpe out" and "art-net and sacn" — the earlier app's opening. The
    /// Studio build (10004–10017) has none of those, so a fold that still sold them was the 2.3
    /// mismatch GM28 names. The needles below are the Studio's opening sentence, measured against
    /// `EchoelStudio/` (CLAIMS Nachtrag 5); the camera, the picture and the light protocols are
    /// being built by other waves and return here only with the build that ships them.
    func testTheFirstThreeLinesSellTheRig() throws {
        for (locale, needles) in [("en-US", ["music workstation", "iphone and ipad", "piano roll", "session grid", "no account"]),
                                  ("de-DE", ["musik-workstation", "iphone und ipad", "pianorolle", "session-raster", "kein konto"])] {
            let lines = try text("fastlane/metadata/\(locale)/description.txt").split(separator: "\n", omittingEmptySubsequences: false)
            let fold = lines.prefix(3).joined(separator: "\n").lowercased()
            for needle in needles {
                XCTAssertTrue(fold.contains(needle), """
                    \(locale): `\(needle)` is no longer above the fold (#1256, GM28). The first three \
                    lines are what a buyer reads before tapping "more"; they must say what Echoel \
                    Studio IS. If the opening was rewritten on purpose, move this needle to the \
                    sentence that now carries the fact — do not drop the fact.
                    """)
            }
        }
    }

    /// Claim 5 — the promotional text fits Apple's 170 characters and names the Studio's
    /// instruments and exports: the synth engines, the drum kit, the sampler, Audio Unit plugins,
    /// WAV and MIDI.
    ///
    /// ⛔ 2026-10-29: this claim required "OSC", "MIDI", "Art-Net", "sACN" and "ADM-OSC" — the
    /// earlier app's rig protocols, none of which the Studio build sends. The promo now names
    /// what 10017 ships (CLAIMS Nachtrag 5). Case-insensitive on purpose: the German promo
    /// hyphenates ("Synth-Engines", "Audio-Unit"), and a hyphen is not a claim.
    func testThePromotionalTextFitsAndNamesTheRig() throws {
        for (locale, needles) in [("en-US", ["synth engines", "drum kit", "sampler", "audio unit", "wav", "midi"]),
                                  ("de-DE", ["synth-engines", "drumkit", "sampler", "audio-unit", "wav", "midi"])] {
            let promo = try text("fastlane/metadata/\(locale)/promotional_text.txt").trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertLessThanOrEqual(promo.count, 170, "\(locale) promotional text exceeds 170 characters (#1256)")
            let flat = promo.lowercased()
            for needle in needles {
                XCTAssertTrue(flat.contains(needle), """
                    \(locale) promo no longer names `\(needle)` (#1256, GM28). The promotional text \
                    is the one field App Store Connect lets you change without a new build, so it \
                    is where a pillar quietly falls out. Name every pillar the Studio build ships, \
                    or retire the pillar from the build first.
                    """)
            }
            XCTAssertFalse(flat.contains("colour"))
        }
    }

    /// Claim 6 — the export bullet carries its measured numbers in both locales: 24-bit, 48 kHz,
    /// loudness in LUFS and true peak reported (`OfflineRender`, `EchoelDSP` BS.1770 loudness and
    /// true-peak meters — CLAIMS "Aufnahme, Mix, Export").
    ///
    /// ⛔ 2026-10-29: this claim pinned the external-display bullet ("USB-C/HDMI or AirPlay",
    /// CLAIMS ✅ #206) — a feature of the earlier app (`ExternalDisplayScene`) that the Studio
    /// build does not have, so the bullet left the text and the claim with it. The export bullet
    /// is pinned instead because it is the Studio sentence most likely to drift silently: a change
    /// to the render's bit depth or sample rate is a one-line code edit, and the store text has
    /// no compiler.
    func testTheExportBulletCarriesItsMeasuredNumbers() throws {
        let en = try text("fastlane/metadata/en-US/description.txt")
        let de = try text("fastlane/metadata/de-DE/description.txt")
        for needle in ["24-bit, 48 kHz stereo WAV", "loudness (LUFS)", "true peak"] {
            XCTAssertTrue(en.contains(needle), """
                en-US description lost `\(needle)` from the export bullet (GM28). The numbers are \
                measured facts about `OfflineRender`; if the render changed, change the sentence \
                AND `ContentPipeline/CLAIMS.md` in the same commit — do not let the bullet go vague.
                """)
        }
        for needle in ["24 Bit, 48 kHz", "Lautheit (LUFS)", "True Peak"] {
            XCTAssertTrue(de.contains(needle), """
                de-DE description lost `\(needle)` from the export bullet (GM28). Both locales \
                describe ONE render; a number that moves in one locale only is the #757 defect.
                """)
        }
    }

    /// Claim 7 — the honesty sentences stay, in both locales: the app needs no account, recorded
    /// takes stay on the device, and the release notes say that songs from earlier versions are
    /// not imported (F17 — the App Group is not requested, so the import finds nothing).
    ///
    /// ⛔ 2026-10-29: this claim held the sACN unicast sentence, the MPE-input disclaimer and the
    /// medical sentence — three qualifiers of outputs and sources the Studio build does not have,
    /// so they left with their subjects. What replaces them is the same KIND of sentence: the
    /// qualifier that keeps a true claim honest. The no-account line is the About screen's own
    /// sentence (`EchoelStudio/App/Views/AboutView.swift`); "takes stay on the device" is CLAIMS
    /// §11 Nachtrag 2; the import line is `EchoelStudio/RELEASE` ("group.com.echoelmusic … still
    /// not requested") read by a buyer who owns the earlier app. When F17 ships and the import
    /// works on a device, flip the release-notes needle to the new sentence — never delete it.
    func testTheRestOfTheCopyIsUntouched() throws {
        let en = try text("fastlane/metadata/en-US/description.txt")
        let de = try text("fastlane/metadata/de-DE/description.txt")
        XCTAssertTrue(en.contains("No account, no ads, no tracking"), "the en-US no-account sentence must stay (GM28)")
        XCTAssertTrue(de.contains("Kein Konto, keine Werbung, kein Tracking"), "the de-DE no-account sentence must stay (GM28)")
        XCTAssertTrue(en.contains("Takes stay on the device."), "the en-US recording bullet must keep its privacy half (CLAIMS §11)")
        XCTAssertTrue(de.contains("Takes bleiben auf dem Gerät."), "the de-DE recording bullet must keep its privacy half (CLAIMS §11)")
        let notesEN = try text("fastlane/metadata/en-US/release_notes.txt")
        let notesDE = try text("fastlane/metadata/de-DE/release_notes.txt")
        XCTAssertTrue(notesEN.contains("Songs from earlier versions of Echoel are not imported by this version."),
                      "the en-US release notes no longer tell an earlier-app user that their songs are not imported (F17)")
        XCTAssertTrue(notesDE.contains("Songs früherer Echoel-Versionen werden von dieser Version nicht importiert."),
                      "the de-DE release notes no longer tell an earlier-app user that their songs are not imported (F17)")
    }

    /// Claim 8 — both descriptions fit Apple's 4000-character ceiling and keep a floor.
    ///
    /// ⚠️ PREVENTIVE (#464): GREEN on the parent (3977 / 3998) and on this tree (3979 / 3996).
    /// What it would have caught is this slice's own first draft — 4266 / 4324 after the fold
    /// and the external-display bullet — which App Store Connect refuses and which nothing in
    /// the repo measured; the German copy had two characters of headroom and no one knew.
    /// The count is CHARACTERS, as Apple counts (`String.count`), not bytes — the German copy
    /// carries umlauts and every `—` is three bytes. 2026-10-29: the Studio text's first draft
    /// measured 4092 / 4600 and was trimmed to 3972 / 3967 before it was committed — the claim
    /// did its job once more, in Python, before CI could.
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

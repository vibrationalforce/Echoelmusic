import XCTest
@testable import Echoelmusic

/// #999 — the app's most distinctive interaction stops being denied in public.
///
/// WHY IT EXISTS. This was not silence, it was an ACTIVE denial. The FAQ item titled "What touch
/// instruments are available?" answered that in-app you only shape the patch, and closed with
/// "Dedicated touch instruments … are on the roadmap, not in the app today" — while
/// `TouchInstrumentView` is mounted in `FloatingVisualWindow`'s visual overlay, at every window
/// size, and that window opens on launch. The tools list repeated the Planned tag. And there was
/// ZERO mention of touch, fingers, berühren or tippen anywhere in `fastlane/metadata` or under
/// `docs/` — so a musician evaluating the listing had no way to learn the instrument has hands.
///
/// ⚠️ THE FOUR PADS ARE STILL ROADMAP and must stay marked so. Chord pad, melody XY pad,
/// multi-octave keyboard and strum pad do not exist; what ships is ONE surface — the picture
/// itself, quantized to the take's key and scale. Claim 3 keeps that line from being erased in
/// the enthusiasm of finally being allowed to mention hands.
///
/// ⚠️ WHY NOT IN `TheStoreTextClaimsOnlyWhatShipsTests` (#416). That file asks one question — is
/// anything sold that does not ship. This asks the opposite one — is something that ships absent
/// from the copy — and it also reaches `docs/` and `Sources/`, which that file does not read.
/// Two questions, two homes; the store needle here was a PRESENCE check and could not collide
/// with a ban there.
///
/// ⛔ 2026-10-29 (GM28, W6 STORE): CLAIM 2 FLIPPED FROM PRESENCE TO ABSENCE, and the reason is the
/// App Store record, not the surface. `fastlane/metadata/{en-US,de-DE}` now describes Echoel
/// Studio 11.0.0 (builds 10004–10017), and the Studio build has no playable picture — its visual
/// is being built by another wave and is not in 10017 (`ContentPipeline/CLAIMS.md`, Nachtrag 5).
/// A store description that said "touch the visual" would sell, to a Studio buyer, a surface the
/// app they download does not have — the 2.3 mismatch GM28 names. The WEBSITE (`docs/`) still
/// describes the earlier app, where the surface IS mounted (claim 4), so claims 1, 3 and 4 are
/// unchanged. Claim 2 now asserts that the earlier app's sentence does not come back into the
/// Studio listing; when the Studio ships a playable visual, flip it back to presence in the SAME
/// commit as the code — the message says so.
final class ThePictureIsSoldAsPlayableTests: XCTestCase {

    private func source(_ relative: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(relative)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read — a missing anchor is a "
                    + "finding, not a pass.")
            return ""
        }
        return text
    }

    // 1 — the denial is gone. The exact sentence, not a paraphrase: it is what a reader saw.
    func testTheSiteNoLongerDeniesTheShippedSurface() throws {
        let faq = try source("docs/faq.html")
        XCTAssertFalse(faq.contains("Dedicated touch instruments"), """
            The FAQ denies the touch surface again. `TouchInstrumentView` is mounted in \
            `FloatingVisualWindow`'s visual overlay at every size, and that window opens on \
            launch — so this sentence tells a musician the opposite of what the app does, on \
            the page they read while deciding.
            """)
        XCTAssertTrue(faq.lowercased().contains("playable"), """
            The FAQ no longer says the picture is playable. Removing the denial is only half the \
            repair: a reader who is told nothing concludes the same thing the denial said.
            """)
    }

    // 2 — the acquisition copy does NOT carry it while the Studio build has no such surface.
    // Until 2026-10-29 this was the presence check (#999): "touch the visual" in both locales,
    // the harder half of that finding — the denial was one page, the absence was sixteen files.
    // The listing now describes Echoel Studio, whose build (10004–10017) has no playable picture,
    // so the same sentence is an over-claim there and the needles are inverted. The anchor is the
    // sentence's own wording in both locales, so a paraphrase ("tap the picture") walks past —
    // stated rather than hidden; `TheStoreTextClaimsOnlyWhatShipsTests` bans the broader
    // vocabulary (camera, visual outputs) that such a paraphrase would need.
    func testBothStoreLocalesSayThePictureIsPlayable() throws {
        for (path, needles) in [("fastlane/metadata/en-US/description.txt", ["touch the visual"]),
                                ("fastlane/metadata/de-DE/description.txt", ["berühre das visual"])] {
            let text = try source(path).lowercased()
            XCTAssertFalse(needles.contains(where: { text.contains($0) }), """
                \(path) tells a buyer the picture can be played, but the Echoel Studio build on \
                this App Store record has no playable picture (GM28, CLAIMS Nachtrag 5). That is \
                the earlier app's sentence returning to a listing that no longer describes it. \
                When the Studio ships a playable visual, flip this claim back to presence in the \
                SAME commit as the code and the copy — do not leave the sentence unguarded either way.
                """)
        }
    }

    // 3 — COUNTERWEIGHT against the enthusiasm this slice creates. The four pads do NOT exist;
    // only the picture does. If a future edit folds them into the shipped claim, this goes red.
    func testTheFourPadsStayOnTheRoadmap() throws {
        let faq = try source("docs/faq.html")
        guard let range = faq.range(of: "chord pad") else {
            return XCTFail("""
                The FAQ no longer names the chord pad as roadmap. That is allowed if the pads \
                genuinely shipped — but then say so deliberately, here and in the store copy, \
                rather than letting the line vanish while the pads do not exist.
                """)
        }
        let window = String(faq[range.lowerBound...].prefix(260)).lowercased()
        XCTAssertTrue(window.contains("roadmap"), """
            The FAQ names the chord pad without marking it roadmap. Chord pad, melody XY pad, \
            multi-octave keyboard and strum pad are NOT built; the one surface that ships is the \
            picture itself. Selling four instruments that do not exist is a 2.3 conversation.
            """)
    }

    // 4 — COUNTERWEIGHT on the SOURCE of the claim. The copy above is only true while the mount
    // exists; this goes red the day it does not, and says to pull the copy in the same commit
    // rather than leaving three surfaces selling a removed surface (#456).
    func testTheClaimStillHasItsMount() throws {
        let window = try source("Sources/Echoelmusic/Studio/FloatingVisualWindow.swift")
        XCTAssertTrue(window.contains("TouchInstrumentView("), """
            `FloatingVisualWindow` no longer mounts `TouchInstrumentView`, so the picture is not \
            playable — and the FAQ and `ContentPipeline/CLAIMS.md` still say it is (the store \
            descriptions stopped saying it on 2026-10-29, when they moved to Echoel Studio). If \
            the surface was removed on purpose, remove those claims in the same commit and delete \
            this guard with them.
            """)
    }
}

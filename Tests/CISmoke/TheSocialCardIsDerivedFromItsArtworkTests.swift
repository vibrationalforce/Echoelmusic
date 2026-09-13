// TheSocialCardIsDerivedFromItsArtworkTests.swift
// Echoel — #1312. Blocking bundle. Claims 1–3 are FILE-CONTENT checks over `docs/` and
// `scripts/`; claim 4 reads the PNG header itself, which is the one END-TO-END assertion here
// (`Tests/CISmoke/CLAUDE.md` §1). None of them proves what a link preview LOOKS like — that is
// a human's look at `docs/og-cover.png`, and it is named as open rather than implied.
//
// ⭐ WHY THIS FILE EXISTS, AND IT IS NOT "THE CARD SAID AUv3". That was the symptom. The defect
// is that `docs/og-cover.png` — the `og:image` and `twitter:image` of twenty pages, i.e. every
// link preview of the site — was a HAND-MADE BINARY WITH NO GENERATOR. Its artwork source
// `docs/og-image.svg` had already been corrected (badge 4 read `MIDI` there) while the shipped
// raster still advertised `AUv3`, a claim #158 and #192 each spent a whole cycle removing from
// this site and #184 removed twelve of from the App Store text. It also still carried the word
// `motion`, struck 2026-07-31 for having no producer.
//
// ⛔ AND NOTHING IN THE TOOLCHAIN COULD HAVE REPORTED IT. A text guard cannot read a raster, and
// `docs/CLAUDE.md` §5 correctly tells the next session that an `AUv3` grep hit in `docs/` is a
// DENIAL and must not be "fixed" — so the one word a session is trained to leave alone was, in
// this one file, an affirmative badge. The repair is therefore not a better needle: it is making
// the PNG DERIVABLE (`scripts/render-og-cover.py`) so the SVG is the single truth, and pinning
// the derivation so the two cannot part again.
//
// ⚠️ WHY THE PIN IS ON THE SOURCE DIGEST AND NOT ON THE PNG's (#364). Chromium builds differ, so
// two correct re-renders on two machines produce two different PNGs; a PNG digest in this guard
// would turn the founder's own correct re-render red. `scripts/render-og-cover.py` therefore
// writes `docs/og-cover.source.sha256` — the digest of the SVG it rendered FROM. That value is
// byte-identical everywhere, and it still goes red for exactly the case that happened: artwork
// edited, raster not re-rendered. Claim 1 forbids no artwork change whatsoever; it requires the
// render to travel in the same commit, and its message says the command.
//
// ⚠️ WHAT CLAIM 2 DOES NOT SAY. It bans a short list of struck CAPABILITY words from the artwork
// source only — not from `docs/*.html`, where those same words are the site's corrections and
// must stay (docs/CLAUDE.md §5). The SVG has no prose room for a denial: a capability word in it
// is a badge or a strapline, i.e. a claim. `Sequencer` is deliberately NOT on the list even
// though this slice replaced that badge with `Generative`: the beat maker is gone (#166/#167)
// but a step clock still exists, so banning the word would forbid a future correct use.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **18 assertions across four claims** —
// stated rather than left to be counted (claim 1 = 2, claim 2 = 1 empty-read check + 9 words,
// claim 3 = 3, claim 4 = 3). All were transcribed in Python and driven against BOTH trees.
// On the PARENT tree (`ff9e9b1`) **6 assertions are red, but they are TWO findings** (#486 — one
// absence reported N times is one finding): the generator and its sidecar did not exist (reds in
// claims 1 and 3, four assertions, one absence), and `motion` stood at og-image.svg:34 (one).
// On today's tree all 18 are green. The other 12 are COUNTERWEIGHTS (#343): they pin that the
// artwork is still the real artwork and the raster still 1200×630, so claim 2's absence can
// never be a vacuous green on a file that was emptied or renamed.
//
// ⛔ AND THE HONEST LIMIT, because it is the opposite of flattering: **this guard would NOT have
// caught the drift that caused it.** On the parent tree the PNG said `AUv3` and no assertion here
// says so — the word is in pixels, and the sidecar that would have exposed the mismatch is the
// thing this slice introduces. What it buys is the NEXT divergence, from the first commit where a
// sidecar exists onwards. Booking it as a catch of the original defect would be the flattering
// direction (#433/#464).

import Foundation
import XCTest
#if canImport(CryptoKit)
import CryptoKit
#endif
@testable import Echoelmusic

final class TheSocialCardIsDerivedFromItsArtworkTests: XCTestCase {

    private static let svgPath = "docs/og-image.svg"
    private static let pngPath = "docs/og-cover.png"
    private static let stampPath = "docs/og-cover.source.sha256"
    private static let scriptPath = "scripts/render-og-cover.py"

    /// Capability words that are a CLAIM when they appear in the card artwork. Every one of them
    /// is struck in `ContentPipeline/CLAIMS.md` or in the root `CLAUDE.md`.
    private static let struckOnTheCard = [
        "AUv3", "motion", "RTMP", "Autotune", "Harmoniz", "Granular",
        "Beat Maker", "Multitrack", "Vocoder",
    ]

    private func repoRoot() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("docs").path) else {
            throw XCTSkip("docs/ not present under \(root.path)")
        }
        return root
    }

    private func text(_ relative: String) throws -> String {
        let url = try repoRoot().appendingPathComponent(relative)
        guard let body = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read — a missing anchor is a "
                    + "finding, not a pass (#454).")
            return ""
        }
        return body
    }

    /// claim 1 — the shipped raster is derived from today's artwork, not from an older copy.
    /// The sidecar is written by the generator, so a green here means someone ran it.
    func testTheCardWasRenderedFromTodaysArtwork() throws {
        let root = try repoRoot()
        let scriptURL = root.appendingPathComponent(Self.scriptPath)
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: scriptURL.path),
            "\(Self.scriptPath) is missing. The social card must stay DERIVABLE — a hand-made "
            + "binary is how docs/og-cover.png drifted into advertising AUv3 (#1312). Restore "
            + "the generator rather than hand-editing the PNG.")

        #if canImport(CryptoKit)
        let svgURL = root.appendingPathComponent(Self.svgPath)
        guard let svgData = try? Data(contentsOf: svgURL) else {
            XCTFail("ANCHOR MISSING: \(Self.svgPath) could not be read (#454).")
            return
        }
        let digest = SHA256.hash(data: svgData).map { String(format: "%02x", $0) }.joined()
        let stamp = try text(Self.stampPath)
        let recorded = stamp.split(separator: " ").first.map(String.init) ?? ""
        XCTAssertEqual(
            recorded, digest,
            "docs/og-cover.png was rendered from a DIFFERENT version of \(Self.svgPath) than the "
            + "one committed here. The raster is the og:image of every page on the site, so a "
            + "stale one publishes yesterday's claims to every link preview. Re-render in THIS "
            + "commit:  python3 scripts/render-og-cover.py  (it rewrites both the PNG and "
            + "\(Self.stampPath)). This assertion forbids no artwork change — it requires the "
            + "render to travel with it (#364).")
        #else
        throw XCTSkip("CryptoKit unavailable — the digest half of claim 1 cannot run here.")
        #endif
    }

    /// claim 2 — no struck capability word survives in the artwork source.
    /// Scoped to the SVG on purpose: in `docs/*.html` these same words are the site's own
    /// corrections and must not be touched (docs/CLAUDE.md §5).
    func testTheArtworkClaimsNothingThatWasStruck() throws {
        let svg = try text(Self.svgPath)
        XCTAssertFalse(svg.isEmpty, "read \(Self.svgPath) and got nothing — that is a finding.")
        for word in Self.struckOnTheCard {
            XCTAssertFalse(
                svg.localizedCaseInsensitiveContains(word),
                "\(Self.svgPath) contains \"\(word)\", a capability this repo has struck. The "
                + "SVG has no prose room for a denial, so a capability word in it is a badge or "
                + "a strapline — i.e. a claim on every link preview of the site. Remove it and "
                + "re-render (python3 scripts/render-og-cover.py).")
        }
    }

    /// claim 3 — counterweight: the generator really names both ends of the derivation, so
    /// claim 1's file-exists half cannot be satisfied by an unrelated script of the same name.
    func testTheGeneratorNamesBothEndsOfTheDerivation() throws {
        let script = try text(Self.scriptPath)
        XCTAssertTrue(script.contains("og-image.svg"),
                      "\(Self.scriptPath) never names its INPUT docs/og-image.svg.")
        XCTAssertTrue(script.contains("og-cover.png"),
                      "\(Self.scriptPath) never names its OUTPUT docs/og-cover.png.")
        XCTAssertTrue(script.contains("og-cover.source.sha256"),
                      "\(Self.scriptPath) never writes the source digest claim 1 reads.")
    }

    /// claim 4 — counterweight, and the one end-to-end assertion: the committed file really is a
    /// 1200×630 PNG. Read straight out of the IHDR chunk, no image library. Without this, claim 2
    /// would stay green on a tree where the artwork was emptied and the raster replaced by a stub.
    func testTheShippedCardIsA1200x630PNG() throws {
        let url = try repoRoot().appendingPathComponent(Self.pngPath)
        guard let data = try? Data(contentsOf: url), data.count > 32 else {
            XCTFail("ANCHOR MISSING: \(Self.pngPath) is absent or too small to be a PNG (#454).")
            return
        }
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        XCTAssertEqual(Array(data.prefix(8)), signature,
                       "\(Self.pngPath) does not start with the PNG signature.")
        func be32(_ offset: Int) -> Int {
            var value = 0
            for index in offset..<(offset + 4) { value = value << 8 | Int(data[index]) }
            return value
        }
        XCTAssertEqual(be32(16), 1200, "\(Self.pngPath) is not 1200 px wide — Open Graph and "
                       + "Twitter both size their cards on 1200×630.")
        XCTAssertEqual(be32(20), 630, "\(Self.pngPath) is not 630 px tall.")
    }
}

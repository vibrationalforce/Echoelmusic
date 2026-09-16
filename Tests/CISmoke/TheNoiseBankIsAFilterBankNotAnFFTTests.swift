// TheNoiseBankIsAFilterBankNotAnFFTTests.swift
// Echoel — #1334. `EchoelDDSP`'s file header described its noise synthesizer as
// "Multi-band FIR-filtered noise" with "65-band frequency-domain multiplication via vDSP_DFT".
// Neither has ever existed in this file. The render loop runs a bank of ONE-POLE IIR filters,
// sample by sample, in the time domain — three lines of it, with a comment that says so.
//
// ⭐ AND THE HEADER HAD PHYSICAL CONSEQUENCES, which is what lifts this above a wording fix.
// Three arrays sized for the overlap-add the header described — `noiseFFTBuffer`,
// `noiseOutputBuffer`, `noiseOverlapBuffer` — were allocated in `init` and then never read or
// written again. Measured before the cut: exactly TWO occurrences of each name in the whole
// file, the declaration and the initialiser. `noiseOutputBuffer` alone is `frameSize +
// 2 × noiseBandCount` floats, per voice, for nothing.
//
// ⭐ WHY A WRONG HEADER IS THE EXPENSIVE KIND, stated because this repo keeps paying for it in
// other files: it is PRESCRIPTIVE. A session optimising "the DFT" goes looking for a transform
// that is not there; a session extending the noise path builds against a shape the render loop
// does not use; and `.claude/rules/swift-audio.md` sends anyone touching `DSP/` to read the
// surrounding file first. The code was correct the whole time — only its description lied.
//
// ⚠️ THIS GUARD DOES NOT FORBID AN FFT NOISE PATH (#364). If one is built, claim 1 reports the
// names and its message says the header must move in the same commit. What it forbids is an
// allocation with no reader, and a header describing an algorithm the file does not run.
//
// ⚠️ HONEST GRADING (§0/§3). No local Swift toolchain — **10 assertions across three claims**
// (claim 1 = 5, claim 2 = 3, claim 3 = 2), transcribed in Python and driven against BOTH trees.
// On the parent (`b31a005`) **5 are red, and they are TWO different things** — the split matters
// because booking all five as regressions is the flattering direction (#433/#464):
//   · **3 = ONE REGRESSION** (#486). `noiseFFTBuffer`, `noiseOutputBuffer`,
//     `noiseOverlapBuffer` are one removal reported three times, not three findings.
//   · **2 = FORWARD guards.** `c3.header` and `c3.retraction` name prose THIS commit writes,
//     so they could not have been red on the parent for any reason but their own absence.
//     They are worth having — a header repair that is quietly swapped rather than recorded is
//     the thing this file is about — but they prove nothing about the parent.
// The other **5 are COUNTERWEIGHTS** (#343), green on both trees, and they are the point of the
// file: the filter bank that DOES run must still be there, or claim 1 would stay green on a
// tree that deleted the noise synthesizer along with its dead buffers.
// ⛔ The first draft of this paragraph said "**4 are red and they are ONE finding**", counting
// the `vDSP_DFT` header line among them — and there was no assertion on `vDSP_DFT` at all.
// Claim 1's doc comment claimed one ("no transform claimed in code") while the method asserted
// only the three buffers: a guard whose header is wider than its assertions, in a slice about
// exactly that defect. The assertion now exists (and is a counterweight, because on the parent
// the only `vDSP_DFT` in this file sat in a COMMENT, which `codeOnly` blanks).
// SOURCE-TEXT SCAN (§1): `EchoelDDSP`'s members are private, so this reads the file; that the
// noise still SOUNDS right is a device probe and is not claimed here.

import Foundation
import XCTest

final class TheNoiseBankIsAFilterBankNotAnFFTTests: XCTestCase {

    private static let ddsp = "Sources/Echoelmusic/DSP/EchoelDDSP.swift"

    /// Claim 1 — no allocation without a reader, and no transform claimed in code.
    /// Read through `SourceText.codeOnly` so the ⛔ header that NAMES the deleted buffers — the
    /// way this repo strikes a claim (#491/#1318) — stays legal.
    func testTheDeadOverlapAddBuffersAreGone() throws {
        let code = SourceText.codeOnly(try Self.text(Self.ddsp))
        XCTAssertFalse(code.isEmpty, "ANCHOR MISSING: could not read \(Self.ddsp) (#454).")
        for name in ["noiseFFTBuffer", "noiseOutputBuffer", "noiseOverlapBuffer"] {
            XCTAssertFalse(
                code.contains(name),
                "`\(name)` is back in `EchoelDDSP`'s code. It was allocated per voice and never "
                + "read or written — the overlap-add half of an FFT noise path this file has "
                + "never had. If an FFT path is being built, that is legal (#364): move the "
                + "file header in the SAME commit, because it is prescriptive for everyone who "
                + "reads `DSP/` next.")
        }
        XCTAssertFalse(
            code.contains("vDSP_DFT"),
            "`EchoelDDSP` now CALLS a transform. That is legal (#364) and it is not what the "
            + "noise stage did for the whole life of this file — the header claimed a "
            + "\"65-band frequency-domain multiplication via vDSP_DFT\" while the render loop "
            + "ran one-pole IIR filters sample by sample. Move the header in the SAME commit. "
            + "(Counterweight, not a regression: on the parent the phrase existed only in that "
            + "comment, which `SourceText.codeOnly` blanks. The wrapper that really owns DFT "
            + "setup is `EchoelVDSPKit`.)")
    }

    /// Claim 2 — counterweight: the filter bank that really runs is intact. Without this,
    /// claim 1 is green on a tree that deleted the noise synthesizer outright.
    func testTheOnePoleBankStillRuns() throws {
        let code = SourceText.codeOnly(try Self.text(Self.ddsp))
        XCTAssertTrue(code.contains("for band in 0..<noiseBandCount {"),
                      "the per-band noise loop is gone — that loop IS the noise synthesizer.")
        XCTAssertTrue(
            code.contains("let filtered = whiteNoise * (1.0 - alpha) + noiseFilterState[band] * alpha"),
            "the one-pole recursion is gone. It is what makes this an IIR bank rather than the "
            + "FIR/overlap-add the old header claimed, and the alphas are pre-computed exactly "
            + "so no `exp()` runs on the audio thread.")
        XCTAssertTrue(code.contains("noiseSample /= Float(noiseBandCount)"),
                      "the band-count normalisation is gone — summing 65 bands without it is "
                      + "the amplitude explosion its own comment names.")
    }

    /// Claim 3 — counterweight: the header now describes THIS algorithm, and the retraction is
    /// recorded rather than the old sentence quietly swapped.
    func testTheHeaderDescribesTheAlgorithmItRuns() throws {
        let raw = try Self.text(Self.ddsp)
        XCTAssertTrue(raw.contains("A bank of `noiseBandCount` (default 65) ONE-POLE IIR filters"),
                      "the header no longer says what the noise stage actually is.")
        XCTAssertTrue(raw.contains("AND NEITHER HAS EVER EXISTED HERE"),
                      "the #1334 retraction is gone. The point is not the new sentence — it is "
                      + "the record that a header can describe a different algorithm than the "
                      + "code for as long as nobody reads both.")
    }

    private static func text(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

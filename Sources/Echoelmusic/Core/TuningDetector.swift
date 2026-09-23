// TuningDetector.swift
// Echoel — hear the room, find the tuning. Given a set of detected fundamental
// frequencies (Hz), this pure analysis estimates:
//
// ⛔ THIS HEADER NAMED ITS PRODUCER AND THE PRODUCER NO LONGER EXISTS. It read
// "from the mic/voice (MicrophoneManager.pitch / .frequency)". `MicrophoneManager`
// was DELETED with #1302 (founder 2026-09-12, "Face und Audio Input komplett
// entfernen"), and the deletion is structural rather than cosmetic:
// `AudioConfiguration.RecordRouteOwner` is an UNINHABITED enum, so
// `claimRecordRoute(_:)` cannot be called and the session can never rise to
// `.playAndRecord`. There is no microphone to read fundamentals from, and
// restoring one is a founder decision, not a slice.
//
// ⭐ THIS TYPE NOW HAS EXACTLY ONE PRODUCTION CALLER, AND THE SENTENCE THAT STOOD HERE
// SAID IT HAD NONE. It was true for about a day. `Sequencer/AudioKeyAnalysis` reads
// windows out of an IMPORTED FILE, estimates a fundamental per window with
// `DSP/PitchTracker` (YIN), and hands the list to `analyze` below. Measure rather than
// trust this line: `git grep -n "TuningDetector" -- Sources | grep -v ': *//'`.
// `TheToneSystemIsNamedByItsTypeTests` pins that there is exactly one and names it —
// a SECOND producer is a finding, because it is likely a duplicate estimator.
//
// ⛔ AND THE PRODUCER IS STILL NOT A MICROPHONE, which is the half of the old note that
// must not be lost. This header used to name `MicrophoneManager.pitch / .frequency`,
// deleted with #1302 (founder 2026-09-12, "Face und Audio Input komplett entfernen"),
// and the deletion is structural: `AudioConfiguration.RecordRouteOwner` is an
// UNINHABITED enum, so `claimRecordRoute(_:)` cannot be called and the session can never
// rise to `.playAndRecord`. Audio input is a FOUNDER HOLD. A microphone-shaped caller
// here would be a regression, not a feature.
//
// ⚠️ **Whoever builds detected key/scale analysis: this type already exists and already
// carries `confidence` plus a nil return when evidence is thin — do not mint a second
// one.** That was the point of writing the orphan entry, and it is why the entry stays
// in CLAUDE.md as a derivation rather than being deleted now that it is wired.
//
// The estimates:
//   • the Kammerton (concert-pitch A4) the source is tuned to, from the circular
//     mean of each note's cents-deviation to the nearest 12-TET pitch, and
//   • the musical key (root + major/minor) via Krumhansl–Kessler key-finding
//     (Pearson correlation of a pitch-class histogram against the 24 key profiles).
//
// Pure value math (no AVFoundation/Accelerate) so it is fully unit-tested on every
// platform — the trustworthy brain behind "listen → suggest tuning + key", mirroring
// how PulsePeriodEstimator backs the rPPG path. Genre/style/character are NOT guessed
// from audio here (that would be a stub); the UI lets the user confirm those when
// saving a preset.

import Foundation

public struct DetectedTuning: Sendable, Equatable {
    /// Best-fit concert pitch (A4) in Hz, e.g. ≈432 or ≈440.
    public var a4Hz: Double
    /// Tonic pitch class, 0 = C … 11 = B.
    public var keyRoot: Int
    /// Major vs natural-minor key.
    public var isMinor: Bool
    /// Key-finding correlation strength, 0…1 (higher = clearer key).
    ///
    /// ⚠️ THIS ALONE DOES NOT MEASURE AMBIGUITY, and reading it as if it did is the trap
    /// this property spent its whole life in. It is the correlation of the WINNER, so a
    /// histogram that fits C major at 0.80 and A minor at 0.79 reports 0.80 — "high" — for
    /// what is a coin flip. Relative and parallel keys share most of their pitch classes,
    /// so near-ties are the NORMAL failure of Krumhansl key-finding, not an exotic one.
    /// Ask `keyMargin` before naming a key to a user.
    public var confidence: Double
    /// The best correlation among the other 23 candidates, 0…1 — the runner-up key's fit.
    /// Stored rather than derived because `analyze` is the only place that sees all 24.
    public var runnerUpConfidence: Double
    /// Global tuning offset vs A4=440, in cents (informational; −31.8 ≈ 432 Hz).
    public var centsOffset: Double
    /// How many valid pitches informed the estimate.
    public var sampleCount: Int

    /// How far ahead of the runner-up the winning key is, ≥ 0. THIS is the ambiguity
    /// measure: near 0 means two keys fit the same material equally well and naming
    /// either one is a guess dressed as a finding.
    public var keyMargin: Double { Swift.max(0, confidence - runnerUpConfidence) }

    /// ⚠️ `runnerUpConfidence` DEFAULTS so the memberwise init stays source-compatible for
    /// callers that only care about `keyName` formatting — NOT because the producer may skip
    /// it. `TuningDetector.analyze` writes it explicitly; a default nobody writes is the
    /// #431/#440/#443 shape, and the reason that warning does not apply here is exactly that
    /// the one production construction site passes a measured value. A default of 0 means
    /// "no runner-up known", which makes `keyMargin` read as the full confidence — the
    /// permissive direction, so any future producer that forgets it is CAUGHT by the guard
    /// rather than silently gated.
    public init(a4Hz: Double, keyRoot: Int, isMinor: Bool,
                confidence: Double, runnerUpConfidence: Double = 0,
                centsOffset: Double, sampleCount: Int) {
        self.a4Hz = a4Hz; self.keyRoot = keyRoot; self.isMinor = isMinor
        self.confidence = confidence; self.runnerUpConfidence = runnerUpConfidence
        self.centsOffset = centsOffset; self.sampleCount = sampleCount
    }

    /// "A minor", "C♯ major" … from keyRoot + isMinor.
    public var keyName: String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let r = ((keyRoot % 12) + 12) % 12
        return "\(names[r]) \(isMinor ? "minor" : "major")"
    }

    /// Snap a4 to the nearest standard Kammerton preset when within `tolHz`, else keep.
    public func snappedA4(tolHz: Double = 1.5) -> Double {
        let nearest = TuningReference.presets.min(by: { abs($0 - a4Hz) < abs($1 - a4Hz) }) ?? a4Hz
        return abs(nearest - a4Hz) <= tolHz ? nearest : a4Hz
    }
}

public struct TuningDetector {

    public init() {}

    // Krumhansl–Kessler probe-tone profiles (tonic-relative).
    static let majorProfile: [Double] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
    static let minorProfile: [Double] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

    /// Analyse detected fundamentals. Returns nil if there isn't enough evidence.
    public func analyze(frequencies: [Double], minHz: Double = 50, maxHz: Double = 2000,
                        minSamples: Int = 8) -> DetectedTuning? {
        let valid = frequencies.filter { $0.isFinite && $0 >= minHz && $0 <= maxHz }
        guard valid.count >= minSamples else { return nil }

        // 1) Kammerton: each pitch's signed cents-deviation to the nearest 12-TET note
        //    at A4=440, then the CIRCULAR mean (period = 100 cents) so the estimate is
        //    robust near the ±50-cent wrap.
        var sumSin = 0.0, sumCos = 0.0
        for f in valid {
            let midiCont = 69.0 + 12.0 * log2(f / 440.0)
            let cents = (midiCont - midiCont.rounded()) * 100.0     // (−50, 50]
            let theta = cents / 100.0 * 2.0 * .pi
            sumSin += sin(theta); sumCos += cos(theta)
        }
        let meanTheta = atan2(sumSin, sumCos)
        let offsetCents = meanTheta / (2.0 * .pi) * 100.0           // (−50, 50]
        let a4 = 440.0 * pow(2.0, offsetCents / 1200.0)

        // 2) Pitch-class histogram at the DETECTED tuning, so off-tuning notes still
        //    land in the correct class.
        var hist = [Double](repeating: 0, count: 12)
        for f in valid {
            let midiCont = 69.0 + 12.0 * log2(f / a4)
            let pc = ((Int(midiCont.rounded()) % 12) + 12) % 12
            hist[pc] += 1
        }

        // 3) Krumhansl key-finding: best Pearson correlation over the 24 keys — AND the
        //    runner-up, because the winner's score says how well the best key fits while
        //    only the GAP says whether a second key fits just as well. Tracking it is two
        //    lines here and impossible anywhere else: this loop is the only place all 24
        //    candidates exist at once.
        //
        //    ⚠️ The verdict is unchanged by this addition — same winner, same nil rule, same
        //    `confidence`. Existing callers that assert a detected key keep their answer;
        //    what is new is that the answer can now say how alone it stands.
        var bestRoot = 0, bestMinor = false, bestCorr = -2.0, runnerUp = -2.0
        for root in 0..<12 {
            for minor in [false, true] {
                let profile = minor ? Self.minorProfile : Self.majorProfile
                let c = Self.correlation(hist, Self.rotated(profile, by: root))
                if c > bestCorr {
                    runnerUp = bestCorr
                    bestCorr = c; bestRoot = root; bestMinor = minor
                } else if c > runnerUp {
                    runnerUp = c
                }
            }
        }

        return DetectedTuning(
            a4Hz: (a4 * 100).rounded() / 100,
            keyRoot: bestRoot, isMinor: bestMinor,
            confidence: max(0, min(1, bestCorr)),
            // Clamped on the SAME scale as `confidence`, so `keyMargin` subtracts comparable
            // numbers. A negative runner-up means the alternative is anti-correlated — no
            // ambiguity at all — and clamping it to 0 says exactly that.
            runnerUpConfidence: max(0, min(1, runnerUp)),
            centsOffset: (offsetCents * 10).rounded() / 10,
            sampleCount: valid.count
        )
    }

    // MARK: - Pure helpers

    /// profile rotated so its tonic (index 0) lands on pitch class `root`.
    static func rotated(_ profile: [Double], by root: Int) -> [Double] {
        (0..<12).map { profile[(($0 - root) % 12 + 12) % 12] }
    }

    /// Pearson correlation of two 12-length vectors (0 when either is flat).
    static func correlation(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let n = Double(a.count)
        let ma = a.reduce(0, +) / n, mb = b.reduce(0, +) / n
        var num = 0.0, da = 0.0, db = 0.0
        for i in a.indices {
            let xa = a[i] - ma, xb = b[i] - mb
            num += xa * xb; da += xa * xa; db += xb * xb
        }
        let denom = (da * db).squareRoot()
        return denom > 1e-9 ? num / denom : 0
    }
}

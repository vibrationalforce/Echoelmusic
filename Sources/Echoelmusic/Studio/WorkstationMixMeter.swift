// WorkstationMixMeter.swift
// Echoel — design slice 13 (mockup vs. shipped Workstation, 2026-09-27): the transport shows how
// loud the mix is while the song plays. The phone mockup's transport carried "position · time ·
// level"; the position is D1 (`SongPositionReadout`), this is the level. The time half is NOT
// built: the Workstation's tempo can follow the body, so a clock derived from ticks would be a
// guess, not a reading.
//
// ⭐ WHAT IT MEASURES, SAID ONCE AND HONESTLY. `AudioEngine.masterLevel`/`masterLevelR` — the
// stereo MIX meter, measured BEFORE the master chain (EQ, auto-gain, limiter). The value is
// `min(3 · RMS, 1)` with a decaying peak-hold: a meter-ballistics number, NOT a decibel level.
// So it is spoken as a SHARE OF THE METER ("Left 30 percent"), never in dB — reading it as dBFS
// would say about 9.5 dB too much and freeze at "0.0 dB" from ≈ −9.5 dBFS RMS on (the #347 lesson,
// `AudioEngine.masterOutputTruePeakDb`'s doc). It is the same reading as the two bars in the Master
// panel (`MasterLoudnessGrid`), drawn by the same bar (`MixLevelBar`, one threshold, #416). The
// loudness of what leaves the device is the Master panel's R128 numbers; the hint says so.
//
// ⚠️ WHY THIS IS ITS OWN FILE AND ITS OWN STRUCT. Both properties are rewritten by the 60 Hz meter
// poll (`AudioEngine.startMeterPollTimer`). A read in `WorkstationView.body` would register the
// whole Workstation — Pickers included — as a 60 Hz observer (the 10.76.41/50 freeze law,
// `TheMenuHostReadsNoHotStateTests`). Read HERE, only this leaf re-renders. `WorkstationView`
// mounts it and names no engine.
//
// ⛔ NOT A PER-TRACK METER. There is no per-lane meter source; the mockup's per-track bars were
// rejected by the vision gate for exactly that reason (MODES_CENSUS § Design). This is the mix.

#if canImport(SwiftUI)
import SwiftUI

/// The mix-level bar's rules, pure so the blocking bundle can drive them.
enum MixLevelMeter {

    /// Meter value above which a bar turns to the warning colour: the top tenth of the meter.
    /// The meter is `3 · RMS`, so this is ≈ −10.5 dBFS RMS — a LOUD mix, not clipping (the limiter
    /// follows the meter). That is why the colour is `warning`, never `danger`: red would read as
    /// "I am clipping". One threshold for every mix-level bar (Master panel and Workstation, #416).
    nonisolated static let warnLevel: Float = 0.9

    /// The share of the bar to fill, 0…1. A non-finite reading draws nothing rather than a
    /// NaN width.
    nonisolated static func fill(_ level: Float) -> Double {
        guard level.isFinite, level > 0 else { return 0 }
        return Double(Swift.min(level, 1))
    }

    /// Whether the bar shows the warning colour.
    nonisolated static func warns(_ level: Float) -> Bool {
        level.isFinite && level > warnLevel
    }

    /// The share of the meter a bar shows, 0…100, whole numbers — what a sighted player sees.
    nonisolated static func percent(_ level: Float) -> Int {
        Int((fill(level) * 100).rounded())
    }

    /// "Left 30 percent, right 28 percent" — the share of the meter, never decibels (the value
    /// is not a dB level; see the file header). Whole numbers, so no decimal separator to get
    /// wrong (#267).
    nonisolated static func spokenText(left: Float, right: Float) -> String {
        // E4-61: the two whole numbers are seamed between catalog keys; " percent" reuses the existing unit.
        let leftHalf: String = String(localized: "Left ") + "\(percent(left))" + String(localized: " percent, right ")
        return leftHalf + "\(percent(right))" + String(localized: " percent")
    }
}

/// One channel's mix-level bar: fill proportional to the meter, the warning colour near its top.
struct MixLevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(EchoelTheme.fill)
                RoundedRectangle(cornerRadius: 2)
                    .fill(MixLevelMeter.warns(level) ? EchoelTheme.warning : EchoelTheme.accent)
                    .frame(width: geo.size.width * CGFloat(MixLevelMeter.fill(level)))
            }
        }
        .frame(height: 5)
    }
}

/// The mix level beside the Workstation's song position, while the song plays.
@MainActor
struct WorkstationMixMeter: View {
    @Environment(AudioEngine.self) private var audioEngine

    var body: some View {
        let left = audioEngine.masterLevel
        let right = audioEngine.masterLevelR
        VStack(spacing: 3) {
            MixLevelBar(level: left)
            MixLevelBar(level: right)
        }
        // Narrow on purpose: it shares the 44 pt row with Play, Click and the song position, and the
        // position must not be the one that gets truncated (review of dfe9525e6).
        .frame(width: 32)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mix level")
        .accessibilityValue(MixLevelMeter.spokenText(left: left, right: right))
        .accessibilityHint("Share of the meter, measured before the master chain. The Master panel shows the loudness of the output.")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
#endif

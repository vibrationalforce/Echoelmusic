// WorkstationMixMeter.swift
// Echoel — design slice 13 (mockup vs. shipped Workstation, 2026-09-27): the transport shows how
// loud the mix is while the song plays. The phone mockup's transport carried "position · time ·
// level"; the position is D1 (`SongPositionReadout`), this is the level. The time half is NOT
// built: the Workstation's tempo can follow the body, so a clock derived from ticks would be a
// guess, not a reading.
//
// ⭐ WHAT IT MEASURES, SAID ONCE AND HONESTLY. `AudioEngine.masterLevel`/`masterLevelR` — the
// stereo MIX level, measured BEFORE the master chain (EQ, auto-gain, limiter). It is the same
// reading as the two bars in the Master panel (`MasterLoudnessGrid`), drawn by the same bar
// (`MixLevelBar`, one threshold, #416). It is not the loudness of what leaves the device; the
// Master panel's R128 numbers are. The VoiceOver hint says where to find them.
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

    /// Linear amplitude above which a bar turns to the danger colour — close to clipping.
    /// One threshold for every mix-level bar (the Master panel's and the Workstation's, #416).
    nonisolated static let warnLevel: Float = 0.9

    /// The share of the bar to fill, 0…1. A non-finite reading draws nothing rather than a
    /// NaN width.
    nonisolated static func fill(_ level: Float) -> Double {
        guard level.isFinite, level > 0 else { return 0 }
        return Double(Swift.min(level, 1))
    }

    /// Whether the bar shows the danger colour.
    nonisolated static func warns(_ level: Float) -> Bool {
        level.isFinite && level > warnLevel
    }

    /// "Left −12.0 dB, right −14.0 dB" — through the Workstation's one decibel rule
    /// (`TrackMix.decibelText`, #416), so silence reads "−∞ dB" and never a number.
    nonisolated static func spokenText(left: Float, right: Float) -> String {
        "Left \(TrackMix.decibelText(Double(left))), right \(TrackMix.decibelText(Double(right)))"
    }
}

/// One channel's mix-level bar: fill proportional to the level, the danger colour near clipping.
struct MixLevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(EchoelTheme.fill)
                RoundedRectangle(cornerRadius: 2)
                    .fill(MixLevelMeter.warns(level) ? EchoelTheme.danger : EchoelTheme.accent)
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
        .frame(width: 56)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mix level")
        .accessibilityValue(MixLevelMeter.spokenText(left: left, right: right))
        .accessibilityHint("Measured before the master chain. The Master panel shows the loudness of the output.")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
#endif

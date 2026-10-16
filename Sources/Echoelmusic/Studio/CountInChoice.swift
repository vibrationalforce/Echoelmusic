// CountInChoice.swift
// Echoel — Arrange & Perform item 5 (founder 2026-10-16, "Count-in"): Record can count in one or
// two bars of click before the piece starts and the take begins.
//
// What a count-in is here, and what it is not:
//   · It runs BEFORE the transport. Record still plays the piece from bar 1 and records from bar 1
//     (`RecordTake.caption`); the count-in only delays that one start by n bars of click, so the
//     first note of a take can land on the downbeat instead of being played into silence.
//   · The click is the ONE `MetronomeVoice`. Its bar is restarted at the tap (`restartBar()`), so
//     the count-in's first click is its downbeat; if the click was off, it sounds for the count-in
//     only and is off again when the take starts. Nothing here is a second click.
//   · The wait is `bars × Transport.beatsPerBar` beats at the transport's tempo, through the
//     metronome's own clamp (`MetronomeVoice.samplesPerBeat`, #416) — so a count-in never runs at a
//     tempo the click itself would refuse.
//
// ⚠️ The wait is a main-actor sleep, not a sample-accurate pre-roll. The first transport beat
// re-anchors the click (`anchorBeat`, slice 10), which absorbs a late start of up to a quarter beat
// (`MetronomeVoice.anchorAbsorbShare`). NEEDS-FOUNDER-VERIFY (A10): arm a MIDI track, set Count-in to
// 1 bar, press Record — four clicks, then the piece starts on the fifth with no gap or double click;
// press Record again during the count-in — it stops, nothing records, the click returns to its state.

import SwiftUI

/// The count-in before a recording: off, one bar or two bars of click.
enum CountInChoice: Int, CaseIterable, Sendable {
    case off = 0
    case oneBar = 1
    case twoBars = 2

    /// The persisted choice (an Int, the number of bars).
    nonisolated static let key = "record.countInBars"

    nonisolated var bars: Int { rawValue }

    var displayName: String {
        switch self {
        case .off: return String(localized: "Off")
        case .oneBar: return String(localized: "1 bar")
        case .twoBars: return String(localized: "2 bars")
        }
    }

    /// An unknown stored value counts in nothing — a count-in nobody chose is never played.
    nonisolated static func resolved(_ raw: Int) -> CountInChoice { CountInChoice(rawValue: raw) ?? .off }

    /// How long to wait before the one start: the count-in less ONE step, because the transport's
    /// step 0 sounds one step after `play()` (`Transport.stepDuration`). So bar 1 lands on the
    /// count-in's next downbeat — the click's own, which the first transport beat then anchors
    /// inside the absorb window instead of striking it a second time a sixteenth late (finesse
    /// review 2026-10-16). Never negative. Pure.
    nonisolated static func startDelay(bars: Int, bpm: Double, beatsPerBar: Int) -> Double {
        let length = seconds(bars: bars, bpm: bpm, beatsPerBar: beatsPerBar)
        guard length > 0 else { return 0 }
        return Swift.max(0, length - Transport.stepDuration(atTempo: bpm))
    }

    /// How long `bars` bars of `beatsPerBar` beats last at `bpm`, through the click's own tempo
    /// clamp. Zero for no bars or a bar of no beats; never NaN or infinite.
    nonisolated static func seconds(bars: Int, bpm: Double, beatsPerBar: Int) -> Double {
        guard bars > 0, beatsPerBar > 0 else { return 0 }
        let rate = 48_000.0
        return Double(bars * beatsPerBar) * MetronomeVoice.samplesPerBeat(bpm: bpm, sampleRate: rate) / rate
    }
}

/// The Count-in menu beside Record. Writes the one persisted choice; Record reads it.
struct CountInPicker: View {

    @AppStorage(CountInChoice.key) private var raw = CountInChoice.off.rawValue

    var body: some View {
        Picker("Count-in", selection: $raw) {
            ForEach(CountInChoice.allCases, id: \.rawValue) { choice in
                Text(choice.displayName).tag(choice.rawValue)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
        .accessibilityHint("Bars of click before Record starts the piece")
    }
}

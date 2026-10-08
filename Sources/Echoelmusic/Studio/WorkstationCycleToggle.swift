//
//  WorkstationCycleToggle.swift
//  Echoelmusic — Studio (GMMW AE-12b: the Cycle button)
//
//  WHY THIS EXISTS. Every big DAW loops a range of bars while you work on it — Logic's and
//  GarageBand's Cycle, Ableton's loop brace (founder 2026-10-08: "Orientiere dich an den
//  Bigplayern"). AE-12a taught the piece and the player a cycle (`TimelineDocument.cycle`); this
//  is the door. ONE button in the Workstation's pinned transport row, beside Click, so it stays in
//  reach on every plate and in focus:
//  · off → on: the piece loops the selected part's bars, or — with no part selected — four bars
//    from where Play starts (`CycleChoice.proposal`), whole bars inside the piece;
//  · on → off: the whole piece loops again.
//  The ruler draws the cycle as a band (`ArrangeRulerLocator`), so the range is seen where the
//  bars are counted.
//
//  ⚠️ ONE WRITER, ONE STEP. The tap calls `TimelineStore.setCycle` once — one `.cycle` Undo step
//  — and nothing else in the app writes the cycle (`TheCycleButtonLoopsThePartTests`).
//
//  ⚠️ COLD, AND IT MUST STAY SO. It reads the piece, the selection, the cue and whether a take
//  records — each changes on a tap or an edit. Never `currentTick`: the playhead is a leaf that
//  drives itself (10.76.41/50), and this button sits in the row beside the transport's meter.
//
//  ⛔ LOCKED WHILE A TAKE RECORDS. A MIDI take ends where the song wraps (`songEndTick`, R1) and
//  counts transport ticks that only count forward; a cycle set mid-take could end it at once.
//  A piece bounce needs no lock — it turns the loop off and renders the whole piece — and a loop
//  capture records what is heard, which a cycle legitimately changes.
//
//  NEEDS-FOUNDER-VERIFY (device): select a part on bars 3–4, tap the Cycle button → a band marks
//  bars 3–4 on the ruler; Play loops bars 3–4 with no click at the jump. Tap it again → the band
//  goes and the whole piece loops. Undo after either tap → the previous state.
//

import SwiftUI

/// The pure half: which bars the Cycle button loops when it is turned on, and how they are named.
enum CycleChoice {

    /// How many bars the button loops when no part is selected.
    nonisolated static let defaultBars = 4

    /// The cycle a tap turns on: the selected `part`'s bars (its start floored, its end rounded up
    /// to a bar line), else `defaultBars` from the bar Play starts on — never the whole piece, which
    /// already loops, and always stored as the window it plays (`TimelineCycle.window`). nil =
    /// nothing to loop: a piece of one bar, or a part that spans the whole piece. Pure.
    nonisolated static func proposal(part: TimelineRegion?, cueTick: Int, loopTicks: Int) -> TimelineCycle? {
        let bar = TimelineTime.ticksPerBar
        guard loopTicks > bar else { return nil }
        let wanted: TimelineCycle
        if let part {
            let start = (Swift.max(0, part.startTick) / bar) * bar
            let end = Swift.min(Swift.max(0, part.endTick), loopTicks)
            wanted = TimelineCycle(startTick: start, endTick: ((end + bar - 1) / bar) * bar)
        } else {
            let start = TimelineRegionPlayer.barStartTick(for: cueTick, loopTicks: loopTicks)
            wanted = TimelineCycle(startTick: start, endTick: start + Swift.min(defaultBars * bar, loopTicks - bar))
        }
        guard let window = wanted.window(loopTicks: loopTicks) else { return nil }
        return TimelineCycle(startTick: window.lowerBound, endTick: window.upperBound)
    }

    /// What a tap on the button will do — its VoiceOver hint, one sentence per state. Pure.
    nonisolated static func hint(locked: Bool, on: Bool, hasProposal: Bool, hasPart: Bool) -> String {
        if locked { return String(localized: "Locked while a recording runs.") }
        if on { return String(localized: "Turns the cycle off, so the whole piece loops again.") }
        if !hasProposal { return String(localized: "Nothing to cycle: the whole piece already loops.") }
        return hasPart ? String(localized: "Loops the selected part's bars.")
                       : String(localized: "Loops four bars from where Play starts.")
    }

    /// "Bar 3 · to bar 4" — the words every part speaks (`SessionGrid.label`, `TrackParts.spanTitle`);
    /// one bar is just "Bar 3".
    nonisolated static func label(_ window: Range<Int>) -> String {
        let first = SessionGrid.label(forTick: window.lowerBound)
        let lastBar = window.upperBound / TimelineTime.ticksPerBar
        return lastBar > window.lowerBound / TimelineTime.ticksPerBar + 1
            ? first + String(localized: " · to bar ") + "\(lastBar)"
            : first
    }
}

/// The transport row's Cycle button: the piece loops a range of its bars, or the whole piece.
struct WorkstationCycleToggle: View {
    @Environment(TimelineStore.self) private var timeline
    @Environment(WorkstationSelection.self) private var selection
    /// Only `cueTick` — cold (a tap on the ruler).
    @Environment(TimelineRegionPlayer.self) private var player
    /// Only `isRecording` — cold (Record, Stop, the piece's end).
    @Environment(RecordController.self) private var recorder

    var body: some View {
        let document = timeline.document
        let loopTicks = TimelineRegionPlayer.loopTicks(for: document)
        let shown = document.cycle?.window(loopTicks: loopTicks)
        let on = shown != nil
        let part = WorkstationSelection.resolvedRegion(selection.regionID, track: selection.trackID, in: document)
            .flatMap { id in document.regions.first { $0.id == id } }
        let proposal = CycleChoice.proposal(part: part, cueTick: player.cueTick, loopTicks: loopTicks)
        let locked = recorder.isRecording
        let enabled = !locked && (on || proposal != nil)
        let hint = CycleChoice.hint(locked: locked, on: on, hasProposal: proposal != nil, hasPart: part != nil)
        Button {
            timeline.setCycle(on ? nil : proposal)
        } label: {
            Image(systemName: "repeat")
                .font(EchoelTheme.font(13, .semibold))
                // ON is the inverted monochrome tile, the look Click and every Workstation switch
                // wear — never green, which is the body's signal and a sounding part.
                .foregroundStyle(enabled ? (on ? EchoelTheme.onPrimary : EchoelTheme.text) : EchoelTheme.dim)
                .frame(minWidth: 44, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .fill(on ? EchoelTheme.text : EchoelTheme.fill))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                    .strokeBorder(on ? Color.clear : EchoelTheme.borderStrong, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(String(localized: "Cycle"))
        .accessibilityValue(shown.map(CycleChoice.label) ?? String(localized: "Off"))
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint(hint)
    }
}

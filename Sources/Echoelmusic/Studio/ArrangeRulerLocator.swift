//
//  ArrangeRulerLocator.swift
//  Echoelmusic — Studio (GMMW AE-7: the ruler locates the piece)
//
//  WHY THIS EXISTS. Every DAW lets you tap the ruler to say where the music plays from; this one
//  had numbers you could not touch, and Play always started at bar 1 (founder 2026-10-08: "Die
//  klassische DAW Audio Editing View fehlt mir noch. Orientiere dich an den Bigplayern").
//  A tap on the ruler now picks a bar:
//  · stopped — Play starts there from now on (`TimelineRegionPlayer.cueTick`, drawn as a line);
//  · playing — the piece also moves there at once (`relocate`, through `locate`).
//  Record and the WAV bounce keep their bar-1 start, and say so in their own words.
//
//  ⚠️ THE NUMBERS STAY A PURE PICTURE. `ArrangeBarRuler` is untouched: cold, untappable, hidden
//  from VoiceOver (`TheArrangeCanvasNamesItsBarsTests`). This leaf wraps it and owns the three new
//  jobs — the tap, the marker, the VoiceOver control — so the rule "the numbers read nothing" holds.
//
//  ⚠️ COLD, AND IT MUST STAY SO. It reads `cueTick` and nothing else of the player: the cue changes
//  on a tap. `currentTick` is never read here — the playhead is `ArrangePlayheadView`'s, a leaf
//  that drives itself (10.76.41/50). ONE call per tap or VoiceOver step, never per drag frame:
//  a drag on the ruler scrolls the time, it never locates (`relocate` says why).
//
//  ⭐ THE NON-GESTURE TWIN. VoiceOver and Switch Control cannot aim a tap at a bar, so the leaf is
//  ONE adjustable element — "Play from, Bar 3" — that moves a bar per swipe up or down, through
//  the same `locate`.
//
//  ⚠️ THE ROW IS A TAP TARGET, so it is at least `EchoelTheme.controlTapHeight` tall — the canvas
//  hands in that height and gives the names column the same empty cell (`rulerRowHeight`). The
//  numbers keep their own scaled height (`numbersHeight`) at the row's foot, so the tick lines do
//  not stretch to the tap floor.
//
//  ⛔ LOCKED WHILE THE PIECE IS BEING WRITTEN DOWN (AE-7 review, HIGH-1 + MED-2). A MIDI take
//  counts its ticks from the transport, which only counts forward (`RecordController`: "nothing
//  seeks the transport") — a jump mid-take would write the notes heard at bar 2 at bar 7. A piece
//  bounce or a loop capture records the output — a jump would bake a cut into the file. So while
//  a take records, a bounce runs or a capture runs, the row neither moves the piece nor the cue,
//  and VoiceOver hears why.
//
//  ⚠️ NO HAPTIC (review LOW-7): a trigger on `cueTick` also fired when Open reset it, and stayed
//  silent on a same-bar tap that did jump. The line moving is the feedback.
//
//  NEEDS-FOUNDER-VERIFY (device): stopped, tap bar 3 on the ruler → a line marks bar 3; Play
//  starts there and its VoiceOver hint names bar 3. Playing, tap bar 5 → the piece moves to bar 5
//  at once, with no click and no gap longer than a bar. Open another piece → Play starts at bar 1.
//

import SwiftUI

/// The pure half: which bar a tap or a VoiceOver step names.
enum RulerLocate {

    /// The downbeat tick of the bar a tap at `x` names on a lane `laneWidth` wide — the scale the
    /// ruler's numbers and the parts sit on (`songTicks`). A tap past the last bar's start names
    /// the last bar; a tap left of the lane names bar 1. Degenerate geometry, or a piece shorter
    /// than one bar, names nothing.
    nonisolated static func barTick(atX x: CGFloat, laneWidth: CGFloat, songTicks: Int) -> Int? {
        let perBar = TimelineTime.ticksPerBar
        let bars = perBar > 0 ? songTicks / perBar : 0
        guard bars > 0, x.isFinite, laneWidth.isFinite, laneWidth > 0 else { return nil }
        let fraction = Double(x / laneWidth).clamped(to: 0...1)
        let bar = Swift.min(bars - 1, Int(fraction * Double(bars)))
        return bar * perBar
    }

    /// One VoiceOver step from the bar Play starts on: a bar later or earlier, never before the
    /// top or past the last bar. nil = no step (already at that edge, or no piece).
    nonisolated static func steppedBarTick(from tick: Int, later: Bool, songTicks: Int) -> Int? {
        let perBar = TimelineTime.ticksPerBar
        let bars = perBar > 0 ? songTicks / perBar : 0
        guard bars > 0 else { return nil }
        let bar = Swift.min(Swift.max(0, tick) / perBar, bars - 1)
        let next = later ? bar + 1 : bar - 1
        guard next >= 0, next < bars else { return nil }
        return next * perBar
    }
}

/// The ruler row of the Arrange canvas: the bar numbers, the line where Play starts, and the tap
/// that moves it.
@MainActor
struct ArrangeRulerLocator: View {

    @Environment(TimelineRegionPlayer.self) private var player
    /// Only `isRecording` — cold (Record, Stop, the piece's end).
    @Environment(RecordController.self) private var recorder
    /// Only `pieceTakeInFlight` and whether a capture runs — cold (a bounce's start and end).
    @Environment(LoopExporter.self) private var exporter

    /// Handed in by the canvas (cold: an edit or an Open) — only to fold the cue the way `play`
    /// folds it (`TimelineRegionPlayer.playStartTick`), so the line marks the bar Play takes.
    let document: TimelineDocument
    let songTicks: Int
    /// The row's height, owned by the canvas (`rulerRowHeight`) so the names stay level.
    let height: CGFloat
    /// The numbers' own scaled height (`rulerHeight`), drawn at the row's foot.
    let numbersHeight: CGFloat

    var body: some View {
        let start = TimelineRegionPlayer.playStartTick(forCue: player.cueTick, in: document)
        let locked = recorder.isRecording || exporter.pieceTakeInFlight || exporter.status == .capturing
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .bottomLeading) {
                ArrangeBarRuler(songTicks: songTicks, height: numbersHeight)
                if let fraction = ArrangeCanvas.playheadFraction(tick: start, songTicks: songTicks) {
                    // Where Play starts. Accent, the colour of the playhead it becomes; 2 pt so it
                    // reads as a marker beside the 1-pt bar lines.
                    Rectangle()
                        .fill(EchoelTheme.accent)
                        .frame(width: 2, height: height)
                        .offset(x: width * fraction)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in
                guard !locked,
                      let tick = RulerLocate.barTick(atX: location.x, laneWidth: width,
                                                     songTicks: songTicks) else { return }
                player.locate(toTick: tick)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Play from"))
        .accessibilityValue(SessionGrid.label(forTick: start))
        .accessibilityHint(locked
            ? String(localized: "Locked while a recording or an audio bounce runs.")
            : String(localized: "Sets the bar Play starts from. While the piece plays, it moves there at once."))
        // AE-7 review (MED-4): VoiceOver's double-tap would otherwise fire the located tap at the
        // element's activation point — the middle of the zoomed piece — and jump there. The
        // default action does nothing; a swipe up or down is the VoiceOver way to move the bar.
        .accessibilityAction { }
        .accessibilityAdjustableAction { direction in
            guard !locked else { return }
            let later: Bool
            switch direction {
            case .increment: later = true
            case .decrement: later = false
            @unknown default: return
            }
            guard let tick = RulerLocate.steppedBarTick(from: start, later: later,
                                                        songTicks: songTicks) else { return }
            player.locate(toTick: tick)
        }
    }
}

/// GMMW AE-3 review (MED-1) — the ruler alone, for focus. Focus takes the canvas off the plate,
/// and with it the one control that moves a stopped playhead; this keeps the same row (the tap,
/// the line where Play starts, the VoiceOver control) over the whole piece at one zoom. Not a
/// second ruler: it IS `ArrangeRulerLocator`, sized the way the canvas sizes it — the numbers
/// scale with the text, the row never drops below the tap floor.
struct ArrangeFocusRuler: View {
    let document: TimelineDocument
    let songTicks: Int
    /// The canvas's `rulerHeight`, same base and same scaling.
    @ScaledMetric(relativeTo: .body) private var numbersHeight: CGFloat = 14

    var body: some View {
        ArrangeRulerLocator(document: document, songTicks: songTicks,
                            height: Swift.max(numbersHeight, EchoelTheme.controlTapHeight),
                            numbersHeight: numbersHeight)
    }
}

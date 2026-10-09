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
//  ⭐ GMMW AE-8 — HOLD, THEN SLIDE, AND YOU HEAR IT. While the piece is stopped, holding the ruler and
//  sliding sounds the audio under the finger, one transport step at a time (`RulerScrub`): a short
//  grain of the FILE under the part that plays there, through the same audition sink the Media
//  Library previews with (`BeatPlayer.audition`). It is an AUDITION, never a locate — the cue does not move, the
//  piece does not start — and it is refused whenever a preview is (`MediaBrowserView.previewRefusal`:
//  the piece or the loop playing, the engine off), and while the row is locked. The drag lives in
//  its own modifier (`RulerScrubGesture`), so this row's own law stands as written: its body holds
//  no drag and no gesture state. Nothing touches the render thread: each grain is one
//  `scheduleSegment` on the audition sink, the way a preview is (MediaBrowserView precedent).
//  ⚠️ WHAT A GRAIN IS NOT (AE-8 review, SHOULD-2): it is the part's FILE at the right file second,
//  not the part as Play renders it. No transpose (a tape-mode or pitched part scrubs at the file's
//  own pitch), no stretch speed (a warped part sounds the right seconds at native speed), no fades,
//  no part level. Carrying pitch would need the sink's time-pitch chain, which `play` attaches only
//  for a stretch. And only the TOP heard track sounds — Play mixes every track.
//  ⚠️ A GRAIN STARTS AND STOPS HARD (the sink's `stop()`), so a fast slide clicks. The pace rule
//  (`mayStartGrain`) lets each grain play `minimumGrainSeconds` before the next may cut it — at
//  zoom 1 on a long piece one point spans several steps, and without it every frame was a grain.
//  ⚠️ Gesture-only: VoiceOver and Switch Control keep the row's adjustable step, which moves where
//  Play starts, and Play then sounds that position — the way to hear a place without a finger.
//  ⚠️ NO AUTO-SCROLL: once the hold began, sliding past the visible edge does not pan a zoomed
//  piece (the part blocks share that limit, `ArrangeTimeZoom`). Lift, scroll, hold again.
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
//  NEEDS-FOUNDER-VERIFY (device, AE-8): stopped, hold the ruler over an audio part and slide → the
//  part's sound follows the finger in short grains; lift → silence; the line where Play starts
//  does not move. Playing, the same hold-and-slide stays silent. A fast slide at zoom 1 over a
//  long piece: grains, not a buzz of clicks? Hold 0.3 s and lift without sliding: does the tap
//  still move the line, or does nothing happen (a long Touch Accommodations hold)? Slide under
//  10 pt and lift: does the line stay put? A Media Library preview playing, then a scrub over a
//  gap: does the preview keep playing?
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

    /// GMMW AE-12b — where the cycle's band sits on the ruler, as fractions of the lane: the window
    /// the player loops (`TimelineCycle.window`), on the ruler's own scale (`songTicks`). nil = no
    /// cycle plays, or a scale that cannot place it. Pure.
    nonisolated static func cycleBand(_ cycle: TimelineCycle?, loopTicks: Int,
                                      songTicks: Int) -> (start: Double, width: Double)? {
        guard songTicks > 0, let window = cycle?.window(loopTicks: loopTicks) else { return nil }
        let start = Double(window.lowerBound) / Double(songTicks)
        let end = Swift.min(Double(window.upperBound) / Double(songTicks), 1)
        guard start < 1, end > start else { return nil }
        return (start, end - start)
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

/// GMMW AE-8 — the pure half of the scrub: which grain of which file a finger on the ruler names.
enum RulerScrub {

    /// What one scrub step sounds: a short stretch of one part's file.
    struct Grain: Equatable, Sendable {
        let regionID: UUID
        /// The resolved file — never a bare reference (#1439).
        let url: URL
        /// Seconds into the file where the step under the finger begins.
        let fromSeconds: Double
        /// The file seconds one transport step covers, cut at the part's end.
        let lengthSeconds: Double
    }

    /// The shortest stretch a grain plays before the next one may cut it. A grain starts and stops
    /// hard, so at 60–120 changes a second a slide was a click train; at this pace it is at most
    /// ~16 grains a second, each long enough to hear as sound.
    static let minimumGrainSeconds: Double = 0.06

    /// Whether a new grain may start `secondsSinceLast` after the last one started. The first grain
    /// of a hold — nil — always may; so does a reading that is not a finite, non-negative span.
    nonisolated static func mayStartGrain(secondsSinceLast elapsed: Double?) -> Bool {
        guard let elapsed, elapsed.isFinite, elapsed >= 0 else { return true }
        return elapsed >= minimumGrainSeconds
    }

    /// The transport step a finger at `x` names on a lane `laneWidth` wide — the grid a scrub sounds
    /// on, finer than the bar a tap names, on the ruler's own scale (`songTicks`). A finger left of
    /// the lane names the first step, one past its end the last. Degenerate geometry, or a piece
    /// shorter than one step, names nothing.
    nonisolated static func stepTick(atX x: CGFloat, laneWidth: CGFloat, songTicks: Int) -> Int? {
        let step = TimelineTime.ticksPerTransportStep
        guard step > 0, songTicks >= step, x.isFinite, laneWidth.isFinite, laneWidth > 0 else { return nil }
        let fraction = Double(x / laneWidth).clamped(to: 0...1)
        let tick = Swift.min(songTicks - 1, Int(fraction * Double(songTicks)))
        return (tick / step) * step
    }

    /// The grain the piece sounds at `tick`: on the first audio track, top to bottom, that is heard
    /// (`MultiRollFanout.audible`: mute, a foreign solo and level 0 silence it) and has a part there,
    /// the part `TimelineScheduling.activeRegion` picks (#1440) — one transport step of its file, on
    /// the stretch the canvas draws (`ArrangeCanvas.audioWindow`, #416). A part at level 0, a file
    /// the player's resolver cannot find (#1439), a clip with no file, or a step past the end of a file
    /// the part outlasts (the sink would play nothing there) passes to the next track.
    /// nil when nothing sounds there or the tempo cannot map.
    nonisolated static func grain(in document: TimelineDocument, atTick tick: Int, bpm: Double,
                                  clip: (UUID) -> Clip?, resolveURL: (UUID) -> URL?) -> Grain? {
        let step = Double(TimelineTime.ticksPerTransportStep)
        for laneID in document.audioLaneIDs where MultiRollFanout.audible(document, laneID: laneID) {
            guard let region = TimelineScheduling.activeRegion(in: document, laneID: laneID, at: tick),
                  region.gain > 0 else { continue }
            let media = clip(region.clipID)
            guard let window = ArrangeCanvas.audioWindow(for: region, clip: media, bpm: bpm),
                  let url = resolveURL(region.clipID) else { continue }
            let secondsPerTick = window.lengthSeconds / Double(region.lengthTicks)
            let from = window.fromSeconds + Double(tick - region.startTick) * secondsPerTick
            let length = Swift.min(step, Double(region.endTick - tick)) * secondsPerTick
            guard from.isFinite, from >= 0, length.isFinite, length > 0 else { continue }
            if let fileSeconds = media?.nativeDurationSeconds, fileSeconds.isFinite, from >= fileSeconds { continue }
            return Grain(regionID: region.id, url: url, fromSeconds: from, lengthSeconds: length)
        }
        return nil
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
                // GMMW AE-12b: the piece's cycle, a muted band under the numbers — the bars Play
                // loops. Read off the document handed in (cold), through the window the player plays.
                if let band = RulerLocate.cycleBand(document.cycle,
                                                    loopTicks: TimelineRegionPlayer.loopTicks(for: document),
                                                    songTicks: songTicks) {
                    Rectangle()
                        .fill(EchoelTheme.fill)
                        .frame(width: width * band.width, height: height)
                        .offset(x: width * band.start)
                }
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
            // GMMW AE-8: hold, then slide — an audition, never a locate.
            .modifier(RulerScrubGesture(document: document, songTicks: songTicks, laneWidth: width,
                                        locked: locked))
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

/// GMMW AE-8 — hold the ruler, then slide: the audio under the finger sounds a step at a time while
/// the piece is stopped.
///
/// ⭐ THE FINGER-RATE STATE LIVES HERE, not in the row: `fingerX` is `@GestureState`, so it resets
/// itself when the finger lifts or the gesture is cancelled — and that reset is what silences the
/// last grain (`onChange` sees nil). The row's body stays cold.
///
/// ⚠️ THE PLAYER IS READ IN THE ACTION, never in `body(content:)`: whether the piece plays, its tempo
/// and its resolver are asked at the moment a grain would sound (10.76.41/50).
///
/// ⚠️ THE PACE IS A REFERENCE, NOT OBSERVED STATE (`Pace`, the `ArrangeTimeZoom` viewport pattern):
/// when the last grain started and whether one of ours is sounding change with every grain, and
/// nothing on screen shows them — a redraw per grain would be pure churn.
@MainActor
private struct RulerScrubGesture: ViewModifier {

    /// The last grain's start and whether a grain of this scrub may still be sounding.
    private final class Pace {
        var lastStart: ContinuousClock.Instant?
        var sounding = false
    }

    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(BeatPlayer.self) private var beatPlayer
    @Environment(AudioEngine.self) private var audioEngine
    @Environment(ClipStore.self) private var clipStore

    let document: TimelineDocument
    let songTicks: Int
    let laneWidth: CGFloat
    /// The row's lock (a take, a bounce, a capture): no grain while the piece is written down.
    let locked: Bool

    /// Where the finger is while a scrub runs, in the row's own points — nil otherwise.
    @GestureState private var fingerX: CGFloat? = nil
    @State private var pace = Pace()

    func body(content: Content) -> some View {
        let tick = fingerX.flatMap { RulerScrub.stepTick(atX: $0, laneWidth: laneWidth, songTicks: songTicks) }
        content
            .overlay(alignment: .leading) {
                // The step under the finger, while it is held: a thin neutral line, never the accent
                // that marks where Play starts.
                if let tick, songTicks > 0 {
                    Rectangle()
                        .fill(EchoelTheme.dim)
                        .frame(width: 1)
                        .offset(x: laneWidth * CGFloat(Double(tick) / Double(songTicks)))
                        .allowsHitTesting(false)
                }
            }
            .gesture(scrub)
            .onChange(of: tick) { _, next in sound(next) }
    }

    /// Hold first, then slide — so a swipe on the ruler still scrolls the piece (the part blocks'
    /// own rule, `ArrangePartBlock.move`).
    private var scrub: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .updating($fingerX) { value, state, _ in
                if case .second(true, let drag?) = value { state = drag.location.x }
            }
    }

    /// One grain for the step the finger entered; silence when it lifts, or when a preview could
    /// not play now — the one rule for that is the Media Library's (`previewRefusal`, #416).
    private func sound(_ tick: Int?) {
        guard let tick, !locked,
              MediaBrowserView.previewRefusal(songPlaying: player.isPlaying,
                                              loopPlaying: beatPlayer.pattern.isPlaying,
                                              engineRunning: audioEngine.isRunning) == nil,
              let grain = RulerScrub.grain(in: document, atTick: tick, bpm: player.preflightTempo,
                                           clip: { clipStore.clip(id: $0) },
                                           resolveURL: { player.audioLanes?.resolvedURL(forClipID: $0) }) else {
            // Only a grain THIS scrub started is stopped: the sink is the Media Library's too, and a
            // step into a gap must not cut a preview playing there (AE-8 review, NIT-5).
            if pace.sounding { beatPlayer.stopAudition() }
            pace.sounding = false
            pace.lastStart = nil
            return
        }
        let now = ContinuousClock.now
        let elapsed = pace.lastStart.map { start -> Double in
            let span = start.duration(to: now).components
            return Double(span.seconds) + Double(span.attoseconds) / 1e18
        }
        // Too soon after the last grain: let it play on; the next step under the finger asks again.
        guard RulerScrub.mayStartGrain(secondsSinceLast: elapsed) else { return }
        pace.lastStart = now
        pace.sounding = true
        beatPlayer.audition(url: grain.url, fromSeconds: grain.fromSeconds, lengthSeconds: grain.lengthSeconds)
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

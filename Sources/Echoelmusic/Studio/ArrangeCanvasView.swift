//
//  ArrangeCanvasView.swift
//  Echoelmusic — Studio (WA4 critical path 4: the Arrange canvas)
//
//  WHY THIS EXISTS. Until now the song was drawn as one thin, read-only strip under each track
//  row (WA4.5), and a part could only be reached through its track's inspector list. The
//  canvas is the arrangement itself: every track that holds parts, one row each, on ONE shared
//  scale, and a part is selected by tapping it. Selecting a part selects its track too
//  (`WorkstationSelection`), so the inspector below opens on the track that owns it.
//
//  ⚠️ ONE GEOMETRY RULE. Block positions come from `ArrangementStrip.blocks` — the pure half
//  WA4.5 already pinned — and draw order is `TrackParts.parts` order, so a later-starting part
//  sits ON TOP of the one it overlaps, which is exactly who `TimelineScheduling.activeRegion`
//  lets play (#1440). The part you tap on top is the part you hear.
//
//  ⚠️ THE CANVAS IS COLD; THE PLAYHEAD IS ITS OWN LEAF. The canvas re-renders only when the
//  document, the selection or the clip grid changes (a tap, a commit, a debounced re-bake — never
//  a clock; since design slice 11 it reads `ClipStore` for the note sketches). The position is `@ObservationIgnored`
//  ~8 Hz state; `ArrangePlayheadView` self-drives with `TimelineView(.animation)` at 15 Hz,
//  paused while the timeline is stopped, and is the ONLY reader of `currentTick` here. A body
//  read of the position in this canvas or in the Workstation would make every ancestor a hot
//  reader and tear down an open `.menu` Picker (10.76.41/50).
//
//  ⭐ DRAG-TO-MOVE (WA4 path D). Press and hold a part, then slide it: it follows the finger on
//  the grid the screen can show (whole bars; beats, then steps, once the time is zoomed wide
//  enough — GMMW AE-11) and lands where its preview sits. The preview is GESTURE-LOCAL — `@GestureState`
//  in `ArrangePartBlock`, so only the dragged block redraws at finger rate and a drag the
//  surrounding scroll view cancels springs back by itself — and the release is ONE bounded
//  commit through `TrackParts.move`, the same store call as the part bar's Earlier/Later, i.e.
//  one undo step. Preview and commit both come from `ArrangeCanvas.dropTick`, so what you see
//  is where it lands.
//  History (classified, not restored): the cut `ArrangeTimelineView` (eb58e7a^) dragged a clip
//  BODY with a `@GestureState` delta and previewed the snapped drop — INTERACTION IDEA PORTED.
//  Its tick conversion (`TimelineDragMath.tickDelta`, still shipped) — ALGORITHM PORTED. Its
//  zoom — RESTORED AS A TIME ZOOM in DAW shell S9a (`ArrangeTimeZoom`, its own file and leaf;
//  the drag converts on the zoomed lane width, so a bar is still a bar). Its snap menu — PORTED AS
//  A RULE, NOT A MENU (GMMW AE-11): the grid follows the zoom through `PartTrim.snapUnit`, the
//  audio editor's own rule, so a cell is never narrower than a fingertip. Its neighbour magnet,
//  lane change and overlap trimming — NOT RESTORED: precedence stays with
//  `TimelineScheduling.activeRegion` (#1440), and rows here are only the tracks with parts, so a
//  vertical drop has no honest target yet. The long press is new, and deliberate: the canvas
//  sits inside the Workstation's vertical scroll, and a bare drag on a part would steal it.
//
//  ⭐ THE DRAG HAS A NON-DRAG TWIN (modes census 2026-09-26, UX F2). A hold-and-slide cannot
//  be performed with VoiceOver or Switch Control, so each block carries two named actions —
//  "Move one bar earlier" / "Move one bar later" — that land through `drop`, i.e. the SAME
//  `TrackParts.move` commit and the part bar's own `earlierStart`/`laterStart` step (#416: no
//  tick maths here). "Earlier" is offered only where a bar earlier exists.
//
//  ⭐ THE BAR RULER (modes census 2026-09-26, design slice 1). The lanes showed WHERE parts sit
//  and nothing said at WHICH bar — the one number the part bar, the parts list and the
//  position readout all speak in. A row of bar numbers now runs above the lanes, on the same
//  scale as the blocks — since S9a in the SAME zoomed column, so a pinch cannot move a number
//  off its bar. `ArrangeCanvas.rulerMarks`
//  thins the numbers by powers of two so a long song never overprints, and the minimum label
//  spacing is a `@ScaledMetric`, so at large text sizes the numbers thin further instead of
//  colliding. The NUMBERS are COLD (they read the song length, never the position) and hidden
//  from VoiceOver: every part already speaks its bar (`SessionGrid.label`), and a list of bare
//  numbers would be noise between the rows.
//  ⭐ GMMW AE-7: the ruler ROW is a control. `ArrangeRulerLocator` wraps the numbers: a tap picks
//  the bar Play starts from (and, while playing, moves the piece there), a line marks it, and
//  VoiceOver hears ONE adjustable "Play from" element. The numbers view itself is unchanged.
//
//  ⭐ WHAT IS SILENT IS SEEN (modes census 2026-09-26, design slice 5). A muted track, and every
//  track another track's solo silences, looked exactly like a playing one — the canvas is where
//  a musician looks to see what the song is doing, and it showed parts that make no sound.
//  `ArrangeCanvas.hearing` names the state; a silenced lane's parts dim, the name gutter
//  carries a SHAPE (a speaker with a slash; headphones for the soloed track), never colour
//  alone, and VoiceOver hears the state on the row and on every part. The rule is the mixer's
//  (`TimelineDocument.effectiveGain`): mute wins over its own solo. Nothing here MUTES or
//  SOLOS — Mute and Solo stay the track header's switches, the ONE control for each. Since A5
//  (founder 2026-10-01) a tap on the name gutter SELECTS the track and opens that header under
//  the canvas; on a phone two 44 pt switches do not fit a 96 pt gutter beside a name.
//
//  ⭐ A PART SHOWS ITS NOTES (modes census 2026-09-26, design slice 11). Every block was the same
//  grey bar, so two parts of one track looked alike and a composer evolve changed nothing on
//  screen. A MIDI part's block now carries one short dash per note, placed along the part and
//  by pitch (`ArrangeCanvas.noteMarks`) — the notes the part PLAYS, windowed by the note
//  editor's own `ClipNoteEdit.visibleNotes`, so a trimmed part shows only what it sounds. The
//  canvas reads the clip grid (cold: an edit, an import, an evolve) and hands each block its
//  marks; the block draws them under its border, they travel with a drag, take no touches and
//  say nothing.
//
//  ⭐ AN AUDIO PART SHOWS ITS WAVEFORM (audio editor W1, founder 2026-10-08: "Die klassische DAW
//  Audio Editing View fehlt mir noch."). An audio part was a plain bar until now. The lane hands
//  each audio part its window (`ArrangeCanvas.audioWindow`: the player's own media position,
//  length and stretch rate, plus the part's gain), and `AudioPartWaveform` draws that stretch of
//  the file — min/max and RMS per column, the pro reduction (`WaveformSketch`). The file is read
//  ONCE per part, off the main actor, and never by this file: the block stays a leaf with one
//  state (the drag). What is drawn is what the part plays — a trimmed part shows its own
//  stretch, a quieter part a smaller wave. The tempo arrives cold (`bpm`), so a glide never
//  re-renders the canvas. ⚠️ COST: each audio part reads its whole file once when it appears,
//  even when two parts share a file — measure on a device before adding a cache.
//

import SwiftUI

/// The pure half of the canvas: which tracks it draws and where the playhead sits.
enum ArrangeCanvas {

    /// The tracks the canvas draws, in the document's order: every non-bio track with parts.
    /// A bio curve is not an arrangement and draws no row.
    nonisolated static func rows(_ summary: WorkstationSummary) -> [WorkstationSummary.LaneRow] {
        summary.lanes.filter { !$0.isBio && $0.regionCount > 0 }
    }

    /// Whether a track also gets a card in the list under the canvas (A5, founder 2026-10-01).
    /// The canvas gutter IS the head of every track it draws, so only the OPEN track (its card
    /// is the inspector's head, holding the one Mute/Solo) and the tracks the canvas cannot draw
    /// (a bio curve, a track with no parts yet) keep a card. Every track has exactly one head.
    nonisolated static func listsCard(_ laneID: UUID, open: UUID?,
                                      canvasRows: [WorkstationSummary.LaneRow]) -> Bool {
        laneID == open || !canvasRows.contains { $0.id == laneID }
    }

    /// What a track's MUTE and SOLO do to it, as the canvas shows it.
    enum Hearing: Equatable, Sendable {
        case plays
        case muted
        case soloed
        /// Another track is soloed and this one is not.
        case silencedBySolo
    }

    /// The track's mute/solo state in `TimelineDocument.effectiveGain`'s order: mute wins over
    /// its own solo, then a solo anywhere silences every track that is not soloed. An unknown
    /// track plays (nothing to dim). The equivalence with `effectiveGain` is DRIVEN by
    /// `TheCanvasShowsWhatIsSilentTests` over every mute/solo combination at full level, so the
    /// two cannot drift apart silently.
    ///
    /// ⚠️ MUTE AND SOLO ONLY — NOT EVERY SILENCE. A track whose level is at zero, or one with no
    /// voice to play it, is silent too, and `effectiveGain` knows the level; the canvas does not
    /// dim either (the track header's level and voice readouts say those). And it reads the
    /// STORE's document: while the song plays, a track added mid-play is not in the player's
    /// snapshot until Stop (`TimelineDocument.mergeMixer`, KNOWN ASYMMETRY), so a solo on it
    /// dims the other rows before it silences them — the header's SOLO tag shares that.
    nonisolated static func hearing(of laneID: UUID, in document: TimelineDocument) -> Hearing {
        guard let lane = document.lanes.first(where: { $0.id == laneID }) else { return .plays }
        if lane.isMuted { return .muted }
        if lane.isSoloed { return .soloed }
        if document.lanes.contains(where: { $0.isSoloed }) { return .silencedBySolo }
        return .plays
    }

    /// Whether the track's parts are drawn dimmed — its mute, or another track's solo, keeps
    /// them from sounding.
    nonisolated static func isSilenced(_ hearing: Hearing) -> Bool {
        hearing == .muted || hearing == .silencedBySolo
    }

    /// The SF Symbol in the name gutter, or nil for a track that simply plays.
    nonisolated static func symbol(_ hearing: Hearing) -> String? {
        switch hearing {
        case .plays:          return nil
        case .muted:          return "speaker.slash.fill"
        case .silencedBySolo: return "speaker.slash"
        case .soloed:         return "headphones"
        }
    }

    /// What VoiceOver adds after the track's name — empty for a track that simply plays.
    nonisolated static func spokenState(_ hearing: Hearing) -> String {
        switch hearing {
        case .plays:          return ""
        case .muted:          return String(localized: ", muted")
        case .soloed:         return String(localized: ", soloed")
        case .silencedBySolo: return String(localized: ", silent while another track is soloed")
        }
    }

    /// The name a part wears on the canvas (A1b): its clip's name, trimmed — empty when the
    /// clip is gone or unnamed, and then the block simply shows no tag. The name is content the
    /// user or the composer wrote, so it is shown as written, never translated.
    nonisolated static func partName(_ clip: Clip?) -> String {
        clip?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Where the playhead sits on the song's scale, 0…1, or nil when there is no scale. A
    /// position past the end (a loop running on) pins to the end instead of leaving the canvas.
    nonisolated static func playheadFraction(tick: Int, songTicks: Int) -> Double? {
        guard songTicks > 0 else { return nil }
        return (Double(tick) / Double(songTicks)).clamped(to: 0...1)
    }

    /// Where a part dragged `dragPoints` across a lane `laneWidth` wide lands: its start moved by
    /// WHOLE GRID CELLS — so an off-grid part keeps its offset and a wobble under half a cell is
    /// no move — never before the song's top. Degenerate geometry is no move.
    ///
    /// ⭐ GMMW AE-11 — THE CELL FOLLOWS THE ZOOM: a bar while a bar is narrow on screen, a beat
    /// once a beat is a fingertip wide, a transport step once a step is. Asked of
    /// `PartTrim.snapUnit` — the audio editor's edge handles snap by the same rule (#416) — at
    /// `snapZoom`, how many touch targets a bar spans here. Never finer than a step: the
    /// transport starts a part only on a step.
    nonisolated static func dropTick(startTick: Int, dragPoints: CGFloat, laneWidth: CGFloat,
                                     songTicks: Int) -> Int {
        guard songTicks > 0, laneWidth.isFinite, laneWidth > 0 else { return startTick }
        let pointsPerBeat = laneWidth * CGFloat(TimelineTime.ticksPerBeat) / CGFloat(songTicks)
        let ticks = TimelineDragMath.tickDelta(fromPoints: dragPoints, ppb: pointsPerBeat)
        let unit = PartTrim.snapUnit(zoom: snapZoom(laneWidth: laneWidth, songTicks: songTicks))
        guard unit > 0 else { return startTick }
        let cells = Int((Double(ticks) / Double(unit)).rounded())
        return Swift.max(0, startTick + cells * unit)
    }

    /// GMMW AE-11 — the zoom `PartTrim.snapUnit` reads on the canvas: how many touch targets
    /// (`AudioPartEditor.handleHitPoints`) one bar spans on a lane `laneWidth` wide — the same
    /// measure the audio editor's `snapZoom` takes, so a grid cell is never narrower than a
    /// fingertip. 0 for degenerate geometry, which `snapUnit` reads as "bars".
    nonisolated static func snapZoom(laneWidth: CGFloat, songTicks: Int) -> Double {
        guard songTicks > 0, laneWidth.isFinite, laneWidth > 0 else { return 0 }
        let pointsPerBar = Double(laneWidth) * Double(TimelineTime.ticksPerBar) / Double(songTicks)
        let zoom = pointsPerBar / AudioPartEditor.handleHitPoints
        return zoom.isFinite && zoom > 0 ? zoom : 0
    }

    /// How far, in points, a part drawn at `startTick` is shown shifted when it will land at
    /// `tick` — the preview of `dropTick`, on the same scale the blocks are placed on.
    nonisolated static func offsetPoints(from startTick: Int, to tick: Int, laneWidth: CGFloat,
                                         songTicks: Int) -> CGFloat {
        guard songTicks > 0, laneWidth.isFinite, laneWidth > 0 else { return 0 }
        return CGFloat(tick - startTick) / CGFloat(songTicks) * laneWidth
    }

    /// One number on the bar ruler: the bar (1-based, as every other surface names it) and
    /// where its downbeat sits on the lane, 0…1 — the scale the blocks are placed on.
    struct RulerMark: Identifiable, Equatable, Sendable {
        let bar: Int
        let fraction: Double
        var id: Int { bar }
    }

    /// The bars the ruler names over a lane `laneWidth` points wide: bar 1, then every `step`-th
    /// bar, `step` the smallest power of two that leaves at least `minSpacing` points between two
    /// numbers — a long song thins its labels instead of overprinting them, and every label
    /// still sits on its downbeat. Positions divide by `songTicks`, exactly as the blocks, the
    /// playhead and `dropTick` do, so a song that is not a whole number of bars would still line
    /// up (review of d16d764b1, LOW-1 — latent today: `ArrangementStrip.songTicks` is always whole
    /// bars, so the two scales agreed; this keeps them agreeing if that ever changes). A number too close to the lane's end to be printed there
    /// is left out rather than spilling past it (LOW-2) — bar 1 always stays. The song's end is
    /// not a bar and is not named. Degenerate geometry, or a song shorter than one bar, names
    /// nothing.
    nonisolated static func rulerMarks(songTicks: Int, laneWidth: CGFloat,
                                       minSpacing: CGFloat) -> [RulerMark] {
        let perBar = TimelineTime.ticksPerBar
        let bars = perBar > 0 ? songTicks / perBar : 0
        guard bars > 0, laneWidth.isFinite, laneWidth > 0,
              minSpacing.isFinite, minSpacing > 0 else { return [] }
        let width = Double(laneWidth)
        let spacing = Double(minSpacing)
        let pointsPerBar = width * Double(perBar) / Double(songTicks)
        var step = 1
        while step < bars, Double(step) * pointsPerBar < spacing { step *= 2 }
        return stride(from: 1, through: bars, by: step).compactMap { bar in
            let fraction = Double((bar - 1) * perBar) / Double(songTicks)
            guard bar == 1 || fraction * width + spacing <= width else { return nil }
            return RulerMark(bar: bar, fraction: fraction)
        }
    }

    /// One note sketched inside a part's block: where it starts and how far it runs along the
    /// part (0…1 of the part's length), and its height (0 = the part's highest note, 1 = its
    /// lowest; a part whose notes share one pitch draws them at the middle).
    struct NoteMark: Equatable, Sendable {
        let start: Double
        let length: Double
        let height: Double
    }

    /// The most notes one block sketches. A denser part is thinned EVENLY along its length —
    /// never cut after the first notes, which would draw a busy part as silent at its end.
    static let maxNoteMarks = 192

    /// A part's notes as the block sketches them — the notes the part PLAYS, windowed exactly
    /// as the note editor and the player window them (`ClipNoteEdit.visibleNotes`), so a trimmed
    /// part shows only what it sounds. An audio part, a part without a clip, and a part whose
    /// window is still in seconds (`windowOffset` = nil) sketch nothing.
    nonisolated static func noteMarks(for region: TimelineRegion, clip: Clip?) -> [NoteMark] {
        guard let clip, clip.kind == .midi,
              let offset = ClipNoteEdit.windowOffset(of: region) else { return [] }
        let notes = ClipNoteEdit.visibleNotes(clip.melody?.notes ?? [], offsetTicks: offset,
                                              lengthTicks: region.lengthTicks)
        return noteMarks(notes, lengthTicks: region.lengthTicks)
    }

    /// The sketch of part-relative notes over a part `lengthTicks` long, in start order. The
    /// pitch span is taken over ALL the notes before any thinning, so thinning a dense part
    /// never changes the height at which a kept note is drawn.
    nonisolated static func noteMarks(_ notes: [Note], lengthTicks: Int) -> [NoteMark] {
        guard lengthTicks > 0,
              let low = notes.map(\.pitch).min(),
              let high = notes.map(\.pitch).max() else { return [] }
        let ordered = notes.sorted { ($0.startTick, $0.pitch) < ($1.startTick, $1.pitch) }
        let every = (ordered.count + maxNoteMarks - 1) / maxNoteMarks
        let span = Double(high - low)
        let length = Double(lengthTicks)
        return stride(from: 0, to: ordered.count, by: Swift.max(1, every)).map { index in
            let note = ordered[index]
            let start = (Double(note.startTick) / length).clamped(to: 0...1)
            let end = (Double(note.startTick + note.lengthTicks) / length).clamped(to: 0...1)
            return NoteMark(start: start, length: Swift.max(0, end - start),
                            height: span > 0 ? Double(high - note.pitch) / span : 0.5)
        }
    }

    /// The stretch of its file an audio part plays (audio editor W1): which file, from where,
    /// for how long, at what level. The waveform leaf draws exactly this window.
    struct AudioWindow: Equatable, Sendable {
        let mediaRef: String
        let fromSeconds: Double
        let lengthSeconds: Double
        let gain: Float
        /// W4c: the part's fade-in and fade-out as they play, each a fraction of the part (0…1)
        /// — tempo-free, because a fade is kept in ticks like the part's length.
        let fadeIn: Double
        let fadeOut: Double

        /// The level the part's fades leave at `fraction` (0…1) of its length — the one fade
        /// rule, asked (`FadeEnvelope`, #416). 1 everywhere for a part without fades.
        func fadeLevel(atFraction fraction: Double) -> Double {
            FadeEnvelope.gain(atElapsed: fraction, duration: 1, fadeIn: fadeIn, fadeOut: fadeOut)
        }
    }

    /// An audio part's window at `bpm`, by the player's own two calls (#416): the media position
    /// at the part's first tick (`AudioRegionPlayback.filePositionSeconds`) and its length in
    /// song time times the region's `StretchPlan` rate — what `AudioLanePlayer.start` hands the
    /// sink at the part's onset. nil for a MIDI part, a part without a clip or a file, and a
    /// tempo that is not a tempo; the block then stays plain.
    nonisolated static func audioWindow(for region: TimelineRegion, clip: Clip?,
                                        bpm: Double) -> AudioWindow? {
        guard let clip, clip.kind == .audio,
              let ref = clip.mediaRef, !ref.isEmpty,
              bpm.isFinite, bpm > 0, region.lengthTicks > 0 else { return nil }
        let plan = StretchPlan.resolve(mode: region.stretchMode, warpEnabled: region.warpEnabled,
                                       nativeBPM: clip.nativeBPM, projectBPM: bpm,
                                       capabilities: StretchMode.timelineCapabilities)
        guard let from = AudioRegionPlayback.filePositionSeconds(for: region, atTick: region.startTick,
                                                                 bpm: bpm, stretchRate: plan.rate) else {
            return nil
        }
        let length = TimelineTime.seconds(fromTicks: region.lengthTicks, bpm: bpm) * plan.rate
        // W4c: the fades as the player plays them, as fractions of the part's own ticks.
        let ticks = Double(region.lengthTicks)
        let fades = FadeEnvelope.effective(fadeIn: Double(region.fadeInTicks),
                                           fadeOut: Double(region.fadeOutTicks), duration: ticks)
        return AudioWindow(mediaRef: ref, fromSeconds: from, lengthSeconds: length, gain: region.gain,
                           fadeIn: fades.fadeIn / ticks, fadeOut: fades.fadeOut / ticks)
    }
}

/// Every track's parts on one scale, each part tappable to select it.
struct ArrangeCanvasView: View {

    @Environment(WorkstationSelection.self) private var selection
    /// Only for the drop's ONE commit (`TrackParts.move`); the canvas reads the song from the
    /// `document` it is handed, never from the store.
    @Environment(TimelineStore.self) private var timeline
    /// Only to sketch each part's notes (design slice 11). Cold for the freeze law — nothing
    /// writes the clip grid per step or per frame, and this canvas hosts no `.menu` Picker —
    /// but not rare (review of c51b1645a, LOW-5): a note edit or undo, an import, Generate, an
    /// evolve (~25–45 s), and the Mix fader's re-bake (`scheduleRebalance`, a TRAILING-edge
    /// 350 ms debounce: it writes once the fader has rested that long, so a continuous drag writes
    /// once at its end and a drag with pauses once per pause — review of 3bab7f277, LOW-12) all
    /// rewrite it.
    ///
    /// ⚠️ THE COST (LOW-7): every canvas render rebuilds every part's sketch — a window, a sort
    /// and a map per part — and the canvas also renders per event while the track inspector's
    /// Level or Pan is dragged (the document changes). Negligible for generated parts; a song of
    /// several imported parts with thousands of notes each pays it per drag event. Measure on a
    /// device before caching — a cache keyed on the clip is a second source of truth.
    @Environment(ClipStore.self) private var clipStore

    let rows: [WorkstationSummary.LaneRow]
    let document: TimelineDocument
    /// The song tempo an audio part's waveform window is taken at (W1) — handed in COLD by the
    /// Workstation (`preflightTempo`, `@ObservationIgnored`), so a tempo glide never re-renders
    /// the canvas; the window follows on the next render. A warped part's window does not
    /// depend on it at all (its rate cancels the tempo).
    let bpm: Double
    let songTicks: Int

    /// Tall enough to hit with a finger and to read a part's sketch at a glance (A1, founder
    /// 2026-10-01: the workstation mockups' lanes; 28 pt read as a strip of grey bars). 44 since
    /// A5: the gutter became a tap target, and a tap target is 44 pt.
    private static let rowHeight: CGFloat = 44
    /// Room for the track's hue band, its instrument symbol and a short name.
    static let nameWidth: CGFloat = 96
    static let gutter: CGFloat = 8
    /// The bar numbers' height, scaled with the text (S9a).
    @ScaledMetric(relativeTo: .body) private var rulerHeight: CGFloat = 14
    /// The ruler ROW — ONE definition, read by the ruler and by the empty cell over the names, so
    /// every name stays level with its lane at every text size. Since GMMW AE-7 the ruler is a
    /// tap target (`ArrangeRulerLocator`), so the row is never shorter than one.
    private var rulerRowHeight: CGFloat { Swift.max(rulerHeight, EchoelTheme.controlTapHeight) }

    var body: some View {
        let selected = WorkstationSelection.resolvedRegion(selection.regionID,
                                                           track: selection.trackID, in: document)
        // ⭐ DAW SHELL S9a (founder 2026-10-02, inbox E16 „Zeit zoomen"): TWO COLUMNS. The names
        // stand still on the left; the ruler, the lanes and the playhead share ONE zoomed width
        // on the right (`ArrangeTimeZoom`), so a pinch spreads the bars and the numbers stay on
        // them by construction. Both columns stack the same heights with the same spacing —
        // the ruler's `rulerHeight`, then `rowHeight` per track — so each name sits beside its
        // lane. VoiceOver reads the names first, then the lanes; every lane and every part says
        // its track's name and state, so no lane is anonymous.
        HStack(alignment: .top, spacing: Self.gutter) {
            VStack(spacing: 4) {
                // The ruler's row in this column is empty, so the names start where the lanes do.
                Color.clear.frame(width: Self.nameWidth, height: rulerRowHeight)
                ForEach(rows) { row in
                    // A name gutter: one line, truncating, at the lane's height. The name AND
                    // its mute/solo symbol grow with the type size inside a FIXED gutter width
                    // and lane height (`nameWidth`, `rowHeight`) (review LOW-3), so at the
                    // largest sizes a silenced track's name shrinks to a few letters — the row
                    // and every part still SAY name and state, and the parts list in the track
                    // inspector is the large-type way in.
                    nameGutter(row)
                        .frame(height: Self.rowHeight)
                }
            }
            ArrangeTimeZoom {
                VStack(spacing: 4) {
                    ArrangeRulerLocator(document: document, songTicks: songTicks, height: rulerRowHeight,
                                        numbersHeight: rulerHeight)
                    ForEach(rows) { row in
                        laneRow(row, selected: selected)
                    }
                }
                .overlay(alignment: .leading) {
                    ArrangePlayheadView(songTicks: songTicks)
                }
            }
        }
    }

    /// The track's head on the canvas (A5): hue, symbol, its mute/solo symbol when it has one,
    /// and the name. A tap selects the track and opens its header (with Mute and Solo) under
    /// the canvas; a second tap closes it — `selection.toggleTrack`, the card's own gesture.
    /// ONE VoiceOver element that says name and state; selection is a trait AND a ring, never
    /// colour alone. Not a `Button`: it selects, it never mutes or solos.
    private func nameGutter(_ row: WorkstationSummary.LaneRow) -> some View {
        let hearing = ArrangeCanvas.hearing(of: row.id, in: document)
        let open = WorkstationSelection.resolvedTrack(selection.trackID, in: document) == row.id
        let hue = EchoelTheme.TrackHue.of(kind: row.kind, instrument: row.instrument, isBio: row.isBio)
        return HStack(spacing: 4) {
            // The track's identity (A1): a hue band and the instrument's symbol in that hue —
            // the colour never travels without the symbol and the name.
            RoundedRectangle(cornerRadius: 1.5)
                .fill(hue.color)
                .frame(width: 3)
            Image(systemName: EchoelTheme.TrackHue.symbol(kind: row.kind, instrument: row.instrument,
                                                          isBio: row.isBio))
                .font(EchoelTheme.font(11))
                .foregroundStyle(hue.color)
            if let symbol = ArrangeCanvas.symbol(hearing) {
                Image(systemName: symbol)
                    .font(EchoelTheme.font(11))
                    .foregroundStyle(EchoelTheme.dim)
            }
            Text(row.name)
                .font(EchoelTheme.font(12))
                .foregroundStyle(EchoelTheme.text)
                .lineLimit(1)
        }
        .frame(width: Self.nameWidth, alignment: .leading)
        .frame(maxHeight: .infinity)
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
            .strokeBorder(open ? EchoelTheme.accent : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { selection.toggleTrack(row.id) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.name + ArrangeCanvas.spokenState(hearing))
        .accessibilityAddTraits(open ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction { selection.toggleTrack(row.id) }
        .accessibilityHint(open ? String(localized: "Closes this track's details")
                                : String(localized: "Opens this track's details: its device, and its mixer and parts where it has them"))
    }

    private func laneRow(_ row: WorkstationSummary.LaneRow, selected: UUID?) -> some View {
        let hearing = ArrangeCanvas.hearing(of: row.id, in: document)
        let spokenName = row.name + ArrangeCanvas.spokenState(hearing)
        let blocks = ArrangementStrip.blocks(onLane: row.id, in: document, songTicks: songTicks)
        let starts = Dictionary(TrackParts.parts(onLane: row.id, in: document)
            .map { ($0.id, $0.startTick) }, uniquingKeysWith: { first, _ in first })
        let tint = EchoelTheme.TrackHue.of(kind: row.kind, instrument: row.instrument, isBio: row.isBio).color
        // The clip grid is read ONCE per lane: each part's own clip gives its sketch and its name.
        let clips: [UUID: (TimelineRegion, Clip?)] = Dictionary(document.regions.filter { $0.laneID == row.id }
            .map { ($0.id, ($0, clipStore.clip(id: $0.clipID))) },
                                                                uniquingKeysWith: { first, _ in first })
        let sketches = clips.mapValues { ArrangeCanvas.noteMarks(for: $0.0, clip: $0.1) }
        let names = clips.mapValues { ArrangeCanvas.partName($0.1) }
        // W1: the same one read of the clip grid gives each AUDIO part the stretch of its file
        // it plays; a MIDI part gets nil and keeps its note sketch.
        let waves = clips.compactMapValues { ArrangeCanvas.audioWindow(for: $0.0, clip: $0.1, bpm: bpm) }
        return GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .fill(EchoelTheme.fill)
                ForEach(blocks) { block in
                    let start = starts[block.id] ?? 0
                    ArrangePartBlock(block: block, startTick: start,
                                     isSelected: block.id == selected,
                                     laneWidth: width, songTicks: songTicks,
                                     label: spokenName + String(localized: ", part at ") + SessionGrid.label(forTick: start),
                                     noteMarks: sketches[block.id] ?? [],
                                     audio: waves[block.id],
                                     name: names[block.id] ?? "",
                                     tint: tint,
                                     onSelect: { selection.selectRegion(block.id, in: document) },
                                     onDrop: { tick in drop(block.id, onLane: row.id, from: start, to: tick) },
                                     onStep: { later in step(block.id, onLane: row.id, later: later) })
                }
            }
            // Dimmed, not hidden: the parts are still there to select and move — they make no
            // sound. Opacity only (Uncodixfy), and never the only cue (the gutter's symbol).
            .opacity(ArrangeCanvas.isSilenced(hearing) ? 0.45 : 1)
        }
        .frame(height: Self.rowHeight)
        // The row speaks as a group — the track and where its parts start (the one label
        // rule, `ArrangementStrip.spoken`) — and each part inside it is its own button.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(spokenName): " + ArrangementStrip.spoken(onLane: row.id, in: document))
    }

    /// The release of a drag: select the part, then ONE store edit — or nothing, when it lands
    /// where it started (no empty undo step).
    private func drop(_ regionID: UUID, onLane laneID: UUID, from startTick: Int, to tick: Int) {
        selection.selectRegion(regionID, in: document)
        guard tick != startTick,
              let part = TrackParts.parts(onLane: laneID, in: document)
                .first(where: { $0.id == regionID }) else { return }
        TrackParts.move(part, toStartTick: tick, timeline: timeline)
    }

    /// The drag's non-drag twin: one bar through the part bar's own step, landed by `drop`.
    /// It says where the part landed: VoiceOver does not re-read a label that changes after a
    /// custom action, so without the announcement the move is silent to the one user group the
    /// actions exist for.
    private func step(_ regionID: UUID, onLane laneID: UUID, later: Bool) {
        guard let part = TrackParts.parts(onLane: laneID, in: document)
                .first(where: { $0.id == regionID }) else { return }
        let target: Int? = later ? TrackParts.laterStart(part) : TrackParts.earlierStart(part)
        guard let target else { return }
        drop(regionID, onLane: laneID, from: part.startTick, to: target)
        AccessibilityNotification.Announcement(String(localized: "Part at ") + SessionGrid.label(forTick: target)).post()
    }
}

/// The bar numbers over the lanes. Cold: it reads the song length it is handed and nothing
/// else — no position, no store, no selection.
struct ArrangeBarRuler: View {

    let songTicks: Int
    /// Handed in by the canvas, which owns the one scaled value (S9a): the empty cell over the
    /// names reads the same number, so the names and the lanes stay level.
    let height: CGFloat

    /// Scaled with the text, so a larger size thins the numbers rather than colliding them.
    @ScaledMetric(relativeTo: .body) private var labelSpacing: CGFloat = 28

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                ForEach(ArrangeCanvas.rulerMarks(songTicks: songTicks, laneWidth: width,
                                                 minSpacing: labelSpacing)) { mark in
                    HStack(spacing: 3) {
                        Rectangle()
                            .fill(EchoelTheme.border)
                            .frame(width: 1)
                        Text("\(mark.bar)")
                            .font(EchoelTheme.font(11).monospacedDigit())
                            .foregroundStyle(EchoelTheme.dim)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .offset(x: width * mark.fraction)
                }
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The song position over the canvas. The ONLY reader of `currentTick` on this surface: it
/// self-drives at 15 Hz while the timeline plays and is paused (and absent) while it is
/// stopped, so nothing above it ever observes the position.
struct ArrangePlayheadView: View {

    @Environment(TimelineRegionPlayer.self) private var player

    let songTicks: Int

    var body: some View {
        let playing = player.isPlaying
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing)) { _ in
            GeometryReader { geometry in
                if playing,
                   let fraction = ArrangeCanvas.playheadFraction(tick: player.currentTick,
                                                                 songTicks: songTicks) {
                    Rectangle()
                        .fill(EchoelTheme.accent)
                        .frame(width: 1)
                        .offset(x: geometry.size.width * fraction)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One part on a lane: tap to select it; press, hold and slide to move it by whole bars.
///
/// ⭐ THE ONLY FINGER-RATE STATE IN THIS FILE (the time zoom's pinch lives in its own leaf,
/// `ArrangeTimeZoom`, since S9a). `dragPoints` is `@GestureState`, so it lives
/// in this leaf alone (only this block redraws while it moves) and resets itself when the
/// scroll view cancels the gesture — a plain `@State` delta stuck there and left the part
/// drawn away from where it sits (the cut arrange view's #56 C2). Nothing is written until the
/// finger lifts, and then exactly once, through `onDrop`.
struct ArrangePartBlock: View {

    let block: ArrangementStrip.Block
    let startTick: Int
    let isSelected: Bool
    let laneWidth: CGFloat
    let songTicks: Int
    let label: String
    /// The part's notes, sketched small (design slice 11) — empty for an audio part.
    let noteMarks: [ArrangeCanvas.NoteMark]
    /// An audio part's stretch of its file (W1), drawn as its waveform — nil for a MIDI part.
    let audio: ArrangeCanvas.AudioWindow?
    /// Its clip's name (A1b), shown top-left inside the block; empty = no tag.
    let name: String
    /// Its track's hue (A1): the part wears the colour of the track it sits on.
    let tint: Color
    let onSelect: () -> Void
    let onDrop: (Int) -> Void
    /// The drag's non-drag twin (true = one bar later) — see the file header.
    let onStep: (Bool) -> Void

    @GestureState private var dragPoints: CGFloat = 0

    var body: some View {
        let landing = ArrangeCanvas.dropTick(startTick: startTick, dragPoints: dragPoints,
                                             laneWidth: laneWidth, songTicks: songTicks)
        let shift = ArrangeCanvas.offsetPoints(from: startTick, to: landing,
                                               laneWidth: laneWidth, songTicks: songTicks)
        let moving = dragPoints != 0
        RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
            .fill(tint.opacity(Self.tintOpacity))
            .overlay { noteSketch }
            .overlay { audioSketch }
            .overlay(alignment: .topLeading) { nameTag }
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .strokeBorder(isSelected || moving ? EchoelTheme.accent : tint.opacity(Self.edgeOpacity),
                              lineWidth: isSelected || moving ? 2 : 1))
            .opacity(moving ? 0.8 : 1)
            // A part being moved draws over its neighbours, not under a later-starting one
            // (review of e3211f21d, L4); at rest the draw order is the play order again.
            .zIndex(moving ? 1 : 0)
            .frame(width: Swift.max(2, laneWidth * block.width))
            .offset(x: laneWidth * block.start + shift)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .gesture(move)
            // UX audit slice 13b: a light tick each time the preview snaps to another grid cell
            // (a bar, or a beat or step once zoomed — AE-11), so the hand feels the grid it lands
            // on. Triggered by the SNAPPED landing, never the raw finger — one tick per cell, not
            // one per frame — and by nothing it writes.
            .sensoryFeedback(.selection, trigger: landing)
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityValue(name)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction { onSelect() }
            .accessibilityActions {
                if startTick > 0 {
                    Button("Move one bar earlier") { onStep(false) }
                }
                Button("Move one bar later") { onStep(true) }
            }
    }

    /// The part's name, top-left (A1b) — read first, so a song reads as named sections rather
    /// than coloured bars. One line, truncated at the block's edge, clipped to it at large text
    /// sizes; it takes no touches, and VoiceOver hears it as the block's value.
    @ViewBuilder private var nameTag: some View {
        if !name.isEmpty {
            Text(name)
                .font(EchoelTheme.font(11, .medium))
                .foregroundStyle(EchoelTheme.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 4)
                .padding(.top, 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The notes, one short dash each, drawn inside the block (design slice 11): the part shows
    /// its melody's shape, and it travels with the block while it is dragged. It takes no
    /// touches and says nothing — the block speaks for the part.
    private var noteSketch: some View {
        Canvas { context, size in
            let dash = Swift.min(Self.dashHeight, size.height)
            for mark in noteMarks {
                let rect = CGRect(x: CGFloat(mark.start) * size.width,
                                  y: CGFloat(mark.height) * (size.height - dash),
                                  width: Swift.max(1, CGFloat(mark.length) * size.width),
                                  height: dash)
                context.fill(Path(rect), with: .color(tint))
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        // Below the name tag, so the dashes never run through the letters.
        .padding(.top, name.isEmpty ? 0 : Self.nameRoom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// How thick one note is drawn — thin enough that a busy part still reads as a shape.
    private static let dashHeight: CGFloat = 2
    /// The height the name tag claims at the top of the block (11 pt text plus its inset).
    private static let nameRoom: CGFloat = 13
    /// The part's body is its track's hue, muted, so the full-strength dashes read on it and
    /// the selection ring (`accent`, 2 pt) stays the loudest edge on the lane.
    private static let tintOpacity: Double = 0.30
    private static let edgeOpacity: Double = 0.70

    /// An audio part's waveform (W1), under the name tag and the selection ring like the note
    /// sketch. The reading and its state live in `AudioPartWaveform`, never here: this leaf
    /// keeps exactly one piece of state, the drag.
    @ViewBuilder private var audioSketch: some View {
        if let audio {
            // No horizontal inset, on purpose: the wave spans the block edge to edge so a hit
            // sits on the same scale as the ruler and the playhead above it.
            AudioPartWaveform(window: audio, tint: tint)
                .padding(.vertical, EchoelTheme.spaceXS)
                .padding(.top, name.isEmpty ? 0 : Self.nameRoom)
        }
    }

    /// Hold first, then slide — so a swipe that starts on a part still scrolls the Workstation.
    private var move: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($dragPoints) { value, state, _ in
                if case .second(true, let drag?) = value { state = drag.translation.width }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                onDrop(ArrangeCanvas.dropTick(startTick: startTick,
                                              dragPoints: drag.translation.width,
                                              laneWidth: laneWidth, songTicks: songTicks))
            }
    }
}

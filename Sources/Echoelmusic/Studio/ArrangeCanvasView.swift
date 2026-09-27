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
//  ⭐ DRAG-TO-MOVE (WA4 path D). Press and hold a part, then slide it: it follows the finger in
//  whole bars and lands where its preview sits. The preview is GESTURE-LOCAL — `@GestureState`
//  in `ArrangePartBlock`, so only the dragged block redraws at finger rate and a drag the
//  surrounding scroll view cancels springs back by itself — and the release is ONE bounded
//  commit through `TrackParts.move`, the same store call as the part bar's Earlier/Later, i.e.
//  one undo step. Preview and commit both come from `ArrangeCanvas.dropTick`, so what you see
//  is where it lands.
//  History (classified, not restored): the cut `ArrangeTimelineView` (eb58e7a^) dragged a clip
//  BODY with a `@GestureState` delta and previewed the snapped drop — INTERACTION IDEA PORTED.
//  Its tick conversion (`TimelineDragMath.tickDelta`, still shipped) — ALGORITHM PORTED. Its
//  zoom, snap menu, neighbour magnet, lane change and overlap trimming — NOT RESTORED: the
//  canvas has one fixed scale, the part bar's one-bar step is the grid, precedence stays with
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
//  scale as the blocks (`nameWidth + gutter` in, `laneWidth` wide). `ArrangeCanvas.rulerMarks`
//  thins the numbers by powers of two so a long song never overprints, and the minimum label
//  spacing is a `@ScaledMetric`, so at large text sizes the numbers thin further instead of
//  colliding. The ruler is COLD (it reads the song length, never the position) and hidden from
//  VoiceOver: every part already speaks its bar (`SessionGrid.label`), and a list of bare
//  numbers would be noise between the rows.
//
//  ⭐ WHAT IS SILENT IS SEEN (modes census 2026-09-26, design slice 5). A muted track, and every
//  track another track's solo silences, looked exactly like a playing one — the canvas is where
//  a musician looks to see what the song is doing, and it showed parts that make no sound.
//  `ArrangeCanvas.hearing` names the state; a silenced lane's parts dim, the name gutter
//  carries a SHAPE (a speaker with a slash; headphones for the soloed track), never colour
//  alone, and VoiceOver hears the state on the row and on every part. The rule is the mixer's
//  (`TimelineDocument.effectiveGain`): mute wins over its own solo. Nothing here is tappable —
//  Mute and Solo stay the track header's switches, the ONE control for each.
//
//  ⭐ A PART SHOWS ITS NOTES (modes census 2026-09-26, design slice 11). Every block was the same
//  grey bar, so two parts of one track looked alike and a composer evolve changed nothing on
//  screen. A MIDI part's block now carries one short dash per note, placed along the part and
//  by pitch (`ArrangeCanvas.noteMarks`) — the notes the part PLAYS, windowed by the note
//  editor's own `ClipNoteEdit.visibleNotes`, so a trimmed part shows only what it sounds. The
//  canvas reads the clip grid (cold: an edit, an import, an evolve) and hands each block its
//  marks; the block draws them under its border, they travel with a drag, take no touches and
//  say nothing. An audio part stays plain — its waveform is not read here.
//

import SwiftUI

/// The pure half of the canvas: which tracks it draws and where the playhead sits.
enum ArrangeCanvas {

    /// The tracks the canvas draws, in the document's order: every non-bio track with parts.
    /// A bio curve is not an arrangement and draws no row.
    nonisolated static func rows(_ summary: WorkstationSummary) -> [WorkstationSummary.LaneRow] {
        summary.lanes.filter { !$0.isBio && $0.regionCount > 0 }
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
        case .muted:          return ", muted"
        case .soloed:         return ", soloed"
        case .silencedBySolo: return ", silent while another track is soloed"
        }
    }

    /// Where the playhead sits on the song's scale, 0…1, or nil when there is no scale. A
    /// position past the end (a loop running on) pins to the end instead of leaving the canvas.
    nonisolated static func playheadFraction(tick: Int, songTicks: Int) -> Double? {
        guard songTicks > 0 else { return nil }
        return (Double(tick) / Double(songTicks)).clamped(to: 0...1)
    }

    /// Where a part dragged `dragPoints` across a lane `laneWidth` wide lands: its start moved by
    /// WHOLE BARS — the part bar's step, so an off-grid part keeps its offset and a small wobble
    /// is no move — never before the song's top. Degenerate geometry is no move.
    nonisolated static func dropTick(startTick: Int, dragPoints: CGFloat, laneWidth: CGFloat,
                                     songTicks: Int) -> Int {
        guard songTicks > 0, laneWidth.isFinite, laneWidth > 0 else { return startTick }
        let pointsPerBeat = laneWidth * CGFloat(TimelineTime.ticksPerBeat) / CGFloat(songTicks)
        let ticks = TimelineDragMath.tickDelta(fromPoints: dragPoints, ppb: pointsPerBeat)
        let bars = Int((Double(ticks) / Double(TimelineTime.ticksPerBar)).rounded())
        return Swift.max(0, startTick + bars * TimelineTime.ticksPerBar)
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
    /// evolve (~25–45 s), and the Mix fader's re-bake (`scheduleRebalance`, debounced 350 ms —
    /// a few writes a second during a stepwise drag) all rewrite it.
    ///
    /// ⚠️ THE COST (LOW-7): every canvas render rebuilds every part's sketch — a window, a sort
    /// and a map per part — and the canvas also renders per event while the track inspector's
    /// Level or Pan is dragged (the document changes). Negligible for generated parts; a song of
    /// several imported parts with thousands of notes each pays it per drag event. Measure on a
    /// device before caching — a cache keyed on the clip is a second source of truth.
    @Environment(ClipStore.self) private var clipStore

    let rows: [WorkstationSummary.LaneRow]
    let document: TimelineDocument
    let songTicks: Int

    /// Tall enough to hit with a finger; the rows carry no text inside the lane itself.
    private static let rowHeight: CGFloat = 28
    static let nameWidth: CGFloat = 76
    static let gutter: CGFloat = 8

    var body: some View {
        let selected = WorkstationSelection.resolvedRegion(selection.regionID,
                                                           track: selection.trackID, in: document)
        VStack(spacing: 4) {
            // The bar ruler — the gutter left empty so its numbers start where the lanes do.
            HStack(spacing: Self.gutter) {
                Color.clear.frame(width: Self.nameWidth, height: 1)
                ArrangeBarRuler(songTicks: songTicks)
            }
            ForEach(rows) { row in
                HStack(spacing: Self.gutter) {
                    // A name gutter: one line, truncating, so every lane starts at the same x
                    // and the rows line up bar for bar. The name AND its mute/solo symbol grow
                    // with the type size inside a FIXED gutter width and 28 pt lane height
                    // (review LOW-3), so at the largest sizes a silenced track's name shrinks to
                    // a few letters — the row and every part still SAY name and state, and the
                    // parts list in the track inspector is the large-type way in.
                    nameGutter(row)
                    laneRow(row, selected: selected)
                }
                .frame(minHeight: Self.rowHeight)
            }
        }
        .overlay(alignment: .leading) {
            ArrangePlayheadView(songTicks: songTicks)
                .padding(.leading, Self.nameWidth + Self.gutter)
        }
    }

    /// The track's name, led by its mute/solo symbol when it has one. Hidden from VoiceOver:
    /// the row and every part speak the name AND the state themselves.
    private func nameGutter(_ row: WorkstationSummary.LaneRow) -> some View {
        let hearing = ArrangeCanvas.hearing(of: row.id, in: document)
        return HStack(spacing: 3) {
            if let symbol = ArrangeCanvas.symbol(hearing) {
                Image(systemName: symbol)
                    .font(EchoelTheme.font(10))
                    .foregroundStyle(EchoelTheme.dim)
            }
            Text(row.name)
                .font(EchoelTheme.font(12))
                .foregroundStyle(EchoelTheme.dim)
                .lineLimit(1)
        }
        .frame(width: Self.nameWidth, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func laneRow(_ row: WorkstationSummary.LaneRow, selected: UUID?) -> some View {
        let hearing = ArrangeCanvas.hearing(of: row.id, in: document)
        let spokenName = row.name + ArrangeCanvas.spokenState(hearing)
        let blocks = ArrangementStrip.blocks(onLane: row.id, in: document, songTicks: songTicks)
        let starts = Dictionary(TrackParts.parts(onLane: row.id, in: document)
            .map { ($0.id, $0.startTick) }, uniquingKeysWith: { first, _ in first })
        let sketches = Dictionary(document.regions.filter { $0.laneID == row.id }
            .map { ($0.id, ArrangeCanvas.noteMarks(for: $0, clip: clipStore.clip(id: $0.clipID))) },
                                  uniquingKeysWith: { first, _ in first })
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
                                     label: "\(spokenName), part at " + SessionGrid.label(forTick: start),
                                     noteMarks: sketches[block.id] ?? [],
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
        AccessibilityNotification.Announcement("Part at " + SessionGrid.label(forTick: target)).post()
    }
}

/// The bar numbers over the lanes. Cold: it reads the song length it is handed and nothing
/// else — no position, no store, no selection.
struct ArrangeBarRuler: View {

    let songTicks: Int

    /// Scaled with the text, so a larger size thins the numbers rather than colliding them.
    @ScaledMetric(relativeTo: .body) private var labelSpacing: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 14

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
                            .font(EchoelTheme.font(10).monospacedDigit())
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
/// ⭐ THE ONLY FINGER-RATE STATE ON THE CANVAS. `dragPoints` is `@GestureState`, so it lives
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
            .fill(EchoelTheme.dim)
            .overlay { noteSketch }
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .strokeBorder(isSelected || moving ? EchoelTheme.accent : EchoelTheme.border,
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
            .accessibilityElement()
            .accessibilityLabel(label)
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
                context.fill(Path(rect), with: .color(EchoelTheme.surface))
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// How thick one note is drawn — thin enough that a busy part still reads as a shape.
    private static let dashHeight: CGFloat = 2

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

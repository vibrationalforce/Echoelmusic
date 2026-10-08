//
//  AudioPartEditorView.swift
//  Echoelmusic — Studio (GMMW AE-2, founder 2026-10-08: "Die klassische DAW Audio Editing View
//  fehlt mir noch.")
//
//  WHY THIS EXISTS. An audio part's wave sat only inside its block on the Arrange canvas — a
//  strip a few points tall, cut to the stretch the part plays. Every DAW's audio editor shows
//  the WHOLE file with the part's window marked on it, so a person can see what the part leaves
//  out before and after, where the hits are, and where the song is in the file. This is that
//  view, on the selected track's Part page, above the part list. It was read-only in AE-2. Since
//  AE-4b its two window edges are handles (`AudioPartEdgeHandles`, below) that ask the trim
//  rules that already exist (`PartTrim`) rather than a lookalike; the fade, gain and slip
//  handles are AE-5 and AE-6.
//
//  ⭐ NO NEW TRUTH (#416). The part's window is `ArrangeCanvas.audioWindow` — the player's own
//  file position and stretch rate, the stretch the canvas block draws. The file is read by
//  `WaveformSketch.overview(ofRef:)` and cut into columns by `WaveformSketch.window`, the
//  canvas leaf's bucket rule. The fade level is the window's own `fadeLevel` (`FadeEnvelope`).
//  The file's length is the one measured at import (`Clip.nativeDurationSeconds`); a clip from
//  an older build without it takes the overview's own length once read.
//
//  ⚠️ THE FILE IS FOUND BY THE PLAYER'S RESOLVER (#1439). `MediaLibrary.resolveRef` is the
//  function the app's injected `resolveURL:` closure calls for `AudioLanePlayer`; it is asked
//  here OFF the main actor, inside the detached read, as `WaveformSketch` asks it — the
//  player's own `resolvedURL(forClipID:)` wrapper is main-actor state and would put a file-
//  system probe in `body`. So the editor says "file not found" exactly when the player skips
//  the part.
//
//  ⚠️ THE READ IS OFF THE MAIN ACTOR AND CANCELLABLE, the `AudioPartWaveform` shape: a
//  `Task.detached` read whose cancellation the `.task(id:)` forwards — a part deselected or
//  re-pointed mid-read stops within one chunk and never lands over the newer one. It lands in
//  `@State` once per file. This is a SECOND read of a file the canvas block may already have
//  read; it happens once per selected file, detached and bounded by `WaveformSketch`'s caps.
//
//  ⚠️ NOTHING IN THE EDITOR'S BODY IS HOT. The selection changes on a tap, the document on an
//  edit, the tempo is `preflightTempo` (`@ObservationIgnored`, the number the canvas draws by).
//  The song position is read ONLY inside `AudioPartPlayheadView`, a self-driving 15 Hz leaf that
//  is paused while the song is stopped — the `PartNotePlayheadView` shape, one page over. A
//  position read in this body would rebuild the Part page 15 times a second (10.76.41/50).
//
//  ⚠️ NO MODAL. The editor is inline on a page that already exists: no sheet, no cover, no
//  popover, no new page word (the black-screen law on the presentation chain).
//

import SwiftUI

/// The pure half: which part the editor shows, what its header says, and where on the file the
/// part and the song are.
enum AudioPartEditor {

    /// What the editor draws for the selected part.
    struct Subject: Equatable, Sendable {
        let regionID: UUID
        let partStartTick: Int
        let lengthTicks: Int
        /// The stretch of the file the part plays (the canvas's own, #416).
        let window: ArrangeCanvas.AudioWindow
        /// The clip's name as the canvas block shows it; empty when it has none.
        let name: String
        /// The file's length measured at import, or nil for a clip from before that measurement.
        let fileSeconds: Double?
        /// The tempo the part's MEDIA elapses at (`PartSplit.mediaBPM`): the song tempo for an
        /// unwarped part, divided by the stretch rate for a warped one. A tick of the part is this
        /// many seconds of the file, so an edge handle converts a slide to ticks at this tempo.
        let mediaBPM: Double?
    }

    /// How far the file read has got.
    enum Load: Equatable, Sendable {
        case reading
        /// The player's resolver finds no file: the part plays silence (#1439).
        case missing
        /// The file is there but cannot be drawn (unreadable, empty, or past the read caps).
        case unreadable
        case ready(WaveformSketch.Overview)
    }

    /// The selected part when it sits on THIS track — nil for no selection or a part elsewhere.
    nonisolated static func selectedPart(_ regionID: UUID?, track laneID: UUID,
                                         in document: TimelineDocument) -> TimelineRegion? {
        guard let regionID else { return nil }
        return document.regions.first { $0.id == regionID && $0.laneID == laneID }
    }

    /// The editor's subject for a part and its clip at the cold tempo, or nil when the part does
    /// not play a stretch of a file — a MIDI part, a clip without a file, a tempo that is not a
    /// tempo (the gate is `ArrangeCanvas.audioWindow`'s own). A non-finite or non-positive
    /// measured length counts as unmeasured.
    nonisolated static func subject(for region: TimelineRegion, clip: Clip?, bpm: Double) -> Subject? {
        guard let window = ArrangeCanvas.audioWindow(for: region, clip: clip, bpm: bpm) else { return nil }
        let measured = clip?.nativeDurationSeconds.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        return Subject(regionID: region.id, partStartTick: region.startTick, lengthTicks: region.lengthTicks,
                       window: window, name: ArrangeCanvas.partName(clip), fileSeconds: measured,
                       mediaBPM: PartSplit.mediaBPM(for: region, clip: clip, projectBPM: bpm))
    }

    /// The file's length to draw against: the measured one, else the overview's own once read
    /// (its last bucket may cover less, so it can read long by at most one bucket), else nil.
    nonisolated static func fileSeconds(_ subject: Subject, load: Load) -> Double? {
        if let measured = subject.fileSeconds { return measured }
        guard case .ready(let overview) = load else { return nil }
        let seconds = Double(overview.buckets.count) * overview.secondsPerBucket
        return seconds.isFinite && seconds > 0 ? seconds : nil
    }

    /// The part's window on the file, as fractions of the file (0…1): where the part starts
    /// playing and where it stops. A part that runs past the file's end is cut at 1 (it plays
    /// silence there, `WaveformSketch.window`'s rule). nil for degenerate input or a window
    /// wholly outside the file.
    nonisolated static func span(of window: ArrangeCanvas.AudioWindow, fileSeconds: Double) -> ClosedRange<Double>? {
        guard fileSeconds.isFinite, fileSeconds > 0, window.fromSeconds.isFinite,
              window.lengthSeconds.isFinite, window.lengthSeconds > 0 else { return nil }
        let start = window.fromSeconds / fileSeconds
        let end = (window.fromSeconds + window.lengthSeconds) / fileSeconds
        guard end > 0, start < 1 else { return nil }
        return start.clamped(to: 0...1)...end.clamped(to: 0...1)
    }

    /// Where the song is on the file, 0…1, or nil when the song is not inside the part (before
    /// its start, at or past its end), the input is degenerate, or the point lies past the
    /// file's end. Measured from the part's start, through the part's own window: a tick a
    /// fraction into the part is that fraction into the window.
    nonisolated static func playheadFraction(tick: Int, partStartTick: Int, lengthTicks: Int,
                                             window: ArrangeCanvas.AudioWindow, fileSeconds: Double) -> Double? {
        guard lengthTicks > 0, fileSeconds.isFinite, fileSeconds > 0,
              window.fromSeconds.isFinite, window.lengthSeconds.isFinite else { return nil }
        let into = tick - partStartTick
        guard into >= 0, into < lengthTicks else { return nil }
        let seconds = window.fromSeconds + Double(into) / Double(lengthTicks) * window.lengthSeconds
        let fraction = seconds / fileSeconds
        guard fraction.isFinite, fraction >= 0, fraction <= 1 else { return nil }
        return fraction
    }

    /// The header's second line: what the part plays of the file, in seconds — or why there is
    /// no wave. Science first: the numbers, then nothing decorative.
    nonisolated static func summary(_ subject: Subject, load: Load) -> String {
        switch load {
        case .missing:
            return String(localized: "File not found — this part plays silence")
        case .unreadable:
            return String(localized: "This file cannot be drawn")
        case .reading, .ready:
            let from = subject.window.fromSeconds
            let to = from + subject.window.lengthSeconds
            let plays = String(localized: "Plays ") + seconds(from) + "–" + seconds(to) + " s"
            guard let total = fileSeconds(subject, load: load) else { return plays }
            return plays + String(localized: " of ") + seconds(total) + " s"
        }
    }

    /// A time in seconds with two decimals, in the reader's locale.
    nonisolated static func seconds(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    // MARK: AE-4b — the two edges a hold-and-slide moves

    /// Which edge of the part a handle moves.
    enum Edge: Equatable, Sendable {
        case start
        case end
    }

    /// A slide in progress: which edge, and how far the finger has gone, in points.
    struct EdgeDrag: Equatable, Sendable {
        let edge: Edge
        let points: Double
    }

    /// What a released slide writes: ONE store call, the one each edge already has.
    enum EdgeEdit: Equatable, Sendable {
        /// `TimelineStore.trimRegionStart(id:toTick:bpm:)` — the start moves, the file under it
        /// stays where it was in the song.
        case start(tick: Int)
        /// `TimelineStore.resizeRegion(id:lengthTicks:)` — the end moves.
        case end(lengthTicks: Int)
    }

    /// The smallest touch area a handle has: the platform's 44-pt target.
    nonisolated static let handleHitPoints: Double = 44

    /// The zoom `PartTrim.snapUnit` reads, for an editor that draws a whole file of
    /// `fileSeconds` over `widthPoints`: how many touch targets one bar spans. A beat is a quarter
    /// of a bar and a transport step a quarter of a beat, so the rule's two thresholds (4 and 16)
    /// pick the finest grid whose cell is at least one target wide — a handle never snaps to a
    /// line a finger cannot tell from its neighbour. nil for unusable input.
    nonisolated static func snapZoom(widthPoints: Double, fileSeconds: Double, mediaBPM: Double) -> Double? {
        guard widthPoints.isFinite, widthPoints > 0, fileSeconds.isFinite, fileSeconds > 0,
              mediaBPM.isFinite, mediaBPM > 0 else { return nil }
        let barSeconds = TimelineTime.seconds(fromTicks: TimelineTime.ticksPerBar, bpm: mediaBPM)
        let zoom = widthPoints / fileSeconds * barSeconds / handleHitPoints
        return zoom.isFinite && zoom > 0 ? zoom : nil
    }

    /// The song tick an edge sits at after a slide, before the snap: the edge's own tick plus the
    /// file seconds the slide covers on a pane that draws the whole file, at the tempo the part's
    /// media elapses at. nil for unusable input.
    nonisolated static func draggedTick(from edgeTick: Int, dragPoints: Double, widthPoints: Double,
                                        fileSeconds: Double, mediaBPM: Double) -> Int? {
        guard dragPoints.isFinite, widthPoints.isFinite, widthPoints > 0, fileSeconds.isFinite,
              fileSeconds > 0, mediaBPM.isFinite, mediaBPM > 0 else { return nil }
        let seconds = dragPoints / widthPoints * fileSeconds
        let (tick, overflow) = edgeTick.addingReportingOverflow(TimelineTime.ticks(fromSeconds: seconds, bpm: mediaBPM))
        return overflow ? nil : tick
    }

    /// The edit a slide of `dragPoints` on edge `edge` makes, or nil when it makes none. This is
    /// the ONE function the handle asks — for its preview while the finger moves and for the
    /// write on release — so the edge lands where its preview sat.
    ///
    /// The grid is `PartTrim.snapUnit` at this pane's `snapZoom`; nothing else picks a grid. Then,
    /// per direction, the rule that already exists:
    /// · INWARD (either edge) — the snapped tick, kept inside the part, must pass
    ///   `PartTrim.onlyLetsGo`, the rule the part bar's Trim buttons ask. Refused otherwise.
    /// · OUTWARD START — the snapped tick is held at the first grid line at or after the file's
    ///   start (`TimelineRegion.trimmedStart`'s own floor, asked with tick 0), and must pass
    ///   `PartTrim.keepsWhoPlays`. ⚠️ Refused otherwise, NOT walked back: moving a start changes
    ///   which overlapping part starts later, and a tie goes to the later placement, so a start one
    ///   bar back can take a bar from a neighbour while a start two bars back passes under it.
    ///   Legality is not monotone in the distance, and a search would land somewhere the finger
    ///   never pointed.
    /// · OUTWARD END — the farthest grid line up to the snapped tick that passes BOTH
    ///   `PartTrim.keepsWhoPlays` and `PartTrim.endFitsMedia`, found by halving. That search is
    ///   sound because the start does not move: who wins a newly covered tick does not depend on
    ///   how far the end goes, and a longer part only reaches further into its file, so a legal
    ///   end stays legal when it is pulled back. What the search finds in practice is the file's
    ///   end. A neighbour never makes it stop short: a part that starts LATER keeps playing over
    ///   the extended end (the later start wins), and a part that started EARLIER and still plays
    ///   past this end would lose its bars to the very first grid line, so that slide is refused.
    nonisolated static func edgeEdit(_ edge: Edge, dragPoints: Double, widthPoints: Double,
                                     region: TimelineRegion, in document: TimelineDocument,
                                     fileSeconds: Double, mediaBPM: Double) -> EdgeEdit? {
        guard document.regions.contains(where: { $0.id == region.id }), region.lengthTicks > 0,
              let zoom = snapZoom(widthPoints: widthPoints, fileSeconds: fileSeconds, mediaBPM: mediaBPM),
              let proposed = draggedTick(from: edge == .start ? region.startTick : region.endTick,
                                         dragPoints: dragPoints, widthPoints: widthPoints,
                                         fileSeconds: fileSeconds, mediaBPM: mediaBPM),
              // A tick past the tick domain's ceiling is a corrupt part, not an edge to snap.
              Double(proposed).magnitude <= TimelineTime.tickMagnitudeCeiling else { return nil }
        let unit = PartTrim.snapUnit(zoom: zoom)
        guard unit > 0 else { return nil }
        let snapped = Int((Double(proposed) / Double(unit)).rounded()) * unit
        let start = region.startTick
        let end = region.endTick
        switch edge {
        case .start:
            if snapped > start {
                // Inward: the start may not reach the end — the last grid line before it at most.
                let tick = Swift.min(snapped, floorGrid(end - 1, unit))
                guard tick > start,
                      let trimmed = region.trimmedStart(toTick: tick, bpm: mediaBPM), trimmed.startTick == tick,
                      PartTrim.onlyLetsGo(trimmed, replacing: region.id, in: document) else { return nil }
                return .start(tick: tick)
            }
            // Outward: no further back than the file's start, on the grid.
            let floor = region.trimmedStart(toTick: 0, bpm: mediaBPM)?.startTick ?? start
            let tick = Swift.max(snapped, ceilGrid(floor, unit))
            guard tick < start,
                  let extended = region.trimmedStart(toTick: tick, bpm: mediaBPM), extended.startTick == tick,
                  PartTrim.keepsWhoPlays(extending: extended, replacing: region.id, in: document) else { return nil }
            return .start(tick: tick)
        case .end:
            if snapped < end {
                // Inward: the end may not reach the start — the first grid line after it at least.
                let tick = Swift.max(snapped, floorGrid(start, unit) + unit)
                guard tick < end else { return nil }
                var cut = region
                cut.lengthTicks = tick - start
                guard PartTrim.onlyLetsGo(cut, replacing: region.id, in: document) else { return nil }
                return .end(lengthTicks: cut.lengthTicks)
            }
            // Outward: the grid lines after the end, up to the snapped tick; the farthest legal one.
            let nearest = floorGrid(end, unit) + unit
            guard snapped >= nearest else { return nil }
            let count = (snapped - nearest) / unit + 1
            func extended(_ index: Int) -> TimelineRegion {
                var longer = region
                longer.lengthTicks = nearest + index * unit - start
                return longer
            }
            func legal(_ index: Int) -> Bool {
                let longer = extended(index)
                return PartTrim.keepsWhoPlays(extending: longer, replacing: region.id, in: document)
                    && PartTrim.endFitsMedia(longer, mediaSeconds: fileSeconds, mediaBPM: mediaBPM)
            }
            guard legal(0) else { return nil }
            var low = 0            // legal
            var high = count - 1   // the farthest candidate
            while low < high {
                let middle = (low + high + 1) / 2
                if legal(middle) { low = middle } else { high = middle - 1 }
            }
            return .end(lengthTicks: extended(low).lengthTicks)
        }
    }

    /// The grid line at or before `tick` (floor division, so a negative tick rounds down too).
    private nonisolated static func floorGrid(_ tick: Int, _ unit: Int) -> Int {
        let quotient = tick / unit
        return (tick % unit != 0 && tick < 0 ? quotient - 1 : quotient) * unit
    }

    /// The grid line at or after `tick`.
    private nonisolated static func ceilGrid(_ tick: Int, _ unit: Int) -> Int {
        let line = floorGrid(tick, unit)
        return line == tick ? line : line + unit
    }

    /// Where an edit leaves its edge on the file, 0…1 — the preview line's place. A start edit
    /// keeps the file under the song where it was, so the new start sits as many file seconds
    /// before or after the window's start as the edge moved ticks, at the media tempo.
    nonisolated static func edgeFraction(_ edit: EdgeEdit, region: TimelineRegion,
                                         window: ArrangeCanvas.AudioWindow, fileSeconds: Double,
                                         mediaBPM: Double) -> Double? {
        guard fileSeconds.isFinite, fileSeconds > 0, mediaBPM.isFinite, mediaBPM > 0,
              window.fromSeconds.isFinite else { return nil }
        let ticks: Int
        switch edit {
        case .start(let tick): ticks = tick - region.startTick
        case .end(let lengthTicks): ticks = lengthTicks
        }
        let fraction = (window.fromSeconds + TimelineTime.seconds(fromTicks: ticks, bpm: mediaBPM)) / fileSeconds
        return fraction.isFinite ? fraction.clamped(to: 0...1) : nil
    }

    /// The two handles' touch areas on a pane `width` wide, as x ranges: each `handleHitPoints`
    /// wide and centred on its edge where there is room; pushed apart when the window is narrower
    /// than a target, so the two never share a point; and kept inside the pane, whose clip would
    /// otherwise cut a handle at the file's first or last second. nil for a pane narrower than
    /// two targets or unusable input.
    nonisolated static func handleFrames(startX: Double, endX: Double,
                                         width: Double) -> (start: ClosedRange<Double>, end: ClosedRange<Double>)? {
        let hit = handleHitPoints
        guard startX.isFinite, endX.isFinite, width.isFinite, width >= 2 * hit, startX <= endX else { return nil }
        var startLeft = startX - hit / 2
        var endLeft = endX - hit / 2
        if startLeft + hit > endLeft {
            let middle = (startX + endX) / 2
            startLeft = middle - hit
            endLeft = middle
        }
        startLeft = Swift.max(startLeft, 0)
        endLeft = Swift.min(Swift.max(endLeft, startLeft + hit), width - hit)
        startLeft = Swift.min(startLeft, endLeft - hit)
        return (startLeft...(startLeft + hit), endLeft...(endLeft + hit))
    }
}

/// The audio part editor: the selected audio part's whole file, its window bright and the rest
/// dimmed, under a cold header. Draws nothing unless the selected part on this track plays a
/// stretch of a file.
struct AudioPartEditorView: View {

    @Environment(TimelineStore.self) private var timeline
    @Environment(WorkstationSelection.self) private var selection
    @Environment(ClipStore.self) private var clipStore
    /// Read for `preflightTempo` only — `@ObservationIgnored`, the cold number the canvas draws by.
    @Environment(TimelineRegionPlayer.self) private var player

    let laneID: UUID

    var body: some View {
        let document = timeline.document
        if let region = AudioPartEditor.selectedPart(selection.regionID, track: laneID, in: document),
           let lane = document.lanes.first(where: { $0.id == laneID }),
           let subject = AudioPartEditor.subject(for: region, clip: clipStore.clip(id: region.clipID),
                                                 bpm: player.preflightTempo) {
            // The track's own hue, as its blocks on the canvas draw it.
            AudioPartEditorPane(subject: subject, region: region, document: document,
                                tint: EchoelTheme.TrackHue.of(kind: lane.kind, instrument: lane.builtinInstrument,
                                                              isBio: lane.isBio).color)
        }
    }
}

/// The editor's content for one subject. Its own struct so the file read is keyed to the file
/// alone (`.task(id:)`), and a gain or fade edit redraws without re-reading.
private struct AudioPartEditorPane: View {

    let subject: AudioPartEditor.Subject
    /// The part and the arrangement it sits in — handed to the edge handles alone, which ask the
    /// trim rules of both (AE-4b).
    let region: TimelineRegion
    let document: TimelineDocument
    let tint: Color

    @State private var load: AudioPartEditor.Load = .reading

    var body: some View {
        let load = self.load
        let total = AudioPartEditor.fileSeconds(subject, load: load)
        let summary = AudioPartEditor.summary(subject, load: load)
        VStack(alignment: .leading, spacing: EchoelTheme.spaceXS) {
            Text(subject.name.isEmpty ? String(localized: "Audio part") : subject.name)
                .font(EchoelTheme.font(12, .semibold))
                .foregroundStyle(EchoelTheme.text)
                .lineLimit(1)
            Text(summary)
                .font(EchoelTheme.font(11).monospacedDigit())
                .foregroundStyle(EchoelTheme.dim)
            ZStack(alignment: .leading) {
                AudioPartFileWave(subject: subject, load: load, fileSeconds: total, tint: tint)
                if let total {
                    AudioPartPlayheadView(subject: subject, fileSeconds: total)
                }
                if let total, let mediaBPM = subject.mediaBPM, case .ready = load {
                    AudioPartEdgeHandles(subject: subject, region: region, document: document,
                                         fileSeconds: total, mediaBPM: mediaBPM)
                }
            }
            .frame(minHeight: 72)
            .background(EchoelTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Audio part editor") + ", "
                            + (subject.name.isEmpty ? String(localized: "Audio part") : subject.name))
        .accessibilityValue(summary)
        .task(id: subject.window.mediaRef) {
            let ref = subject.window.mediaRef
            self.load = .reading
            let reader = Task.detached(priority: .utility) { () -> AudioPartEditor.Load in
                guard MediaLibrary.resolveRef(ref) != nil else { return .missing }
                guard let overview = WaveformSketch.overview(ofRef: ref) else { return .unreadable }
                return .ready(overview)
            }
            let read = await withTaskCancellationHandler {
                await reader.value
            } onCancel: {
                reader.cancel()
            }
            // A detached hop does not inherit cancellation: a read for a file this part no
            // longer plays must not land over the newer one.
            guard !Task.isCancelled else { return }
            self.load = read
        }
    }
}

/// The whole file's wave: the part's window in full hue at the level its gain and fades leave
/// it, the rest dimmed. Takes no touches and says nothing — the pane speaks for the part.
private struct AudioPartFileWave: View {

    let subject: AudioPartEditor.Subject
    let load: AudioPartEditor.Load
    let fileSeconds: Double?
    let tint: Color

    var body: some View {
        let subject = self.subject
        let load = self.load
        let total = self.fileSeconds
        let tint = self.tint
        Canvas { context, size in
            guard case .ready(let overview) = load, let total, size.width > 0, size.height > 0 else { return }
            let window = subject.window
            let columns = WaveformSketch.window(overview, fromSeconds: 0, lengthSeconds: total,
                                                columns: WaveformSketch.columns(forWidthPoints: Double(size.width)),
                                                gain: window.gain)
            guard !columns.isEmpty else { return }
            let span = AudioPartEditor.span(of: window, fileSeconds: total)
            let mid = size.height / 2
            let width = size.width / CGFloat(columns.count)
            var inside = Path()
            var outside = Path()
            for (index, column) in columns.enumerated() {
                let centre = (Double(index) + 0.5) / Double(columns.count)
                let x = CGFloat(index) * width
                var level: CGFloat = 1
                var bright = false
                if let span, span.contains(centre), span.upperBound > span.lowerBound {
                    bright = true
                    // The level the part's fades leave at this point of the part (`FadeEnvelope`).
                    level = CGFloat(window.fadeLevel(atFraction: (centre - span.lowerBound)
                                                     / (span.upperBound - span.lowerBound)))
                }
                let top = mid - CGFloat(column.max) * level * mid
                let bottom = mid - CGFloat(column.min) * level * mid
                let rect = CGRect(x: x, y: top, width: width, height: Swift.max(Self.hairline, bottom - top))
                if bright { inside.addRect(rect) } else { outside.addRect(rect) }
            }
            context.fill(outside, with: .color(tint.opacity(Self.dimOpacity)))
            context.fill(inside, with: .color(tint))
            // The window's two edges, so a quiet edge still reads where the part starts and stops.
            if let span {
                var edges = Path()
                for fraction in [span.lowerBound, span.upperBound] {
                    let x = CGFloat(fraction) * size.width
                    edges.move(to: CGPoint(x: x, y: 0))
                    edges.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(edges, with: .color(EchoelTheme.borderStrong), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The thinnest a column is drawn — silence is a line, not nothing.
    private static let hairline: CGFloat = 0.5
    /// The file outside the part's window: present, but plainly not what the part plays.
    private static let dimOpacity: Double = 0.25
}

/// The window's two edge handles (AE-4b). Hold, then slide: the edge follows the finger on the
/// grid `PartTrim.snapUnit` picks for this file's scale, a line shows where it will land, and
/// releasing writes ONCE — `trimRegionStart` for the start, `resizeRegion` for the end, each one
/// Undo step. The preview and the write ask the same `AudioPartEditor.edgeEdit`, so the edge lands
/// where its line sat; a slide the rules refuse shows the finger's place in the dim hue and
/// writes nothing.
///
/// ⭐ THE FINGER-RATE STATE LIVES HERE. `drag` is `@GestureState` — it resets itself when the
/// slide ends or a scroll takes it over — and only this leaf redraws while the finger moves; the
/// pane, its wave and the Part page above it do not. Nothing here reads the song position.
/// Hidden from VoiceOver like the rest of the pane: the part bar's Trim buttons are the
/// accessible way to move an edge, on the same rules.
private struct AudioPartEdgeHandles: View {

    @Environment(TimelineStore.self) private var timeline

    let subject: AudioPartEditor.Subject
    let region: TimelineRegion
    let document: TimelineDocument
    let fileSeconds: Double
    let mediaBPM: Double

    @GestureState private var drag: AudioPartEditor.EdgeDrag? = nil

    var body: some View {
        GeometryReader { geometry in
            let width = Double(geometry.size.width)
            let height = geometry.size.height
            if let span = AudioPartEditor.span(of: subject.window, fileSeconds: fileSeconds),
               let frames = AudioPartEditor.handleFrames(startX: span.lowerBound * width,
                                                        endX: span.upperBound * width, width: width) {
                ZStack(alignment: .topLeading) {
                    handle(.start, frame: frames.start, width: width, height: height)
                    handle(.end, frame: frames.end, width: width, height: height)
                    if let drag {
                        preview(drag, span: span, width: width, height: height)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// One handle: a touch area a full target wide and as tall as the wave, with a short grip
    /// on the edge itself so the person can see there is something to hold.
    private func handle(_ edge: AudioPartEditor.Edge, frame: ClosedRange<Double>,
                        width: Double, height: CGFloat) -> some View {
        let hit = CGFloat(frame.upperBound - frame.lowerBound)
        return ZStack {
            Color.clear
            RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(EchoelTheme.borderStrong)
                .frame(width: Self.gripWidth, height: Swift.min(Self.gripHeight, height))
        }
        .frame(width: hit, height: height)
        .contentShape(Rectangle())
        .offset(x: CGFloat(frame.lowerBound))
        .gesture(slide(edge, width: width))
    }

    /// Where the edge will land — or, when the rules refuse, where the finger is.
    @ViewBuilder
    private func preview(_ drag: AudioPartEditor.EdgeDrag, span: ClosedRange<Double>,
                         width: Double, height: CGFloat) -> some View {
        if let landing = edit(drag.edge, points: drag.points, width: width),
           let fraction = AudioPartEditor.edgeFraction(landing, region: region, window: subject.window,
                                                       fileSeconds: fileSeconds, mediaBPM: mediaBPM) {
            Rectangle()
                .fill(EchoelTheme.accent)
                .frame(width: Self.landingWidth, height: height)
                .offset(x: CGFloat(fraction * width) - Self.landingWidth / 2)
                .allowsHitTesting(false)
        } else {
            let edgeX = (drag.edge == .start ? span.lowerBound : span.upperBound) * width
            Rectangle()
                .fill(EchoelTheme.dim)
                .frame(width: Self.refusedWidth, height: height)
                .offset(x: CGFloat((edgeX + drag.points).clamped(to: 0...width)))
                .allowsHitTesting(false)
        }
    }

    /// Hold first, then slide — so a swipe that starts on the wave still scrolls the page (the
    /// Arrange canvas's hold-and-slide, the same 0.3 s). Nothing is written until release.
    private func slide(_ edge: AudioPartEditor.Edge, width: Double) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($drag) { value, state, _ in
                if case .second(true, let slide?) = value {
                    state = AudioPartEditor.EdgeDrag(edge: edge, points: Double(slide.translation.width))
                }
            }
            .onEnded { value in
                guard case .second(true, let slide?) = value,
                      let change = edit(edge, points: Double(slide.translation.width), width: width) else { return }
                switch change {
                case .start(let tick):
                    timeline.trimRegionStart(id: region.id, toTick: tick, bpm: mediaBPM)
                case .end(let lengthTicks):
                    timeline.resizeRegion(id: region.id, lengthTicks: lengthTicks)
                }
            }
    }

    /// The one question both the preview and the release ask.
    private func edit(_ edge: AudioPartEditor.Edge, points: Double, width: Double) -> AudioPartEditor.EdgeEdit? {
        AudioPartEditor.edgeEdit(edge, dragPoints: points, widthPoints: width, region: region, in: document,
                                 fileSeconds: fileSeconds, mediaBPM: mediaBPM)
    }

    /// The grip drawn on each edge: thin, and short enough to leave the wave readable.
    private static let gripWidth: CGFloat = 4
    private static let gripHeight: CGFloat = 24
    /// The landing line, as wide as the playhead's accent plus one point so the two read apart.
    private static let landingWidth: CGFloat = 2
    /// The refused slide's line: the finger's place, quiet.
    private static let refusedWidth: CGFloat = 1
}

/// The song position on the file. The ONLY reader of `currentTick` in this file: it self-drives
/// at 15 Hz while the song plays and is paused (and absent) while it is stopped, so the pane
/// above it never observes the position. Hidden from VoiceOver — the Workstation's song-position
/// readout speaks where the song is.
struct AudioPartPlayheadView: View {

    @Environment(TimelineRegionPlayer.self) private var player

    let subject: AudioPartEditor.Subject
    let fileSeconds: Double

    var body: some View {
        let playing = player.isPlaying
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing)) { _ in
            GeometryReader { geometry in
                if playing,
                   let fraction = AudioPartEditor.playheadFraction(tick: player.currentTick,
                                                                   partStartTick: subject.partStartTick,
                                                                   lengthTicks: subject.lengthTicks,
                                                                   window: subject.window,
                                                                   fileSeconds: fileSeconds) {
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

import EchoelCore
import EchoelDSP
import SwiftUI

/// The song on a bar timeline: one lane per track, its clips and audio laid out where they
/// play. Tap empty space to place the track's clip at that bar — or, on an audio track, to
/// import a file there; tap a clip to edit its notes, drag a clip or audio region to move it
/// onto the magnet (Snap, shared with the note editor: Off to the tick, Bar, Beat, 1/8 … 1/128,
/// triplets), hold for Snap, Duplicate, Duplicate as Linked, Make Unique, Split at Playhead, Consolidate and Delete. One drag is one
/// undo step, and so is each of those.
/// Tap or drag along the ruler to say where the song plays from: stopped, that bar (on the magnet)
/// becomes the cue — Play starts there, Stop returns there, a second Stop goes back to bar 1;
/// playing, the song moves there when the finger lifts. Locked while a take records or an export is
/// written. VoiceOver reaches the ruler as one adjustable "Play from, Bar N".
/// A video part shows its hits (CUT): where the picture cuts and where a sound in its own audio
/// begins. With Snap to Hits a dragged clip or audio region lands on a hit within reach instead of
/// the bar, and Place at Next Hit moves one to the next hit.
/// Its body reads no playhead, so nothing here rebuilds while the song plays: the playhead line
/// over the lanes is a leaf of its own (`PlayheadLine`), the one view on this page that polls it.
/// Two fingers spread or narrow the song's time (`ArrangeZoom`), and Zoom Out / Zoom In under the
/// lanes do the same one step at a time, so one finger is enough. The ruler, the lanes and the
/// playhead line sit in ONE horizontal scroll view and draw with ONE ticks-per-point, so they
/// never drift apart at any zoom; a drag spans as many ticks as the points it covers at that zoom.
/// The zoom is kept on this device, never in the song, and is not an edit.
struct ArrangeView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(StudioRouter.self) private var router
    @Environment(DocumentController.self) private var documents
    /// The video files' hits; they change only when a file's search ends.
    @Environment(VideoHits.self) private var videoHits: VideoHits?
    @AppStorage(ArrangeView.snapsToHitsKey) private var snapsToHits = true
    @AppStorage(SnapGrid.storageKey) private var snap: SnapGrid = .standard
    /// Opens the note editor on this clip of this track.
    let open: (TrackID, ClipID) -> Void
    /// Asks for an audio file to place on a track at a tick — or, on a video track, a video.
    let importAudio: (TrackID, Tick) -> Void

    @ScaledMetric(relativeTo: .body) private var nameWidth: CGFloat = 96
    /// The horizontal zoom at rest, kept on this device (`ArrangeZoom.level` reads a broken one
    /// as the standard zoom).
    @AppStorage(ArrangeZoom.storageKey) private var zoom = ArrangeZoom.base
    /// The live factor of a pinch in progress; it resets itself on release or when a scroll takes
    /// the touch, and the zoom changes once, when the fingers lift.
    @GestureState private var pinch: CGFloat = 1
    /// Empty bars drawn past the song's end, so there is always room to place the next clip.
    private static let spareBars = 8

    /// The zoom shown now: the one at rest times the pinch under the fingers.
    private var shownZoom: Double { ArrangeZoom.zoomed(zoom, by: Double(pinch)) }

    var body: some View {
        let project = store.project
        let bars = Arranging.songBars(of: project) + Self.spareBars
        // The first bar is `pointsPerBar` wide; every later one as wide as its ticks (a 7/8 bar
        // after 4/4 is narrower), so x stays proportional to musical time. One scale for the
        // ruler, every lane and the playhead line.
        let meter = project.meterMap
        let shown = shownZoom
        let pointsPerBar = CGFloat(ArrangeZoom.pointsPerBar(shown))
        let ticksPerPoint = ArrangeZoom.ticksPerPoint(shown, meter: meter)
        let laneWidth = CGFloat(Double(meter.tick(ofBar: Int64(bars))) / ticksPerPoint)
        let files = videoHits?.files ?? [:]
        let hits = Hits.ticks(in: project, files: files)
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: Theme.Space.hairline) {
                    Text("\(Arranging.songBars(of: project)) bars")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(height: Self.rulerRowHeight)
                        .accessibilityLabel("Song length \(Arranging.songBars(of: project)) bars")
                        .contextMenu {
                            AutomateMenu(owner: .master)
                            ModulateMenu(owner: .master)
                        }
                    ForEach(project.tracks) { track in
                        Text(track.name)
                            .font(Theme.Font.label)
                            .foregroundStyle(Theme.Color.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, Theme.Space.s)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: Theme.Size.trackRowHeight)
                            .background(Theme.Color.surface)
                            .contextMenu { trackMenu(track, showsHits: !hits.isEmpty) }
                            .accessibilityHidden(true)
                        ForEach(TakeLanes.rows(of: track)) { row in TakeLaneName(row: row) }
                        ForEach(Self.lanes(of: .track(track.id), in: project), id: \.target) { lane in
                            AutomationName(lane: lane)
                        }
                    }
                    ForEach(Self.lanes(of: .master, in: project), id: \.target) { lane in
                        AutomationName(lane: lane)
                    }
                }
                .frame(width: nameWidth)
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                        RulerLocator(bars: bars, meter: meter, ticksPerPoint: ticksPerPoint, width: laneWidth)
                            .overlay(alignment: .bottomLeading) {
                                MarkerStrip(markers: project.markers, meter: meter, ticksPerPoint: ticksPerPoint)
                            }
                            .contextMenu { MarkerAddButton() }
                        ForEach(project.tracks) { track in
                            ArrangeLane(track: track, project: project, pointsPerBar: pointsPerBar,
                                        open: open, importAudio: importAudio, files: files, hits: hits)
                                .frame(width: laneWidth, height: Theme.Size.trackRowHeight)
                            ForEach(TakeLanes.rows(of: track)) { row in
                                TakeLane(track: track, project: project, row: row, pointsPerBar: pointsPerBar)
                                    .frame(width: laneWidth, height: TakeLanes.rowHeight)
                            }
                            ForEach(Self.lanes(of: .track(track.id), in: project), id: \.target) { lane in
                                AutomationRow(lane: lane, signature: project.timeSignature, pointsPerBar: pointsPerBar)
                                    .frame(width: laneWidth, height: Theme.Size.trackRowHeight)
                            }
                        }
                        ForEach(Self.lanes(of: .master, in: project), id: \.target) { lane in
                            AutomationRow(lane: lane, signature: project.timeSignature, pointsPerBar: pointsPerBar)
                                .frame(width: laneWidth, height: Theme.Size.trackRowHeight)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        PlayheadLine(ticksPerPoint: ticksPerPoint)
                    }
                }
                .simultaneousGesture(pinchGesture)
            }
            if project.tracks.isEmpty {
                Text("Add a track on the Tracks page to start arranging.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(Theme.Space.l)
            }
        }
        .background(Theme.Color.background)
        .safeAreaInset(edge: .bottom, spacing: 0) { zoomBar }
        // A video file added to the song is searched for its hits once, off the main thread.
        .task(id: videoMedia(of: project)) {
            videoHits?.find(in: store.project) { documents.mediaURL($0) }
        }
    }

    /// Two fingers zoom the song's time; the zoom is written once, when they lift.
    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in zoom = ArrangeZoom.zoomed(zoom, by: Double(value.magnification)) }
    }

    /// Zoom Out and Zoom In under the lanes: the pinch is a shortcut, never the only way.
    private var zoomBar: some View {
        HStack(spacing: Theme.Space.s) {
            Spacer()
            zoomButton("Zoom Out", systemImage: "minus.magnifyingglass",
                       enabled: ArrangeZoom.canZoomOut(zoom)) { zoom = ArrangeZoom.zoomedOut(zoom) }
            zoomButton("Zoom In", systemImage: "plus.magnifyingglass",
                       enabled: ArrangeZoom.canZoomIn(zoom)) { zoom = ArrangeZoom.zoomedIn(zoom) }
        }
        .padding(.horizontal, Theme.Space.s)
        .background(Theme.Color.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Color.border).frame(height: 1)
        }
    }

    private func zoomButton(_ title: String, systemImage: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(Theme.Font.label)
                .foregroundStyle(enabled ? Theme.Color.text : Theme.Color.textTertiary)
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
        .accessibilityValue(ArrangeZoom.spoken(zoom))
    }

    private func videoMedia(of project: Project) -> [MediaID] {
        project.media.filter { $0.kind == .video }.map(\.id)
    }

    /// A track name's hold menu; a video track with hits also switches Snap to Hits.
    @ViewBuilder private func trackMenu(_ track: Track, showsHits: Bool) -> some View {
        Button("Rename Track…", systemImage: "pencil") { router.sheet = .rename(.track(track.id)) }
        SnapPicker(snap: $snap)
        if track.kind == .video, showsHits {
            Toggle("Snap to Hits", systemImage: "scope", isOn: $snapsToHits)
        }
        AutomateMenu(owner: .track(track.id))
        ModulateMenu(owner: .track(track.id))
    }
}

extension ArrangeView {
    /// The song's lanes that belong to `owner`, in the order they were made.
    static func lanes(of owner: ParameterAddress.Owner, in project: Project) -> [AutomationLane] {
        project.automation.filter { $0.target.owner == owner }
    }

    /// Whether a dragged clip or region lands on a hit within reach (CUT): kept on this device, on at first.
    nonisolated static let snapsToHitsKey = "arrange.snapToHits"
    /// How near a hit, in points, a dragged start must come to land on it.
    static let hitReach: CGFloat = 12
    /// The ruler row is a tap target, so at least a touch target high; the numbers keep their own
    /// height at its foot, and the names column gives the same height to its first cell.
    static let rulerRowHeight = Swift.max(Theme.Size.rulerHeight, Theme.Size.touch)

    /// The hit a start dragged to `tick` lands on; nil with snapping off or no hit within reach.
    static func hit(near tick: Tick, in hits: [Tick], ticksPerPoint: Double, snapping: Bool) -> Tick? {
        guard snapping, !hits.isEmpty, ticksPerPoint.isFinite, ticksPerPoint > 0 else { return nil }
        return Hits.nearest(to: tick, in: hits, tolerance: Tick((Double(hitReach) * ticksPerPoint).rounded()))
    }
}

/// The one magnet as a hold-menu choice: Off (to the tick), Bar, Beat, 1/8 … 1/128 and the
/// triplets — the same setting the note editor's Snap shows (`SnapGrid`).
struct SnapPicker: View {
    @Binding var snap: SnapGrid

    var body: some View {
        Picker(selection: $snap) {
            ForEach(SnapGrid.allCases, id: \.self) { choice in
                Text(choice.title).tag(choice).accessibilityLabel(choice.spokenTitle)
            }
        } label: {
            Label("Snap \(snap.title)", systemImage: "square.grid.3x1.below.line.grid.1x2")
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Snap")
        .accessibilityValue(snap.spokenTitle)
    }
}

extension SnapGrid {
    /// Where a block dragged from `start` by `translation` points shows while the finger is down:
    /// on the magnet's line, so what lifts is what was seen.
    /// The rule is `ArrangeZoom.previewPoints`, the same one the drop commits with.
    func previewOffset(from start: Tick, translation: CGFloat, ticksPerPoint: Double, meter: MeterMap) -> CGFloat {
        CGFloat(ArrangeZoom.previewPoints(from: start, dragged: Double(translation), ticksPerPoint: ticksPerPoint,
                                          snap: self, meter: meter))
    }
}

/// Bar numbers along the top, at the bar lines of the song's meter.
private struct BarRuler: View {
    let bars: Int
    let meter: MeterMap
    let ticksPerPoint: Double
    let width: CGFloat

    var body: some View {
        Canvas { [meter, ticksPerPoint] context, size in
            for bar in 0..<bars {
                let x = CGFloat(Double(meter.tick(ofBar: Int64(bar))) / ticksPerPoint)
                context.fill(Path(CGRect(x: x, y: size.height - 6, width: 1, height: 6)),
                             with: .color(Theme.Color.border))
                context.draw(Text("\(bar + 1)").font(Theme.Font.caption).foregroundStyle(Theme.Color.textSecondary),
                             at: CGPoint(x: x + 4, y: size.height / 2), anchor: .leading)
            }
        }
        .frame(width: width, height: Theme.Size.rulerHeight)
        .background(Theme.Color.surface)
        .accessibilityHidden(true)
    }
}

/// The ruler row: the bar numbers, the line where Play starts (the cue), and the touch that moves
/// it — the earlier app's ruler locator (AE-7), ported onto this engine. `BarRuler` stays a cold
/// picture; this leaf owns the three new jobs: the touch, the cue line, the VoiceOver control.
///
/// A tap or a drag lands on the magnet's line (`SnapGrid`, shared with the editors) when the finger
/// lifts — ONE locate per touch, never one per frame. While the finger is down a line shows where
/// it will land; that position is `@GestureState`, so it lives in this leaf alone and resets itself
/// when the scroll view takes the touch. Stopped, the locate sets the cue and the playhead; playing,
/// the song moves there at once (`AudioEngine.locate`). A drag that starts on the ruler does not
/// scroll the page — the lanes do.
///
/// ⛔ Locked while a take records or an export is written (`TimelineGeometry.mayLocate`): a take
/// counts its time from the transport, and a jump mid-take writes what was played at bar 2 at bar 7.
/// VoiceOver hears why in the hint.
///
/// Reads the cue and whether the song plays — both change with a press, never with the clock — and
/// never the moving playhead (Law 6); VoiceOver's step reads it in its action.
private struct RulerLocator: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(RecordController.self) private var recording
    @Environment(DocumentController.self) private var documents
    @AppStorage(SnapGrid.storageKey) private var snap: SnapGrid = .standard
    /// Where the finger is while it is down, in points along the ruler.
    @GestureState private var finger: CGFloat? = nil
    let bars: Int
    let meter: MeterMap
    let ticksPerPoint: Double
    let width: CGFloat

    private var locked: Bool {
        !TimelineGeometry.mayLocate(recording: recording.isRecording, exporting: documents.isExporting)
    }

    var body: some View {
        let cue = engine.cue.tick
        ZStack(alignment: .bottomLeading) {
            BarRuler(bars: bars, meter: meter, ticksPerPoint: ticksPerPoint, width: width)
            if let cue {
                line(at: cue, color: Theme.Color.text)
            }
            if let finger, !locked {
                line(at: landing(finger), color: Theme.Color.accent)
            }
        }
        .frame(width: width, height: ArrangeView.rulerRowHeight, alignment: .bottomLeading)
        .background(Theme.Color.surface)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($finger) { value, state, _ in state = value.location.x }
                .onEnded { value in locate(atX: value.location.x) }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Play from")
        .accessibilityValue(spokenBar)
        .accessibilityHint(locked ? "Locked while a take records or an export is written."
                                  : "Swipe up or down to move one bar.")
        .accessibilityAdjustableAction { direction in step(direction) }
    }

    /// A 1-pt line across the row at `tick`.
    private func line(at tick: Tick, color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 1, height: ArrangeView.rulerRowHeight)
            .offset(x: CGFloat(TimelineGeometry.x(ofTick: tick, ticksPerPoint: ticksPerPoint)))
    }

    /// The tick a touch at `x` lands on.
    private func landing(_ x: CGFloat) -> Tick {
        TimelineGeometry.tick(atX: Double(x), ticksPerPoint: ticksPerPoint, snap: snap, meter: meter)
    }

    private func locate(atX x: CGFloat) {
        guard !locked else { return }
        engine.locate(to: landing(x))
    }

    /// Stopped: the bar Play starts from. Playing: the bar Stop returns to.
    private var spokenBar: String {
        let at = engine.isPlaying ? (engine.cue.tick ?? 0) : engine.restingTick
        return "Bar \(meter.bar(at: at) + 1)"
    }

    /// One bar later or earlier, from where the song stands — read here, in the action.
    private func step(_ direction: AccessibilityAdjustmentDirection) {
        guard !locked else { return }
        let bars: Int64
        switch direction {
        case .increment: bars = 1
        case .decrement: bars = -1
        @unknown default: return
        }
        let from = engine.isPlaying ? engine.playheadTick(in: store.project) : engine.restingTick
        engine.locate(to: TimelineGeometry.tick(steppingBars: bars, from: from, meter: meter))
    }
}

/// The song position over the ruler and the lanes: a 1-pt accent line, no glow. The ONLY reader
/// of the moving playhead on this page (Law 6): it polls 30 times a second while the song plays,
/// so only this line redraws; its timeline is paused while the song is stopped, when it stands
/// where the transport rests (`AudioEngine.restingTick`, which changes only with Stop, a pause or
/// a locate). Takes no touch and says nothing to VoiceOver — the position readout says where.
private struct PlayheadLine: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(ProjectStore.self) private var store
    let ticksPerPoint: Double

    var body: some View {
        // Both read here, outside the timeline: a Stop or a locate redraws the resting line.
        let playing = engine.isPlaying
        let resting = Double(engine.restingTick)
        let project = store.project
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !playing)) { _ in
            let at = playing ? engine.heardTick(in: project) : resting
            let x = TimelineGeometry.x(ofPosition: at, ticksPerPoint: ticksPerPoint)
            Rectangle()
                .fill(Theme.Color.accent)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .offset(x: CGFloat(x))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// "Add Marker" on the ruler's hold menu: a marker on the magnet's line nearest the playhead,
/// named "Marker N", one undo step. The playhead is read when the button is pressed, never in a body.
private struct MarkerAddButton: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @AppStorage(SnapGrid.storageKey) private var snap: SnapGrid = .standard

    var body: some View {
        Button("Add Marker at Playhead", systemImage: "flag") {
            let project = store.project
            let tick = snap.nearest(engine.playheadTick(in: project), meter: project.meterMap)
            try? store.perform(.addMarker(at: tick, name: project.nextMarkerName()))
        }
    }
}

/// The song's markers on the ruler: a flag with its name at each one. Hold one to rename, move or
/// delete it; VoiceOver reaches each as its own element with the same actions.
private struct MarkerStrip: View {
    let markers: [Marker]
    let meter: MeterMap
    let ticksPerPoint: Double

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(markers, id: \.tick) { marker in
                MarkerFlag(marker: marker, meter: meter)
                    .offset(x: CGFloat(Double(marker.tick) / ticksPerPoint))
            }
        }
        .frame(height: Theme.Size.rulerHeight, alignment: .topLeading)
    }
}

private struct MarkerFlag: View {
    @Environment(ProjectStore.self) private var store
    @Environment(StudioRouter.self) private var router
    @Environment(AudioEngine.self) private var engine
    @AppStorage(SnapGrid.storageKey) private var snap: SnapGrid = .standard
    let marker: Marker
    let meter: MeterMap

    private var bar: Int { Int(clamping: meter.bar(at: marker.tick)) + 1 }

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Rectangle()
                .fill(Theme.Color.accent)
                .frame(width: 2, height: Theme.Size.rulerHeight)
            Text(marker.name)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.text)
                .lineLimit(1)
                .padding(.horizontal, Theme.Space.xs)
                .background(Theme.Color.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
        .frame(height: Theme.Size.rulerHeight)
        .contentShape(Rectangle())
        .contextMenu { menu }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Marker \(marker.name), bar \(bar)")
        .accessibilityAction(named: "Rename") { rename() }
        .accessibilityAction(named: "Move to Playhead") { moveToPlayhead() }
        .accessibilityAction(named: "Move One Bar Later") { move(byBars: 1) }
        .accessibilityAction(named: "Move One Bar Earlier") { move(byBars: -1) }
        .accessibilityAction(named: "Delete") { remove() }
    }

    @ViewBuilder private var menu: some View {
        Button("Rename Marker…", systemImage: "pencil") { rename() }
        Button("Move to Playhead", systemImage: "arrow.right.to.line") { moveToPlayhead() }
        Button("Move One Bar Later", systemImage: "arrow.right") { move(byBars: 1) }
        Button("Move One Bar Earlier", systemImage: "arrow.left") { move(byBars: -1) }
        Button("Delete Marker", systemImage: "trash", role: .destructive) { remove() }
    }

    private func rename() { router.sheet = .rename(.marker(marker.tick)) }

    private func moveToPlayhead() {
        let project = store.project
        let to = snap.nearest(engine.playheadTick(in: project), meter: project.meterMap)
        guard to != marker.tick else { return }
        try? store.perform(.moveMarker(from: marker.tick, to: to))
    }

    private func move(byBars bars: Int64) {
        let to = Swift.max(0, marker.tick + Arranging.ticks(movingBars: bars, from: marker.tick, meter: meter))
        guard to != marker.tick else { return }
        try? store.perform(.moveMarker(from: marker.tick, to: to))
    }

    private func remove() { try? store.perform(.removeMarker(at: marker.tick)) }
}

/// One track's lane: bar lines, its placements, and taps on empty space.
private struct ArrangeLane: View {
    @Environment(ProjectStore.self) private var store
    let track: Track
    let project: Project
    let pointsPerBar: CGFloat
    /// Opens the note editor on this clip of this track.
    let open: (TrackID, ClipID) -> Void
    let importAudio: (TrackID, Tick) -> Void
    /// The video files' hits, and every hit the song's video tracks show (CUT).
    let files: [MediaID: Hits.FileHits]
    let hits: [Tick]
    @AppStorage(ArrangeView.snapsToHitsKey) private var snapsToHits = true

    private var meter: MeterMap { project.meterMap }

    /// The first bar is `pointsPerBar` wide; x is proportional to ticks from there on.
    private var ticksPerPoint: Double {
        TimelineGeometry.ticksPerPoint(meter: meter, pointsPerBar: Double(pointsPerBar))
    }

    /// While snapping is on, a faint line at each hit in every lane but the video's own: where a
    /// clip dragged here can land.
    private var guides: [Tick] {
        snapsToHits && track.kind != .video ? hits : []
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { [guides, ticksPerPoint, meter] context, size in
                var bar: Int64 = 0
                while true {
                    let x = CGFloat(Double(meter.tick(ofBar: bar)) / ticksPerPoint)
                    guard x < size.width, x.isFinite else { break }
                    context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                                 with: .color(Theme.Color.border.opacity(0.6)))
                    bar += 1
                }
                for tick in guides {
                    let at = CGFloat(Double(tick) / ticksPerPoint)
                    context.fill(Path(CGRect(x: at, y: 0, width: 1, height: size.height)),
                                 with: .color(Theme.Color.accent.opacity(0.35)))
                }
            }
            .background(Theme.Color.surface)
            .contentShape(Rectangle())
            .onTapGesture { location in tapEmpty(at: location.x) }
            .accessibilityElement()
            .accessibilityLabel("\(track.name) lane")
            .accessibilityHint(laneHint)
            .accessibilityAction(named: endActionName) { placeAtEnd() }

            placementBlocks
            regionBlocks
        }
        .coordinateSpace(.named(ArrangeLane.space))
    }

    @ViewBuilder private var placementBlocks: some View {
        ForEach(track.placements) { placement in
            if let clip = track.clips.first(where: { $0.id == placement.clip }) {
                PlacementBlock(track: track, placement: placement, clip: clip, meter: meter,
                               pointsPerBar: pointsPerBar, open: open, hits: hits)
            }
        }
    }

    @ViewBuilder private var regionBlocks: some View {
        ForEach(track.regions) { region in
            if let file = project.mediaFile(region.media), let stop = Arranging.end(of: region, in: project) {
                RegionBlock(track: track, region: region, file: file, length: stop - region.start,
                            meter: meter, pointsPerBar: pointsPerBar, hits: hits,
                            ownHits: file.kind == .video
                                ? Hits.hits(of: region, in: project, file: files[region.media] ?? .none) : [])
            }
        }
    }

    /// Drags are measured here, not in the moving block, so the offset never feeds back.
    static let space = "arrange.lane"

    private var laneHint: String {
        switch track.kind {
        case .audio: "Tap to import an audio file at that bar."
        case .instrument: track.clips.isEmpty ? "Tap to create a clip." : ""
        case .returnTrack: ""
        case .video: "Tap to import a video from the photo library at that bar."
        }
    }

    private var endActionName: String {
        switch track.kind {
        case .audio: "Import Audio at End"
        case .video: "Import Video at End"
        default: "Place Clip at End"
        }
    }

    private func tapEmpty(at x: CGFloat) {
        let tick = Tick((Double(x) * ticksPerPoint).rounded(.down))
        if track.kind == .audio || track.kind == .video {
            if Arranging.region(in: track, at: tick, project: project) == nil {
                importAudio(track.id, Arranging.barStart(tick, meter: meter))
            }
            return
        }
        guard track.kind == .instrument else { return }
        if track.clips.isEmpty {
            createClip(at: Arranging.barStart(tick, meter: meter))
        } else if let command = Arranging.tap(on: track, at: tick, meter: meter) {
            try? store.perform(command)
        }
    }

    private func placeAtEnd() {
        let clipsEnd = track.placements.compactMap { Arranging.end(of: $0, in: track) }.max() ?? 0
        let audioEnd = track.regions.compactMap { Arranging.end(of: $0, in: project) }.max() ?? 0
        let start = meter.nextBarLine(atOrAfter: Swift.max(clipsEnd, audioEnd))
        if track.kind == .audio || track.kind == .video {
            importAudio(track.id, start)
        } else if track.clips.isEmpty {
            createClip(at: start)
        } else if let command = Arranging.tap(on: track, at: start, meter: meter) {
            try? store.perform(command)
        }
    }

    /// A track's first clip: four empty bars, placed where the tap fell.
    private func createClip(at start: Tick) {
        guard track.kind == .instrument else { return }
        let clip = ClipID()
        try? store.perform([
            .createClip(track: track.id, id: clip, name: Names.derived(track.name, suffix: "Clip"),
                        length: Swift.max(Arranging.ticks(movingBars: 4, from: start, meter: meter), 1)),
            .placeClip(track: track.id, id: PlacementID(), clip: clip, start: start),
        ], title: "New Clip")
    }
}

/// A placed clip. The drag offset lives in view state while the finger is down and becomes
/// one move command when it lifts.
private struct PlacementBlock: View {
    @Environment(ProjectStore.self) private var store
    @Environment(StudioRouter.self) private var router
    /// Only for the playhead at the moment Split is chosen — never read in `body`.
    @Environment(AudioEngine.self) private var engine
    let track: Track
    let placement: Placement
    let clip: Clip
    let meter: MeterMap
    let pointsPerBar: CGFloat
    /// Opens the note editor on this clip of this track.
    let open: (TrackID, ClipID) -> Void
    /// Every hit the song's video shows (CUT).
    let hits: [Tick]

    @State private var dragX: CGFloat = 0
    @AppStorage(ArrangeView.snapsToHitsKey) private var snapsToHits = true
    @AppStorage(SnapGrid.storageKey) private var snap: SnapGrid = .standard

    private var ticksPerPoint: Double { TimelineGeometry.ticksPerPoint(meter: meter, pointsPerBar: Double(pointsPerBar)) }
    private var startBar: Int { Int(clamping: meter.bar(at: placement.start)) + 1 }
    private var lengthBars: Int {
        Int(clamping: meter.bar(at: meter.nextBarLine(atOrAfter: placement.start + clip.length)) - meter.bar(at: placement.start))
    }
    private var nextHit: Tick? { Hits.next(after: placement.start, in: hits) }
    /// How many places play this clip (placements and session slots); two or more is a linked copy.
    private var uses: Int { track.uses(of: clip.id) }

    var body: some View {
        accessible(block.contextMenu { menu })
    }

    /// The block itself: shape, name, size, position and the move drag.
    private var block: some View {
        let color = Theme.Color.track(track.colorIndex)
        let width = Swift.max(8, CGFloat(Double(clip.length) / ticksPerPoint))
        return RoundedRectangle(cornerRadius: Theme.Radius.small)
            .fill(color.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(color, lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                Text(clip.name)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(1)
                    .padding(Theme.Space.xs)
            }
            .overlay(alignment: .bottomTrailing) { linkBadge }
            .frame(width: width, height: Theme.Size.trackRowHeight - Theme.Space.s)
            .offset(x: CGFloat(Double(placement.start) / ticksPerPoint) + dragX, y: Theme.Space.xs)
            .opacity(dragX == 0 ? 1 : 0.8)
            .onTapGesture { open(track.id, clip.id) }
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named(ArrangeLane.space))
                    .onChanged { dragX = dragOffset($0.translation.width) }
                    .onEnded { value in
                        dragX = 0
                        drop(movedBy: value.translation.width)
                    }
            )
    }

    /// A linked copy shows a chain and how many places play its clip (×3). VoiceOver reads it in the
    /// block's label.
    @ViewBuilder private var linkBadge: some View {
        if uses >= 2 {
            HStack(spacing: 2) {
                Image(systemName: "link")
                Text("×\(uses)")
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.text)
            .lineLimit(1)
            .padding(Theme.Space.xs)
        }
    }

    /// Where the block shows while the finger moves: on a hit as soon as one is within reach.
    private func dragOffset(_ translation: CGFloat) -> CGFloat {
        let tick = placement.start + ArrangeZoom.ticks(dragged: Double(translation), ticksPerPoint: ticksPerPoint)
        guard let hit = ArrangeView.hit(near: tick, in: hits, ticksPerPoint: ticksPerPoint, snapping: snapsToHits) else {
            return snap.previewOffset(from: placement.start, translation: translation, ticksPerPoint: ticksPerPoint, meter: meter)
        }
        return CGFloat(Double(hit - placement.start) / ticksPerPoint)
    }

    /// One undo step: onto the hit within reach, else onto the magnet's nearest line (to the tick
    /// with it off).
    private func drop(movedBy translation: CGFloat) {
        let delta = ArrangeZoom.ticks(dragged: Double(translation), ticksPerPoint: ticksPerPoint)
        if let hit = ArrangeView.hit(near: placement.start + delta, in: hits, ticksPerPoint: ticksPerPoint,
                                     snapping: snapsToHits) {
            if let command = Hits.placed(placement, in: track, at: hit) { try? store.perform(command) }
        } else if let command = Arranging.moved(placement, in: track, byTicks: delta, meter: meter, snap: snap) {
            try? store.perform(command)
        }
    }

    /// The hold menu, apart from the block so each expression stays small enough to type-check.
    @ViewBuilder private var menu: some View {
        Button("Edit Notes", systemImage: "pianokeys") { open(track.id, clip.id) }
        if nextHit != nil {
            Button("Place at Next Hit", systemImage: "arrow.right.to.line") { placeAtNextHit() }
        }
        SnapPicker(snap: $snap)
        if !hits.isEmpty {
            Toggle("Snap to Hits", systemImage: "scope", isOn: $snapsToHits)
        }
        Button("Duplicate", systemImage: "plus.square.on.square") { duplicate() }
        Button("Duplicate as Linked", systemImage: "link") { duplicateLinked() }
        if uses >= 2 {
            Button("Make Unique", systemImage: "link.badge.plus") { makeUnique() }
        }
        Button("Split at Playhead", systemImage: "scissors") { splitAtPlayhead() }
        if Arranging.consolidated(placement, in: track) != nil {
            Button("Consolidate", systemImage: "rectangle.compress.vertical") { consolidate() }
        }
        Button("Rename Clip…", systemImage: "pencil") { router.sheet = .rename(.clip(clip.id)) }
        Button("Delete", systemImage: "trash", role: .destructive) { remove() }
        // The clip itself: every place it is in the arrangement and every session slot (undoable).
        Button("Delete Clip Everywhere", systemImage: "trash.slash", role: .destructive) {
            try? store.perform(.deleteClip(clip.id))
        }
    }

    private func accessible(_ view: some View) -> some View {
        view
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the note editor.")
            .accessibilityAction { open(track.id, clip.id) }
            .accessibilityAction(named: "Move One Bar Later") { move(byBars: 1) }
            .accessibilityAction(named: "Move One Bar Earlier") { move(byBars: -1) }
            .accessibilityAction(named: "Place at Next Hit") { placeAtNextHit() }
            .accessibilityAction(named: "Duplicate") { duplicate() }
            .accessibilityAction(named: "Duplicate as Linked") { duplicateLinked() }
            .accessibilityAction(named: "Make Unique") { makeUnique() }
            .accessibilityAction(named: "Split at Playhead") { splitAtPlayhead() }
            .accessibilityAction(named: "Consolidate") { consolidate() }
            .accessibilityAction(named: "Rename Clip") { router.sheet = .rename(.clip(clip.id)) }
            .accessibilityAction(named: "Delete") { remove() }
    }

    private func move(byBars bars: Tick) {
        if let command = Arranging.moved(placement, in: track,
                                         byTicks: Arranging.ticks(movingBars: bars, from: placement.start, meter: meter), meter: meter) {
            try? store.perform(command)
        }
    }

    /// The block's VoiceOver label: name, where, how long, and whether it is a linked copy.
    private var spokenLabel: String {
        let base = "\(clip.name), bar \(startBar), \(lengthBars) bars"
        return uses >= 2 ? "\(base), linked, plays in \(uses) places" : base
    }

    /// An independent copy right after it: a clip of its own, one undo step.
    private func duplicate() {
        if let commands = Arranging.copied(placement, in: track) { try? store.perform(commands, title: "Duplicate") }
    }

    /// A linked copy right after it: the same clip again, so a note edit is heard in both.
    private func duplicateLinked() {
        if let command = Arranging.duplicated(placement, in: track) {
            try? store.perform([command], title: "Duplicate as Linked")
        }
    }

    /// Gives this placement a clip of its own; nothing happens when nothing else plays its clip.
    private func makeUnique() {
        if let command = Arranging.madeUnique(placement, in: track) { try? store.perform(command) }
    }

    /// Starts the clip exactly on the first hit after its start, one undo step; nothing after the last hit.
    private func placeAtNextHit() {
        guard let hit = nextHit, let command = Hits.placed(placement, in: track, at: hit) else { return }
        try? store.perform([command], title: "Place at Next Hit")
    }

    /// Cuts on the magnet's line nearest the playhead (at the playhead with it off); nothing
    /// happens when that is outside the clip.
    private func splitAtPlayhead() {
        let tick = engine.playheadTick(in: store.project)
        if let command = Arranging.split(placement, in: track, at: tick, meter: meter, snap: snap) {
            try? store.perform(command)
        }
    }

    /// Joins the clip with the placements touching or overlapping it into one clip.
    private func consolidate() {
        if let command = Arranging.consolidated(placement, in: track) { try? store.perform(command) }
    }

    private func remove() {
        try? store.perform(.removePlacement(track: track.id, placement.id))
    }
}

/// A placed audio region: the file's name over its length. Drag moves it onto the magnet, one
/// undo step on release; drag an edge to trim it onto the magnet, a top corner's grip to set its
/// fade (one undo step each); hold for Duplicate, Split at
/// Playhead (on the magnet), Consolidate (pieces of one file only), Bake Effects and Delete. A video part
/// shows its hits (CUT); an audio region lands on one within reach and moves to the next on Place
/// at Next Hit.
private struct RegionBlock: View {
    @Environment(ProjectStore.self) private var store
    @Environment(StudioRouter.self) private var router
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    let track: Track
    let region: AudioRegion
    let file: MediaFile
    /// The region's length in ticks at the song's tempo.
    let length: Tick
    let meter: MeterMap
    let pointsPerBar: CGFloat
    /// Every hit the song's video shows, and — for a video part — the hits it shows itself (CUT).
    let hits: [Tick]
    let ownHits: [Hits.Hit]

    @State private var dragX: CGFloat = 0
    /// Live drag of the left and right edge, in points, until the finger lifts.
    @State private var trimLeft: CGFloat = 0
    @State private var trimRight: CGFloat = 0
    /// The fade a grip is dragging, in frames, until the finger lifts.
    @State private var fadeDrag: (edge: Arranging.Edge, frames: Int)?
    @AppStorage(ArrangeView.snapsToHitsKey) private var snapsToHits = true
    @AppStorage(SnapGrid.storageKey) private var snap: SnapGrid = .standard

    private var ticksPerPoint: Double { TimelineGeometry.ticksPerPoint(meter: meter, pointsPerBar: Double(pointsPerBar)) }
    private var startBar: Int { Int(clamping: meter.bar(at: region.start)) + 1 }
    private var seconds: Double { file.sampleRate > 0 ? Double(region.length) / file.sampleRate : 0 }
    private var spokenLabel: String {
        let kind = file.kind == .video ? "video" : "audio"
        let time = NumberText.string(seconds, decimals: 1)
        return "\(file.name), \(kind), bar \(startBar), \(time) seconds" + spokenHits + spokenEdits
    }

    /// A region's fades and level, as they are said: ", fade in, fade out, minus 6 decibels".
    private var spokenEdits: String {
        var parts: [String] = []
        let fades = region.effectiveFades
        if fades.fadeIn > 0 { parts.append("fade in") }
        if fades.fadeOut > 0 { parts.append("fade out") }
        if region.warpBPM != nil { parts.append("follows the song tempo") }
        if let gain = region.gainDB, gain != 0 {
            parts.append("\(gain < 0 ? "minus" : "plus") \(NumberText.string(Swift.abs(gain), decimals: 0)) decibels")
        }
        return parts.isEmpty ? "" : ", " + parts.joined(separator: ", ")
    }

    /// How many hits a video part shows, as it is said: ", 2 cuts, 1 sound".
    private var spokenHits: String {
        guard !ownHits.isEmpty else { return "" }
        let cuts = ownHits.filter { $0.kind == .cut }.count, sounds = ownHits.count - cuts
        return ", \(cuts) \(cuts == 1 ? "cut" : "cuts"), \(sounds) \(sounds == 1 ? "sound" : "sounds")"
    }

    /// An audio region lands on hits; a video part brings its own and moves by bars.
    private var snapsHere: Bool { file.kind == .audio && snapsToHits }
    private var nextHit: Tick? { file.kind == .audio ? Hits.next(after: region.start, in: hits) : nil }

    var body: some View {
        accessible(block.contextMenu { menu })
    }

    /// The block itself: shape, name, size, position and the move drag.
    private var block: some View {
        let color = Theme.Color.track(track.colorIndex)
        let width = Swift.max(8, CGFloat(Double(length) / ticksPerPoint) - trimLeft + trimRight)
        return RoundedRectangle(cornerRadius: Theme.Radius.small)
            .fill(color.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(color, lineWidth: 1)
            )
            .overlay { waveform(tint: color) }
            .overlay(alignment: .topLeading) {
                Label(file.name, systemImage: file.kind == .video ? "film" : "waveform")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(1)
                    .padding(Theme.Space.xs)
            }
            .overlay { fadeMarks }
            .overlay { hitMarks }
            .overlay(alignment: .leading) { edgeHandle(.start) }
            .overlay(alignment: .trailing) { edgeHandle(.end) }
            .overlay(alignment: .topLeading) { fadeGrip(.start, width: width) }
            .overlay(alignment: .topLeading) { fadeGrip(.end, width: width) }
            .frame(width: width, height: Theme.Size.trackRowHeight - Theme.Space.s)
            .offset(x: CGFloat(Double(region.start) / ticksPerPoint) + dragX + trimLeft, y: Theme.Space.xs)
            .opacity(dragX == 0 && trimLeft == 0 && trimRight == 0 ? 1 : 0.8)
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named(ArrangeLane.space))
                    .onChanged { dragX = dragOffset($0.translation.width) }
                    .onEnded { value in
                        dragX = 0
                        drop(movedBy: value.translation.width)
                    }
            )
    }

    /// An audio region's file as it sounds over the stretch the region plays: drawn from the
    /// file's picture, read once (`WaveformCache`), at the region's own level. A video part has none.
    @ViewBuilder private func waveform(tint: Color) -> some View {
        if file.kind == .audio {
            RegionWaveform(url: documents.mediaURL(file), offset: region.offset, length: region.length,
                           level: Float(region.linearGain), tint: tint)
        }
    }

    /// The fades as they play, or as a grip drags one until the finger lifts.
    private var shownFades: (fadeIn: Int, fadeOut: Int) {
        guard let fadeDrag else { return region.effectiveFades }
        return Arranging.fadeLengths(region, edge: fadeDrag.edge, toFrames: fadeDrag.frames)
    }

    /// The region's fades over it, drawn as the curve they play: a line from the bottom corner
    /// rising to the top over the fade-in, falling to the bottom over the fade-out. The grips on
    /// the top corners drag them; the hold menu's Fades & Gain sets them by number.
    private var fadeMarks: some View {
        let fades = shownFades
        let total = Double(Swift.max(region.length, 1))
        let inShare = Double(fades.fadeIn) / total, outShare = Double(fades.fadeOut) / total
        let inCurve = region.fadeInCurve, outCurve = region.fadeOutCurve
        return Canvas { context, size in
            func curve(_ share: Double, _ shape: FadeCurve, rising: Bool) {
                guard share > 0 else { return }
                let width = size.width * CGFloat(share)
                var path = Path()
                for step in 0...24 {
                    let progress = Double(step) / 24
                    let level = CGFloat(shape.level(rising ? progress : 1 - progress))
                    let x = (rising ? 0 : size.width - width) + width * CGFloat(progress)
                    let point = CGPoint(x: x, y: size.height * (1 - level))
                    if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.stroke(path, with: .color(Theme.Color.text.opacity(0.7)), lineWidth: 1)
            }
            curve(inShare, inCurve, rising: true)
            curve(outShare, outCurve, rising: false)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A video part's hits over it: a line the full height where the picture cuts, a short one
    /// from the bottom where a sound in its own audio begins. Drawn, never touched.
    private var hitMarks: some View {
        Canvas { [ownHits, ticksPerPoint] context, size in
            for hit in ownHits {
                let x = CGFloat(Double(hit.tick - region.start) / ticksPerPoint)
                guard x >= 0, x <= size.width else { continue }
                let top = hit.kind == .cut ? 0 : size.height * 0.55
                context.fill(Path(CGRect(x: x, y: top, width: 1.5, height: size.height - top)),
                             with: .color(Theme.Color.accent))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Where the block shows while the finger moves: an audio region on a hit as soon as one is
    /// within reach.
    private func dragOffset(_ translation: CGFloat) -> CGFloat {
        let tick = region.start + ArrangeZoom.ticks(dragged: Double(translation), ticksPerPoint: ticksPerPoint)
        guard let hit = ArrangeView.hit(near: tick, in: hits, ticksPerPoint: ticksPerPoint, snapping: snapsHere) else {
            return snap.previewOffset(from: region.start, translation: translation, ticksPerPoint: ticksPerPoint, meter: meter)
        }
        return CGFloat(Double(hit - region.start) / ticksPerPoint)
    }

    /// One undo step: onto the hit within reach, else to the nearest bar.
    private func drop(movedBy translation: CGFloat) {
        let delta = ArrangeZoom.ticks(dragged: Double(translation), ticksPerPoint: ticksPerPoint)
        if let hit = ArrangeView.hit(near: region.start + delta, in: hits, ticksPerPoint: ticksPerPoint,
                                     snapping: snapsHere) {
            if let command = Hits.placed(region, in: track, at: hit) { try? store.perform(command) }
        } else if let command = Arranging.moved(region, in: track, byTicks: delta, meter: meter, snap: snap) {
            try? store.perform(command)
        }
    }

    /// Starts the region exactly on the first hit after its start, one undo step.
    private func placeAtNextHit() {
        guard let hit = nextHit, let command = Hits.placed(region, in: track, at: hit) else { return }
        try? store.perform([command], title: "Place at Next Hit")
    }

    /// The hold menu, apart from the block so each expression stays small enough to type-check.
    @ViewBuilder private var menu: some View {
        if nextHit != nil {
            Button("Place at Next Hit", systemImage: "arrow.right.to.line") { placeAtNextHit() }
        }
        SnapPicker(snap: $snap)
        if !hits.isEmpty {
            Toggle("Snap to Hits", systemImage: "scope", isOn: $snapsToHits)
        }
        if file.kind == .audio {
            Button("Fades, Gain & Warp…", systemImage: "slider.horizontal.below.rectangle") { editFades() }
            Button("Convert to MIDI…", systemImage: "pianokeys") { router.sheet = .convertToMIDI(track.id, region.id) }
            Button("Pitch & Texture…", systemImage: "tuningfork") { editPitchTexture() }
        }
        if file.kind == .video {
            Button("Color…", systemImage: "camera.filters") { router.sheet = .regionColor(track.id, region.id) }
        }
        // The speech in the part as subtitles, heard on the device (SUBS).
        Button("Transcribe…", systemImage: "captions.bubble") { router.sheet = .transcribe(track.id, region.id) }
        Button("Duplicate", systemImage: "plus.square.on.square") { duplicate() }
        Button("Split at Playhead", systemImage: "scissors") { split() }
        if Arranging.consolidated(region, in: track, project: store.project) != nil {
            Button("Consolidate", systemImage: "rectangle.compress.vertical") { consolidate() }
        }
        if canBake {
            Button("Bake Effects", systemImage: "square.and.arrow.down.on.square") { bake() }
        }
        Button("Delete", systemImage: "trash", role: .destructive) { remove() }
        // The file itself: every region and clip that plays it, and a sampler holding it (undoable).
        Button("Remove File from Song", systemImage: "trash.slash", role: .destructive) { removeFile() }
    }

    private func removeFile() {
        try? store.perform(.removeMedia(file.id))
    }

    private func editFades() {
        guard file.kind == .audio else { return }
        router.sheet = .regionEdit(track.id, region.id)
    }

    /// Pitch correction and a granular texture, baked offline into a new file (W3).
    private func editPitchTexture() {
        guard file.kind == .audio else { return }
        router.sheet = .regionBake(track.id, region.id)
    }

    /// An audio region on a track with an effect switched on, and no export or bake under way.
    private var canBake: Bool {
        file.kind == .audio && track.inserts.contains(where: { !$0.isBypassed }) && !documents.isExporting
    }

    /// Renders the track's effects into a new file and swaps the region for it, one undo step
    /// (`DocumentController.bakeEffects`).
    private func bake() {
        let documents = documents, plugins = engine.plugins
        let region = region.id, track = track.id
        Task { await documents.bakeEffects(region: region, on: track, plugins: plugins) }
    }

    private func accessible(_ view: some View) -> some View {
        view
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenLabel)
            .accessibilityAction(named: "Move One Bar Later") { move(byBars: 1) }
            .accessibilityAction(named: "Move One Bar Earlier") { move(byBars: -1) }
            .accessibilityAction(named: "Place at Next Hit") { placeAtNextHit() }
            .accessibilityAction(named: "Fades, Gain and Warp") { editFades() }
            .accessibilityAction(named: "Pitch and Texture") { editPitchTexture() }
            .accessibilityAction(named: "Duplicate") { duplicate() }
            .accessibilityAction(named: "Split at Playhead") { split() }
            .accessibilityAction(named: "Consolidate") { consolidate() }
            .accessibilityAction(named: "Bake Effects") { if canBake { bake() } }
            .accessibilityAction(named: "Delete") { remove() }
            .accessibilityAction(named: "Trim Start One Beat Later") { trim(.start, beats: 1) }
            .accessibilityAction(named: "Trim End One Beat Earlier") { trim(.end, beats: -1) }
            .accessibilityAction(named: "Extend End One Beat") { trim(.end, beats: 1) }
            .accessibilityAction(named: "Fade In One Beat Longer") { fade(.start, beats: 1) }
            .accessibilityAction(named: "Fade In One Beat Shorter") { fade(.start, beats: -1) }
            .accessibilityAction(named: "Fade Out One Beat Longer") { fade(.end, beats: 1) }
            .accessibilityAction(named: "Fade Out One Beat Shorter") { fade(.end, beats: -1) }
    }

    /// A grip along one edge; it wins over the move drag. It looks narrow (a 4-pt stripe with
    /// 8 pt either side), and it TAKES a full touch target: the hit area reaches 12 pt further on
    /// each side, 44 pt in all, half of it beyond the region's edge.
    private func edgeHandle(_ edge: Arranging.Edge) -> some View {
        Rectangle()
            .fill(Theme.Color.track(track.colorIndex).opacity(0.6))
            .frame(width: Theme.Space.xs)
            .padding(.horizontal, Theme.Space.s)
            .contentShape(Rectangle().inset(by: -Theme.Space.m))
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named(ArrangeLane.space))
                    .onChanged { value in
                        // On the magnet's line the release trims to, at this zoom.
                        let from = edge == .start ? region.start : region.start + length
                        let shown = snap.previewOffset(from: from, translation: value.translation.width,
                                                       ticksPerPoint: ticksPerPoint, meter: meter)
                        if edge == .start { trimLeft = shown } else { trimRight = shown }
                    }
                    .onEnded { value in
                        trimLeft = 0
                        trimRight = 0
                        let delta = ArrangeZoom.ticks(dragged: Double(value.translation.width), ticksPerPoint: ticksPerPoint)
                        apply(edge, byTicks: delta, snap: snap)
                    }
            )
            .accessibilityHidden(true)
    }

    /// A grip on one top corner — the fade-in's on the left, the fade-out's on the right — that
    /// sits where its fade ends and drags it longer or shorter; it wins over the move drag. It
    /// looks small (an 8-pt square just inside the top) and takes a 44-pt touch target centred on
    /// it, so the lower part of each edge stays the trim handle. The fade follows the finger and
    /// is set ONCE when it lifts: one command, one undo step. Audio regions only.
    @ViewBuilder private func fadeGrip(_ edge: Arranging.Edge, width: CGFloat) -> some View {
        if file.kind == .audio {
            let fades = shownFades
            let total = CGFloat(Swift.max(region.length, 1))
            let share = CGFloat(edge == .start ? fades.fadeIn : fades.fadeOut) / total
            let fadeEndX = edge == .start ? share * width : width - share * width
            let inset = Self.gripSize / 2 + 2
            let centre = Swift.max(inset, Swift.min(fadeEndX, width - inset))
            let drawnWidth = Double(length) / ticksPerPoint
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.Color.text)
                .frame(width: Self.gripSize, height: Self.gripSize)
                .frame(width: Self.gripTarget, height: Self.gripTarget)
                .contentShape(Rectangle())
                .offset(x: centre - Self.gripTarget / 2, y: inset - Self.gripTarget / 2)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .named(ArrangeLane.space))
                        .onChanged { value in
                            fadeDrag = (edge, Arranging.fadeFrames(region, edge: edge, dragged: Double(value.translation.width),
                                                                   widthPoints: drawnWidth))
                        }
                        .onEnded { value in
                            fadeDrag = nil
                            let frames = Arranging.fadeFrames(region, edge: edge, dragged: Double(value.translation.width),
                                                              widthPoints: drawnWidth)
                            if let command = Arranging.faded(region, edge: edge, toFrames: frames, in: track) {
                                try? store.perform([command], title: edge == .start ? "Fade In" : "Fade Out")
                            }
                        }
                )
                .accessibilityHidden(true)
        }
    }

    /// VoiceOver's fades by one beat: the same command a grip sets.
    private func fade(_ edge: Arranging.Edge, beats: Int) {
        guard file.kind == .audio,
              let command = Arranging.faded(region, edge: edge, byBeats: beats, in: track, project: store.project) else { return }
        try? store.perform([command], title: edge == .start ? "Fade In" : "Fade Out")
    }

    /// The fade grip as it shows, and the touch it takes.
    private static let gripSize: CGFloat = 8
    private static let gripTarget: CGFloat = 44

    /// VoiceOver's trims by one beat, on the beat whatever the magnet says.
    private func trim(_ edge: Arranging.Edge, beats: Tick) {
        apply(edge, byTicks: beats * meter.ticksPerBeat(at: region.start), snap: .beat)
    }

    private func apply(_ edge: Arranging.Edge, byTicks delta: Tick, snap: SnapGrid) {
        guard let commands = Arranging.trimmed(region, edge: edge, byTicks: delta, in: track, project: store.project,
                                               snap: snap) else { return }
        try? store.perform(commands, title: "Trim Region")
    }

    private func move(byBars bars: Tick) {
        if let command = Arranging.moved(region, in: track,
                                         byTicks: Arranging.ticks(movingBars: bars, from: region.start, meter: meter), meter: meter) {
            try? store.perform(command)
        }
    }

    private func remove() {
        try? store.perform(.removeRegion(track: track.id, region.id))
    }

    /// A cut on the magnet's line nearest the playhead (C5; at the playhead with it off): nothing
    /// of the file is lost, both parts stay movable and trimmable, and one Undo joins them again.
    private func split() {
        let project = store.project
        let at = snap.nearest(engine.playheadTick(in: project), meter: project.meterMap)
        try? store.perform(.splitRegion(track: track.id, region.id, at: at, newID: RegionID()))
    }

    private func duplicate() {
        guard let commands = Arranging.duplicated(region, in: track, project: store.project) else { return }
        try? store.perform(commands, title: "Duplicate Region")
    }

    /// Joins the region with the pieces of the same file it continues — only when no bounce is needed.
    private func consolidate() {
        if let command = Arranging.consolidated(region, in: track, project: store.project) { try? store.perform(command) }
    }
}

/// The waveform inside an audio region: each column's lowest-to-highest sample in the track's hue,
/// softened, with its RMS over it, a flat hairline for silence. The file's picture is read once,
/// off the main thread and cancellable (`WaveformCache`), and lands in `@State` once per file: a
/// cold image. It reads no playhead and no clock, so it redraws only when its size or its window
/// changes (a zoom, a trim, a gain edit). It takes no touches and says nothing: a tap or hold
/// reaches the block, and the block speaks for the region.
private struct RegionWaveform: View {
    let url: URL?
    /// The first frame of the file the region plays, and how many.
    let offset: Int
    let length: Int
    /// The region's own level as a factor.
    let level: Float
    let tint: Color

    /// The file's picture: nil while it is read, and for a file that cannot be read (the block
    /// then stays plain).
    @State private var overview: WaveformOverview?

    var body: some View {
        // Read in `body`, not only in the renderer, so the landing read re-renders the leaf.
        let overview = self.overview
        let offset = self.offset, length = self.length, level = self.level, tint = self.tint
        Canvas { context, size in
            guard let overview, size.width > 0, size.height > 0 else { return }
            let columns = overview.window(offset: offset, length: length,
                                          columns: Self.columnCount(forWidth: Double(size.width)))
            guard !columns.isEmpty else { return }
            let mid = size.height / 2
            let width = size.width / CGFloat(columns.count)
            var peaks = Path()
            var bodies = Path()
            for (index, column) in columns.enumerated() {
                let x = CGFloat(index) * width
                let top = mid - Self.drawn(column.max, level) * mid
                let bottom = mid - Self.drawn(column.min, level) * mid
                peaks.addRect(CGRect(x: x, y: top, width: width, height: Swift.max(Self.hairline, bottom - top)))
                let rms = Swift.max(0, Self.drawn(column.rms, level)) * mid
                bodies.addRect(CGRect(x: x, y: mid - rms, width: width, height: rms * 2))
            }
            // Peaks behind, the RMS body in front: the extremes stay visible, the energy reads.
            context.fill(peaks, with: .color(tint.opacity(Self.peakOpacity)))
            context.fill(bodies, with: .color(tint.opacity(Self.bodyOpacity)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: url) {
            overview = nil
            guard let url else { return }
            let read = await WaveformCache.shared.overview(of: url)
            // A read for a file the region no longer plays must not land over the newer one.
            guard !Task.isCancelled else { return }
            overview = read
        }
    }

    /// One column per two points, at least one, at most 1 024 at any zoom; none for no width.
    private nonisolated static func columnCount(forWidth width: Double) -> Int {
        guard width.isFinite, width > 0 else { return 0 }
        return Int(Swift.min(width / 2, 1_024).rounded(.up))
    }

    /// A sample at the region's level, held to the block (±1); a value that is not a number is silence.
    private nonisolated static func drawn(_ value: Float, _ level: Float) -> CGFloat {
        let scaled = value * level
        guard scaled.isFinite else { return 0 }
        return CGFloat(Swift.min(Swift.max(scaled, -1), 1))
    }

    /// The thinnest a column is drawn — silence is a line, not nothing.
    private nonisolated static let hairline: CGFloat = 0.5
    /// Muted: the wave sits behind the name and the fades, in the track's hue, never brighter than them.
    private nonisolated static let peakOpacity: Double = 0.35
    private nonisolated static let bodyOpacity: Double = 0.6
}

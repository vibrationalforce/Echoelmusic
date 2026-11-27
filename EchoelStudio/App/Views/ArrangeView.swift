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
/// The zoom is kept on this device, never in the song, and is not an edit. Arrange opens where it
/// was left in this window, not at bar 1; only when the playhead moved while another view was open
/// does it open on where Play starts — stopped, with Follow Playhead on, and if that would be out
/// of sight from the kept place (`ArrangePaging`).
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
    /// Whether the modulation rows show under their tracks, kept on this device. Hidden, the
    /// routes still play; the button in the zoom bar shows them again (Michael on 10084: the rows
    /// stay in view and take the room).
    @AppStorage("arrange.showsModulation") private var showsModulation = true
    /// Whether the lanes page along with the playhead while the song plays, kept on this device
    /// (Michael on 10085: the song ran on past the screen's edge).
    @AppStorage("arrange.followsPlayhead") private var followsPlayhead = true
    /// Where the lanes are scrolled to; written only when they page by themselves — the playhead's
    /// page and the place Arrange opens at (`PlayheadFollower`).
    @State private var lanePosition = ScrollPosition(edge: .leading)
    /// What the lanes show now, read by the follower; not observed, so a scroll redraws nothing.
    @State private var viewport = ArrangeViewport()
    /// The height Arrange has on screen, so the track rows can share what the lanes leave free.
    @State private var visibleHeight: CGFloat = 0
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
                nameColumn(project, hits: hits)
                laneColumn(project, bars: bars, pointsPerBar: pointsPerBar, ticksPerPoint: ticksPerPoint,
                           laneWidth: laneWidth, files: files, hits: hits)
            }
            if project.tracks.isEmpty {
                Text("Add a track on the Tracks page to start arranging.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(Theme.Space.l)
            }
        }
        .background(Theme.Color.background)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { visibleHeight = $0 }
        .overlay(alignment: .trailing) {
            SideZoomStrip(zoom: $zoom)
                .padding(.vertical, Theme.Space.l)
                .padding(.trailing, Theme.Space.xs)
        }
        .environment(\.arrangeRowHeight, rowHeight(project))
        .safeAreaInset(edge: .bottom, spacing: 0) { zoomBar }
        // A video file added to the song is searched for its hits once, off the main thread.
        .task(id: videoMedia(of: project)) {
            videoHits?.find(in: store.project) { documents.mediaURL($0) }
        }
        .onAppear { noteFollow(followsPlayhead) }
    }

    /// Follow Playhead as it stands goes to the diagnostics log each time Arrange shows and each
    /// time it is switched, so a shared log says whether the lanes followed the playhead.
    private func noteFollow(_ on: Bool) {
        DiagnosticLog.app.note(DiagnosticReport.Event.followPlayhead, [("on", on ? 1 : 0)])
    }

    /// "1 bar", "4 bars": the song's length and a clip's, said and shown.
    static func barsLabel(_ bars: Int) -> String {
        bars == 1 ? "1 bar" : "\(bars) bars"
    }

    /// The names on the left: the song's length over the ruler, then every track and its lanes.
    /// Apart from `body` so each expression stays small enough to type-check.

    private func nameColumn(_ project: Project, hits: [Tick]) -> some View {
        VStack(spacing: Theme.Space.hairline) {
            Text(Self.barsLabel(Arranging.songBars(of: project)))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: Self.rulerRowHeight)
                .accessibilityLabel("Song length " + Self.barsLabel(Arranging.songBars(of: project)))
                .contextMenu {
                    AutomateMenu(owner: .master)
                    ModulateMenu(owner: .master)
                }
            ForEach(project.tracks) { track in
                trackName(track, showsHits: !hits.isEmpty)
                ForEach(TakeLanes.rows(of: track)) { row in TakeLaneName(row: row) }
                ForEach(Self.lanes(of: .track(track.id), in: project), id: \.target) { lane in
                    AutomationName(lane: lane)
                }
                ForEach(shownRoutes(of: .track(track.id), in: project)) { route in
                    ModulationName(route: route)
                }
            }
            ForEach(Self.lanes(of: .master, in: project), id: \.target) { lane in
                AutomationName(lane: lane)
            }
            ForEach(shownRoutes(of: .master, in: project)) { route in
                ModulationName(route: route)
            }
        }
        .frame(width: nameWidth)
    }

    /// The ruler, every lane and the playhead line in ONE horizontal scroll view, at one scale.
    private func laneColumn(_ project: Project, bars: Int, pointsPerBar: CGFloat, ticksPerPoint: Double,
                            laneWidth: CGFloat, files: [MediaID: Hits.FileHits], hits: [Tick]) -> some View {
        let meter = project.meterMap
        return ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: Theme.Space.hairline) {
                LoopStrip(meter: meter, ticksPerPoint: ticksPerPoint, width: laneWidth)
                RulerLocator(bars: bars, meter: meter, ticksPerPoint: ticksPerPoint, width: laneWidth)
                    .overlay(alignment: .bottomLeading) {
                        MarkerStrip(markers: project.markers, meter: meter, ticksPerPoint: ticksPerPoint)
                    }
                    .contextMenu { MarkerAddButton() }
                ForEach(project.tracks) { track in
                    ArrangeLane(track: track, project: project, pointsPerBar: pointsPerBar,
                                open: open, importAudio: importAudio, files: files, hits: hits)
                        .frame(width: laneWidth, height: rowHeight(project))
                    ForEach(TakeLanes.rows(of: track)) { row in
                        TakeLane(track: track, project: project, row: row, pointsPerBar: pointsPerBar)
                            .frame(width: laneWidth, height: TakeLanes.rowHeight)
                    }
                    ForEach(Self.lanes(of: .track(track.id), in: project), id: \.target) { lane in
                        AutomationRow(lane: lane, signature: project.timeSignature, pointsPerBar: pointsPerBar)
                            .frame(width: laneWidth, height: Theme.Size.trackRowHeight)
                    }
                    ForEach(shownRoutes(of: .track(track.id), in: project)) { route in
                        ModulationLane(route: route)
                            .frame(width: laneWidth, height: Theme.Size.trackRowHeight)
                    }
                }
                ForEach(Self.lanes(of: .master, in: project), id: \.target) { lane in
                    AutomationRow(lane: lane, signature: project.timeSignature, pointsPerBar: pointsPerBar)
                        .frame(width: laneWidth, height: Theme.Size.trackRowHeight)
                }
                ForEach(shownRoutes(of: .master, in: project)) { route in
                    ModulationLane(route: route)
                        .frame(width: laneWidth, height: Theme.Size.trackRowHeight)
                }
            }
            .overlay(alignment: .topLeading) {
                PlayheadLine(ticksPerPoint: ticksPerPoint)
            }
        }
        .scrollPosition($lanePosition)
        .onScrollGeometryChange(for: CGRect.self) { $0.visibleRect } action: { _, shown in
            viewport.visible = shown
        }
        .background {
            PlayheadFollower(ticksPerPoint: ticksPerPoint, follows: followsPlayhead, contentWidth: Double(laneWidth),
                             viewport: viewport, position: $lanePosition)
        }
        .simultaneousGesture(pinchGesture)
    }

    /// Two fingers zoom the song's time; the zoom is written once, when they lift.
    private var pinchGesture: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in zoom = ArrangeZoom.zoomed(zoom, by: Double(value.magnification)) }
    }

    /// Add Marker, Zoom Out and Zoom In under the lanes: the pinch is a shortcut, never the only
    /// way, and a marker is one tap away instead of only behind a hold on the ruler.
    private var zoomBar: some View {
        HStack(spacing: Theme.Space.s) {
            MarkerAddButton(compact: true)
            modulationToggle
            followToggle
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

    /// Turns the lanes' paging with the playhead on or off — while the song plays, and when Arrange
    /// opens stopped after the playhead moved elsewhere; drawn as on while it follows.
    private var followToggle: some View {
        Button {
            let on = !followsPlayhead
            followsPlayhead = on
            noteFollow(on)
        } label: {
            Image(systemName: "arrow.right.to.line")
                .font(Theme.Font.label)
                .foregroundStyle(followsPlayhead ? Theme.Color.accent : Theme.Color.textTertiary)
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Follow Playhead")
        .accessibilityValue(followsPlayhead ? "On" : "Off")
        .accessibilityHint("While the song plays, the lanes turn the page when the playhead reaches the edge. Stopped, Arrange opens on the playhead if it moved while another view was open.")
    }

    /// Shows or hides the modulation rows; drawn as on while they show.
    private var modulationToggle: some View {
        Button { showsModulation.toggle() } label: {
            Image(systemName: "waveform.path.ecg")
                .font(Theme.Font.label)
                .foregroundStyle(showsModulation ? Theme.Color.accent : Theme.Color.textTertiary)
                .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Modulation Rows")
        .accessibilityValue(showsModulation ? "Shown" : "Hidden")
        .accessibilityHint("Shows or hides the modulation rows under the tracks. Hidden routes still play.")
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
    /// A track's name in the names column, with its menu on a long press.
    private func trackName(_ track: Track, showsHits: Bool) -> some View {
        Text(track.name)
            .font(Theme.Font.label)
            .foregroundStyle(Theme.Color.text)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, Theme.Space.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: rowHeight(store.project))
            .background(Theme.Color.surface)
            .contextMenu { trackMenu(track, showsHits: showsHits) }
            // VoiceOver reaches the track's menu here — Automate and Modulate are nowhere else in
            // Arrange (audit 2026-11-19, UX #3): double-tap and hold opens it.
            .accessibilityLabel(track.name)
            .accessibilityHint("Double-tap and hold for the track's menu: Automate, Modulate, Rename.")
            .accessibilityAction(named: "Rename Track") { router.sheet = .rename(.track(track.id)) }
    }

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

    /// The modulation routes that move one owner's values, each shown as a row under its lanes.
    static func routes(of owner: ParameterAddress.Owner, in project: Project) -> [ModulationRoute] {
        project.modRoutes.filter { $0.target.owner == owner }
    }

    /// A track row's height: the room the ruler, the zoom bar and the lanes of fixed height leave,
    /// shared by the tracks — never less than a row always was, never more than twice it. The
    /// 10083 recording showed six rows over an empty half screen with names too small to read.
    private func rowHeight(_ project: Project) -> CGFloat {
        Self.rowHeight(project, visible: visibleHeight, showsModulation: showsModulation)
    }

    /// The routes shown as rows: all of the owner's, or none while the rows are hidden.
    private func shownRoutes(of owner: ParameterAddress.Owner, in project: Project) -> [ModulationRoute] {
        showsModulation ? Self.routes(of: owner, in: project) : []
    }

    static func rowHeight(_ project: Project, visible: CGFloat, showsModulation: Bool = true) -> CGFloat {
        let base = Theme.Size.trackRowHeight
        guard !project.tracks.isEmpty, visible.isFinite, visible > 0 else { return base }
        var fixed = rulerRowHeight + Theme.Size.touch
        for track in project.tracks {
            fixed += CGFloat(TakeLanes.rows(of: track).count) * TakeLanes.rowHeight
            fixed += CGFloat(lanes(of: .track(track.id), in: project).count
                             + (showsModulation ? routes(of: .track(track.id), in: project).count : 0)) * base
        }
        fixed += CGFloat(lanes(of: .master, in: project).count
                         + (showsModulation ? routes(of: .master, in: project).count : 0)) * base
        let share = (visible - fixed) / CGFloat(project.tracks.count)
        return Swift.min(Swift.max(share, base), base * 2)
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
/// The loop strip above the ruler (2026-11-27): drag across it to draw the bars the song loops
/// over, as on a cycle bar; a tap on the drawn bars turns the loop on or off; the menu goes back
/// to the whole song. The bars snap to bar lines (`Arranging.loopRegion`). Locked while a take
/// records or an export is written, as the ruler is: a take's passes are cut at the loop.
///
/// Reads the drawn region and the loop switch — both change with a press, never with the clock
/// (Law 6).
private struct LoopStrip: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(RecordController.self) private var recording
    @Environment(DocumentController.self) private var documents
    /// Where the drag started and where the finger is, in points along the strip.
    @GestureState private var drawing: (from: CGFloat, to: CGFloat)? = nil
    let meter: MeterMap
    let ticksPerPoint: Double
    let width: CGFloat

    static let height: CGFloat = 22
    /// Points a touch may move and still be a tap.
    private static let tapSlop: CGFloat = 6

    private var locked: Bool {
        !TimelineGeometry.mayLocate(recording: recording.isRecording, exporting: documents.isExporting)
    }

    var body: some View {
        let region = engine.loopRegion
        ZStack(alignment: .leading) {
            Rectangle().fill(Theme.Color.surface)
            if let drawing, !locked, let shown = self.region(from: drawing.from, to: drawing.to) {
                band(shown, active: true, drawing: true)
            } else if let region {
                band(region, active: engine.loopsSong, drawing: false)
            }
        }
        .frame(width: width, height: Self.height)
        .contentShape(Rectangle())
        // From the first touch, as the ruler's, so the strip draws instead of scrolling the lanes.
        // A touch that hardly moves is a tap: on the drawn bars it turns the loop on or off.
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($drawing) { value, state, _ in
                    guard Swift.abs(value.location.x - value.startLocation.x) >= Self.tapSlop else { return }
                    state = (value.startLocation.x, value.location.x)
                }
                .onEnded { value in
                    guard !locked else { return }
                    if Swift.abs(value.location.x - value.startLocation.x) < Self.tapSlop {
                        if engine.loopRegion != nil { engine.setLoopsSong(!engine.loopsSong) }
                        return
                    }
                    guard let drawn = self.region(from: value.startLocation.x, to: value.location.x) else { return }
                    engine.setLoopRegion(drawn)
                    Theme.Accessibility.announce(Announcement("Loop \(spoken(drawn))", priority: .normal))
                }
        )
        .contextMenu {
            if engine.loopRegion != nil {
                Button("Loop the Whole Song", systemImage: "arrow.left.and.right") { engine.setLoopRegion(nil) }
            }
            Button(engine.loopsSong ? "Loop Off" : "Loop On", systemImage: "repeat") { engine.setLoopsSong(!engine.loopsSong) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loop Region")
        .accessibilityValue((region.map(spoken) ?? "Whole song") + (engine.loopsSong ? ", on" : ", off"))
        .accessibilityHint(locked ? "Locked while a take records or an export is written."
                                  : "Drag across it to choose the bars the song loops over.")
        .accessibilityAction(named: "Loop the Whole Song") { engine.setLoopRegion(nil) }
        .accessibilityAction(named: engine.loopsSong ? "Loop Off" : "Loop On") { engine.setLoopsSong(!engine.loopsSong) }
    }

    /// The drawn bars as a band: the accent while the loop is on, an outline while it is off.
    private func band(_ region: Range<Tick>, active: Bool, drawing: Bool) -> some View {
        let start = CGFloat(TimelineGeometry.x(ofTick: region.lowerBound, ticksPerPoint: ticksPerPoint))
        let end = CGFloat(TimelineGeometry.x(ofTick: region.upperBound, ticksPerPoint: ticksPerPoint))
        return RoundedRectangle(cornerRadius: Theme.Radius.small)
            .fill(active ? Theme.Color.accent.opacity(drawing ? 0.35 : 0.5) : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).strokeBorder(Theme.Color.accent, lineWidth: 1))
            .frame(width: Swift.max(end - start, 2), height: Self.height - 6)
            .offset(x: start)
    }

    /// The bars a drag between two points along the strip draws.
    private func region(from: CGFloat, to: CGFloat) -> Range<Tick>? {
        Arranging.loopRegion(from: TimelineGeometry.tick(clamping: Double(from) * ticksPerPoint),
                             to: TimelineGeometry.tick(clamping: Double(to) * ticksPerPoint), meter: meter)
    }

    /// "bars 3 to 4", "bar 3".
    private func spoken(_ region: Range<Tick>) -> String {
        let first = meter.bar(at: region.lowerBound) + 1
        let last = meter.bar(at: region.upperBound - 1) + 1
        return first == last ? "bar \(first)" : "bars \(first) to \(last)"
    }
}

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

/// What the lanes' scroll view shows, in its content's points. A plain class held in `@State`, not
/// observed: the scroll writes it on every frame and no view redraws for it.
@MainActor
private final class ArrangeViewport {
    var visible: CGRect = .zero
    /// Whether this appearance of Arrange has opened on its place yet (`PlayheadFollower.open`); a
    /// new appearance starts with a new viewport, so it opens once each time.
    var opened = false
}

/// Turns the lanes' page by itself (`ArrangePaging`). While the song plays and Follow Playhead is
/// on, five times a second it reads where the playhead is heard and, when it nears the right edge
/// or has jumped out of view (a loop's wrap, a locate), scrolls so it stands a tenth of the width
/// in from the left. When Arrange is left it keeps, for this window (scene storage, never in the
/// song), the tick at the lanes' left edge and the tick the playhead stands on; when Arrange opens
/// again it opens on that place, at the first width it is laid out with — unless the playhead moved
/// meanwhile and, stopped with Follow on, where Play starts would be out of sight there. Reads the
/// playhead in a task and the transport in its actions, never in a body (Law 6); draws nothing and
/// takes no touch.
private struct PlayheadFollower: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(ProjectStore.self) private var store
    /// The tick at the lanes' left edge when Arrange was last left in this window.
    @SceneStorage(ArrangePaging.storageKey) private var leftEdgeTick = 0
    /// The tick the playhead stood on then; `ArrangePaging.nothingKept` until Arrange is first left.
    @SceneStorage(ArrangePaging.playheadStorageKey) private var playheadWhenLeft = ArrangePaging.nothingKept
    let ticksPerPoint: Double
    let follows: Bool
    /// The lanes' whole width, so a kept place past the song's end opens on their last page.
    let contentWidth: Double
    let viewport: ArrangeViewport
    @Binding var position: ScrollPosition

    var body: some View {
        let playing = engine.isPlaying
        Color.clear
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            // A background has the scroll view's frame: its width is the lanes' visible width.
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in open(width: width) }
            .onDisappear { keep() }
            .task(id: "\(playing) \(follows) \(ticksPerPoint)") {
                guard playing, follows else { return }
                while !Task.isCancelled {
                    page()
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
    }

    /// Once per appearance, at the first width: where Arrange was left, or where Play starts when the
    /// playhead moved while Arrange was away.
    private func open(width: CGFloat) {
        guard !viewport.opened, width > 0 else { return }
        viewport.opened = true
        let x = ArrangePaging.opening(leftEdge: Tick(leftEdgeTick),
                                      playheadWhenLeft: ArrangePaging.keptTick(playheadWhenLeft),
                                      restingAt: engine.restingTick, playing: engine.isPlaying, follows: follows,
                                      ticksPerPoint: ticksPerPoint, width: Double(width), contentWidth: contentWidth)
        if x > 0 { position.scrollTo(x: CGFloat(x)) }
    }

    /// The tick at the left edge and the one the playhead stands on, for the next time Arrange opens
    /// in this window.
    private func keep() {
        leftEdgeTick = Int(clamping: ArrangePaging.leftEdgeTick(atX: Double(viewport.visible.minX),
                                                                ticksPerPoint: ticksPerPoint))
        playheadWhenLeft = Int(clamping: ArrangePaging.playheadTick(heard: engine.heardTick(in: store.project)))
    }

    private func page() {
        let shown = viewport.visible
        guard let x = ArrangePaging.target(showing: engine.heardTick(in: store.project), ticksPerPoint: ticksPerPoint,
                                           left: Double(shown.minX), width: Double(shown.width)) else { return }
        position.scrollTo(x: CGFloat(x))
    }
}

/// "Add Marker" on the ruler's hold menu and, `compact`, as a flag in the zoom bar: a marker on the
/// magnet's line nearest the playhead, named "Marker N", one undo step. The playhead is read when
/// the button is pressed, never in a body.
private struct MarkerAddButton: View {
    var compact = false
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
    @Environment(AudioEngine.self) private var engine
    @AppStorage(SnapGrid.storageKey) private var snap: SnapGrid = .standard

    var body: some View {
        if compact {
            Button(action: add) {
                Image(systemName: "flag")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.text)
                    .frame(width: Theme.Size.touch, height: Theme.Size.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add Marker at Playhead")
        } else {
            Button("Add Marker at Playhead", systemImage: "flag", action: add)
        }
    }

    private func add() {
        let project = store.project
        let tick = snap.nearest(engine.playheadTick(in: project), meter: project.meterMap)
        documents.attempt(.addMarker(at: tick, name: project.nextMarkerName()))
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
    @Environment(DocumentController.self) private var documents
    @Environment(RecordController.self) private var recording
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
        // A tap plays from the marker, as on a desktop DAW's marker list; the menu edits it.
        .onTapGesture { playFromHere() }
        .contextMenu { menu }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Marker \(marker.name), bar \(bar)")
        .accessibilityAction { playFromHere() }
        .accessibilityHint("Plays from the marker. Its other actions rename, move or delete it.")
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

    /// The song plays on from the marker, or will start there; refused while a take records or an
    /// export is written, as the ruler's tap is.
    private func playFromHere() {
        guard TimelineGeometry.mayLocate(recording: recording.isRecording, exporting: documents.isExporting) else { return }
        engine.locate(to: marker.tick)
    }

    private func moveToPlayhead() {
        let project = store.project
        let to = snap.nearest(engine.playheadTick(in: project), meter: project.meterMap)
        guard to != marker.tick else { return }
        documents.attempt(.moveMarker(from: marker.tick, to: to))
    }

    private func move(byBars bars: Int64) {
        let to = Swift.max(0, marker.tick + Arranging.ticks(movingBars: bars, from: marker.tick, meter: meter))
        guard to != marker.tick else { return }
        documents.attempt(.moveMarker(from: marker.tick, to: to))
    }

    private func remove() { documents.attempt(.removeMarker(at: marker.tick)) }
}

/// One track's lane: bar lines, its placements, and taps on empty space.
private struct ArrangeLane: View {
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
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
            documents.attempt(command)
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
            documents.attempt(command)
        }
    }

    /// A track's first clip: four empty bars, placed where the tap fell.
    private func createClip(at start: Tick) {
        guard track.kind == .instrument else { return }
        let clip = ClipID()
        documents.attempt([
            .createClip(track: track.id, id: clip, name: track.nextClipName(),
                        length: Swift.max(Arranging.ticks(movingBars: 4, from: start, meter: meter), 1)),
            .placeClip(track: track.id, id: PlacementID(), clip: clip, start: start),
        ], title: "New Clip")
    }
}

/// A placed clip. The drag offset lives in view state while the finger is down and becomes
/// one move command when it lifts.
private struct PlacementBlock: View {
    /// The track row's height (`ArrangeView.rowHeight`): the block fills it.
    @Environment(\.arrangeRowHeight) private var rowHeight
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
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
    /// An edge drag in progress, as the edge shows on the magnet's line (2026-11-19).
    @State private var trimLeft: CGFloat = 0
    @State private var trimRight: CGFloat = 0
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

    /// The block itself: shape, name, size, position, the edge grips and the move drag.
    private var block: some View {
        let color = Theme.Color.track(track.colorIndex)
        let width = Swift.max(8, CGFloat(Double(clip.length) / ticksPerPoint) - trimLeft + trimRight)
        let dragging = dragX != 0 || trimLeft != 0 || trimRight != 0
        // Two 44-pt grips need a block of two touch targets, or no room is left to move it; a
        // narrower block trims in the editor's length menu, or after zooming in.
        let grips = CGFloat(Double(clip.length) / ticksPerPoint) >= Self.gripsNeed
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
                    .minimumScaleFactor(0.7)
                    .padding(Theme.Space.xs)
            }
            .overlay(alignment: .bottomTrailing) { linkBadge }
            .overlay(alignment: .leading) { if grips { edgeHandle(.start, color: color) } }
            .overlay(alignment: .trailing) { if grips { edgeHandle(.end, color: color) } }
            .frame(width: width, height: rowHeight - Theme.Space.s)
            .offset(x: CGFloat(Double(placement.start) / ticksPerPoint) + dragX + trimLeft, y: Theme.Space.xs)
            .opacity(dragging ? 0.8 : 1)
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

    /// The narrowest block that shows its grips, in points.
    private static let gripsNeed: CGFloat = 88

    /// A grip along one edge, as an audio region has (2026-11-19): drag the start or the end to
    /// shorten or lengthen the clip. It looks narrow (a 4-pt stripe with 8 pt either side) and
    /// takes a full touch target, 44 pt, half of it beyond the edge; it wins over the move drag.
    private func edgeHandle(_ edge: Arranging.Edge, color: Color) -> some View {
        Rectangle()
            .fill(color.opacity(0.6))
            .frame(width: Theme.Space.xs)
            .padding(.horizontal, Theme.Space.s)
            .contentShape(Rectangle().inset(by: -Theme.Space.m))
            .highPriorityGesture(trimGesture(edge))
            .accessibilityHidden(true)
    }

    /// The edge follows the finger on the magnet's line and trims once when it lifts: one undo step.
    private func trimGesture(_ edge: Arranging.Edge) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(ArrangeLane.space))
            .onChanged { value in
                let from: Tick = edge == .start ? placement.start : placement.start + clip.length
                let shown = snap.previewOffset(from: from, translation: value.translation.width,
                                               ticksPerPoint: ticksPerPoint, meter: meter)
                if edge == .start { trimLeft = shown } else { trimRight = shown }
            }
            .onEnded { value in
                trimLeft = 0
                trimRight = 0
                let delta = ArrangeZoom.ticks(dragged: Double(value.translation.width), ticksPerPoint: ticksPerPoint)
                trim(edge, byTicks: delta, snap: snap)
            }
    }

    private func trim(_ edge: Arranging.Edge, byTicks delta: Tick, snap: SnapGrid) {
        guard let commands = Arranging.trimmed(placement, edge: edge, byTicks: delta, in: track,
                                               project: store.project, snap: snap) else { return }
        documents.attempt(commands, title: "Trim Clip")
    }

    /// VoiceOver's trims by one bar, on the bar whatever the magnet says — and what came of it is
    /// said, or why nothing did (audit A3 #6: these actions were silent).
    private func trim(_ edge: Arranging.Edge, bars: Int64) {
        let from: Tick = edge == .start ? placement.start : placement.start + clip.length
        guard let commands = Arranging.trimmed(placement, edge: edge,
                                               byTicks: Arranging.ticks(movingBars: bars, from: from, meter: meter),
                                               in: track, project: store.project, snap: .bar) else {
            return ArrangeSpeech.say("Not trimmed: the clip stops at bar 1 and at the next clip.")
        }
        guard documents.attempt(commands, title: "Trim Clip") else { return }
        let placed = store.project.track(track.id)?.placements.first { $0.id == placement.id } ?? placement
        let length = store.project.track(track.id)?.clips.first { $0.id == placed.clip }?.length ?? clip.length
        ArrangeSpeech.say(edge == .start ? "Starts at " + ArrangeSpeech.position(placed.start, meter: meter)
                                         : "Ends at " + ArrangeSpeech.position(placed.start + length, meter: meter))
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
            if let command = Hits.placed(placement, in: track, at: hit) { documents.attempt(command) }
        } else if let command = Arranging.moved(placement, in: track, byTicks: delta, meter: meter, snap: snap) {
            documents.attempt(command)
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
        Button("Remove from Song", systemImage: "trash", role: .destructive) { remove() }
        // The clip itself: every place it is in the arrangement and every session slot (undoable).
        Button("Delete Clip Everywhere", systemImage: "trash.slash", role: .destructive) {
            documents.attempt(.deleteClip(clip.id))
        }
    }

    /// Split in two chains: one chain of all the actions timed out the type checker (2026-11-19).
    private func accessible(_ view: some View) -> some View {
        trimActions(
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
        )
    }

    private func trimActions(_ view: some View) -> some View {
        view
            .accessibilityAction(named: "Consolidate") { consolidate() }
            .accessibilityAction(named: "Lengthen End One Bar") { trim(.end, bars: 1) }
            .accessibilityAction(named: "Shorten End One Bar") { trim(.end, bars: -1) }
            .accessibilityAction(named: "Start One Bar Earlier") { trim(.start, bars: -1) }
            .accessibilityAction(named: "Start One Bar Later") { trim(.start, bars: 1) }
            .accessibilityAction(named: "Rename Clip") { router.sheet = .rename(.clip(clip.id)) }
            .accessibilityAction(named: "Remove from Song") { remove() }
            .accessibilityAction(named: "Delete Clip Everywhere") { documents.attempt(.deleteClip(clip.id)) }
    }

    private func move(byBars bars: Tick) {
        if let command = Arranging.moved(placement, in: track,
                                         byTicks: Arranging.ticks(movingBars: bars, from: placement.start, meter: meter), meter: meter) {
            documents.attempt(command)
        }
    }

    /// The block's VoiceOver label: name, where, how long, and whether it is a linked copy.
    private var spokenLabel: String {
        let base = "\(clip.name), bar \(startBar), " + ArrangeView.barsLabel(lengthBars)
        return uses >= 2 ? "\(base), linked, plays in \(uses) places" : base
    }

    /// An independent copy right after it: a clip of its own, one undo step.
    private func duplicate() {
        if let commands = Arranging.copied(placement, in: track) { documents.attempt(commands, title: "Duplicate") }
    }

    /// A linked copy right after it: the same clip again, so a note edit is heard in both.
    private func duplicateLinked() {
        if let command = Arranging.duplicated(placement, in: track) {
            documents.attempt([command], title: "Duplicate as Linked")
        }
    }

    /// Gives this placement a clip of its own; nothing happens when nothing else plays its clip.
    private func makeUnique() {
        if let command = Arranging.madeUnique(placement, in: track) { documents.attempt(command) }
    }

    /// Starts the clip exactly on the first hit after its start, one undo step; nothing after the last hit.
    private func placeAtNextHit() {
        guard let hit = nextHit, let command = Hits.placed(placement, in: track, at: hit) else { return }
        documents.attempt([command], title: "Place at Next Hit")
    }

    /// Cuts on the magnet's line nearest the playhead (at the playhead with it off); nothing
    /// happens when that is outside the clip.
    private func splitAtPlayhead() {
        let tick = engine.playheadTick(in: store.project)
        if let command = Arranging.split(placement, in: track, at: tick, meter: meter, snap: snap) {
            documents.attempt(command)
        }
    }

    /// Joins the clip with the placements touching or overlapping it into one clip.
    private func consolidate() {
        if let command = Arranging.consolidated(placement, in: track) { documents.attempt(command) }
    }

    private func remove() {
        documents.attempt(.removePlacement(track: track.id, placement.id))
    }
}

/// A placed audio region: the file's name over its length. Drag moves it onto the magnet, one
/// undo step on release; drag an edge to trim it onto the magnet, a top corner's grip to set its
/// fade (one undo step each); hold for Duplicate, Split at
/// Playhead (on the magnet), Consolidate (pieces of one file only), Bake Effects and Delete. A video part
/// shows its hits (CUT); an audio region lands on one within reach and moves to the next on Place
/// at Next Hit.
private struct RegionBlock: View {
    /// The track row's height (`ArrangeView.rowHeight`): the block fills it.
    @Environment(\.arrangeRowHeight) private var rowHeight
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
        // A tap opens the region's settings — fades, gain, warp, and the doors to Convert to
        // MIDI, Pitch & Texture, Transcribe, Color and Bake — which were only behind a hold; an audio region
        // (hidden-features audit 2026-11-20, #1). The hold menu stays.
        accessible(block.onTapGesture { editFades() }.contextMenu { menu })
    }

    /// The block itself: shape, name, size, position and the move drag.
    /// Built in three steps — the face, the marks and grips over it, its place in the lane — so
    /// each chain stays small enough to type-check.
    private var block: some View {
        let color = Theme.Color.track(track.colorIndex)
        let width: CGFloat = blockWidth
        let marked = grips(marks(face(color: color)), width: width)
        return placed(marked, width: width)
    }

    /// Drawn width: the region's length at this zoom, with an edge drag in progress, never under 8 pt.
    private var blockWidth: CGFloat {
        let drawn = CGFloat(Double(length) / ticksPerPoint)
        return Swift.max(8, drawn - trimLeft + trimRight)
    }

    /// The fill, the outline, the waveform and the file's name.
    private func face(color: Color) -> some View {
        let outline = RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(color, lineWidth: 1)
        return RoundedRectangle(cornerRadius: Theme.Radius.small)
            .fill(color.opacity(0.25))
            .overlay(outline)
            .overlay { waveform(tint: color) }
            .overlay(alignment: .topLeading) { nameLabel }
    }

    private var nameLabel: some View {
        let symbol = file.kind == .video ? "film" : "waveform"
        return Label(file.name, systemImage: symbol)
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.text)
            .lineLimit(1)
            .padding(Theme.Space.xs)
    }

    /// The fades' curve and a video part's hits, drawn over the face.
    private func marks(_ view: some View) -> some View {
        view
            .overlay { fadeMarks }
            .overlay { hitMarks }
    }

    /// The trim handles on the edges and the fade grips on the top corners.
    private func grips(_ view: some View, width: CGFloat) -> some View {
        view
            .overlay(alignment: .leading) { edgeHandle(.start) }
            .overlay(alignment: .trailing) { edgeHandle(.end) }
            .overlay(alignment: .topLeading) { fadeGrip(.start, width: width) }
            .overlay(alignment: .topLeading) { fadeGrip(.end, width: width) }
    }

    /// Size, place in the lane (following a move or a left-edge drag), and the move drag.
    private func placed(_ view: some View, width: CGFloat) -> some View {
        let height: CGFloat = rowHeight - Theme.Space.s
        let x: CGFloat = CGFloat(Double(region.start) / ticksPerPoint) + dragX + trimLeft
        let isDragging = dragX != 0 || trimLeft != 0 || trimRight != 0
        let opacity: Double = isDragging ? 0.8 : 1
        return view
            .frame(width: width, height: height)
            .offset(x: x, y: Theme.Space.xs)
            .opacity(opacity)
            .gesture(moveGesture)
    }

    /// The move drag: the block follows the finger onto the magnet or a hit, one undo step on release.
    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(ArrangeLane.space))
            .onChanged { value in dragX = dragOffset(value.translation.width) }
            .onEnded { value in
                dragX = 0
                drop(movedBy: value.translation.width)
            }
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
            if let command = Hits.placed(region, in: track, at: hit) { documents.attempt(command) }
        } else if let command = Arranging.moved(region, in: track, byTicks: delta, meter: meter, snap: snap) {
            documents.attempt(command)
        }
    }

    /// Starts the region exactly on the first hit after its start, one undo step.
    private func placeAtNextHit() {
        guard let hit = nextHit, let command = Hits.placed(region, in: track, at: hit) else { return }
        documents.attempt([command], title: "Place at Next Hit")
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
        Button("Remove from Song", systemImage: "trash", role: .destructive) { remove() }
        // The file itself: every region and clip that plays it, and a sampler holding it (undoable).
        Button("Remove File from Song", systemImage: "trash.slash", role: .destructive) { removeFile() }
    }

    private func removeFile() {
        documents.attempt(.removeMedia(file.id))
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

    /// VoiceOver's region: one element, its label, and every action the hold menu and the grips
    /// offer, in this order. Split in groups so each chain stays small enough to type-check.
    private func accessible(_ view: some View) -> some View {
        let element = view
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenLabel)
        return fadeActions(trimActions(editActions(moveActions(element))))
    }

    private func moveActions(_ view: some View) -> some View {
        view
            .accessibilityAction(named: "Move One Bar Later") { move(byBars: 1) }
            .accessibilityAction(named: "Move One Bar Earlier") { move(byBars: -1) }
            .accessibilityAction(named: "Place at Next Hit") { placeAtNextHit() }
    }

    private func editActions(_ view: some View) -> some View {
        view
            .accessibilityAction(named: "Fades, Gain and Warp") { editFades() }
            .accessibilityAction(named: "Pitch and Texture") { editPitchTexture() }
            .accessibilityAction(named: "Duplicate") { duplicate() }
            .accessibilityAction(named: "Split at Playhead") { split() }
            .accessibilityAction(named: "Consolidate") { consolidate() }
            .accessibilityAction(named: "Bake Effects") { if canBake { bake() } }
            .accessibilityAction(named: "Remove from Song") { remove() }
    }

    private func trimActions(_ view: some View) -> some View {
        view
            .accessibilityAction(named: "Trim Start One Beat Later") { trim(.start, beats: 1) }
            .accessibilityAction(named: "Trim End One Beat Earlier") { trim(.end, beats: -1) }
            .accessibilityAction(named: "Extend End One Beat") { trim(.end, beats: 1) }
    }

    private func fadeActions(_ view: some View) -> some View {
        view
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
            .highPriorityGesture(trimGesture(edge))
            .accessibilityHidden(true)
    }

    /// An edge drag: the edge shows on the magnet's line the release trims to, at this zoom, and
    /// trims once when the finger lifts.
    private func trimGesture(_ edge: Arranging.Edge) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(ArrangeLane.space))
            .onChanged { value in
                let from: Tick = edge == .start ? region.start : region.start + length
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
    }

    /// A grip on one top corner — the fade-in's on the left, the fade-out's on the right — that
    /// sits where its fade ends and drags it longer or shorter; it wins over the move drag. It
    /// looks small (an 8-pt square just inside the top) and takes a 44-pt touch target centred on
    /// it, so the lower part of each edge stays the trim handle. The fade follows the finger and
    /// is set ONCE when it lifts: one command, one undo step. Audio regions only.
    @ViewBuilder private func fadeGrip(_ edge: Arranging.Edge, width: CGFloat) -> some View {
        if file.kind == .audio {
            let centre: CGFloat = gripCentre(edge, width: width)
            let inset: CGFloat = Self.gripInset
            let half: CGFloat = Self.gripTarget / 2
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.Color.text)
                .frame(width: Self.gripSize, height: Self.gripSize)
                .frame(width: Self.gripTarget, height: Self.gripTarget)
                .contentShape(Rectangle())
                .offset(x: centre - half, y: inset - half)
                .highPriorityGesture(fadeGesture(edge))
                .accessibilityHidden(true)
        }
    }

    /// Where a fade grip's centre sits: at the end of its fade, held just inside the block.
    private func gripCentre(_ edge: Arranging.Edge, width: CGFloat) -> CGFloat {
        let fades = shownFades
        let total = CGFloat(Swift.max(region.length, 1))
        let frames: Int = edge == .start ? fades.fadeIn : fades.fadeOut
        let share = CGFloat(frames) / total
        let fadeEndX: CGFloat = edge == .start ? share * width : width - share * width
        let inset = Self.gripInset
        return Swift.max(inset, Swift.min(fadeEndX, width - inset))
    }

    /// A fade grip's drag: the fade follows the finger and is set once, when it lifts.
    private func fadeGesture(_ edge: Arranging.Edge) -> some Gesture {
        let drawnWidth = Double(length) / ticksPerPoint
        return DragGesture(minimumDistance: 2, coordinateSpace: .named(ArrangeLane.space))
            .onChanged { value in
                let frames = Arranging.fadeFrames(region, edge: edge, dragged: Double(value.translation.width),
                                                  widthPoints: drawnWidth)
                fadeDrag = (edge: edge, frames: frames)
            }
            .onEnded { value in
                fadeDrag = nil
                let frames = Arranging.fadeFrames(region, edge: edge, dragged: Double(value.translation.width),
                                                  widthPoints: drawnWidth)
                setFade(edge, toFrames: frames)
            }
    }

    /// One command, one undo step.
    private func setFade(_ edge: Arranging.Edge, toFrames frames: Int) {
        guard let command = Arranging.faded(region, edge: edge, toFrames: frames, in: track) else { return }
        documents.attempt([command], title: edge == .start ? "Fade In" : "Fade Out")
    }

    /// VoiceOver's fades by one beat: the same command a grip sets; said after (audit A3 #6).
    private func fade(_ edge: Arranging.Edge, beats: Int) {
        guard file.kind == .audio,
              let command = Arranging.faded(region, edge: edge, byBeats: beats, in: track, project: store.project) else {
            return ArrangeSpeech.say(edge == .start ? "The fade in cannot change further." : "The fade out cannot change further.")
        }
        guard documents.attempt([command], title: edge == .start ? "Fade In" : "Fade Out") else { return }
        ArrangeSpeech.say(edge == .start ? "Fade in changed by \(beats) beat" : "Fade out changed by \(beats) beat")
    }

    /// The fade grip as it shows, and the touch it takes.
    private static let gripSize: CGFloat = 8
    private static let gripTarget: CGFloat = 44
    /// How far a grip's centre stays inside the block's edges and top.
    private static let gripInset: CGFloat = gripSize / 2 + 2

    /// VoiceOver's trims by one beat, on the beat whatever the magnet says; said after (audit A3 #6).
    private func trim(_ edge: Arranging.Edge, beats: Tick) {
        let delta = beats * meter.ticksPerBeat(at: region.start)
        let found = edge == .end && beats > 0
            ? Arranging.extended(region, byTicks: delta, in: track, project: store.project, snap: .beat)
            : Arranging.trimmed(region, edge: edge, byTicks: delta, in: track, project: store.project, snap: .beat)
        guard let commands = found else {
            return ArrangeSpeech.say("Not trimmed: the region stops at its file's edge, bar 1 and the next region.")
        }
        guard documents.attempt(commands, title: "Trim Region") else { return }
        let placed = store.project.track(track.id)?.regions.first { $0.id == region.id } ?? region
        ArrangeSpeech.say(edge == .start ? "Starts at " + ArrangeSpeech.position(placed.start, meter: meter) : "End trimmed")
    }

    /// The end drawn past the file repeats the region up to where the finger lifted (`Arranging.extended`).
    private func apply(_ edge: Arranging.Edge, byTicks delta: Tick, snap: SnapGrid) {
        let commands = edge == .end
            ? Arranging.extended(region, byTicks: delta, in: track, project: store.project, snap: snap)
            : Arranging.trimmed(region, edge: edge, byTicks: delta, in: track, project: store.project, snap: snap)
        guard let commands else { return }
        documents.attempt(commands, title: Self.loops(commands) ? "Loop Region" : "Trim Region")
    }

    /// Whether the commands place copies of the region, rather than only trim it.
    private static func loops(_ commands: [Command]) -> Bool {
        commands.contains { if case .placeAudio = $0 { return true } else { return false } }
    }

    private func move(byBars bars: Tick) {
        guard let command = Arranging.moved(region, in: track,
                                            byTicks: Arranging.ticks(movingBars: bars, from: region.start, meter: meter),
                                            meter: meter) else {
            return ArrangeSpeech.say("Not moved: the region stops at bar 1 and at the next region.")
        }
        guard documents.attempt(command) else { return }
        let placed = store.project.track(track.id)?.regions.first { $0.id == region.id } ?? region
        ArrangeSpeech.say("Moved to " + ArrangeSpeech.position(placed.start, meter: meter))
    }

    private func remove() {
        documents.attempt(.removeRegion(track: track.id, region.id))
    }

    /// A cut on the magnet's line nearest the playhead (C5; at the playhead with it off): nothing
    /// of the file is lost, both parts stay movable and trimmable, and one Undo joins them again.
    private func split() {
        let project = store.project
        let at = snap.nearest(engine.playheadTick(in: project), meter: project.meterMap)
        documents.attempt(.splitRegion(track: track.id, region.id, at: at, newID: RegionID()))
    }

    private func duplicate() {
        guard let commands = Arranging.duplicated(region, in: track, project: store.project) else { return }
        documents.attempt(commands, title: "Duplicate Region")
    }

    /// Joins the region with the pieces of the same file it continues — only when no bounce is needed.
    private func consolidate() {
        if let command = Arranging.consolidated(region, in: track, project: store.project) { documents.attempt(command) }
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
        // Read in `body`, not only in the renderer, so the landing read re-renders the leaf. A
        // different name than the property: the task below writes `overview`, and a local of
        // the same name would shadow it as a constant.
        let picture = self.overview
        let offset = self.offset, length = self.length, level = self.level, tint = self.tint
        Canvas { context, size in
            guard let picture, size.width > 0, size.height > 0 else { return }
            let columns = picture.window(offset: offset, length: length,
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

/// What a VoiceOver action in the arrangement says after it (audit A3 #6): the new place, or why
/// nothing moved. Said the app's one way (`Theme.Accessibility`).
@MainActor
enum ArrangeSpeech {
    static func say(_ text: String) {
        Theme.Accessibility.announce(Announcement(text, priority: .normal))
    }

    /// "bar 5, beat 1" — the place as the note editor says it, on the beat.
    static func position(_ tick: Tick, meter: MeterMap) -> String {
        NoteEditing.spokenPosition(tick, meter: meter, grid: meter.ticksPerBeat(at: tick))
    }
}

extension EnvironmentValues {
    /// The height of a track's row in Arrange, which grows into free room (`ArrangeView.rowHeight`).
    @Entry var arrangeRowHeight: CGFloat = 56
}

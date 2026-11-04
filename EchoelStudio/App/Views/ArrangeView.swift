import EchoelCore
import SwiftUI

/// The song on a bar timeline: one lane per track, its clips and audio laid out where they
/// play. Tap empty space to place the track's clip at that bar — or, on an audio track, to
/// import a file there; tap a clip to edit its notes, drag a clip or audio region to move it
/// onto the magnet (Snap, shared with the note editor: Off to the tick, Bar, Beat, 1/8 … 1/128,
/// triplets), hold for Snap, Duplicate, Split at Playhead, Consolidate and Delete. One drag is one
/// undo step, and so is each of those.
/// A video part shows its hits (CUT): where the picture cuts and where a sound in its own audio
/// begins. With Snap to Hits a dragged clip or audio region lands on a hit within reach instead of
/// the bar, and Place at Next Hit moves one to the next hit.
/// Reads no playhead, so nothing here rebuilds while the song plays.
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
    /// Points per bar; the horizontal zoom.
    private let pointsPerBar: CGFloat = 88
    /// Empty bars drawn past the song's end, so there is always room to place the next clip.
    private static let spareBars = 8

    var body: some View {
        let project = store.project
        let bars = Arranging.songBars(of: project) + Self.spareBars
        // The first bar is `pointsPerBar` wide; every later one as wide as its ticks (a 7/8 bar
        // after 4/4 is narrower), so x stays proportional to musical time.
        let meter = project.meterMap
        let ticksPerPoint = Double(meter.ticksPerBar(at: 0)) / Double(pointsPerBar)
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
                        .frame(height: Theme.Size.rulerHeight)
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
                        BarRuler(bars: bars, meter: meter, ticksPerPoint: ticksPerPoint, width: laneWidth)
                            .overlay(alignment: .topLeading) {
                                MarkerStrip(markers: project.markers, meter: meter, ticksPerPoint: ticksPerPoint)
                            }
                            .contextMenu { MarkerAddButton() }
                        ForEach(project.tracks) { track in
                            ArrangeLane(track: track, project: project, pointsPerBar: pointsPerBar,
                                        open: open, importAudio: importAudio, files: files, hits: hits)
                                .frame(width: laneWidth, height: Theme.Size.trackRowHeight)
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
                }
            }
            if project.tracks.isEmpty {
                Text("Add a track on the Tracks page to start arranging.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(Theme.Space.l)
            }
        }
        .background(Theme.Color.background)
        // A video file added to the song is searched for its hits once, off the main thread.
        .task(id: videoMedia(of: project)) {
            videoHits?.find(in: store.project) { documents.mediaURL($0) }
        }
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
    func previewOffset(from start: Tick, translation: CGFloat, ticksPerPoint: Double, meter: MeterMap) -> CGFloat {
        guard self != .off, ticksPerPoint.isFinite, ticksPerPoint > 0 else { return translation }
        let target = nearest(start + Tick((Double(translation) * ticksPerPoint).rounded()), meter: meter)
        return CGFloat(Double(target - start) / ticksPerPoint)
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
        Double(meter.ticksPerBar(at: 0)) / Double(pointsPerBar)
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

    private var ticksPerPoint: Double { Double(meter.ticksPerBar(at: 0)) / Double(pointsPerBar) }
    private var startBar: Int { Int(clamping: meter.bar(at: placement.start)) + 1 }
    private var lengthBars: Int {
        Int(clamping: meter.bar(at: meter.nextBarLine(atOrAfter: placement.start + clip.length)) - meter.bar(at: placement.start))
    }
    private var nextHit: Tick? { Hits.next(after: placement.start, in: hits) }

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

    /// Where the block shows while the finger moves: on a hit as soon as one is within reach.
    private func dragOffset(_ translation: CGFloat) -> CGFloat {
        let tick = placement.start + Tick((Double(translation) * ticksPerPoint).rounded())
        guard let hit = ArrangeView.hit(near: tick, in: hits, ticksPerPoint: ticksPerPoint, snapping: snapsToHits) else {
            return snap.previewOffset(from: placement.start, translation: translation, ticksPerPoint: ticksPerPoint, meter: meter)
        }
        return CGFloat(Double(hit - placement.start) / ticksPerPoint)
    }

    /// One undo step: onto the hit within reach, else onto the magnet's nearest line (to the tick
    /// with it off).
    private func drop(movedBy translation: CGFloat) {
        let delta = Tick((Double(translation) * ticksPerPoint).rounded())
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
            .accessibilityLabel("\(clip.name), bar \(startBar), \(lengthBars) bars")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the note editor.")
            .accessibilityAction { open(track.id, clip.id) }
            .accessibilityAction(named: "Move One Bar Later") { move(byBars: 1) }
            .accessibilityAction(named: "Move One Bar Earlier") { move(byBars: -1) }
            .accessibilityAction(named: "Place at Next Hit") { placeAtNextHit() }
            .accessibilityAction(named: "Duplicate") { duplicate() }
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

    private func duplicate() {
        if let command = Arranging.duplicated(placement, in: track) { try? store.perform(command) }
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
/// undo step on release; drag an edge to trim it onto the magnet; hold for Duplicate, Split at
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
    @AppStorage(ArrangeView.snapsToHitsKey) private var snapsToHits = true
    @AppStorage(SnapGrid.storageKey) private var snap: SnapGrid = .standard

    private var ticksPerPoint: Double { Double(meter.ticksPerBar(at: 0)) / Double(pointsPerBar) }
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

    /// The region's fades over it, drawn as the curve they play: a line from the bottom corner
    /// rising to the top over the fade-in, falling to the bottom over the fade-out. Drawn, never
    /// touched; the hold menu's Fades & Gain sets them.
    private var fadeMarks: some View {
        let fades = region.effectiveFades
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
        let tick = region.start + Tick((Double(translation) * ticksPerPoint).rounded())
        guard let hit = ArrangeView.hit(near: tick, in: hits, ticksPerPoint: ticksPerPoint, snapping: snapsHere) else {
            return snap.previewOffset(from: region.start, translation: translation, ticksPerPoint: ticksPerPoint, meter: meter)
        }
        return CGFloat(Double(hit - region.start) / ticksPerPoint)
    }

    /// One undo step: onto the hit within reach, else to the nearest bar.
    private func drop(movedBy translation: CGFloat) {
        let delta = Tick((Double(translation) * ticksPerPoint).rounded())
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
        }
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
            .accessibilityAction(named: "Duplicate") { duplicate() }
            .accessibilityAction(named: "Split at Playhead") { split() }
            .accessibilityAction(named: "Consolidate") { consolidate() }
            .accessibilityAction(named: "Bake Effects") { if canBake { bake() } }
            .accessibilityAction(named: "Delete") { remove() }
            .accessibilityAction(named: "Trim Start One Beat Later") { trim(.start, beats: 1) }
            .accessibilityAction(named: "Trim End One Beat Earlier") { trim(.end, beats: -1) }
            .accessibilityAction(named: "Extend End One Beat") { trim(.end, beats: 1) }
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
                        if edge == .start { trimLeft = value.translation.width } else { trimRight = value.translation.width }
                    }
                    .onEnded { value in
                        trimLeft = 0
                        trimRight = 0
                        let delta = Tick((Double(value.translation.width) * ticksPerPoint).rounded())
                        apply(edge, byTicks: delta, snap: snap)
                    }
            )
            .accessibilityHidden(true)
    }

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

import EchoelCore
import SwiftUI

/// The song on a bar timeline: one lane per track, its clips and audio laid out where they
/// play. Tap empty space to place the track's clip at that bar — or, on an audio track, to
/// import a file there; tap a clip to edit its notes, drag a clip or audio region to move it
/// by whole bars, hold for Duplicate, Split at Playhead, Consolidate and Delete. One drag is one
/// undo step, and so is each of those.
/// Reads no playhead, so nothing here rebuilds while the song plays.
struct ArrangeView: View {
    @Environment(ProjectStore.self) private var store
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
        let laneWidth = CGFloat(bars) * pointsPerBar
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 1) {
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
                            .contextMenu {
                                AutomateMenu(owner: .track(track.id))
                                ModulateMenu(owner: .track(track.id))
                            }
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
                    VStack(alignment: .leading, spacing: 1) {
                        BarRuler(bars: bars, pointsPerBar: pointsPerBar)
                        ForEach(project.tracks) { track in
                            ArrangeLane(track: track, project: project, pointsPerBar: pointsPerBar,
                                        open: open, importAudio: importAudio)
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
    }
}

extension ArrangeView {
    /// The song's lanes that belong to `owner`, in the order they were made.
    static func lanes(of owner: ParameterAddress.Owner, in project: Project) -> [AutomationLane] {
        project.automation.filter { $0.target.owner == owner }
    }
}

/// Bar numbers along the top.
private struct BarRuler: View {
    let bars: Int
    let pointsPerBar: CGFloat

    var body: some View {
        Canvas { context, size in
            for bar in 0..<bars {
                let x = CGFloat(bar) * pointsPerBar
                context.fill(Path(CGRect(x: x, y: size.height - 6, width: 1, height: 6)),
                             with: .color(Theme.Color.border))
                context.draw(Text("\(bar + 1)").font(Theme.Font.caption).foregroundStyle(Theme.Color.textSecondary),
                             at: CGPoint(x: x + 4, y: size.height / 2), anchor: .leading)
            }
        }
        .frame(width: CGFloat(bars) * pointsPerBar, height: Theme.Size.rulerHeight)
        .background(Theme.Color.surface)
        .accessibilityHidden(true)
    }
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

    private var signature: TimeSignature { project.timeSignature }

    private var ticksPerPoint: Double {
        Double(MusicalTime.ticksPerBar(signature)) / Double(pointsPerBar)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                var x: CGFloat = 0
                while x < size.width {
                    context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)),
                                 with: .color(Theme.Color.border.opacity(0.6)))
                    x += pointsPerBar
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
                PlacementBlock(track: track, placement: placement, clip: clip, signature: signature,
                               pointsPerBar: pointsPerBar, open: open)
            }
        }
    }

    @ViewBuilder private var regionBlocks: some View {
        ForEach(track.regions) { region in
            if let file = project.mediaFile(region.media), let stop = Arranging.end(of: region, in: project) {
                RegionBlock(track: track, region: region, file: file, length: stop - region.start,
                            signature: signature, pointsPerBar: pointsPerBar)
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
                importAudio(track.id, Arranging.barStart(tick, signature: signature))
            }
            return
        }
        guard track.kind == .instrument else { return }
        if track.clips.isEmpty {
            createClip(at: Arranging.barStart(tick, signature: signature))
        } else if let command = Arranging.tap(on: track, at: tick, signature: signature) {
            try? store.perform(command)
        }
    }

    private func placeAtEnd() {
        let clipsEnd = track.placements.compactMap { Arranging.end(of: $0, in: track) }.max() ?? 0
        let audioEnd = track.regions.compactMap { Arranging.end(of: $0, in: project) }.max() ?? 0
        let start = Arranging.barStart(Swift.max(clipsEnd, audioEnd) + MusicalTime.ticksPerBar(signature) - 1,
                                       signature: signature)
        if track.kind == .audio || track.kind == .video {
            importAudio(track.id, start)
        } else if track.clips.isEmpty {
            createClip(at: start)
        } else if let command = Arranging.tap(on: track, at: start, signature: signature) {
            try? store.perform(command)
        }
    }

    /// A track's first clip: four empty bars, placed where the tap fell.
    private func createClip(at start: Tick) {
        guard track.kind == .instrument else { return }
        let clip = ClipID()
        try? store.perform([
            .createClip(track: track.id, id: clip, name: Names.derived(track.name, suffix: "Clip"),
                        length: 4 * MusicalTime.ticksPerBar(signature)),
            .placeClip(track: track.id, id: PlacementID(), clip: clip, start: start),
        ], title: "New Clip")
    }
}

/// A placed clip. The drag offset lives in view state while the finger is down and becomes
/// one move command when it lifts.
private struct PlacementBlock: View {
    @Environment(ProjectStore.self) private var store
    /// Only for the playhead at the moment Split is chosen — never read in `body`.
    @Environment(AudioEngine.self) private var engine
    let track: Track
    let placement: Placement
    let clip: Clip
    let signature: TimeSignature
    let pointsPerBar: CGFloat
    /// Opens the note editor on this clip of this track.
    let open: (TrackID, ClipID) -> Void

    @State private var dragX: CGFloat = 0

    private var ticksPerBar: Tick { MusicalTime.ticksPerBar(signature) }
    private var ticksPerPoint: Double { Double(ticksPerBar) / Double(pointsPerBar) }
    private var startBar: Int { Int(placement.start / Swift.max(1, ticksPerBar)) + 1 }
    private var lengthBars: Int { Int((clip.length + ticksPerBar - 1) / Swift.max(1, ticksPerBar)) }

    var body: some View {
        let color = Theme.Color.track(track.colorIndex)
        let width = Swift.max(8, CGFloat(Double(clip.length) / ticksPerPoint))
        RoundedRectangle(cornerRadius: Theme.Radius.small)
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
            .frame(width: width, height: Theme.Size.trackRowHeight - 8)
            .offset(x: CGFloat(Double(placement.start) / ticksPerPoint) + dragX, y: 4)
            .opacity(dragX == 0 ? 1 : 0.8)
            .onTapGesture { open(track.id, clip.id) }
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named(ArrangeLane.space))
                    .onChanged { dragX = $0.translation.width }
                    .onEnded { value in
                        let delta = Tick((Double(value.translation.width) * ticksPerPoint).rounded())
                        dragX = 0
                        if let command = Arranging.moved(placement, in: track, byTicks: delta, signature: signature) {
                            try? store.perform(command)
                        }
                    }
            )
            .contextMenu {
                Button("Edit Notes", systemImage: "pianokeys") { open(track.id, clip.id) }
                Button("Duplicate", systemImage: "plus.square.on.square") { duplicate() }
                Button("Split at Playhead", systemImage: "scissors") { splitAtPlayhead() }
                if Arranging.consolidated(placement, in: track) != nil {
                    Button("Consolidate", systemImage: "rectangle.compress.vertical") { consolidate() }
                }
                Button("Delete", systemImage: "trash", role: .destructive) { remove() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(clip.name), bar \(startBar), \(lengthBars) bars")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the note editor.")
            .accessibilityAction { open(track.id, clip.id) }
            .accessibilityAction(named: "Move One Bar Later") { move(byBars: 1) }
            .accessibilityAction(named: "Move One Bar Earlier") { move(byBars: -1) }
            .accessibilityAction(named: "Duplicate") { duplicate() }
            .accessibilityAction(named: "Split at Playhead") { splitAtPlayhead() }
            .accessibilityAction(named: "Consolidate") { consolidate() }
            .accessibilityAction(named: "Delete") { remove() }
    }

    private func move(byBars bars: Tick) {
        if let command = Arranging.moved(placement, in: track, byTicks: bars * ticksPerBar, signature: signature) {
            try? store.perform(command)
        }
    }

    private func duplicate() {
        if let command = Arranging.duplicated(placement, in: track) { try? store.perform(command) }
    }

    /// Cuts where the playhead stands now; nothing happens when it is outside the clip.
    private func splitAtPlayhead() {
        let tick = engine.playheadTick(in: store.project)
        if let command = Arranging.split(placement, in: track, at: tick) { try? store.perform(command) }
    }

    /// Joins the clip with the placements touching or overlapping it into one clip.
    private func consolidate() {
        if let command = Arranging.consolidated(placement, in: track) { try? store.perform(command) }
    }

    private func remove() {
        try? store.perform(.removePlacement(track: track.id, placement.id))
    }
}

/// A placed audio region: the file's name over its length. Drag moves it by whole bars, one
/// undo step on release; drag an edge to trim it to the beat; hold for Duplicate, Split at
/// Playhead Bar, Consolidate (pieces of one file only) and Delete.
private struct RegionBlock: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    let track: Track
    let region: AudioRegion
    let file: MediaFile
    /// The region's length in ticks at the song's tempo.
    let length: Tick
    let signature: TimeSignature
    let pointsPerBar: CGFloat

    @State private var dragX: CGFloat = 0
    /// Live drag of the left and right edge, in points, until the finger lifts.
    @State private var trimLeft: CGFloat = 0
    @State private var trimRight: CGFloat = 0

    private var ticksPerBar: Tick { MusicalTime.ticksPerBar(signature) }
    private var ticksPerPoint: Double { Double(ticksPerBar) / Double(pointsPerBar) }
    private var startBar: Int { Int(region.start / Swift.max(1, ticksPerBar)) + 1 }
    private var seconds: Double { file.sampleRate > 0 ? Double(region.length) / file.sampleRate : 0 }

    var body: some View {
        let color = Theme.Color.track(track.colorIndex)
        let width = Swift.max(8, CGFloat(Double(length) / ticksPerPoint) - trimLeft + trimRight)
        RoundedRectangle(cornerRadius: Theme.Radius.small)
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
            .overlay(alignment: .leading) { edgeHandle(.start) }
            .overlay(alignment: .trailing) { edgeHandle(.end) }
            .frame(width: width, height: Theme.Size.trackRowHeight - 8)
            .offset(x: CGFloat(Double(region.start) / ticksPerPoint) + dragX + trimLeft, y: 4)
            .opacity(dragX == 0 && trimLeft == 0 && trimRight == 0 ? 1 : 0.8)
            .gesture(
                DragGesture(minimumDistance: 6, coordinateSpace: .named(ArrangeLane.space))
                    .onChanged { dragX = $0.translation.width }
                    .onEnded { value in
                        let delta = Tick((Double(value.translation.width) * ticksPerPoint).rounded())
                        dragX = 0
                        if let command = Arranging.moved(region, in: track, byTicks: delta, signature: signature) {
                            try? store.perform(command)
                        }
                    }
            )
            .contextMenu {
                Button("Duplicate", systemImage: "plus.square.on.square") { duplicate() }
                Button("Split at Playhead Bar", systemImage: "scissors") { split() }
                if Arranging.consolidated(region, in: track, project: store.project) != nil {
                    Button("Consolidate", systemImage: "rectangle.compress.vertical") { consolidate() }
                }
                Button("Delete", systemImage: "trash", role: .destructive) { remove() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(file.name), \(file.kind == .video ? "video" : "audio"), bar \(startBar), \(seconds.formatted(.number.precision(.fractionLength(1)))) seconds")
            .accessibilityAction(named: "Move One Bar Later") { move(byBars: 1) }
            .accessibilityAction(named: "Move One Bar Earlier") { move(byBars: -1) }
            .accessibilityAction(named: "Duplicate") { duplicate() }
            .accessibilityAction(named: "Split at Playhead Bar") { split() }
            .accessibilityAction(named: "Consolidate") { consolidate() }
            .accessibilityAction(named: "Delete") { remove() }
            .accessibilityAction(named: "Trim Start One Beat Later") { trim(.start, beats: 1) }
            .accessibilityAction(named: "Trim End One Beat Earlier") { trim(.end, beats: -1) }
            .accessibilityAction(named: "Extend End One Beat") { trim(.end, beats: 1) }
    }

    /// A grip along one edge, wide enough for a finger; it wins over the move drag.
    private func edgeHandle(_ edge: Arranging.Edge) -> some View {
        Rectangle()
            .fill(Theme.Color.track(track.colorIndex).opacity(0.6))
            .frame(width: 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named(ArrangeLane.space))
                    .onChanged { value in
                        if edge == .start { trimLeft = value.translation.width } else { trimRight = value.translation.width }
                    }
                    .onEnded { value in
                        trimLeft = 0
                        trimRight = 0
                        let delta = Tick((Double(value.translation.width) * ticksPerPoint).rounded())
                        apply(edge, byTicks: delta)
                    }
            )
            .accessibilityHidden(true)
    }

    private func trim(_ edge: Arranging.Edge, beats: Tick) {
        apply(edge, byTicks: beats * MusicalTime.ticksPerBeat(signature))
    }

    private func apply(_ edge: Arranging.Edge, byTicks delta: Tick) {
        guard let commands = Arranging.trimmed(region, edge: edge, byTicks: delta, in: track, project: store.project) else { return }
        try? store.perform(commands, title: "Trim Region")
    }

    private func move(byBars bars: Tick) {
        if let command = Arranging.moved(region, in: track, byTicks: bars * ticksPerBar, signature: signature) {
            try? store.perform(command)
        }
    }

    private func remove() {
        try? store.perform(.removeRegion(track: track.id, region.id))
    }

    /// A cut at the bar line nearest the playhead (C5): nothing of the file is lost, both parts
    /// stay movable and trimmable, and one Undo joins them again.
    private func split() {
        let project = store.project
        let at = Arranging.nearestBar(engine.playheadTick(in: project), signature: project.timeSignature)
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

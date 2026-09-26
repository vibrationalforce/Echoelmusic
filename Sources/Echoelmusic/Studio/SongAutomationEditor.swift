//
//  SongAutomationEditor.swift
//  Echoelmusic — Studio (Phase 3 / Creation Workflow, Automation editing slice A1)
//
//  WHY THIS EXISTS. The song has carried an automation layer all along (`TimelineDocument
//  .automation`, persisted, played every transport step by `AutomationPlayer`), and nothing
//  could draw into it: the arrangement row that did (`TimelineAutomationRow`) went with #473,
//  and the store's per-point mutators outlived it with no caller and no Undo. This is the first
//  way back: on the selected track, a song-wide row for ONE parameter — tap to add a point, tap
//  a point to pick it, press and hold a point then slide to move it, type its value, remove it.
//
//  ⭐ ONE OWNER, ONE WRITER, ONE HISTORY. The curve is the song's (`document.automation`). Every
//  edit builds the whole new lane list locally (`SongAutomationEdit`, over the tested pure cores
//  `ClipAutomationEdit` / `AutomationCanvasMath` / `TimelineAutomationRowMath`) and commits it
//  ONCE through `TimelineStore.setSongAutomation` — one call, one undo step (`.automation`), on
//  the same stack `SongHistoryRow` drives.
//
//  ⭐ THE DRAG LAW (founder performance law): finger samples → a GESTURE-LOCAL preview
//  (`@GestureState` in the `SongAutomationCanvas` leaf) → ONE commit when the finger lifts → ONE
//  undo step. Preview and commit are the same value (`SongAutomationEdit.resolveMove`). Hold
//  first, like the note grid, so a swipe still scrolls. The value field edits a draft and writes
//  once, when its edit ends.
//
//  ⚠️ WHERE IT EXISTS, AND WHY ONLY THERE. The row is offered only where the curve SOUNDS: a MIDI
//  track played by a POLY rack voice (`TrackMix.Role.laneSynth(.poly)`, the DC1 Effect-row gate).
//  The key it writes is the track's own (`track.<id>.ddsp.osc.brightness`), which
//  `PerTrackAutomationResolver` resolves to that track's rack slot. On the Echoel track the
//  per-track key resolves to nothing and the global key reaches only the harmony voice — which
//  of the two the Echoel track should mean is a founder call, so it gets no row rather than a
//  row that draws silence.
//
//  ⚠️ WHAT IT DOES NOT DO, stated so the surface does not read as more: one parameter
//  (Brightness), no curve shape or bend, no multi-select, no playhead. Playback samples the curve
//  once per sixteenth (the transport step), and after Stop the parameter keeps its last value.
//  The canvas is touch-only; VoiceOver hears its summary and reaches the picked point's value
//  field and Remove.
//
//  Cold reads only: the selection and `timeline.document` change on a tap or an edit — never on
//  a clock. No transport, playhead or meter is read here.
//

import SwiftUI

/// The pure half: where the row is offered, which key it writes, and each gesture as a whole new
/// lane list. Nothing here touches a store.
enum SongAutomationEdit {

    /// The one parameter slice A1 draws. Its NAME and eligibility are the catalog's (#416).
    static let base = "ddsp.osc.brightness"

    /// The parameter as the catalog describes it — nil when this build does not offer it for
    /// automation, and then there is no row.
    nonisolated static var descriptor: ParameterDescriptor? {
        DDSPParameterCatalog.descriptors.first { $0.keyPath == base && $0.automationEligible }
    }

    /// The track's own key — `PerTrackParameterKeyPath`, the namespace the router dispatches.
    nonisolated static func key(for laneID: UUID) -> String {
        PerTrackParameterKeyPath.make(laneID: laneID, base: base)
    }

    /// Whether a curve on this track would SOUND: a poly rack voice plays it.
    nonisolated static func sounds(on laneID: UUID, in document: TimelineDocument,
                                   voiceCapacity: Int) -> Bool {
        descriptor != nil
            && TrackMix.role(of: laneID, in: document, voiceCapacity: voiceCapacity) == .laneSynth(.poly)
    }

    /// The track's points inside the song (a point past a shortened song end is kept in the
    /// document, and not drawn or hit here).
    nonisolated static func points(_ key: String, in lanes: [AutomationLane],
                                   songTicks: Int) -> [AutomationPoint] {
        (lanes.first { $0.parameter == key }?.points ?? []).filter { $0.tick <= songTicks }
    }

    /// What a tap means: pick the point under the finger, or add one where it landed.
    enum Tap: Equatable, Sendable {
        case pick(UUID)
        case add(tick: Int, value: Double)
    }

    nonisolated static func resolveTap(x: Double, y: Double, width: Double, height: Double,
                                       points: [AutomationPoint], songTicks: Int) -> Tap? {
        guard songTicks > 0, width > 0, height > 0, x.isFinite, y.isFinite else { return nil }
        let pxPerTick = width / Double(songTicks)
        if let hit = TimelineAutomationRowMath.hitPointID(atX: x, y: y, points: points,
                                                          pxPerTick: pxPerTick, height: height) {
            return .pick(hit)
        }
        let tick = TimelineAutomationRowMath.tick(forX: x, pxPerTick: pxPerTick, maxTick: songTicks)
        return .add(tick: AutomationCanvasMath.snappedTick(tick, spanTicks: songTicks),
                    value: AutomationCanvasMath.value(forY: y, height: height))
    }

    /// A point being moved: where it lands (snapped to the sixteenth — the playback grid).
    struct Move: Equatable, Sendable {
        let id: UUID
        let tick: Int
        let value: Double
    }

    /// The move a hold-and-slide means: the point under the START of the slide, carried by the
    /// finger's travel from its OWN position (grabbing a point off-centre does not make it jump).
    /// nil when the slide did not start on a point.
    nonisolated static func resolveMove(startX: Double, startY: Double, dx: Double, dy: Double,
                                        width: Double, height: Double,
                                        points: [AutomationPoint], songTicks: Int) -> Move? {
        guard songTicks > 0, width > 0, height > 0,
              dx.isFinite, dy.isFinite else { return nil }
        let pxPerTick = width / Double(songTicks)
        guard let id = TimelineAutomationRowMath.hitPointID(atX: startX, y: startY, points: points,
                                                            pxPerTick: pxPerTick, height: height),
              let point = points.first(where: { $0.id == id }) else { return nil }
        let x = TimelineAutomationRowMath.x(forTick: point.tick, pxPerTick: pxPerTick) + dx
        let y = AutomationCanvasMath.y(forValue: point.value, height: height) + dy
        let tick = TimelineAutomationRowMath.tick(forX: x, pxPerTick: pxPerTick, maxTick: songTicks)
        return Move(id: id, tick: AutomationCanvasMath.snappedTick(tick, spanTicks: songTicks),
                    value: AutomationCanvasMath.value(forY: y, height: height))
    }

    // MARK: Edits — each returns the WHOLE new lane list for the one writer

    /// Add a point — or, on a sixteenth that already holds one, set its value (a redraw is a
    /// value edit, never a stacked duplicate).
    nonisolated static func adding(tick: Int, value: Double, key: String,
                                   to lanes: [AutomationLane], songTicks: Int) -> [AutomationLane] {
        ClipAutomationEdit.upsertPoint(lanes, parameter: key, tick: tick, value: value,
                                       spanTicks: songTicks)
    }

    nonisolated static func moving(_ move: Move, in lanes: [AutomationLane],
                                   songTicks: Int) -> [AutomationLane] {
        ClipAutomationEdit.movePoint(lanes, id: move.id, toTick: move.tick, value: move.value,
                                     spanTicks: songTicks)
    }

    /// Remove a point; a lane it empties goes with it (no ghost lanes in the song).
    nonisolated static func removing(_ id: UUID, from lanes: [AutomationLane]) -> [AutomationLane] {
        ClipAutomationEdit.removePoint(lanes, id: id)
    }

    nonisolated static func revaluing(_ id: UUID, to value: Double,
                                      in lanes: [AutomationLane]) -> [AutomationLane] {
        var out = lanes
        for i in out.indices where out[i].points.contains(where: { $0.id == id }) {
            out[i].setValue(id: id, value)
        }
        return out
    }
}

/// The selected track's automation — an "Automation" switch, then the row.
@MainActor
struct SongAutomationEditor: View {

    /// The song's length on the Arrange canvas's scale, handed in by the Workstation.
    let songTicks: Int

    @Environment(WorkstationSelection.self) private var selection
    @Environment(TimelineStore.self) private var timeline
    /// Read for `laneVoiceCapacity` only — a cold number set once at start.
    @Environment(TimelineRegionPlayer.self) private var player
    /// View state: whether the row is open. Not part of the song, never persisted.
    @State private var isOpen = false

    var body: some View {
        let document = timeline.document
        if let laneID = WorkstationSelection.resolvedTrack(selection.trackID, in: document),
           let descriptor = SongAutomationEdit.descriptor,
           SongAutomationEdit.sounds(on: laneID, in: document,
                                     voiceCapacity: player.laneVoiceCapacity) {
            VStack(alignment: .leading, spacing: 6) {
                Button { isOpen.toggle() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Automation").font(EchoelTheme.font(12, .semibold))
                    }
                    .foregroundStyle(EchoelTheme.text)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                        .fill(EchoelTheme.fill))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isOpen ? "Hide the selected track's automation"
                                           : "Show the selected track's automation")
                if isOpen {
                    // Keyed by the track: another track starts with nothing picked.
                    SongAutomationLane(laneID: laneID, title: descriptor.displayName,
                                       songTicks: songTicks)
                        .id(laneID)
                }
            }
        }
    }
}

/// One track's curve for the one parameter, and the picked point's controls.
@MainActor
private struct SongAutomationLane: View {

    let laneID: UUID
    let title: String
    let songTicks: Int

    @Environment(TimelineStore.self) private var timeline
    /// View state: the picked point. Not part of the song.
    @State private var picked: UUID?

    private static let height: CGFloat = 72

    var body: some View {
        let key = SongAutomationEdit.key(for: laneID)
        let points = SongAutomationEdit.points(key, in: timeline.document.automation,
                                               songTicks: songTicks)
        let chosen = points.first { $0.id == picked }
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: ArrangeCanvasView.gutter) {
                Text(title)
                    .font(EchoelTheme.font(11, .semibold))
                    .foregroundStyle(EchoelTheme.dim)
                    .lineLimit(1)
                    .frame(width: ArrangeCanvasView.nameWidth, alignment: .leading)
                SongAutomationCanvas(points: points, picked: picked, songTicks: songTicks,
                                     title: title,
                                     onTap: { location, size in
                                         tap(location, size, points: points, key: key)
                                     },
                                     onRelease: { move in commitMove(move) })
                    .frame(height: Self.height)
            }
            if let chosen {
                pickedControls(chosen)
            } else {
                Text(points.isEmpty ? "Tap the row to add the first point."
                                    : "Tap a point to pick it. Press and hold a point, then slide to move it.")
                    .font(EchoelTheme.font(11))
                    .foregroundStyle(EchoelTheme.dim)
            }
        }
        // An undo can take the picked point away; the pick must not outlive it.
        .onChange(of: points.map(\.id)) { _, ids in
            if let picked, !ids.contains(picked) { self.picked = nil }
        }
    }

    private func pickedControls(_ point: AutomationPoint) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Point at \(SessionGrid.label(forTick: point.tick))")
                .font(EchoelTheme.font(11, .semibold))
                .foregroundStyle(EchoelTheme.text)
            SongAutomationValueRow(shown: point.value, pointID: point.id) { value in
                let lanes = SongAutomationEdit.revaluing(point.id, to: value,
                                                         in: timeline.document.automation)
                timeline.setSongAutomation(lanes)
            }
            Button {
                let lanes = SongAutomationEdit.removing(point.id, from: timeline.document.automation)
                if timeline.setSongAutomation(lanes) { picked = nil }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash").font(.system(size: 11, weight: .semibold))
                    Text("Remove point").font(EchoelTheme.font(11, .semibold))
                }
                .foregroundStyle(EchoelTheme.text)
                .padding(.horizontal, 8)
                .frame(minHeight: 44)
                .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .fill(EchoelTheme.fill))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove the point at \(SessionGrid.label(forTick: point.tick))")
        }
    }

    private func tap(_ location: CGPoint, _ size: CGSize, points: [AutomationPoint], key: String) {
        guard let resolved = SongAutomationEdit.resolveTap(
            x: Double(location.x), y: Double(location.y),
            width: Double(size.width), height: Double(size.height),
            points: points, songTicks: songTicks) else { return }
        switch resolved {
        case .pick(let id):
            picked = picked == id ? nil : id
        case .add(let tick, let value):
            let lanes = SongAutomationEdit.adding(tick: tick, value: value, key: key,
                                                  to: timeline.document.automation,
                                                  songTicks: songTicks)
            if timeline.setSongAutomation(lanes) {
                picked = SongAutomationEdit.points(key, in: lanes, songTicks: songTicks)
                    .first { $0.tick == tick }?.id
            }
        }
    }

    private func commitMove(_ move: SongAutomationEdit.Move) {
        let lanes = SongAutomationEdit.moving(move, in: timeline.document.automation,
                                              songTicks: songTicks)
        if timeline.setSongAutomation(lanes) { picked = move.id }
    }
}

/// The drawn curve and its press-hold-and-slide. ⭐ THE ONLY FINGER-RATE STATE IN THE EDITOR:
/// `live` is `@GestureState`, so only this leaf redraws while a finger slides, and it resets
/// itself when the scroll view cancels the gesture. Nothing is written until the finger lifts,
/// and then exactly once, through `onRelease`.
@MainActor
private struct SongAutomationCanvas: View {

    let points: [AutomationPoint]
    let picked: UUID?
    let songTicks: Int
    let title: String
    let onTap: (CGPoint, CGSize) -> Void
    let onRelease: (SongAutomationEdit.Move) -> Void

    @GestureState private var live: SongAutomationEdit.Move? = nil

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let shown = live.map {
                TimelineAutomationRowMath.displayPoints(points, movingID: $0.id,
                                                        toTick: $0.tick, value: $0.value)
            } ?? points
            let lit = live?.id ?? picked
            Canvas { context, canvasSize in
                Self.draw(shown, lit: lit, songTicks: songTicks, in: &context, size: canvasSize)
            }
            .background(EchoelTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .stroke(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in onTap(location, size) }
            .gesture(edit(size: size))
            .accessibilityElement()
            .accessibilityLabel("\(title) automation: \(points.count) points")
            .accessibilityHint("Tap to add a point. Tap a point to pick it; its value and Remove follow below.")
        }
    }

    /// Hold first, then slide — so a swipe that starts on the row still scrolls.
    private func edit(size: CGSize) -> some Gesture {
        // Values, captured once per body — the gesture closures read no view state.
        let points = self.points
        let songTicks = self.songTicks
        let width = Double(size.width)
        let height = Double(size.height)
        return LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .updating($live) { value, state, _ in
                guard case .second(true, let drag?) = value else { return }
                state = Self.resolve(drag, points: points, width: width, height: height,
                                     songTicks: songTicks)
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let move = Self.resolve(drag, points: points, width: width,
                                              height: height, songTicks: songTicks) else { return }
                onRelease(move)
            }
    }

    private nonisolated static func resolve(_ drag: DragGesture.Value, points: [AutomationPoint],
                                            width: Double, height: Double,
                                            songTicks: Int) -> SongAutomationEdit.Move? {
        SongAutomationEdit.resolveMove(
            startX: Double(drag.startLocation.x), startY: Double(drag.startLocation.y),
            dx: Double(drag.translation.width), dy: Double(drag.translation.height),
            width: width, height: height, points: points, songTicks: songTicks)
    }

    private nonisolated static func draw(_ points: [AutomationPoint], lit: UUID?, songTicks: Int,
                             in context: inout GraphicsContext, size: CGSize) {
        guard songTicks > 0, size.width > 0, size.height > 0 else { return }
        let pxPerTick = Double(size.width) / Double(songTicks)
        // Bar lines on the Arrange canvas's scale.
        let bars = songTicks / TimelineTime.ticksPerBar
        if bars > 0 {
            for bar in 0...bars {
                let x = CGFloat(TimelineAutomationRowMath.x(forTick: bar * TimelineTime.ticksPerBar,
                                                            pxPerTick: pxPerTick))
                context.fill(Path(CGRect(x: x, y: 0, width: 0.5, height: size.height)),
                             with: .color(EchoelTheme.border.opacity(0.6)))
            }
        }
        guard !points.isEmpty else { return }
        // The curve as playback reads it (hold before the first point and after the last).
        let lane = AutomationLane(parameter: "", points: points)
        var path = Path()
        let columns = max(2, Int(size.width / 2))
        for c in 0...columns {
            let x = Double(size.width) * Double(c) / Double(columns)
            let tick = Int((x / pxPerTick).rounded())
            let y = AutomationCanvasMath.y(forValue: lane.value(atTick: tick) ?? 0,
                                           height: Double(size.height))
            let p = CGPoint(x: x, y: y)
            if c == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        context.stroke(path, with: .color(EchoelTheme.accent), lineWidth: 1.5)
        for point in points {
            let center = CGPoint(
                x: TimelineAutomationRowMath.x(forTick: point.tick, pxPerTick: pxPerTick),
                y: AutomationCanvasMath.y(forValue: point.value, height: Double(size.height)))
            let r: CGFloat = point.id == lit ? 6 : 4
            context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                                width: 2 * r, height: 2 * r)),
                         with: .color(point.id == lit ? EchoelTheme.text : EchoelTheme.accent))
        }
    }
}

/// The picked point's value. ⭐ ITS OWN LEAF, FOR THE PERFORMANCE LAW: an `EchoelValueField` drag
/// moves the value at finger rate, so the drag edits `draft` — only this row redraws — and the
/// curve is written ONCE, when the edit ends. One drag, one commit, one Undo.
@MainActor
private struct SongAutomationValueRow: View {

    let shown: Double
    let pointID: UUID
    let commit: (Double) -> Void

    @State private var draft: Double?

    var body: some View {
        EchoelValueField(label: "Value",
                         value: Binding(get: { draft ?? shown }, set: { draft = $0 }),
                         range: 0...1, decimals: 2,
                         hint: "Sets the picked point's value",
                         onCommit: {
                             if let draft { commit(draft) }
                             draft = nil
                         })
            // A draft no commit cleared must not outlive the point or value it was drafted from
            // (an Undo changes `shown`; picking another point changes `pointID`).
            .onChange(of: pointID) { _, _ in draft = nil }
            .onChange(of: shown) { _, _ in draft = nil }
    }
}

//
//  SongAutomationEditor.swift
//  Echoelmusic — Studio (Phase 3 / Creation Workflow, Automation editing slices A1–A2)
//
//  WHY THIS EXISTS. The song has carried an automation layer all along (`TimelineDocument
//  .automation`, persisted, played every transport step by `AutomationPlayer`), and nothing
//  could draw into it: the arrangement row that did (`TimelineAutomationRow`) went with #473,
//  and the store's per-point mutators outlived it with no caller and no Undo. This is the first
//  way back: on the selected track, a song-wide row for one CHOSEN parameter — tap to add a point,
//  tap a point to pick it, press and hold a point then slide to move it, type its value, remove it.
//  A2: the parameter is a menu over `SongAutomationEdit.offered`, a PROJECTION of
//  `PolySynthVoice.automatableBases` ∩ the catalog's `automationEligible` (#416) — each parameter
//  is its own lane in the song; the row opens on the one the track already has a curve for.
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
//  The key it writes is the track's own (`track.<id>.<base>`), which
//  `PerTrackAutomationResolver` resolves to that track's rack slot. On the Echoel track the
//  per-track key resolves to nothing and the global key reaches only the harmony voice — which
//  of the two the Echoel track should mean is a founder call, so it gets no row rather than a
//  row that draws silence.
//
//  ⚠️ WHAT IT DOES NOT DO, stated so the surface does not read as more: one parameter SHOWN at a
//  time (the others keep playing), no curve shape or bend, no multi-select, no playhead. Playback samples the curve
//  once per sixteenth (the transport step), and after Stop the parameter keeps its last value.
//  The row's height is the parameter's range, LINEAR, as playback maps it: for a time in seconds
//  (0.001–10 s) the short, musical times sit near the bottom — the value field shows and takes
//  the real number with its unit. After Stop a curve that ended low leaves its value in the
//  track's voice, inaudibly: nothing plays a rack track while the song is stopped, and every
//  region load re-sends the track's patch before its notes (A4 restore-on-Stop: reverted).
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

    /// The parameter a track opens on when it has no curve yet (A1's one parameter).
    static let defaultBase = "ddsp.osc.brightness"

    /// Every parameter a rack track's curve can move (A2): the poly voice's automatable bases, in
    /// their order, each as the catalog describes it — a PROJECTION (#416), never a copy, so a
    /// base the catalog does not offer for automation is never offered here.
    nonisolated static var offered: [ParameterDescriptor] {
        PolySynthVoice.automatableBases.compactMap { base in
            DDSPParameterCatalog.descriptors.first { $0.keyPath == base && $0.automationEligible }
        }
    }

    /// The track's own key for one parameter — `PerTrackParameterKeyPath`, the namespace the
    /// router dispatches.
    nonisolated static func key(for laneID: UUID, base: String) -> String {
        PerTrackParameterKeyPath.make(laneID: laneID, base: base)
    }

    /// The stored point value (0…1, what the curve holds) in the parameter's REAL unit — the
    /// same linear `denormalized` playback applies (`PerTrackAutomationResolver`), so the number
    /// the user reads is the number the voice gets. A1 could show 0…1 raw only because
    /// Brightness IS 0…1; attack runs 0.001–10 s (A2 review H1).
    nonisolated static func realValue(_ stored: Double, of d: ParameterDescriptor) -> Double {
        Double(d.denormalized(Float(stored)))
    }

    /// The inverse: a typed real value back into the curve's 0…1 (clamped by the descriptor).
    nonisolated static func storedValue(_ real: Double, of d: ParameterDescriptor) -> Double {
        Double(d.normalized(Float(real)))
    }

    /// Enough decimals to show the range's floor (0.001 s needs three).
    nonisolated static func decimals(for d: ParameterDescriptor) -> Int {
        d.min > 0 && d.min < 0.01 ? 3 : 2
    }

    /// How the Sound panel's automation readout (`AutomationStatusStrip`) names and scales a
    /// curve this editor drew — "Keys · Envelope attack", in seconds — or nil when the key is not
    /// a per-track key, or its track would not sound it today (removed, now another device, past
    /// the rack's capacity); the readout then says "no effect", which is then true (A3).
    /// ⭐ Same gate as the row (`sounds`) and same scale as the value field (`realValue`), so the
    /// two surfaces cannot disagree about one curve (#416). Before A3 the readout listed these
    /// curves under their raw `track.<uuid>.…` key and called them "no effect" while they played.
    nonisolated static func statusScale(_ parameter: String, in document: TimelineDocument,
                                        voiceCapacity: Int) -> AutomationScale? {
        guard let (laneID, base) = PerTrackParameterKeyPath.parse(parameter),
              let d = offered.first(where: { $0.keyPath == base }),
              sounds(on: laneID, in: document, voiceCapacity: voiceCapacity) else { return nil }
        let track = document.lanes.first { $0.id == laneID }?.name ?? "Track"
        return AutomationScale(displayName: "\(track) · \(d.displayName)", unit: d.unit,
                               decimals: decimals(for: d)) { SongAutomationEdit.realValue($0, of: d) }
    }

    /// Whether this track already carries a curve for the parameter.
    nonisolated static func hasCurve(_ laneID: UUID, base: String,
                                     in lanes: [AutomationLane]) -> Bool {
        let key = key(for: laneID, base: base)
        return lanes.contains { $0.parameter == key && !$0.isEmpty }
    }

    /// The parameter the row opens on: the first offered one this track already has a curve
    /// for (so a reopened row shows the work), else the default, else the first offered.
    nonisolated static func openingBase(for laneID: UUID, in lanes: [AutomationLane]) -> String? {
        let bases = offered.map(\.keyPath)
        return bases.first { hasCurve(laneID, base: $0, in: lanes) }
            ?? (bases.contains(defaultBase) ? defaultBase : bases.first)
    }

    /// Whether a curve on this track would SOUND: a poly rack voice plays it.
    nonisolated static func sounds(on laneID: UUID, in document: TimelineDocument,
                                   voiceCapacity: Int) -> Bool {
        !offered.isEmpty
            && TrackMix.role(of: laneID, in: document, voiceCapacity: voiceCapacity) == .laneSynth(.poly)
    }

    /// The track's points inside the song (a point past a shortened song end is kept in the
    /// document, and not drawn or hit here).
    nonisolated static func points(_ key: String, in lanes: [AutomationLane],
                                   songTicks: Int) -> [AutomationPoint] {
        (lanes.first { $0.parameter == key }?.points ?? []).filter { $0.tick <= songTicks }
    }

    /// The first point past a shortened song end. It is not drawn or hit, but playback inside
    /// the song ramps toward it, so the drawn curve must too (A1 review LOW-5: the last segment
    /// was drawn flat while the sound moved). Only the FIRST matters — later points cannot
    /// shape any tick inside the song.
    nonisolated static func pointPastEnd(_ key: String, in lanes: [AutomationLane],
                                         songTicks: Int) -> AutomationPoint? {
        (lanes.first { $0.parameter == key }?.points ?? []).first { $0.tick > songTicks }
    }

    /// The row's hint. A curve can run on to a point after a shortened song end — not drawn, not
    /// hit — so the hint says so rather than "add the first point" over a line it draws (A5 review).
    nonisolated static func hint(inSongPoints count: Int, continuesPastEnd: Bool) -> String {
        let past = continuesPastEnd ? " The curve runs on to a point after the song end." : ""
        if count == 0 {
            return (continuesPastEnd ? "Tap the row to add a point in the song."
                                     : "Tap the row to add the first point.") + past
        }
        return "Tap a point to pick it. Press and hold a point, then slide to move it." + past
    }

    /// VoiceOver's count: the song's points, and the one after the end when there is one.
    nonisolated static func countLabel(inSongPoints count: Int, continuesPastEnd: Bool) -> String {
        let base = count == 1 ? "1 point" : "\(count) points"
        return continuesPastEnd ? base + ", and 1 after the song end" : base
    }

    /// The points the drawn curve runs through: the song's own, plus the one past its end.
    nonisolated static func curvePoints(_ shown: [AutomationPoint],
                                        pastEnd: AutomationPoint?) -> [AutomationPoint] {
        guard let pastEnd else { return shown }
        return shown + [pastEnd]
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
    /// nil when the slide did not start on a point — or travelled less than the shared tap slop
    /// (a held, trembling finger moves nothing and writes no Undo step).
    nonisolated static func resolveMove(startX: Double, startY: Double, dx: Double, dy: Double,
                                        width: Double, height: Double,
                                        points: [AutomationPoint], songTicks: Int) -> Move? {
        guard songTicks > 0, width > 0, height > 0,
              dx.isFinite, dy.isFinite,
              (dx * dx + dy * dy).squareRoot() >= TimelineAutomationRowMath.tapSlopPoints
        else { return nil }
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

    /// Move a point; one it lands on (same lane, same sixteenth) is replaced, as a redraw
    /// replaces — never two points stacked on one step.
    nonisolated static func moving(_ move: Move, in lanes: [AutomationLane],
                                   songTicks: Int) -> [AutomationLane] {
        var out = ClipAutomationEdit.movePoint(lanes, id: move.id, toTick: move.tick,
                                               value: move.value, spanTicks: songTicks)
        guard let i = out.firstIndex(where: { $0.points.contains { $0.id == move.id } }),
              let landed = out[i].points.first(where: { $0.id == move.id }) else { return out }
        for other in out[i].points where other.id != move.id && other.tick == landed.tick {
            out[i].removePoint(id: other.id)
        }
        return out
    }

    /// Remove a point; the lane it empties goes with it (no ghost lanes in the song). Only that
    /// lane — every other lane in the song is left exactly as it was.
    nonisolated static func removing(_ id: UUID, from lanes: [AutomationLane]) -> [AutomationLane] {
        var out = lanes
        guard let i = out.firstIndex(where: { $0.points.contains { $0.id == id } }) else { return out }
        out[i].removePoint(id: id)
        if out[i].isEmpty { out.remove(at: i) }
        return out
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
                    // Keyed by the track: another track starts with nothing picked and opens on
                    // its own parameter.
                    SongAutomationLane(laneID: laneID, songTicks: songTicks)
                        .id(laneID)
                }
            }
        }
    }
}

/// One track's curve for the chosen parameter, and the picked point's controls.
@MainActor
private struct SongAutomationLane: View {

    let laneID: UUID
    let songTicks: Int

    @Environment(TimelineStore.self) private var timeline
    /// View state: the picked point. Not part of the song.
    @State private var picked: UUID?
    /// View state: the parameter the user switched to (A2); nil = the opening parameter. Not
    /// part of the song — every parameter's curve lives in the song regardless.
    @State private var chosenBase: String?

    private static let height: CGFloat = 72

    var body: some View {
        let lanes = timeline.document.automation
        let offered = SongAutomationEdit.offered
        let base = chosenBase ?? SongAutomationEdit.openingBase(for: laneID, in: lanes)
            ?? SongAutomationEdit.defaultBase
        let descriptor = offered.first { $0.keyPath == base }
        let title = descriptor?.displayName ?? base
        let key = SongAutomationEdit.key(for: laneID, base: base)
        let points = SongAutomationEdit.points(key, in: lanes, songTicks: songTicks)
        let pastEnd = SongAutomationEdit.pointPastEnd(key, in: lanes, songTicks: songTicks)
        let chosen = points.first { $0.id == picked }
        VStack(alignment: .leading, spacing: 6) {
            parameterPicker(base, offered: offered, lanes: lanes)
            HStack(alignment: .top, spacing: ArrangeCanvasView.gutter) {
                Text(title)
                    .font(EchoelTheme.font(11, .semibold))
                    .foregroundStyle(EchoelTheme.dim)
                    .lineLimit(1)
                    .frame(width: ArrangeCanvasView.nameWidth, alignment: .leading)
                SongAutomationCanvas(points: points,
                                     pastEnd: pastEnd,
                                     picked: picked, songTicks: songTicks,
                                     title: title,
                                     onTap: { location, size in
                                         tap(location, size, points: points, key: key)
                                     },
                                     onRelease: { move in commitMove(move) },
                                     onStep: { by in step(by, points: points) })
                    .frame(height: Self.height)
            }
            if let chosen, let descriptor {
                pickedControls(chosen, descriptor: descriptor)
            } else {
                Text(SongAutomationEdit.hint(inSongPoints: points.count,
                                             continuesPastEnd: pastEnd != nil))
                    .font(EchoelTheme.font(11))
                    .foregroundStyle(EchoelTheme.dim)
            }
        }
        // An undo can take the picked point away; the pick must not outlive it.
        .onChange(of: points.map(\.id)) { _, ids in
            if let picked, !ids.contains(picked) { self.picked = nil }
        }
        // The opening parameter is decided ONCE per track, so removing a curve's last point
        // does not make the row jump to another parameter under the finger.
        .onAppear {
            if chosenBase == nil {
                chosenBase = SongAutomationEdit.openingBase(for: laneID,
                                                            in: timeline.document.automation)
            }
        }
    }

    private func pickedControls(_ point: AutomationPoint,
                                descriptor: ParameterDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Point at \(SessionGrid.label(forTick: point.tick))")
                .font(EchoelTheme.font(11, .semibold))
                .foregroundStyle(EchoelTheme.text)
            SongAutomationValueRow(shown: point.value, pointID: point.id,
                                   descriptor: descriptor) { value in
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

    /// Which parameter the row draws. A named choice, so a `Picker` (the numeric law does not
    /// apply). A parameter that already carries a curve on this track says so in the menu.
    private func parameterPicker(_ base: String, offered: [ParameterDescriptor],
                                 lanes: [AutomationLane]) -> some View {
        HStack(spacing: 8) {
            Text("Parameter")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            Picker("Parameter", selection: Binding<String>(
                get: { base },
                set: { chosenBase = $0; picked = nil })) {
                ForEach(offered, id: \.keyPath) { d in
                    Text(SongAutomationEdit.hasCurve(laneID, base: d.keyPath, in: lanes)
                         ? "\(d.displayName) · curve" : d.displayName)
                        .tag(d.keyPath)
                }
            }
            .pickerStyle(.menu).tint(EchoelTheme.text)
            .accessibilityLabel("Automated parameter")
        }
    }

    /// VoiceOver's way to a point: pick the next / previous one in song order.
    private func step(_ by: Int, points: [AutomationPoint]) {
        guard !points.isEmpty else { return }
        let next: Int
        if let current = points.firstIndex(where: { $0.id == picked }) {
            next = ((current + by) % points.count + points.count) % points.count
        } else {
            next = by > 0 ? 0 : points.count - 1
        }
        picked = points[next].id
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
    /// Not drawn as a point and not hit — only the curve runs toward it (LOW-5).
    let pastEnd: AutomationPoint?
    let picked: UUID?
    let songTicks: Int
    let title: String
    let onTap: (CGPoint, CGSize) -> Void
    let onRelease: (SongAutomationEdit.Move) -> Void
    let onStep: (Int) -> Void

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
                Self.draw(shown, pastEnd: pastEnd, lit: lit, songTicks: songTicks,
                          in: &context, size: canvasSize)
            }
            .background(EchoelTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .stroke(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in onTap(location, size) }
            .gesture(edit(size: size))
            .accessibilityElement()
            .accessibilityLabel("\(title) automation: \(pointCountLabel)")
            .accessibilityHint("Double-tap adds or picks the point in the middle of the song. Use the actions to pick another point; its value and Remove follow below.")
            .accessibilityAction(named: "Pick next point") { onStep(1) }
            .accessibilityAction(named: "Pick previous point") { onStep(-1) }
        }
    }

    private var pointCountLabel: String {
        SongAutomationEdit.countLabel(inSongPoints: points.count, continuesPastEnd: pastEnd != nil)
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

    private nonisolated static func draw(_ points: [AutomationPoint], pastEnd: AutomationPoint?,
                                         lit: UUID?, songTicks: Int,
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
        guard !points.isEmpty || pastEnd != nil else { return }
        // The curve playback follows: through the song's points AND the first one past a
        // shortened song end (hold before the first; after the last only when none lies beyond).
        let lane = AutomationLane(parameter: "",
                                  points: SongAutomationEdit.curvePoints(points, pastEnd: pastEnd))
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
            let r: CGFloat = 5   // the pick shows by colour, never by size (Uncodixfy)
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

    /// The stored 0…1 value; shown and typed in the parameter's real unit.
    let shown: Double
    let pointID: UUID
    let descriptor: ParameterDescriptor
    /// Receives the STORED 0…1 value.
    let commit: (Double) -> Void

    @State private var draft: Double?

    var body: some View {
        EchoelValueField(label: "Value",
                         value: Binding(get: { draft ?? SongAutomationEdit.realValue(shown, of: descriptor) },
                                        set: { draft = $0 }),
                         range: Double(descriptor.min)...Double(descriptor.max),
                         unit: descriptor.unit,
                         decimals: SongAutomationEdit.decimals(for: descriptor),
                         hint: "Sets the picked point's value",
                         onCommit: {
                             if let draft { commit(SongAutomationEdit.storedValue(draft, of: descriptor)) }
                             draft = nil
                         })
            // A draft no commit cleared must not outlive the point or value it was drafted from
            // (an Undo changes `shown`; picking another point changes `pointID`).
            .onChange(of: pointID) { _, _ in draft = nil }
            .onChange(of: shown) { _, _ in draft = nil }
    }
}

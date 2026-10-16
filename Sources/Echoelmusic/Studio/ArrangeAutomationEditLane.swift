// ArrangeAutomationEditLane.swift
// Echoel — Arrange & Perform item 7b (founder 2026-10-16, "Automation direkt auf dem Canvas"): in
// Draw mode (`WorkstationSelection.drawingAutomation`) each track row of the canvas edits its
// automation where it is drawn — a tap adds a point, a tap on a point removes it, a hold-and-slide
// moves it. Item 7a only drew the curves (`ArrangeAutomationTrace`).
//
// What this reuses, and why it is its own file:
//   · Every decision is the Track page's (`SongAutomationEdit`): which parameters a track offers
//     (`parameters(on:in:voiceCapacity:)` — the Echoel and bio tracks offer none), the one a row
//     opens on (`openingBase`), what a touch means (`resolveTap` / `resolveMove`, snapped to the
//     sixteenth), and the edits (`adding` / `moving` / `removing`). Only the SCALE differs: the
//     canvas's `songTicks` (with its headroom bars), so a point lands under the finger.
//   · The one writer is `timeline.setSongAutomation` — one Undo step per touch.
//   · The canvas file holds exactly one drag and one finger-rate state
//     (`TheArrangeCanvasMovesAPartByDraggingTests`); this leaf's hold-and-slide and its
//     `@GestureState` live here instead, and the canvas mounts it only in Draw mode.
//   · No parameter menu on the canvas (its header: no `.menu` Picker under the finger). The row
//     draws the parameter chosen on the Track page (7c, `SongAutomationEdit.shownBase`), else the
//     one it opens on.
//
// NEEDS-FOUNDER-VERIFY (7b): a synth track, "Draw automation", tap its row on bar 3 high and on bar
// 7 low → two points, the line runs between them; hold the second and slide → it follows and lands
// on a sixteenth; tap it → gone; one Undo per touch; "Done" → the parts take taps again.

import SwiftUI

/// One track row's automation, editable. Draws nothing — and takes no touch — on a track whose
/// curves move nothing (the Echoel track, the body, a silent track).
@MainActor
struct ArrangeAutomationEditLane: View {
    let laneID: UUID
    let songTicks: Int

    @Environment(TimelineStore.self) private var timeline
    @Environment(TimelineRegionPlayer.self) private var player
    @Environment(WorkstationSelection.self) private var selection

    var body: some View {
        let document = timeline.document
        let offered = SongAutomationEdit.parameters(on: laneID, in: document,
                                                    voiceCapacity: player.laneVoiceCapacity)
        // 7c: the parameter chosen on the Track page, else the one it opens on (one question).
        if let base = SongAutomationEdit.shownBase(chosen: selection.automationBase(for: laneID),
                                                   for: laneID, in: document.automation,
                                                   among: offered.map(\.keyPath)) {
            let key = SongAutomationEdit.key(for: laneID, base: base)
            let points = SongAutomationEdit.points(key, in: document.automation, songTicks: songTicks)
            let name = offered.first { $0.keyPath == base }.map(SongAutomationEdit.name) ?? base
            ArrangeAutomationTouchLayer(points: points, songTicks: songTicks, name: name,
                                        onTap: { location, size in tap(location, size, points: points, key: key) },
                                        onRelease: { move in
                                            let lanes = SongAutomationEdit.moving(move, in: timeline.document.automation,
                                                                                  songTicks: songTicks)
                                            timeline.setSongAutomation(lanes)
                                        })
        }
    }

    private func tap(_ location: CGPoint, _ size: CGSize, points: [AutomationPoint], key: String) {
        guard let resolved = SongAutomationEdit.resolveTap(
            x: Double(location.x), y: Double(location.y),
            width: Double(size.width), height: Double(size.height),
            points: points, songTicks: songTicks) else { return }
        switch resolved {
        case .pick(let id):
            timeline.setSongAutomation(SongAutomationEdit.removing(id, from: timeline.document.automation))
        case .add(let tick, let value):
            timeline.setSongAutomation(SongAutomationEdit.adding(tick: tick, value: value, key: key,
                                                                 to: timeline.document.automation,
                                                                 songTicks: songTicks))
        }
    }
}

/// The points and the touch. ⭐ The only finger-rate state of Draw mode: `live` is `@GestureState`,
/// so only this leaf redraws while a finger slides; nothing is written until it lifts.
@MainActor
private struct ArrangeAutomationTouchLayer: View {
    let points: [AutomationPoint]
    let songTicks: Int
    let name: String
    let onTap: (CGPoint, CGSize) -> Void
    let onRelease: (SongAutomationEdit.Move) -> Void

    @GestureState private var live: SongAutomationEdit.Move? = nil

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let shown = live.map {
                TimelineAutomationRowMath.displayPoints(points, movingID: $0.id, toTick: $0.tick, value: $0.value)
            } ?? points
            ZStack(alignment: .topLeading) {
                Canvas { context, canvasSize in
                    Self.draw(shown, lit: live?.id, songTicks: songTicks, in: &context, size: canvasSize)
                }
                Text(name)
                    .font(EchoelTheme.font(10, .semibold))
                    .foregroundStyle(EchoelTheme.text)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall).fill(EchoelTheme.surface))
                    .padding(4)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { location in onTap(location, size) }
            .gesture(edit(size: size))
            .accessibilityElement()
            .accessibilityLabel(name + String(localized: " automation: ")
                                + SongAutomationEdit.countLabel(inSongPoints: points.count, continuesPastEnd: false))
            .accessibilityHint("Double-tap adds a point in the middle of the piece. The Track page lists every point.")
        }
    }

    /// Hold first, then slide — so a swipe that starts on the row still scrolls the canvas.
    private func edit(size: CGSize) -> some Gesture {
        let points = self.points
        let songTicks = self.songTicks
        let width = Double(size.width)
        let height = Double(size.height)
        return LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .updating($live) { value, state, _ in
                guard case .second(true, let drag?) = value else { return }
                state = Self.resolve(drag, points: points, width: width, height: height, songTicks: songTicks)
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let move = Self.resolve(drag, points: points, width: width, height: height,
                                              songTicks: songTicks) else { return }
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

    /// The points only — the curve itself is the trace drawn beneath (`ArrangeAutomationTrace`),
    /// except while a point is moved, when the moved shape is drawn here so it follows the finger.
    private nonisolated static func draw(_ points: [AutomationPoint], lit: UUID?, songTicks: Int,
                                         in context: inout GraphicsContext, size: CGSize) {
        guard songTicks > 0, size.width > 0, size.height > 0 else { return }
        let pxPerTick = Double(size.width) / Double(songTicks)
        if lit != nil, !points.isEmpty {
            let lane = AutomationLane(parameter: "", points: points)
            var path = Path()
            let columns = ArrangeAutomation.columns(forWidth: Double(size.width))
            for s in ArrangeAutomation.samples(of: lane, songTicks: songTicks, columns: columns) {
                let p = CGPoint(x: s.x * Double(size.width),
                                y: AutomationCanvasMath.y(forValue: s.value, height: Double(size.height)))
                if path.isEmpty { path.move(to: p) } else { path.addLine(to: p) }
            }
            context.stroke(path, with: .color(EchoelTheme.accent), lineWidth: 1.5)
        }
        for point in points {
            let center = CGPoint(
                x: TimelineAutomationRowMath.x(forTick: point.tick, pxPerTick: pxPerTick),
                y: AutomationCanvasMath.y(forValue: point.value, height: Double(size.height)))
            let r: CGFloat = 5   // the moved point shows by colour, never by size (Uncodixfy)
            context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(point.id == lit ? EchoelTheme.text : EchoelTheme.accent))
        }
    }
}

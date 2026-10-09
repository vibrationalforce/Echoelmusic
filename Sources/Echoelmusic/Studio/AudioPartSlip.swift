//
//  AudioPartSlip.swift
//  Echoelmusic — Studio (GMMW AE-6, founder 2026-10-08: "Die klassische DAW Audio Editing View
//  fehlt mir noch.")
//
//  WHY THIS EXISTS. A slip edit moves the FILE under a part while the part stays where it is in
//  the song: the same bars, a different stretch of the recording. The store writer for it existed
//  since CLIP-4 (`TimelineStore.setAudioRegionWindow`) with no caller — and with a trap: its `gain`
//  defaulted to 1, so the first caller that left it out would have reset every part it slipped to
//  unity (#431/#440: a defaulted argument no call site writes shows up in no diff). The default is
//  gone; the one caller below passes the part's own gain, read from the store when it writes.
//
//  ⭐ WHO PLAYS NEVER CHANGES. A slip writes the file offset only; the part's start and length stay,
//  and `activeRegion` decides an overlap by ticks alone (#1440). Unlike a trim, a slip needs no
//  precedence rule.
//
//  ⭐ BOUNDS. Never before the file's first second; never further past its last second than the part
//  already reaches — a part longer than what is left of its file slips back, never on.
//
//  ⭐ WHILE THE SONG PLAYS TOO, LIKE A TRIM. The player chases a structural edit on its next transport
//  step (`TimelineRegionPlayer.refreshStructure` re-primes every audio lane at the current tick),
//  so a slip is heard from that step on — the same as an edge trim or a Split, neither of which
//  refuses while playing. ⛔ The first draft refused here, on the claim that a slip would be heard
//  "only from the next prime"; the next prime IS the next step, and the refusal made the slip the
//  one edit in the pane that went dead on Play. `apply` is the one write all three doors use: the
//  hold-and-slide on the part's window, the buttons, and VoiceOver's adjustable action on the pane.
//  The slide writes once, on release, so a slide restarts the lanes once, not per finger move.
//
//  ⚠️ THIS FILE, NOT `AudioPartEditorView.swift`, holds the slip's finger-rate state: that file's
//  one `@GestureState` is the edge slide, and it keeps every song-state read inside its playhead
//  leaf (`TheAudioPartHasAnEditorTests`, `ThePartEdgeMovesOnTheGridItCanPlayTests`). Nothing here
//  reads the song position; the tempo is `preflightTempo`, which is `@ObservationIgnored`.
//
//  Guard: `TheSlipKeepsThePartLevelTests`.
//

import SwiftUI

/// The slip rule and its one write.
enum AudioPartSlip {

    /// The shortest slip that is written — a millisecond, below anything placed on purpose.
    nonisolated static let minimumSeconds = 0.001

    /// What a slip writes: the new file offset, and the tempo the part's media elapses at (the
    /// store keeps the offset's tick twin at it, the tempo the trims use).
    struct Change: Equatable, Sendable {
        let offsetSeconds: Double
        /// How much of the file the part plays — unchanged by the slip; the preview draws it.
        let lengthSeconds: Double
        let mediaBPM: Double
    }

    /// The file offset a slip of `deltaSeconds` leaves the part at, or nil when it changes
    /// nothing. Never below 0; never above the larger of where the part is and the last offset
    /// at which the whole part still fits in the file.
    nonisolated static func offset(by deltaSeconds: Double, from offsetSeconds: Double,
                                   lengthSeconds: Double, fileSeconds: Double) -> Double? {
        guard deltaSeconds.isFinite, offsetSeconds.isFinite, lengthSeconds.isFinite, lengthSeconds > 0,
              fileSeconds.isFinite, fileSeconds > 0 else { return nil }
        let current = Swift.max(0, offsetSeconds)
        let ceiling = Swift.max(current, fileSeconds - lengthSeconds)
        let next = (current + deltaSeconds).clamped(to: 0...ceiling)
        guard (next - current).magnitude >= minimumSeconds else { return nil }
        return next
    }

    /// A slide of `dragPoints` on a pane that draws the whole file, in file seconds.
    nonisolated static func seconds(dragPoints: Double, widthPoints: Double, fileSeconds: Double) -> Double? {
        guard dragPoints.isFinite, widthPoints.isFinite, widthPoints > 0,
              fileSeconds.isFinite, fileSeconds > 0 else { return nil }
        return dragPoints / widthPoints * fileSeconds
    }

    /// The step a button or a VoiceOver swipe moves: one beat of the part's media.
    nonisolated static func stepSeconds(mediaBPM: Double) -> Double? {
        guard mediaBPM.isFinite, mediaBPM > 0 else { return nil }
        let step = TimelineTime.seconds(fromTicks: TimelineTime.ticksPerBeat, bpm: mediaBPM)
        return step.isFinite && step > 0 ? step : nil
    }

    /// The change a slip of `deltaSeconds` makes to `region` at the song tempo `projectBPM`, or
    /// nil when it makes none. The ONE question the preview and the write both ask; the window's
    /// length is the canvas's own (`ArrangeCanvas.audioWindow`, #416).
    nonisolated static func change(by deltaSeconds: Double, region: TimelineRegion, clip: Clip?,
                                   fileSeconds: Double, projectBPM: Double) -> Change? {
        guard let mediaBPM = PartSplit.mediaBPM(for: region, clip: clip, projectBPM: projectBPM),
              let window = ArrangeCanvas.audioWindow(for: region, clip: clip, bpm: projectBPM),
              let next = offset(by: deltaSeconds, from: region.contentOffsetSeconds,
                                lengthSeconds: window.lengthSeconds, fileSeconds: fileSeconds) else { return nil }
        return Change(offsetSeconds: next, lengthSeconds: window.lengthSeconds, mediaBPM: mediaBPM)
    }

    /// The ONE write every slip door makes: asked of the PART as the store holds it now (so a gain
    /// changed since the last draw is the gain written back; the clip is the one the pane drew), at
    /// the player's cold tempo read once for the question and the write. One Undo step.
    @MainActor
    static func apply(by deltaSeconds: Double, regionID: UUID, clip: Clip?, fileSeconds: Double,
                      timeline: TimelineStore, player: TimelineRegionPlayer) {
        guard let live = timeline.document.regions.first(where: { $0.id == regionID }),
              let change = change(by: deltaSeconds, region: live, clip: clip, fileSeconds: fileSeconds,
                                  projectBPM: player.preflightTempo) else { return }
        timeline.setAudioRegionWindow(id: live.id, contentOffsetSeconds: change.offsetSeconds,
                                      lengthTicks: live.lengthTicks, bpm: change.mediaBPM, gain: live.gain)
    }

    /// One beat earlier (`direction` < 0) or later (> 0) — the buttons' and VoiceOver's step.
    @MainActor
    static func applyStep(_ direction: Double, regionID: UUID, clip: Clip?, fileSeconds: Double,
                          timeline: TimelineStore, player: TimelineRegionPlayer) {
        guard direction != 0,
              let live = timeline.document.regions.first(where: { $0.id == regionID }),
              let bpm = PartSplit.mediaBPM(for: live, clip: clip, projectBPM: player.preflightTempo),
              let step = stepSeconds(mediaBPM: bpm) else { return }
        apply(by: direction < 0 ? -step : step, regionID: regionID, clip: clip, fileSeconds: fileSeconds,
              timeline: timeline, player: player)
    }
}

/// The part's window as a handle of its own: hold, then slide, and the window follows the finger
/// along the file; a frame shows where it will sit, and the release writes once. Takes the touches
/// between the two edge handles only, so an edge still trims. Hidden from VoiceOver like the wave;
/// the pane's adjustable action and the buttons are the slip's other doors.
/// NEEDS-FOUNDER-VERIFY: on the Part page, hold an audio part's window and slide — the hold wins
/// over the page's scroll, the frame follows the finger, release slips once (one Undo), and the
/// slipped part sounds the stretch of the file the frame showed, stopped and while playing.
struct AudioPartSlipArea: View {

    @Environment(TimelineStore.self) private var timeline
    /// Read for `preflightTempo` only — `@ObservationIgnored`, so nothing here observes it.
    @Environment(TimelineRegionPlayer.self) private var player

    let region: TimelineRegion
    let clip: Clip?
    let fileSeconds: Double
    /// The pane's width in points — the whole file.
    let paneWidth: Double
    /// The x range that takes the slide: between the edge handles' touch areas.
    let touch: ClosedRange<Double>
    let height: CGFloat

    /// The slide in flight: how far the finger has moved, and where it is on the pane.
    private struct Slide: Equatable {
        let points: Double
        let fingerX: Double
    }

    @GestureState private var slideState: Slide? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: CGFloat(touch.upperBound - touch.lowerBound), height: height)
                .contentShape(Rectangle())
                .offset(x: CGFloat(touch.lowerBound))
                .gesture(slide)
            if let slideState {
                preview(slideState)
            }
        }
        .frame(width: CGFloat(paneWidth), height: height, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    /// Where the window will sit when the finger lifts — where it is now when the slide changes
    /// nothing yet (the hold has just won, or the window is already at a bound). Only a part with no
    /// window at all gets the dim line, drawn where the finger is.
    @ViewBuilder
    private func preview(_ slide: Slide) -> some View {
        if let span = span(after: slide) {
            Rectangle()
                .strokeBorder(EchoelTheme.accent, lineWidth: 1)
                .frame(width: CGFloat(Swift.max(1, span.end - span.x)), height: height)
                .offset(x: CGFloat(span.x))
                .allowsHitTesting(false)
        } else {
            Rectangle()
                .fill(EchoelTheme.dim)
                .frame(width: 1, height: height)
                .offset(x: CGFloat(slide.fingerX.clamped(to: 0...paneWidth)))
                .allowsHitTesting(false)
        }
    }

    /// The window's span on the pane, in points, after `slide` — the write's own question first, the
    /// part's window as it stands when that question changes nothing.
    private func span(after slide: Slide) -> (x: Double, end: Double)? {
        let bpm = player.preflightTempo
        let offset: Double
        let length: Double
        if let seconds = AudioPartSlip.seconds(dragPoints: slide.points, widthPoints: paneWidth, fileSeconds: fileSeconds),
           let change = AudioPartSlip.change(by: seconds, region: region, clip: clip, fileSeconds: fileSeconds,
                                             projectBPM: bpm) {
            offset = change.offsetSeconds
            length = change.lengthSeconds
        } else if let window = ArrangeCanvas.audioWindow(for: region, clip: clip, bpm: bpm) {
            offset = window.fromSeconds
            length = window.lengthSeconds
        } else {
            return nil
        }
        let x = (offset / fileSeconds * paneWidth).clamped(to: 0...paneWidth)
        let end = ((offset + length) / fileSeconds * paneWidth).clamped(to: 0...paneWidth)
        return (x, end)
    }

    /// Hold first, then slide — the edge handles' and the canvas's 0.3 s, so a swipe that starts
    /// on the wave still scrolls the page. Nothing is written until release.
    private var slide: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($slideState) { value, state, _ in
                if case .second(true, let drag?) = value {
                    state = Slide(points: Double(drag.translation.width),
                                  fingerX: touch.lowerBound + Double(drag.location.x))
                }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let seconds = AudioPartSlip.seconds(dragPoints: Double(drag.translation.width),
                                                         widthPoints: paneWidth, fileSeconds: fileSeconds)
                else { return }
                AudioPartSlip.apply(by: seconds, regionID: region.id, clip: clip, fileSeconds: fileSeconds,
                                    timeline: timeline, player: player)
            }
    }
}

/// The slip without a drag (WCAG 2.5.7): play the part from one beat earlier or later in its file.
/// A button is disabled where its step would move nothing (the file's first second, or its end).
/// When NEITHER moves — a part as long as what is left of its file, which every freshly imported
/// part is — the row says why instead of showing two dead buttons. Outside the pane's one
/// VoiceOver element, so Voice Control, Switch Control and a keyboard reach each button.
struct AudioPartSlipButtons: View {

    @Environment(TimelineStore.self) private var timeline
    /// Read for `preflightTempo` only — `@ObservationIgnored`, so nothing here observes it.
    @Environment(TimelineRegionPlayer.self) private var player

    let region: TimelineRegion
    let clip: Clip?
    let fileSeconds: Double

    var body: some View {
        let earlier = moves(-1)
        let later = moves(1)
        if earlier || later {
            HStack(spacing: EchoelTheme.spaceXS) {
                step(-1, symbol: "chevron.left", label: String(localized: "Play from one beat earlier in the file"),
                     enabled: earlier)
                Text(String(localized: "Slip"))
                    .font(EchoelTheme.font(11))
                    .foregroundStyle(EchoelTheme.dim)
                step(1, symbol: "chevron.right", label: String(localized: "Play from one beat later in the file"),
                     enabled: later)
            }
        } else {
            Text(String(localized: "Trim the part shorter than its file to slip it"))
                .font(EchoelTheme.font(11))
                .foregroundStyle(EchoelTheme.dim)
        }
    }

    /// Whether a step that way changes anything — the write's own question.
    private func moves(_ direction: Double) -> Bool {
        guard let bpm = PartSplit.mediaBPM(for: region, clip: clip, projectBPM: player.preflightTempo),
              let step = AudioPartSlip.stepSeconds(mediaBPM: bpm) else { return false }
        return AudioPartSlip.change(by: direction < 0 ? -step : step, region: region, clip: clip,
                                    fileSeconds: fileSeconds, projectBPM: player.preflightTempo) != nil
    }

    private func step(_ direction: Double, symbol: String, label: String, enabled: Bool) -> some View {
        Button {
            AudioPartSlip.applyStep(direction, regionID: region.id, clip: clip, fileSeconds: fileSeconds,
                                    timeline: timeline, player: player)
        } label: {
            Image(systemName: symbol)
                .font(EchoelTheme.font(12, .semibold))
                .frame(minWidth: CGFloat(AudioPartEditor.handleHitPoints),
                       minHeight: CGFloat(AudioPartEditor.handleHitPoints))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? EchoelTheme.text : EchoelTheme.dim)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}

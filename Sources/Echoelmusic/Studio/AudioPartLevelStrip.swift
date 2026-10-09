//
//  AudioPartLevelStrip.swift
//  Echoelmusic — Studio (GMMW AE-5, founder 2026-10-08: "Die klassische DAW Audio Editing View
//  fehlt mir noch.")
//
//  WHY THIS EXISTS. A DAW's audio editor lets a person pull a fade out of a part's corner and
//  drag its level line, on the picture of the sound. The audio part editor drew both (the wave
//  inside the window already sits at the level its gain and fades leave it) and took neither:
//  the only way in was the part bar's three number fields. This strip, directly above the wave
//  and the same width, draws the part's level envelope — a ramp up over the fade-in, the level
//  line, a ramp down over the fade-out — with a grip at each top corner and the line between them.
//
//  ⭐ NO SECOND FIELD SET (#416). The strip writes the facts the part bar's fields write, through
//  the SAME store calls — `TimelineStore.setRegionFades` and `TimelineStore.setRegionGain`, one
//  Undo step each — and reads them through the bar's own pure halves: `PartFades.lengths` (the
//  fades AS THEY PLAY, the "in wins" rule), `PartGain.range` (the store's clamp). A fade-in grip
//  never shortens the fade-out and the other way round — the fields' `inRange`/`outRange` rule,
//  in ticks. The fields stay the numeric home and the VoiceOver path; the strip is the hand.
//
//  ⭐ THE SAME TOUCH LAYOUT AS THE WAVE BELOW IT. The two fade grips take their touch areas from
//  `AudioPartEditor.handleFrames` — a full target each, pushed apart when the fades nearly meet,
//  kept inside the pane — and the level line takes the touches between them, exactly as the edge
//  handles and the slip share the wave (AE-4b, AE-6). Hold first (0.3 s), then slide, so a swipe
//  on the strip still scrolls the page. Nothing is written until release, and the release asks
//  the part as the store holds it then.
//
//  ⭐ THE FADES SIT ON THE PART'S OWN SCALE, NOT ON THE CUT PICTURE (review S1). An unwarped import
//  is whole bars, so it usually outlasts its file. The first draft spread the part's ticks over the
//  window as the wave CUTS it at the file's end — every fade was squeezed into the file's last
//  seconds, and a fade-out pulled 44 pt in was drawn over 2.62–3.0 s of a 3-s file while the player
//  faded 3.5–4.0 s, after the sound had ended. Ticks now map over `AudioPartEditor.partXs`, the
//  UNCUT window, and the wave's fades below measure there too. A corner past the pane's right edge
//  is drawn, and held, AT that edge: pulled inward it comes to the finger, pushed outward it moves
//  on from where it really is (`edit`).
//
//  ⚠️ A FINGER THAT HOLDS STILL WRITES NOTHING (review S3). A hold of 0.3 s drifts a point or more,
//  and on this strip one point is ~0.045 of level or ten ticks of fade — every hold-and-release
//  wrote an Undo step, and a Normalized level was snapped onto the 0.01 grid by a touch. The first
//  `holdStillPoints` of a slide are slack; the change starts after them, without a jump.
//
//  ⚠️ NOTHING HERE IS HOT. No song position, no tempo: a fade is kept in ticks and the level is a
//  number. The finger-rate state is this leaf's `@GestureState`; the pane above does not redraw
//  while the finger moves. Hidden from VoiceOver like the wave.
//
//  Guard: `TheWaveCarriesTheFadesAndTheLevelTests`.
//

import SwiftUI

/// The pure half: where the envelope's corners sit, and what a slide of each grip writes.
enum AudioPartLevel {

    /// What a slide moves.
    enum Grip: Equatable, Sendable {
        case fadeIn
        case fadeOut
        case level
    }

    /// A slide in flight: which grip, and how far — across for a fade, down for the level.
    struct Slide: Equatable, Sendable {
        let grip: Grip
        let points: Double
    }

    /// What a released slide writes: ONE store call, the one the part bar's field already makes.
    enum Edit: Equatable, Sendable {
        /// `TimelineStore.setRegionFades` — both lengths, the unmoved one as it plays.
        case fades(fadeInTicks: Int, fadeOutTicks: Int)
        /// `TimelineStore.setRegionGain`.
        case level(Float)
    }

    /// The level step the line moves in: the field's own two decimals.
    nonisolated static let levelStep: Double = 0.01

    /// How far a finger may drift while it holds, in points, before a slide moves anything. The
    /// slide's change starts after it, so crossing it does not jump.
    nonisolated static let holdStillPoints: Double = 3

    /// A slide of `points` with the hold's slack taken off: 0 inside it, and the rest beyond it,
    /// sign kept.
    nonisolated static func moved(_ points: Double) -> Double {
        guard points.isFinite else { return 0 }
        let beyond = abs(points) - holdStillPoints
        guard beyond > 0 else { return 0 }
        return points < 0 ? -beyond : beyond
    }

    /// The level line's distance from the strip's top: the top of `PartGain.range` at the top,
    /// its bottom (silence) at the bottom, unity half-way. NaN reads as silence (the NaN-safe
    /// clamp's lower bound); the store clamps every level it holds, so nothing else arrives.
    nonisolated static func levelY(_ level: Double, heightPoints: Double) -> Double {
        let range = PartGain.range
        let span = range.upperBound - range.lowerBound
        guard heightPoints.isFinite, heightPoints > 0, span > 0 else { return 0 }
        return heightPoints * (1 - (level.clamped(to: range) - range.lowerBound) / span)
    }

    /// Where the fade-in ends and the fade-out begins, in points, on a part from `startX` to `endX`
    /// (`AudioPartEditor.partXs`, uncut) — the envelope's two top corners. BOTH are measured from
    /// `startX` (review S2): measured from opposite ends, fades that fill the part could land the
    /// fade-in corner one rounding error AFTER the fade-out corner, and `handleFrames` then refused
    /// every grip. nil for a degenerate part.
    nonisolated static func cornerXs(_ lengths: PartFades.Lengths, startX: Double,
                                     endX: Double) -> (fadeIn: Double, fadeOut: Double)? {
        guard startX.isFinite, endX.isFinite, endX > startX, lengths.lengthTicks > 0 else { return nil }
        let perTick = (endX - startX) / Double(lengths.lengthTicks)
        return (startX + Double(lengths.fadeInTicks) * perTick,
                startX + Double(lengths.lengthTicks - lengths.fadeOutTicks) * perTick)
    }

    /// Where a corner is drawn and held on a pane `paneWidth` wide: where it is, or the pane's
    /// right edge when the part outlasts its file and the corner lies past it.
    nonisolated static func shownX(_ x: Double, paneWidth: Double) -> Double {
        Swift.min(x, paneWidth)
    }

    /// What a slide of `points` on `grip` writes for a part with these fades and this level — the
    /// part from `startX` to `endX` on a pane `paneWidth` wide (uncut, `AudioPartEditor.partXs`),
    /// on a strip `heightPoints` tall — or nil when it changes nothing or the input cannot be used.
    /// The ONE question the preview and the write both ask.
    nonisolated static func edit(_ grip: Grip, points: Double, lengths: PartFades.Lengths, level: Float,
                                 startX: Double, endX: Double, paneWidth: Double, heightPoints: Double) -> Edit? {
        let slide = moved(points)
        guard slide != 0 else { return nil }
        switch grip {
        case .fadeIn, .fadeOut:
            guard paneWidth.isFinite, paneWidth > 0,
                  let corners = cornerXs(lengths, startX: startX, endX: endX) else { return nil }
            let ticksPerPoint = Double(lengths.lengthTicks) / (endX - startX)
            guard ticksPerPoint.isFinite else { return nil }
            // A corner past the pane's edge is held AT the edge: pulled inward (left) it comes to the
            // finger from there, pushed outward it moves on from where it really is. Inside the
            // pane both starting points are the same.
            let corner = grip == .fadeIn ? corners.fadeIn : corners.fadeOut
            let from = slide < 0 ? shownX(corner, paneWidth: paneWidth) : corner
            let to = from + slide
            if grip == .fadeIn {
                let limit = Double(Swift.max(0, lengths.lengthTicks - lengths.fadeOutTicks))
                let next = Int(((to - startX) * ticksPerPoint).rounded().clamped(to: 0...limit))
                guard next != lengths.fadeInTicks else { return nil }
                return .fades(fadeInTicks: next, fadeOutTicks: lengths.fadeOutTicks)
            }
            let limit = Double(Swift.max(0, lengths.lengthTicks - lengths.fadeInTicks))
            let next = Int(((endX - to) * ticksPerPoint).rounded().clamped(to: 0...limit))
            guard next != lengths.fadeOutTicks else { return nil }
            return .fades(fadeInTicks: lengths.fadeInTicks, fadeOutTicks: next)
        case .level:
            let range = PartGain.range
            guard heightPoints.isFinite, heightPoints > 0, level.isFinite else { return nil }
            let delta = slide / heightPoints * (range.upperBound - range.lowerBound)
            guard delta.isFinite else { return nil }
            let next = Float((((Double(level) - delta) / levelStep).rounded() * levelStep).clamped(to: range))
            guard next != level else { return nil }
            return .level(next)
        }
    }

    /// The ONE write a released slide makes: asked of the part as the store holds it NOW (an Undo
    /// or a field edit during the slide is the starting point, not the drawn one), through the
    /// part bar's own store call. One Undo step; nothing when it changes nothing.
    @MainActor
    static func apply(_ grip: Grip, points: Double, regionID: UUID, startX: Double, endX: Double,
                      paneWidth: Double, heightPoints: Double, timeline: TimelineStore) {
        let document = timeline.document
        guard let lengths = PartFades.lengths(of: regionID, in: document),
              let level = PartGain.gain(of: regionID, in: document),
              let edit = edit(grip, points: points, lengths: lengths, level: level, startX: startX, endX: endX,
                              paneWidth: paneWidth, heightPoints: heightPoints) else { return }
        switch edit {
        case .fades(let fadeIn, let fadeOut):
            timeline.setRegionFades(id: regionID, fadeInTicks: fadeIn, fadeOutTicks: fadeOut)
        case .level(let value):
            timeline.setRegionGain(id: regionID, value)
        }
    }
}

/// The level envelope over the part's window, with its three grips. Hidden from VoiceOver; the
/// part bar's Fade in, Fade out and Part level fields are the same three facts, spoken.
/// NEEDS-FOUNDER-VERIFY: on the Part page, hold a fade corner or the level line on the strip above
/// an audio part's wave and slide — the hold wins over the page's scroll, the envelope follows the
/// finger, release writes once (one Undo), the wave below redraws at the new level, and the part
/// bar's fields show the same numbers.
struct AudioPartLevelStrip: View {

    @Environment(TimelineStore.self) private var timeline

    let subject: AudioPartEditor.Subject
    let regionID: UUID
    /// The part's fades as they play and its level — cold, per render.
    let lengths: PartFades.Lengths
    let level: Float
    let fileSeconds: Double

    @GestureState private var slideState: AudioPartLevel.Slide? = nil

    /// The part on this pane, uncut (`AudioPartEditor.partXs`), and the strip's size.
    private struct Geometry {
        let startX: Double
        let endX: Double
        let paneWidth: Double
        let height: Double
    }

    var body: some View {
        GeometryReader { geometry in
            let width = Double(geometry.size.width)
            let height = Double(geometry.size.height)
            if let part = AudioPartEditor.partXs(of: subject.window, fileSeconds: fileSeconds, width: width) {
                let layout = Geometry(startX: part.start, endX: part.end, paneWidth: width, height: height)
                let shown = shownValues(layout)
                ZStack(alignment: .topLeading) {
                    envelope(shown.lengths, level: shown.level, geometry: layout, live: slideState != nil)
                    if let corners = AudioPartLevel.cornerXs(lengths, startX: part.start, endX: part.end),
                       let frames = AudioPartEditor.handleFrames(
                           startX: AudioPartLevel.shownX(corners.fadeIn, paneWidth: width),
                           endX: AudioPartLevel.shownX(corners.fadeOut, paneWidth: width), width: width) {
                        if frames.start.upperBound < frames.end.lowerBound {
                            zone(.level, x: frames.start.upperBound...frames.end.lowerBound, geometry: layout)
                        }
                        zone(.fadeIn, x: frames.start, geometry: layout)
                        zone(.fadeOut, x: frames.end, geometry: layout)
                    }
                    if let slideState {
                        readout(slideState.grip, lengths: shown.lengths, level: shown.level)
                    }
                }
            }
        }
        .frame(height: CGFloat(AudioPartEditor.handleHitPoints))
        .background(EchoelTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
            .strokeBorder(EchoelTheme.border, lineWidth: 1))
        .accessibilityHidden(true)
    }

    /// The fades and the level the strip draws: the slide's edit while a finger moves (the write's
    /// own question), the part's own otherwise.
    private func shownValues(_ geometry: Geometry) -> (lengths: PartFades.Lengths, level: Float) {
        guard let slideState,
              let edit = AudioPartLevel.edit(slideState.grip, points: slideState.points, lengths: lengths, level: level,
                                             startX: geometry.startX, endX: geometry.endX,
                                             paneWidth: geometry.paneWidth, heightPoints: geometry.height) else {
            return (lengths, level)
        }
        switch edit {
        case .fades(let fadeIn, let fadeOut):
            return (PartFades.Lengths(fadeInTicks: fadeIn, fadeOutTicks: fadeOut, lengthTicks: lengths.lengthTicks),
                    level)
        case .level(let value):
            return (lengths, value)
        }
    }

    /// The envelope: silence at the part's start, up to the level over the fade-in, along the
    /// level, down to silence over the fade-out; a dim hairline at unity for reference. Drawn on the
    /// uncut part, so a ramp past the file's end runs off the pane's right edge, where the player
    /// puts it; the grips stay on the pane (`shownX`).
    private func envelope(_ lengths: PartFades.Lengths, level: Float, geometry: Geometry, live: Bool) -> some View {
        let startX = geometry.startX
        let endX = geometry.endX
        let paneWidth = geometry.paneWidth
        return Canvas { context, size in
            let height = Double(size.height)
            guard let corners = AudioPartLevel.cornerXs(lengths, startX: startX, endX: endX), height > 0 else { return }
            let y = AudioPartLevel.levelY(Double(level), heightPoints: height)
            var unity = Path()
            let unityY = AudioPartLevel.levelY(1, heightPoints: height)
            unity.move(to: CGPoint(x: startX, y: unityY))
            unity.addLine(to: CGPoint(x: endX, y: unityY))
            context.stroke(unity, with: .color(EchoelTheme.border), lineWidth: 1)
            var line = Path()
            line.move(to: CGPoint(x: startX, y: height))
            line.addLine(to: CGPoint(x: corners.fadeIn, y: y))
            line.addLine(to: CGPoint(x: corners.fadeOut, y: y))
            line.addLine(to: CGPoint(x: endX, y: height))
            context.stroke(line, with: .color(live ? EchoelTheme.accent : EchoelTheme.text), lineWidth: 1.5)
            let half = Double(Self.gripSize) / 2
            for corner in [corners.fadeIn, corners.fadeOut] {
                let x = Swift.min(AudioPartLevel.shownX(corner, paneWidth: paneWidth), paneWidth - half)
                let grip = CGRect(x: x - half, y: y - half, width: Double(Self.gripSize), height: Double(Self.gripSize))
                context.fill(Path(grip), with: .color(live ? EchoelTheme.accent : EchoelTheme.borderStrong))
            }
        }
        .allowsHitTesting(false)
    }

    /// One touch zone: hold, then slide; the release writes once.
    private func zone(_ grip: AudioPartLevel.Grip, x: ClosedRange<Double>, geometry: Geometry) -> some View {
        Color.clear
            .frame(width: CGFloat(x.upperBound - x.lowerBound), height: CGFloat(geometry.height))
            .contentShape(Rectangle())
            .offset(x: CGFloat(x.lowerBound))
            .gesture(slide(grip, geometry: geometry))
    }

    /// Hold first, then slide — the wave's own 0.3 s. A fade follows the finger across, the level
    /// follows it up and down. Nothing is written until release.
    private func slide(_ grip: AudioPartLevel.Grip, geometry: Geometry) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($slideState) { value, state, _ in
                if case .second(true, let drag?) = value {
                    state = AudioPartLevel.Slide(grip: grip, points: Double(grip == .level ? drag.translation.height
                                                                                         : drag.translation.width))
                }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                AudioPartLevel.apply(grip, points: Double(grip == .level ? drag.translation.height : drag.translation.width),
                                     regionID: regionID, startX: geometry.startX, endX: geometry.endX,
                                     paneWidth: geometry.paneWidth, heightPoints: geometry.height,
                                     timeline: timeline)
            }
    }

    /// The number under the finger, in the part bar's own words — and its own number: the field's
    /// display rule (`ScrubPrecision.gridded`, then the reader's decimal separator), so the strip and
    /// the field never show 0.12 and 0.13, or 1.25 and 1,25, for one fade (review S4).
    private func readout(_ grip: AudioPartLevel.Grip, lengths: PartFades.Lengths, level: Float) -> some View {
        let text: String
        switch grip {
        case .fadeIn:
            text = String(localized: "Fade in") + " " + Self.beatsText(lengths.fadeInTicks) + " " + String(localized: "beats")
        case .fadeOut:
            text = String(localized: "Fade out") + " " + Self.beatsText(lengths.fadeOutTicks) + " " + String(localized: "beats")
        case .level:
            text = String(localized: "Part level") + " " + TrackMix.decibelText(Double(level))
        }
        return Text(text)
            .font(EchoelTheme.font(11).monospacedDigit())
            .foregroundStyle(EchoelTheme.accent)
            .padding(.horizontal, EchoelTheme.spaceXS)
            .allowsHitTesting(false)
    }

    /// A fade in beats as the part bar's field shows it: two decimals, the field's rounding, the
    /// reader's separator.
    private static func beatsText(_ ticks: Int) -> String {
        EchoelDecimalText.string(ScrubPrecision.gridded(PartFades.beats(fromTicks: ticks), decimals: 2), decimals: 2)
    }

    /// The corner grips: small, square, on the envelope's two top corners.
    private static let gripSize: CGFloat = 6
}

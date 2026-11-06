import EchoelCore
import EchoelEngine
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The Field (wave W3): the picture that moves with the music and the body. On a device with Metal
/// the GPU draws it (`MetalFieldView`, the earlier app's proven renderer); anywhere else the Canvas
/// does (`FieldCanvasView`). Both draw from the ONE `FieldFrame` snapshot, built by
/// `FieldFrame.current(store:engine:)` from the engine's playhead — one timebase, no second clock —
/// and every brightness passes the `FlashLimit`, so neither flashes more than three times a second.
/// Calm by design: nothing on screen that the song or the body does not carry.
///
/// The picture is the musician's choice (`FieldPattern`, kept on this device): the rings, the
/// Chladni plate, whose figure the master's partials choose, or one of the earlier app's looks —
/// Dish, Water, Aurora, Depth — and a second look blended over it. They need the GPU; the Canvas
/// draws the rings.
struct FieldView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(FieldPattern.storageKey) private var patternName = FieldPattern.rings.rawValue
    @AppStorage(FieldPattern.blendStorageKey) private var partnerName = ""
    @AppStorage(FieldPattern.blendMixStorageKey) private var mixPercent = FieldPattern.standardMixPercent
    @AppStorage(FieldMeter.storageKey) private var meterName = FieldMeter.off.rawValue
    @AppStorage(FieldFold.storageKey) private var foldSegments = 1
    /// True for the Field on an external display (`ExternalFieldRoot`); every other Field yields
    /// to it while it shows, so one renderer draws at a time.
    let onStage: Bool

    init(onStage: Bool = false) {
        self.onStage = onStage
    }

    var body: some View {
        let meter = FieldMeter(stored: meterName)
        if !onStage, ExternalFieldStage.shared.isShowing {
            ExternalFieldNotice()
        } else if meter != .off {
            FieldMeterView(meter: meter, reduceMotion: motionReduced)
        } else {
            picture
                .overlay(alignment: .bottomLeading) {
                    // The audience's screen shows the picture alone.
                    if !onStage { FieldToneReadout() }
                }
        }
    }

    /// The system's Reduce Motion. The external display's window is built by UIKit, so there the
    /// setting is also read straight from UIKit; either saying "reduce" reduces.
    private var motionReduced: Bool {
        #if canImport(UIKit)
        reduceMotion || (onStage && UIAccessibility.isReduceMotionEnabled)
        #else
        reduceMotion
        #endif
    }

    @ViewBuilder
    private var picture: some View {
        #if canImport(MetalKit) && canImport(UIKit)
        if MetalField.isAvailable {
            MetalFieldView(reduceMotion: motionReduced, pattern: FieldPattern(stored: patternName),
                           partner: FieldPattern.blend(stored: partnerName),
                           mix: Double(Swift.min(Swift.max(mixPercent, 0), 100)) / 100,
                           fold: FieldFold.segments(stored: foldSegments))
                .background(Theme.Color.background)
                .accessibilityHidden(true)
                .overlay { FieldSpokenValue().allowsHitTesting(false) }
        } else {
            FieldCanvasView()
        }
        #else
        FieldCanvasView()
        #endif
    }
}

/// The physics under the picture's colour, written out for the key's tonic: "A4 · 440 Hz ·
/// 40 octaves · 484 THz · 620 nm" — the pitch, how many octaves up it reaches light, that light's
/// frequency and wavelength (`ToneLight.readout`). It changes only with the song's key or concert
/// pitch, never with the playhead.
private struct FieldToneReadout: View {
    @Environment(ProjectStore.self) private var store

    var body: some View {
        let context = store.project.context
        let tonic = 60 + ((context.root % 12) + 12) % 12
        if let text = ToneLight.readout(pitch: tonic, concertPitch: context.concertPitch) {
            Text(text)
                .font(Theme.Font.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, Theme.Space.s)
                .padding(.vertical, Theme.Space.xs)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                .padding(Theme.Space.s)
                .allowsHitTesting(false)
                .accessibilityLabel(ToneLight.spokenReadout(pitch: tonic, concertPitch: context.concertPitch) ?? text)
        }
    }
}

/// What VoiceOver says the Field shows, from the same sources the picture draws. Its own leaf: the
/// strap's pulse changes about once a second, and only this view reads it (Law 6).
private struct FieldSpokenValue: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(HeartRateStrap.self) private var strap
    @Environment(ProjectStore.self) private var store
    @AppStorage(FieldPattern.storageKey) private var patternName = FieldPattern.rings.rawValue
    @AppStorage(FieldPattern.blendStorageKey) private var partnerName = ""

    var body: some View {
        Color.clear
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Field")
            .accessibilityValue(spoken)
    }

    private var spoken: String {
        var parts = [engine.isPlaying ? "Playing" : "Stopped"]
        if let bpm = strap.beatsPerMinute { parts.append("pulse \(bpm) beats per minute") }
        // The Moiré look shows the tuning: say the third and its beat.
        if FieldPattern(stored: patternName) == .moire || FieldPattern.blend(stored: partnerName) == .moire {
            parts.append(TuningBeat.of(store.project.context).spoken)
        }
        // The Weave grows from the key, a row a bar: say whose.
        if FieldPattern(stored: patternName) == .weave || FieldPattern.blend(stored: partnerName) == .weave {
            parts.append("weave of \(store.project.context.title)")
        }
        return parts.joined(separator: ", ")
    }
}

extension FieldFrame {
    /// The one snapshot every Field renderer draws: the song from the engine's playhead, master
    /// meter and musical context, the body from the engine's modulation inputs. Built on the main
    /// actor, in the renderer's own loop or a `TimelineView` leaf, never in an ancestor body.
    @MainActor
    static func current(store: ProjectStore, engine: AudioEngine) -> FieldFrame {
        let project = store.project
        let meter = engine.meterLevel(nil)
        let peak = Double(Swift.max(meter.left, meter.right))
        let inputs = engine.modulation
        return FieldFrame.at(tick: Double(engine.playheadTick(in: project)), meter: engine.playedMeterMap(of: project),
                             context: project.context, level: peak.squareRoot(),
                             pulse: inputs.value(.heartRate), hrv: inputs.value(.hrv),
                             coherence: inputs.value(.coherence), isPlaying: engine.isPlaying,
                             breath: inputs.value(.breath))
    }
}

/// The Field on the CPU: a SwiftUI Canvas at 30 frames a second, for a device without Metal. It
/// reads one `FieldFrame` per drawn frame in this leaf (Law 6). A slow ring for each beat, the key
/// as its colour, the level as its size, the pulse and coherence as a breathing centre.
struct FieldCanvasView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @State private var light = FieldLight()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let frame = FieldFrame.current(store: store, engine: engine)
            let shown = light.shown(frame, at: context.date)
            Canvas { canvas, size in
                FieldCanvasView.draw(frame, shown, in: &canvas, size: size)
            }
            .background(Theme.Color.background)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Field")
            .accessibilityValue(FieldCanvasView.spoken(frame))
        }
    }

    /// The brightnesses the frame asks for, after the flash guard.
    struct Shown {
        var beat: Double
        var centre: Double
    }

    private static func draw(_ frame: FieldFrame, _ shown: Shown, in canvas: inout GraphicsContext, size: CGSize) {
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)
        let reach = Double(Swift.min(size.width, size.height)) / 2
        // The key's colour is its tonic's light (data, `ToneLight`), the colour the Metal Field
        // and the lamp show, so these are not Theme colours.
        let keyLight = ToneLight.colour(forToneHz: frame.tonicHz)
        // The beat: a ring that grows through each beat; its brightness is guarded.
        let ring = reach * (0.35 + 0.55 * frame.beatPhase)
        canvas.stroke(Path(ellipseIn: CGRect(x: middle.x - ring, y: middle.y - ring, width: ring * 2, height: ring * 2)),
                      with: .color(Theme.Color.tone(keyLight, saturation: 0.45, brightness: 0.25 + 0.5 * shown.beat)),
                      lineWidth: 2)
        // The bar: a thin arc showing how far into the bar the song is.
        var arc = Path()
        arc.addArc(center: middle, radius: reach * 0.95, startAngle: .degrees(-90),
                   endAngle: .degrees(-90 + 360 * frame.barPhase), clockwise: false)
        canvas.stroke(arc, with: .color(Theme.Color.textSecondary.opacity(0.5)), lineWidth: 1)
        // The level: the size of the solid disc.
        let disc = reach * (0.08 + 0.25 * frame.level)
        canvas.fill(Path(ellipseIn: CGRect(x: middle.x - disc, y: middle.y - disc, width: disc * 2, height: disc * 2)),
                    with: .color(Theme.Color.tone(keyLight, saturation: 0.35, brightness: 0.2 + 0.35 * shown.centre)))
        // The body: coherence widens a quiet halo; absent, there is none.
        if let coherence = frame.coherence {
            let halo = disc + reach * 0.15 * coherence
            canvas.stroke(Path(ellipseIn: CGRect(x: middle.x - halo, y: middle.y - halo, width: halo * 2, height: halo * 2)),
                          with: .color(Theme.Color.tone(keyLight, saturation: 0.25, brightness: 0.6)), lineWidth: 1)
        }
    }

    static func spoken(_ frame: FieldFrame) -> String {
        var parts = [frame.isPlaying ? "Playing" : "Stopped"]
        if let pulse = frame.pulse { parts.append("pulse \(Int((pulse * 100).rounded())) percent") }
        if let coherence = frame.coherence { parts.append("coherence \(Int((coherence * 100).rounded())) percent") }
        return parts.joined(separator: ", ")
    }
}

/// The flash guards behind the Canvas Field's brightnesses. A plain class the view owns: it changes
/// every frame, and nothing observes it.
final class FieldLight {
    private var beat = FlashLimit()
    private var centre = FlashLimit()
    private var last: Date?

    func shown(_ frame: FieldFrame, at now: Date) -> FieldCanvasView.Shown {
        let seconds = last.map { now.timeIntervalSince($0) } ?? 0
        last = now
        // A beat lights the ring at its start and lets it fade; the guard decides how fast.
        let beatTarget = frame.isPlaying ? 1 - frame.beatPhase : 0
        let centreTarget = frame.pulse ?? frame.level
        return FieldCanvasView.Shown(beat: beat.next(towards: beatTarget, after: seconds),
                                     centre: centre.next(towards: centreTarget, after: seconds))
    }
}

import Foundation

/// GMMW GA-10d2 — what the Grain rows of an audio track's Device page do, kept out of the view so
/// it can be driven without SwiftUI. Every write goes through the ONE writer,
/// `TimelineStore.setLaneGrain` (per-track seed, no-op on no change, no undo — like the track's
/// Effect). A track is offered the rows exactly where a grain can SOUND: the player's own audio
/// lanes (`TimelineDocument.audioLaneIDs`, #416).
@MainActor
enum TrackGrain {
    static func offered(_ laneID: UUID, in document: TimelineDocument) -> Bool {
        document.audioLaneIDs.contains(laneID)
    }

    /// The grain this track sounds, or nil (none, disabled, or a later build's format).
    static func current(_ laneID: UUID, in document: TimelineDocument) -> GrainSettings? {
        document.lanes.first(where: { $0.id == laneID })?.deviceChain?.soundingGrain
    }

    /// On places the default grain (the writer gives it the track's own seed); Off removes it,
    /// settings included (no undo, like the track's Effect — the hint says so) — the track then
    /// plays exactly as before.
    static func setOn(_ on: Bool, laneID: UUID, timeline: TimelineStore) {
        guard on != (current(laneID, in: timeline.document) != nil) else { return }
        timeline.setLaneGrain(laneID, settings: on ? GrainSettings() : nil)
    }

    /// One knob moves; every other value — the seed included — is read back from the store, so a
    /// stale view can never write an old setting over a new one. A non-finite value is ignored.
    static func update(_ laneID: UUID, timeline: TimelineStore,
                       _ change: (inout GrainSettings) -> Void) {
        guard var settings = current(laneID, in: timeline.document) else { return }
        change(&settings)
        timeline.setLaneGrain(laneID, settings: settings.sanitized)
    }

    /// UI review (MED): whether a part on this track plays WITHOUT the grain although the grain is
    /// on — a pitched part (track Pitch plus part pitch, `AudioTranspose`) or a warped one. Both
    /// stay off the plain node the rendering plays on (`AudioLanePlayer.grainToPlay`). A warped
    /// part whose file tempo is unknown actually plays unstretched; the note may then be cautious.
    static func hasPartWithoutGrain(_ laneID: UUID, in document: TimelineDocument) -> Bool {
        document.regions.contains { region in
            region.laneID == laneID
                && (region.warpEnabled || AudioTranspose.semitones(for: region, in: document) != 0)
        }
    }

    /// A model range as the field's range — asked of `GrainSettings.Limits`, never restated.
    nonisolated static func range(_ limits: ClosedRange<Float>) -> ClosedRange<Double> {
        Double(limits.lowerBound)...Double(limits.upperBound)
    }
}

#if canImport(SwiftUI)
import SwiftUI

/// GMMW GA-10d2 — Echoel Grain on an AUDIO track's Device page: on/off, the six knobs of the
/// cloud and the mix, each an `EchoelValueField` (numbers, not knobs). Cold reads of
/// `timeline.document` only: the document moves on an edit, never on a clock, so this leaf adds
/// no churn under the inspector's menu pickers (10.76.41/50 law). No modal.
///
/// ⚠️ WHAT A PERSON HEARS, stated on screen: the grain is rendered off the main actor for each
/// part, so a change is heard from a part's NEXT start, and a part that starts before its new
/// rendering is ready plays dry for that pass. Mix 0 is the file itself. A stretched or pitched
/// part plays without the grain (`AudioLanePlayer.grainToPlay`).
/// NEEDS-FOUNDER-VERIFY: G10 — the grain is heard on an audio track, mid-song edits land on the
/// next pass, and the render does not stall a phone.
@MainActor
struct TrackGrainRows: View {
    @Environment(TimelineStore.self) private var timeline
    let laneID: UUID

    var body: some View {
        let grain = TrackGrain.current(laneID, in: timeline.document)
        let standard = GrainSettings()
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { grain != nil },
                set: { TrackGrain.setOn($0, laneID: laneID, timeline: timeline) })) {
                Text("Grain")
                    .font(EchoelTheme.font(12, .semibold)).foregroundStyle(EchoelTheme.text)
            }
            .tint(EchoelTheme.accent)
            .accessibilityHint("Scatters short grains of this track's audio. Off removes the grain and its settings")
            if grain != nil {
                field("Position", \.position, GrainSettings.Limits.position, unit: "", decimals: 2,
                      hint: String(localized: "0 reads from the start of the part, 1 from its end"),
                      standard: standard.position)
                field("Grain length", \.grainMilliseconds, GrainSettings.Limits.grainMilliseconds,
                      unit: "ms", decimals: 0,
                      hint: String(localized: "How long each grain lasts"),
                      standard: standard.grainMilliseconds)
                field("Density", \.density, GrainSettings.Limits.density, unit: "", decimals: 2,
                      hint: String(localized: "How many grains overlap"),
                      standard: standard.density)
                field("Spray", \.spraySeconds, GrainSettings.Limits.spraySeconds, unit: "s", decimals: 2,
                      hint: String(localized: "How far around the position a grain may start"),
                      standard: standard.spraySeconds)
                field("Pitch", \.pitchSemitones, GrainSettings.Limits.pitchSemitones,
                      unit: "semitones", decimals: 0,
                      hint: String(localized: "Each grain's pitch, in semitones"),
                      standard: standard.pitchSemitones)
                field("Spread", \.stereoSpread, GrainSettings.Limits.stereoSpread, unit: "", decimals: 2,
                      hint: String(localized: "0 keeps every grain centred, 1 scatters them left and right"),
                      standard: standard.stereoSpread)
                field("Mix", \.mix, GrainSettings.Limits.mix, unit: "", decimals: 2,
                      hint: String(localized: "0 plays only the part, 1 only the grains"),
                      standard: standard.mix)
                Text("A change is heard from a part's next start. Until its new sound is ready, a part plays without the grain.")
                    .font(EchoelTheme.font(11))
                    .foregroundStyle(EchoelTheme.dim)
                    .fixedSize(horizontal: false, vertical: true)
                if TrackGrain.hasPartWithoutGrain(laneID, in: timeline.document) {
                    Text("A pitched or warped part on this track plays without the grain.")
                        .font(EchoelTheme.font(11))
                        .foregroundStyle(EchoelTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func field(_ label: String, _ key: WritableKeyPath<GrainSettings, Float>,
                       _ limits: ClosedRange<Float>, unit: String, decimals: Int,
                       hint: String, standard: Float) -> some View {
        EchoelValueField(
            label: label,
            value: Binding(
                get: { Double(TrackGrain.current(laneID, in: timeline.document)?[keyPath: key] ?? standard) },
                set: { newValue in
                    guard newValue.isFinite else { return }
                    TrackGrain.update(laneID, timeline: timeline) { $0[keyPath: key] = Float(newValue) }
                }),
            range: TrackGrain.range(limits),
            unit: unit,
            decimals: decimals,
            hint: hint,
            standard: Double(standard))
    }
}
#endif

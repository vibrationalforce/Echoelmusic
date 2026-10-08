#if canImport(SwiftUI)
import SwiftUI

/// Restructure E13-1 (founder 2026-10-04: „Beats aus Samples … gehören bereits zum DMMW-Ziel") —
/// the Sampler's sound. A track on EchoelSampler plays its parts' notes through `SamplerVoice`,
/// and until this row nothing could give it a sample: `TimelineStore.setLaneSample` had no caller,
/// so the inspector did not offer the Sampler at all. The row picks a file from the media library
/// (`Media/Audio`, the files Import Audio copied in) and writes the lane's `samplePath` through
/// that one writer, wrapped in `editLaneSample` — ONE Undo step per pick (`.laneSample`).
///
/// The path is the library file's own path; `MediaLibrary.resolveRef` re-roots it by name when the
/// container moves, the same convention every audio part uses. The region player loads it on the
/// next part load or at once while playing (`slotSampleSink` → `LaneVoiceRack.setSample`).
///
/// ⚠️ ITS OWN LEAF, ON PURPOSE: the library listing is disk I/O, so it runs DETACHED in `.task`
/// (the `MediaBrowserView` pattern), never in a `body`.
/// ⚠️ LIMIT stated where it is met: `SamplerVoice` plays the first ~2 s of a file. ⛔ "the rack holds
/// ONE sampler unit, so a second Sampler track plays EchoelSynth" stood here — since GMMW GA-4 the
/// rack holds one unit per slot, so every rack track can play its own file.
/// NEEDS-FOUNDER-VERIFY: G7 — a sample picked here sounds on a MIDI part, and again after reopening.
@MainActor
struct TrackSampleRow: View {
    @Environment(TimelineStore.self) private var timeline
    let laneID: UUID

    @State private var assets: [MediaAsset] = []
    @State private var loaded = false

    var body: some View {
        let current = timeline.document.lanes.first(where: { $0.id == laneID })?.samplePath
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: EchoelTheme.spaceS) {
                Text("Sample")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
                    .accessibilityHidden(true)   // the Picker speaks the label once
                Picker("Sample", selection: Binding<String?>(
                    get: { current },
                    set: { path in
                        timeline.editLaneSample(id: laneID) {
                            timeline.setLaneSample(laneID, path: path)
                        }
                    })) {
                    Text("No sample").tag(String?.none)
                    if let current, !assets.contains(where: { $0.url.path == current }) {
                        Section("In this piece") {
                            Text(BeatPlayer.sampleRefDisplayName(current) ?? current).tag(String?.some(current))
                        }
                    }
                    if !assets.isEmpty {
                        Section("Library") {
                            ForEach(assets) { asset in
                                Text(asset.displayName).tag(String?.some(asset.url.path))
                            }
                        }
                    }
                }
                .pickerStyle(.menu).tint(EchoelTheme.text)
                .frame(minHeight: 44)
                .accessibilityHint("The audio file this track's notes play")
                Spacer(minLength: 0)
            }
            Text(Self.note(hasSample: current != nil, libraryEmpty: loaded && assets.isEmpty))
                .font(EchoelTheme.font(11))
                .foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task {
            let result = await Task.detached(priority: .utility) { MediaLibrary.listAudio() }.value
            guard !Task.isCancelled else { return }
            assets = result ?? []
            loaded = true
        }
    }

    /// What the row says under the menu: what is missing first, then the honest limits.
    static func note(hasSample: Bool, libraryEmpty: Bool) -> String {
        if libraryEmpty && !hasSample {
            return String(localized: "Your library has no audio yet. Use Import Audio in the Add menu on Arrange, then pick the file here.")
        }
        if !hasSample {
            return String(localized: "This track makes no sound until it has a sample.")
        }
        return String(localized: "Plays the first 2 seconds of the file. Middle C plays it as recorded; other notes pitch it up or down.")
    }
}
#endif

import EchoelCore
import EchoelEngine
import SwiftUI

/// Pitch & Texture (W3): one audio region baked with pitch correction toward the song's key, a
/// granular texture, or both — offline, never live. The page holds the settings until Bake; Preview
/// plays the first seconds through the engine's preview player; Bake renders the region's stretch of
/// its original into a new file and points the region at it in one undo step; Revert plays the
/// original again. A baked region opens with the settings it was baked with. Opened from the
/// region's hold menu through the one sheet slot.
struct RegionBakeView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
    @Environment(AudioEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss
    let trackID: TrackID
    let regionID: RegionID

    @State private var corrects = true
    @State private var strength = 100
    @State private var retuneMS = 40
    @State private var textured = false
    @State private var sizeMS = 80
    @State private var density = 50
    @State private var scatterMS = 50
    @State private var pitch = 0
    @State private var seed = 1
    @State private var loaded = false
    /// The bake or preview under way, so Stop can end it.
    @State private var running: BakeCancellation?
    @State private var isBaking = false
    @State private var isPreviewing = false
    @State private var previewTake: UInt64?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Pitch & Texture")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { close() }
                    }
                }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: load)
        .onDisappear(perform: stop)
    }

    private var region: AudioRegion? {
        store.project.track(trackID)?.regions.first { $0.id == regionID }
    }

    @ViewBuilder private var content: some View {
        ScrollView {
            if let region, let file = store.project.mediaFile(region.media), file.kind == .audio {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Text(region.bake == nil ? file.name : "\(file.name) — baked; the original stays in the song")
                        .font(Theme.Font.label)
                        .foregroundStyle(Theme.Color.textSecondary)
                    correctionSection
                    textureSection
                    actions(region)
                }
                .padding(Theme.Space.l)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                Text("This region is no longer in the song.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(Theme.Space.l)
            }
        }
        .background(Theme.Color.background)
        .numberPadHost()
    }

    private var correctionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Toggle("Pitch Correction", isOn: $corrects)
                .toggleStyle(EchoelToggleStyle())
                .accessibilityHint("Pulls each sung or played note toward the nearest note of the song's key and scale.")
            if corrects {
                HStack(spacing: Theme.Space.s) {
                    SettingField(title: "Strength", value: strength, range: 0...100, unit: "%", standard: 100,
                                 spokenUnit: "percent") { strength = $0 }
                    SettingField(title: "Retune", value: retuneMS, range: 0...500, unit: "ms", standard: 40,
                                 spokenUnit: "milliseconds") { retuneMS = $0 }
                }
                Text("Targets the song's key and scale in its tone system. A vibrato keeps its swing. Formants move with the pitch, by at most two semitones.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
    }

    private var textureSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Toggle("Granular Texture", isOn: $textured)
                .toggleStyle(EchoelToggleStyle())
                .accessibilityHint("Rebuilds the region from short grains of itself.")
            if textured {
                HStack(spacing: Theme.Space.s) {
                    SettingField(title: "Grain Size", value: sizeMS, range: 10...500, unit: "ms", standard: 80,
                                 spokenUnit: "milliseconds") { sizeMS = $0 }
                    SettingField(title: "Density", value: density, range: 0...100, unit: "%", standard: 50,
                                 spokenUnit: "percent") { density = $0 }
                }
                HStack(spacing: Theme.Space.s) {
                    SettingField(title: "Scatter", value: scatterMS, range: 0...500, unit: "ms", standard: 50,
                                 spokenUnit: "milliseconds") { scatterMS = $0 }
                    SettingField(title: "Pitch", value: pitch, range: -24...24, unit: "st", standard: 0,
                                 spokenUnit: "semitones") { pitch = $0 }
                }
                SettingField(title: "Seed", value: seed, range: RegionBaking.GrainTexture.seedRange, standard: 1,
                             drags: false) { seed = $0 }
                Text("The same seed gives the same texture.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .padding(.top, Theme.Space.m)
    }

    @ViewBuilder private func actions(_ region: AudioRegion) -> some View {
        let nothing = !corrects && !textured
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.s) {
                Button(isPreviewing ? "Stop Preview" : "Preview", systemImage: isPreviewing ? "stop.fill" : "play.fill") {
                    if isPreviewing { stop() } else { preview() }
                }
                .disabled(nothing || isBaking || !engine.isUp)
                if isBaking {
                    Button("Stop Bake", systemImage: "xmark") { stop() }
                } else {
                    Button(region.bake == nil ? "Bake" : "Bake Again", systemImage: "square.and.arrow.down.on.square") { bake() }
                        .disabled(nothing || documents.isExporting)
                }
            }
            .buttonStyle(ToolButtonStyle())
            if isBaking {
                ProgressView("Baking…")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            if region.bake != nil {
                Button("Revert to Original", systemImage: "arrow.uturn.backward") { revert() }
                    .buttonStyle(ToolButtonStyle())
                    .disabled(isBaking)
                    .accessibilityHint("Plays the original file again; the baked file stays in the song.")
            }
        }
        .padding(.top, Theme.Space.m)
    }

    /// The page's values as a bake's edits.
    private var edits: (pitch: RegionBaking.PitchCorrection?, texture: RegionBaking.GrainTexture?) {
        let correction = corrects ? RegionBaking.PitchCorrection(strength: Double(strength) / 100, retune: Double(retuneMS) / 1_000) : nil
        let grains = textured
            ? RegionBaking.GrainTexture(size: Double(sizeMS) / 1_000, density: Double(density) / 100,
                                        scatter: Double(scatterMS) / 1_000, pitch: Double(pitch), seed: seed)
            : nil
        return (correction, grains)
    }

    /// A baked region opens with the settings it was baked with.
    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let bake = region?.bake else { return }
        corrects = bake.pitchCorrection != nil
        if let correction = bake.pitchCorrection {
            strength = Int((correction.strength * 100).rounded())
            retuneMS = Int((correction.retune * 1_000).rounded())
        }
        textured = bake.texture != nil
        if let texture = bake.texture {
            sizeMS = Int((texture.size * 1_000).rounded())
            density = Int((texture.density * 100).rounded())
            scatterMS = Int((texture.scatter * 1_000).rounded())
            pitch = Int(texture.pitch.rounded())
            seed = texture.seed
        }
    }

    private func preview() {
        stop()
        let flag = BakeCancellation()
        running = flag
        isPreviewing = true
        let (correction, grains) = edits
        let documents = documents, player = engine.preview
        Task {
            let buffer = await documents.pitchTexturePreview(region: regionID, on: trackID, pitch: correction,
                                                             texture: grains, cancellation: flag)
            guard !flag.isCancelled, let buffer else {
                if running === flag { isPreviewing = false }
                return
            }
            previewTake = player.play(buffer)
        }
    }

    private func bake() {
        stop()
        let flag = BakeCancellation()
        running = flag
        isBaking = true
        let (correction, grains) = edits
        let documents = documents
        Task {
            _ = await documents.bakePitchTexture(region: regionID, on: trackID, pitch: correction, texture: grains,
                                                 cancellation: flag)
            if running === flag {
                isBaking = false
                running = nil
            }
        }
    }

    private func revert() {
        stop()
        let documents = documents
        Task { await documents.revertBake(region: regionID, on: trackID) }
    }

    /// Ends a preview or a bake under way; a stopped bake changes nothing.
    private func stop() {
        running?.cancel()
        running = nil
        isBaking = false
        if isPreviewing, previewTake.map({ engine.preview.isPlaying($0) }) ?? true { engine.preview.stop() }
        isPreviewing = false
        previewTake = nil
    }

    private func close() {
        stop()
        dismiss()
    }
}

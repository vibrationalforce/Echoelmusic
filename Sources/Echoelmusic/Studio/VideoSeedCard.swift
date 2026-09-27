// VideoSeedCard.swift
// Echoel — MV2b (founder order 2026-09-27, "Foto und Video werden zu kreativem Material"): the video
// door. "Video to Visuals" on the Workstation plate: choose a short video, see one frame of it and
// what was measured — length, frame rate, picture change, cuts and flashes, its length in bars at
// the current tempo — apply it to the live visual, take it back.
//
// ⭐ THE SAME SHAPE AS `PhotoSeedCard`, ON PURPOSE. `PhotosPicker` presents the system picker itself
// (no modifier on the Studio's presentation chain, no photo-library permission); every piece of
// state lives in this leaf; the way back is the SHARED `MediaLookUndo`, so a photo look and a video
// look can never stack and hide the look from before either.
//
// ⭐ NOTHING HOT IN `body`. The tempo glides at ~20 Hz (`beatPlayer.pattern.tempo`), so it is read
// ONCE, in `load`, when the video is read — the bar count is a reading taken then, and the card
// says at which tempo.
//
// ⭐ THE FILE IS NEVER HELD WHOLE. The picker hands over a file; it is copied on disk, read by
// `VideoSeedReader` in at most 48 small frames, and the copy is removed. A newer pick cancels the
// older read (the reader checks before every frame).
//
// ⚠️ WHAT IS NOT HERE, AND WHY — so nobody reads it as forgotten:
// · Recording a video with the camera: #1304 removed video capture (founder 2026-09-12) and the
//   rear camera is the pulse source. Import only.
// · The video's SOUND as a beat or sampler source: not built. The integration point is named in
//   `scratchpads/PLAN_MEDIA_SEED_2026-09-27.md` §3.4 (AVAssetReader → `Media/Audio` →
//   `AudioImport.commit`); the card says in words whether the file has sound, and claims no more.
// · Trimming the clip and placing it in the song: the bar count is shown, the arrangement slice
//   (MS4/MV3) does the placing. Nothing here claims it.

#if canImport(SwiftUI) && canImport(PhotosUI) && canImport(AVFoundation)
import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers

/// A picked video, copied out of the picker's short-lived file so it outlives the callback.
/// The copy lives in the temporary directory and is removed after the read.
struct PickedVideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("echoel-video-\(UUID().uuidString)")
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedVideoFile(url: copy)
        }
    }
}

/// The words the card shows, pure so the blocking bundle can drive them.
enum VideoSeedText {

    static var unreadable: String {
        let minutes = Int(VideoSeedAnalysis.maxDurationSeconds / 60)
        return "This video could not be read. Videos up to \(minutes) minutes can be used; try another one."
    }
    static let reading = "Reading the video…"

    private static func seconds(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        return String(format: "%.1f", value) + " s"   // the house style of `TrackMix.decibelText`
    }

    /// "Length 12.4 s, 30 fps".
    static func length(_ seed: VideoSeed) -> String {
        let fps = seed.frameRate.isFinite ? Int(seed.frameRate.rounded()) : 0
        return "Length \(seconds(seed.durationSeconds)), \(fps) fps"
    }

    /// "No cuts or flashes" / "1 cut or flash: 2.0 s" / "7 cuts or flashes: 1.0 s, 2.5 s, … and 2 more".
    static func cuts(_ times: [Double]) -> String {
        guard !times.isEmpty else { return "No cuts or flashes" }
        let shown = times.prefix(5).map(seconds).joined(separator: ", ")
        let more = times.count > 5 ? " and \(times.count - 5) more" : ""
        let noun = times.count == 1 ? "cut or flash" : "cuts or flashes"
        return "\(times.count) \(noun): \(shown)\(more)"
    }

    /// "About 6 bars of 4/4 at 120 BPM" — the musical length, measured at the tempo when read.
    static func bars(_ seed: VideoSeed, bpm: Double) -> String {
        guard let bars = VideoSeedAnalysis.bars(forSeconds: seed.durationSeconds, bpm: bpm) else {
            return "Length in bars: unknown"
        }
        let noun = bars == 1 ? "bar" : "bars"
        return "About \(bars) \(noun) of 4/4 at \(Int(bpm.rounded())) BPM"
    }

    /// Whether the file carries sound — and that it is not used yet.
    static func sound(_ hasAudio: Bool) -> String {
        hasAudio ? "It has sound. The sound is not used yet." : "No sound."
    }

    /// The four lines of "now → with this video", named as the Visual panel names its fields.
    static func changes(from before: VisualLookSnapshot, to after: VisualLookSnapshot) -> [String] {
        [PhotoSeedText.change("Intensity", before.intensity, after.intensity),
         PhotoSeedText.change("Motion", before.motion, after.motion),
         PhotoSeedText.change("Hue", before.hue, after.hue),
         PhotoSeedText.change("Saturation", before.saturation, after.saturation)]
    }
}

@MainActor
struct VideoSeedCard: View {

    private enum Phase {
        case empty
        case reading
        case ready(VideoSeedReader.Read, VisualLookSnapshot, bpm: Double)
        case failed(String)
    }

    /// Read ONLY in `load`, never in `body` — the tempo glides at ~20 Hz.
    @Environment(BeatPlayer.self) private var beatPlayer

    @State private var isOpen = false
    @State private var item: PhotosPickerItem?
    @State private var phase: Phase = .empty
    /// Whether the video on screen is the one whose look is applied; the way back is `MediaLookUndo`.
    @State private var appliedHere = false
    @State private var loadTask: Task<Void, Never>?
    @State private var appliedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if isOpen { content }
        }
        .sensoryFeedback(.success, trigger: appliedCount)
        .onDisappear {
            loadTask?.cancel()
            MediaLookUndo.shared.showVideo(nil)
        }
    }

    /// The seed of the video this card has read, if any.
    private var shownSeed: VideoSeed? {
        if case .ready(let read, _, _) = phase { return read.seed }
        return nil
    }

    private var header: some View {
        Button {
            isOpen.toggle()
            // Collapsed, the video is not on screen, so it is not "this video" to the agent
            // (EchoelAI review MED-1). Opened again, the one still read is offered again.
            MediaLookUndo.shared.showVideo(isOpen ? shownSeed : nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(EchoelTheme.font(12, .semibold))
                Text("Video to Visuals").font(EchoelTheme.font(13, .semibold))
            }
            .foregroundStyle(EchoelTheme.text)
            .padding(.horizontal, 14)
            .frame(minWidth: 92, minHeight: 44)
            .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
                .strokeBorder(EchoelTheme.border, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Video to Visuals")
        .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
        .accessibilityHint("Choose a short video; its brightness, colour and movement can shape the visuals")
    }

    private var isShowingVideo: Bool {
        if case .ready = phase { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        PhotosPicker(selection: $item, matching: .videos) {
            MediaActionLabel(title: "Choose Video", systemImage: "film")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose video")
        .accessibilityHint("Opens your videos. Nothing is changed until you apply it.")
        .onChange(of: item) { _, picked in load(picked) }

        switch phase {
        case .empty:
            EmptyView()
        case .reading:
            Text(VideoSeedText.reading)
                .font(EchoelTheme.font(13))
                .foregroundStyle(EchoelTheme.dim)
        case .failed(let message):
            Text(message)
                .font(EchoelTheme.font(13))
                .foregroundStyle(EchoelTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        case .ready(let read, let before, let bpm):
            ready(read, before: before, bpm: bpm, undo: MediaLookUndo.shared)
        }
        if !isShowingVideo && MediaLookUndo.shared.pending != nil {
            undoButton(MediaLookUndo.shared)
        }
    }

    @ViewBuilder
    private func ready(_ read: VideoSeedReader.Read, before: VisualLookSnapshot, bpm: Double,
                       undo: MediaLookUndo) -> some View {
        let seed = read.seed
        Image(decorative: read.proxy, scale: 1)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 180, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: EchoelTheme.radius))
            .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 2) {
            Text(VideoSeedText.length(seed))
            Text(VideoSeedText.bars(seed, bpm: bpm))
            Text("Movement \(PhotoSeedText.percent(seed.motionEnergy))")
            Text(VideoSeedText.cuts(seed.transientTimes))
            Text("Brightness \(PhotoSeedText.percent(seed.brightness))")
            Text(seed.hasDominantColour
                 ? "Main colour: hue \(Int((seed.hue * 360).rounded()) % 360)°"
                 : "No main colour")
            Text(VideoSeedText.sound(read.hasAudioTrack))
        }
        .font(EchoelTheme.font(13))
        .foregroundStyle(EchoelTheme.text)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)

        let after = before.applying(seed)
        // Applied here, or by EchoelAI through the same owner with this video (review LOW-3).
        let isLive = appliedHere || undo.pending == MediaSeedApplication(before: before, after: after)
        VStack(alignment: .leading, spacing: 2) {
            Text(isLive ? "Applied:" : "With this video:")
                .font(EchoelTheme.font(13, .semibold))
            ForEach(VideoSeedText.changes(from: before, to: after), id: \.self) { line in
                Text(line)
            }
            Text("Movement is how much the picture changes; it sets how fast the visual moves.")
                .foregroundStyle(EchoelTheme.dim)
        }
        .font(EchoelTheme.font(13))
        .foregroundStyle(EchoelTheme.text)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)

        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { applyButton(read, bpm: bpm, undo: undo); undoButton(undo) }
            VStack(alignment: .leading, spacing: 8) { applyButton(read, bpm: bpm, undo: undo); undoButton(undo) }
        }
    }

    private func applyButton(_ read: VideoSeedReader.Read, bpm: Double, undo: MediaLookUndo) -> some View {
        Button {
            guard let application = undo.apply(video: read.seed, on: .standard) else { return }
            phase = .ready(read, application.before, bpm: bpm)
            appliedHere = true
            appliedCount += 1
        } label: {
            MediaActionLabel(title: "Apply to Visuals", systemImage: "wand.and.stars")
        }
        .buttonStyle(.plain)
        .disabled(undo.pending != nil)
        .accessibilityLabel("Apply to visuals")
        .accessibilityHint(undo.pending == nil
                           ? "Sets the visuals' intensity, movement, hue and saturation from the video"
                           : "A \(undo.medium) look is applied. Undo it first to apply this one.")
    }

    private func undoButton(_ undo: MediaLookUndo) -> some View {
        Button {
            undo.undo(on: .standard)
            appliedHere = false
        } label: {
            MediaActionLabel(title: "Undo", systemImage: "arrow.uturn.backward")
        }
        .buttonStyle(.plain)
        .disabled(undo.pending == nil)
        .accessibilityLabel(undo.pending == nil ? "Undo" : "Undo \(undo.medium) look")
        .accessibilityHint("Puts the visuals back the way they were before. A value you changed since stays.")
    }

    /// Reads a newly picked video. The tempo is read here, once. The read runs in THIS task (the
    /// reader is nonisolated async, so it leaves the main actor) — which is what lets a newer pick's
    /// `cancel()` reach it; a detached task would not inherit the cancellation.
    private func load(_ picked: PhotosPickerItem?) {
        // nil is the reset after a failure below, not a user action: nothing to read.
        guard let picked else { return }
        loadTask?.cancel()
        appliedHere = false
        phase = .reading
        MediaLookUndo.shared.showVideo(nil)
        let bpm = beatPlayer.pattern.tempo
        loadTask = Task {
            var read: VideoSeedReader.Read?
            if let file = try? await picked.loadTransferable(type: PickedVideoFile.self) {
                read = await VideoSeedReader.read(url: file.url)
                try? FileManager.default.removeItem(at: file.url)
            }
            guard !Task.isCancelled else { return }
            if let read {
                phase = .ready(read, VisualLookSnapshot.read(from: .standard), bpm: bpm)
                // Offered to the agent only while the card is OPEN: a read that finishes after the
                // person collapsed the card must not re-publish a picture nobody sees (review
                // repair 2e). Opening the card again offers it (`header`).
                if isOpen { MediaLookUndo.shared.showVideo(read.seed) }
            } else {
                phase = .failed(VideoSeedText.unreadable)
                // Clear the selection, or picking the same video again would change nothing.
                item = nil
            }
        }
    }
}
#endif

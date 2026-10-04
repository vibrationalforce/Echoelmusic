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
// · ⭐ The video's SOUND is no longer in this list (E12-1, founder 2026-10-04: „Beats aus Samples
//   und Video als musikalisches Material gehören bereits zum DMMW-Ziel"). "Use Its Sound" exports the
//   sound track (`VideoSound`) and hands the file to the Workstation's ONE import door
//   (`useSound`, owned by `WorkstationView`), so it lands as a part on the first audio track and in
//   the library, with the same tempo and key analysis as a file from Files. ⛔ It used to say "not
//   built" here and "The sound is not used yet." on screen. What is STILL not here: the sound is
//   not cut to the picture's length, and it is not a sampler source by itself — a Sampler track
//   picks it from the library like any other file (E13-1, `TrackSampleRow`).
//   ⚠️ The copy of a video WITH sound is kept until its sound is used, a newer video is picked, or
//   the card goes away (`discardSoundSource`); every other copy is removed right after the read.
// · Trimming the clip and placing it in the song: the bar count is shown, the arrangement slice
//   (MS4/MV3) does the placing. Nothing here claims it.

#if canImport(SwiftUI) && canImport(PhotosUI) && canImport(AVFoundation)
import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers

/// A picked video, copied out of the picker's short-lived file so it outlives the callback.
/// The copy lives in the temporary directory and is removed after the read — or, for a video with
/// sound, once its sound is used or the card lets it go (E12-1).
struct PickedVideoFile: Transferable {
    let url: URL
    /// The picked file's own name without its extension — the sound file is named after it.
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("echoel-video-\(UUID().uuidString)")
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedVideoFile(url: copy, name: received.file.deletingPathExtension().lastPathComponent)
        }
    }
}

/// What the Workstation's import answered for a video's sound (E12-1): whether it landed, and the
/// sentence the import door wrote — shown on the card, because the card is not where the
/// Workstation's own note line sits.
struct VideoSoundLanding: Equatable {
    let placed: Bool
    let note: String
}

/// The words the card shows, pure so the blocking bundle can drive them.
enum VideoSeedText {

    static var unreadable: String {
        let minutes = Int(VideoSeedAnalysis.maxDurationSeconds / 60)
        // E4-42: seams around the number; the bundle's English is byte-identical ("… up to 10 minutes …").
        return String(localized: "This video could not be read. Videos up to ") + "\(minutes)" + String(localized: " minutes can be used; try another one.")
    }
    static var reading: String { String(localized: "Reading the video…") }

    private static func seconds(_ value: Double) -> String {
        guard value.isFinite else { return "–" }
        return String(format: "%.1f", value) + " s"   // the house style of `TrackMix.decibelText`
    }

    /// "Length 12.4 s, 30 fps".
    static func length(_ seed: VideoSeed) -> String {
        let fps = seed.frameRate.isFinite ? Int(seed.frameRate.rounded()) : 0
        let head: String = String(localized: "Length ") + seconds(seed.durationSeconds)
        return head + ", " + "\(fps)" + String(localized: " fps")
    }

    /// "No cuts or flashes" / "1 cut or flash: 2.0 s" / "7 cuts or flashes: 1.0 s, 2.5 s, … and 2 more".
    static func cuts(_ times: [Double]) -> String {
        guard !times.isEmpty else { return String(localized: "No cuts or flashes") }
        let shown = times.prefix(5).map(seconds).joined(separator: ", ")
        // E4-42: count beside a catalog noun per grammatical number; the overflow a seam + number + seam.
        let overflow: String = String(localized: " and ") + "\(times.count - 5)" + String(localized: " more")
        let more: String = times.count > 5 ? overflow : ""
        let noun: String = times.count == 1 ? String(localized: "cut or flash") : String(localized: "cuts or flashes")
        let head: String = "\(times.count) " + noun + ": "
        return head + shown + more
    }

    /// "About 6 bars of 4/4 at 120 BPM" — the musical length, measured at the tempo when read.
    static func bars(_ seed: VideoSeed, bpm: Double) -> String {
        guard let bars = VideoSeedAnalysis.bars(forSeconds: seed.durationSeconds, bpm: bpm) else {
            return String(localized: "Length in bars: unknown")
        }
        let noun: String = bars == 1 ? String(localized: "bar") : String(localized: "bars")
        let head: String = String(localized: "About ") + "\(bars) " + noun
        return head + String(localized: " of 4/4 at ") + "\(Int(bpm.rounded()))" + " BPM"
    }

    /// What the card can do with the video's sound right now (E12-1).
    enum SoundState: Equatable {
        /// The video has no sound track.
        case none
        /// It has sound and the card still holds the video: "Use Its Sound" is offered.
        case usable
        /// Its sound was placed in the piece from this card.
        case placed
        /// It has sound, but the card let the video go (it was hidden): pick it again.
        case released
    }

    /// The sound line, one sentence per state — never a promise the card cannot keep.
    static func sound(_ state: SoundState) -> String {
        switch state {
        case .none:     return String(localized: "No sound.")
        case .usable:   return String(localized: "It has sound. Use Its Sound places it as a part on the first audio track.")
        case .placed:   return String(localized: "Its sound is in the piece and in your library.")
        case .released: return String(localized: "It has sound. Choose the video again to use it.")
        }
    }

    static var extractingSound: String { String(localized: "Reading the sound…") }
    static var soundUnreadable: String { String(localized: "This video's sound could not be read.") }

    /// The four lines of "now → with this video", named as the Visual panel names its fields.
    static func changes(from before: VisualLookSnapshot, to after: VisualLookSnapshot) -> [String] {
        [PhotoSeedText.change(String(localized: "Intensity"), before.intensity, after.intensity),
         PhotoSeedText.change(String(localized: "Motion"), before.motion, after.motion),
         PhotoSeedText.change(String(localized: "Hue"), before.hue, after.hue),
         PhotoSeedText.change(String(localized: "Saturation"), before.saturation, after.saturation)]
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

    /// E12-1 — the Workstation's import door, handed in by the view that owns it. The card never
    /// names `AudioImport`: one door means one caller of the transaction.
    let useSound: @MainActor (URL) -> VideoSoundLanding

    @State private var isOpen = false
    @State private var item: PhotosPickerItem?
    @State private var phase: Phase = .empty
    /// Whether the video on screen is the one whose look is applied; the way back is `MediaLookUndo`.
    @State private var appliedHere = false
    @State private var loadTask: Task<Void, Never>?
    @State private var appliedCount = 0
    /// E12-1 — the copy of a video with sound, kept so "Use Its Sound" can read it.
    @State private var soundSource: PickedVideoFile?
    @State private var soundPlaced = false
    @State private var soundNote: String?
    @State private var soundTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if isOpen { content }
        }
        .sensoryFeedback(.success, trigger: appliedCount)
        .onDisappear {
            loadTask?.cancel()
            MediaLookUndo.shared.showVideo(nil)
            // E12-1: a hidden card holds no video on disk. Clearing the selection lets the same
            // video be picked again, which is what the "released" sound line asks for.
            soundTask?.cancel()
            soundTask = nil
            discardSoundSource()
            item = nil
        }
    }

    /// The seed of the video this card has read, if any.
    private var shownSeed: VideoSeed? {
        if case .ready(let read, _, _) = phase { return read.seed }
        return nil
    }

    private var header: some View {
        let undo = MediaLookUndo.shared
        return Button {
            isOpen.toggle()
            // Collapsed, the video is not on screen, so it is not "this video" to the agent
            // (EchoelAI review MED-1). Opened again, the one still read is offered again.
            MediaLookUndo.shared.showVideo(isOpen ? shownSeed : nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(EchoelTheme.font(12, .semibold))
                Text("Video to Visuals").font(EchoelTheme.font(13, .semibold))
                // Collapsed, the card still says that ITS look is live (review MED-8).
                if undo.pending != nil, undo.medium == MediaLookUndo.videoMedium {
                    Text("· look applied").font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.dim)
                }
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
        .accessibilityValue(disclosureValue(undo))
        .accessibilityHint("Choose a short video; its brightness, colour and movement can shape the visuals")
    }

    // E4-42: the spoken state and the spoken Undo label were interpolated or concatenated literals —
    // Strings, read verbatim on a German phone. Each English seam is a key; the spoken medium word is
    // `MediaLookUndo.spokenMedium` (E4-41), never the compared identifier. Typed steps, no `+` in a ternary.
    private func disclosureValue(_ undo: MediaLookUndo) -> String {
        let state: String = isOpen ? String(localized: "Expanded") : String(localized: "Collapsed")
        let applied: Bool = undo.pending != nil && undo.medium == MediaLookUndo.videoMedium
        return applied ? state + String(localized: ", look applied") : state
    }
    private func undoLabel(_ undo: MediaLookUndo) -> String {
        guard undo.pending != nil else { return String(localized: "Undo") }
        return String(localized: "Undo ") + undo.spokenMedium + String(localized: " look")
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
            Text(String(localized: "Movement") + " " + PhotoSeedText.percent(seed.motionEnergy))
            Text(VideoSeedText.cuts(seed.transientTimes))
            Text(String(localized: "Brightness") + " " + PhotoSeedText.percent(seed.brightness))
            let hueLine: String = String(localized: "Main colour: hue ") + "\(Int((seed.hue * 360).rounded()) % 360)" + "°"
            Text(seed.hasDominantColour ? hueLine : String(localized: "No main colour"))
            Text(VideoSeedText.sound(soundState(read)))
        }
        .font(EchoelTheme.font(13))
        .foregroundStyle(EchoelTheme.text)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)

        let after = before.applying(seed)
        // Applied here, or by EchoelAI through the same owner with this video (review LOW-3).
        let isLive = appliedHere || undo.pending == MediaSeedApplication(before: before, after: after)
        VStack(alignment: .leading, spacing: 2) {
            Text(isLive ? String(localized: "Applied:") : String(localized: "With this video:"))
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
        // Why Apply is grey, in sight and not only under VoiceOver (review MED-8). Not shown while the
        // applied look is this video's own — "Applied:" above already says so.
        if !isLive, let reason = undo.applyBlockedReason {
            Text(reason)
                .font(EchoelTheme.font(13))
                .foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        if soundState(read) == .usable { soundButton }
        if let soundNote {
            Text(soundNote)
                .font(EchoelTheme.font(13))
                .foregroundStyle(EchoelTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The sound line's state for the video on screen.
    private func soundState(_ read: VideoSeedReader.Read) -> VideoSeedText.SoundState {
        guard read.hasAudioTrack else { return .none }
        if soundPlaced { return .placed }
        return soundSource == nil ? .released : .usable
    }

    private var soundButton: some View {
        Button {
            useItsSound()
        } label: {
            MediaActionLabel(title: "Use Its Sound", systemImage: "waveform")
        }
        .buttonStyle(.plain)
        .disabled(soundTask != nil)
        .accessibilityLabel("Use its sound")
        .accessibilityHint("Places the video's sound as a part on the first audio track and adds it to your library")
    }

    /// E12-1 — export the kept video's sound, hand the file to the Workstation's import, remove
    /// the export. The export runs in THIS task (`VideoSound.extract` is nonisolated async, so it
    /// leaves the main actor); the import is the Workstation's, on the main actor, as from Files.
    private func useItsSound() {
        guard let source = soundSource, soundTask == nil else { return }
        soundNote = VideoSeedText.extractingSound
        let base = VideoSound.soundFileBase(videoName: source.name)
        soundTask = Task {
            let extracted = await VideoSound.extract(from: source.url, named: base)
            if Task.isCancelled {
                if let extracted { VideoSound.discard(extracted) }
                return
            }
            guard let extracted else {
                soundNote = VideoSeedText.soundUnreadable
                soundTask = nil
                return
            }
            let landing = useSound(extracted)
            VideoSound.discard(extracted)
            soundNote = landing.note
            if landing.placed {
                soundPlaced = true
                discardSoundSource()
            }
            soundTask = nil
        }
    }

    /// Removes the kept video copy, if any.
    private func discardSoundSource() {
        if let source = soundSource { try? FileManager.default.removeItem(at: source.url) }
        soundSource = nil
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
        .accessibilityHint(undo.applyBlockedReason ?? String(localized: "Sets the visuals' intensity, movement, hue and saturation from the video"))
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
        .accessibilityLabel(undoLabel(undo))
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
        // E12-1: the older video's sound goes with it. A running export of it is cancelled and
        // removes its own file.
        soundTask?.cancel()
        soundTask = nil
        discardSoundSource()
        soundPlaced = false
        soundNote = nil
        let bpm = beatPlayer.pattern.tempo
        loadTask = Task {
            var read: VideoSeedReader.Read?
            var kept: PickedVideoFile?
            if let file = try? await picked.loadTransferable(type: PickedVideoFile.self) {
                read = await VideoSeedReader.read(url: file.url)
                // E12-1: a video with sound keeps its copy for "Use Its Sound"; every other copy
                // goes now. No suspension between this check and the one below, so a kept copy
                // is never one a newer pick cancelled.
                if read?.hasAudioTrack == true, !Task.isCancelled {
                    kept = file
                } else {
                    try? FileManager.default.removeItem(at: file.url)
                }
            }
            guard !Task.isCancelled else { return }
            if let read {
                phase = .ready(read, VisualLookSnapshot.read(from: .standard), bpm: bpm)
                soundSource = kept
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

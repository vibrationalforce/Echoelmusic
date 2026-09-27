// PhotoSeedCard.swift
// Echoel — MS3 (founder order 2026-09-27, "Foto und Video werden zu kreativem Material"): the door.
// "Photo to Visuals" on the Workstation plate: choose a photo, see it, see what it would change,
// apply it to the live visual, take it back.
//
// ⭐ NO MODAL, NO PERMISSION. `PhotosPicker` is a BUTTON that presents the system picker itself —
// it adds nothing to the Studio's presentation chain (the black-screen law) — and it runs out of
// process, so reading a picked photo needs no photo-library permission and no Info.plist line.
//
// ⭐ A LEAF, LIKE `MediaBrowserView`. Every piece of state lives here; the Workstation mounts it
// and reads none of it. It reads no hot value: the visual keys are read once when a photo is
// ready (to show "now → with this photo"), never in `body`.
//
// ⭐ SIMPLE BY DEFAULT. Closed it is one labelled button. Open it is one photo, four plain
// readouts, one Apply and one Undo — every action has a text label, every colour has words
// beside it, every readout is one VoiceOver element with a value.
//
// ⚠️ WHAT IS NOT HERE, AND WHY — so nobody reads it as forgotten:
// · Taking a photo with the camera: `NSCameraUsageDescription` describes only the pulse reading
//   today (founder-gated Info.plist), and the rear camera is the rPPG source. Import only.
// · The way back is `MediaLookUndo`, shared with the video card: a second pick or an unmount
//   (the Studio shows one panel at a time) must not take it along.
// · Placing the photo in the song and launching it in Performance: the next slices (MS4/MS5,
//   `scratchpads/PLAN_MEDIA_SEED_2026-09-27.md`). Nothing here claims them.

#if canImport(SwiftUI) && canImport(PhotosUI) && canImport(ImageIO)
import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers

/// A picked image, copied out of the picker's short-lived file so it outlives the callback.
/// The copy lives in the temporary directory and is removed after the decode.
struct PickedImageFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            let ext = received.file.pathExtension.isEmpty ? "image" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("echoel-photo-\(UUID().uuidString)")
                .appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedImageFile(url: copy)
        }
    }
}

/// The words the card shows, pure so the blocking bundle can drive them.
enum PhotoSeedText {

    static let unreadable = "This photo could not be read. Try another photo."
    static let reading = "Reading the photo…"

    /// "Main colour: hue 212°" or "No main colour".
    static func colour(_ seed: MediaSeed) -> String {
        guard seed.hasDominantColour, seed.hue.isFinite else { return "No main colour" }
        return "Main colour: hue \(Int((seed.hue * 360).rounded()) % 360)°"
    }

    /// A 0…1 statistic as a whole percent.
    static func percent(_ value: Double) -> String {
        guard value.isFinite else { return "0 %" }
        return "\(Int((Swift.min(1, Swift.max(0, value)) * 100).rounded())) %"
    }

    /// "Intensity 1.00 → 0.72" — one line per visual value the photo changes. "Unchanged" is
    /// decided on the DISPLAY grid, so a line never shows an arrow from a number to itself.
    static func change(_ name: String, _ before: Double, _ after: Double, digits: Int = 2) -> String {
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(digits))
        let from = before.formatted(style), to = after.formatted(style)
        if from == to { return "\(name) \(from), unchanged" }
        return "\(name) \(from) → \(to)"
    }

    /// The four lines of "now → with this photo", named as the Visual panel names its fields.
    static func changes(from before: VisualLookSnapshot, to after: VisualLookSnapshot) -> [String] {
        [change("Intensity", before.intensity, after.intensity),
         change("Detail", before.detail, after.detail, digits: 0),
         change("Hue", before.hue, after.hue),
         change("Saturation", before.saturation, after.saturation)]
    }
}

@MainActor
struct PhotoSeedCard: View {

    private enum Phase {
        case empty
        case reading
        case ready(PhotoSeedDecoder.Decoded, VisualLookSnapshot)
        case failed(String)
    }

    @State private var isOpen = false
    @State private var item: PhotosPickerItem?
    @State private var phase: Phase = .empty
    /// Whether the photo on screen is the one whose look is applied. The way back itself lives in
    /// `MediaLookUndo`, so a second pick or an unmount cannot lose it.
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
            MediaLookUndo.shared.showPhoto(nil)
        }
    }

    /// The seed of the photo this card has read, if any.
    private var shownSeed: MediaSeed? {
        if case .ready(let decoded, _) = phase { return decoded.seed }
        return nil
    }

    private var header: some View {
        Button {
            isOpen.toggle()
            // Collapsed, the photo is not on screen, so it is not "this photo" to the agent
            // (EchoelAI review MED-1). Opened again, the one still read is offered again.
            MediaLookUndo.shared.showPhoto(isOpen ? shownSeed : nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(EchoelTheme.font(12, .semibold))
                Text("Photo to Visuals").font(EchoelTheme.font(13, .semibold))
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
        .accessibilityLabel("Photo to Visuals")
        .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
        .accessibilityHint("Choose a photo; its colour, brightness and contrast can shape the visuals")
    }

    @ViewBuilder
    private var content: some View {
        PhotosPicker(selection: $item, matching: .images) {
            MediaActionLabel(title: "Choose Photo", systemImage: "photo")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose photo")
        .accessibilityHint("Opens your photos. Nothing is changed until you apply it.")
        .onChange(of: item) { _, picked in load(picked) }

        switch phase {
        case .empty:
            EmptyView()
        case .reading:
            Text(PhotoSeedText.reading)
                .font(EchoelTheme.font(13))
                .foregroundStyle(EchoelTheme.dim)
        case .failed(let message):
            Text(message)
                .font(EchoelTheme.font(13))
                .foregroundStyle(EchoelTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        case .ready(let decoded, let before):
            ready(decoded, before: before, undo: MediaLookUndo.shared)
        }
        // A look applied before this card was last shown (or from the video card) can still be
        // taken back without picking a photo first.
        if !isShowingPhoto && MediaLookUndo.shared.pending != nil {
            undoButton(MediaLookUndo.shared)
        }
    }

    private var isShowingPhoto: Bool {
        if case .ready = phase { return true }
        return false
    }

    @ViewBuilder
    private func ready(_ decoded: PhotoSeedDecoder.Decoded, before: VisualLookSnapshot,
                       undo: MediaLookUndo) -> some View {
        let seed = decoded.seed
        Image(decorative: decoded.preview, scale: 1)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: 180, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: EchoelTheme.radius))
            .accessibilityHidden(true)

        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                .fill(Color(red: seed.dominantRed, green: seed.dominantGreen, blue: seed.dominantBlue))
                .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radiusSmall)
                    .strokeBorder(EchoelTheme.border, lineWidth: 1))
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(PhotoSeedText.colour(seed))
                Text("Brightness \(PhotoSeedText.percent(seed.brightness))")
                Text("Saturation \(PhotoSeedText.percent(seed.saturation))")
                Text("Contrast \(PhotoSeedText.percent(seed.contrast))")
            }
            .font(EchoelTheme.font(13))
            .foregroundStyle(EchoelTheme.text)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)

        let after = before.applying(seed)
        // Applied here, or by EchoelAI through the same owner with this photo (review LOW-3).
        let isLive = appliedHere || undo.pending == MediaSeedApplication(before: before, after: after)
        VStack(alignment: .leading, spacing: 2) {
            Text(isLive ? "Applied:" : "With this photo:")
                .font(EchoelTheme.font(13, .semibold))
            ForEach(PhotoSeedText.changes(from: before, to: after), id: \.self) { line in
                Text(line)
            }
            Text("Hue rotates the visual's own colours; it does not paint them the photo's colour.")
                .foregroundStyle(EchoelTheme.dim)
        }
        .font(EchoelTheme.font(13))
        .foregroundStyle(EchoelTheme.text)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)

        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { applyButton(decoded, undo: undo); undoButton(undo) }
            VStack(alignment: .leading, spacing: 8) { applyButton(decoded, undo: undo); undoButton(undo) }
        }
    }

    private func applyButton(_ decoded: PhotoSeedDecoder.Decoded, undo: MediaLookUndo) -> some View {
        Button {
            guard let application = undo.apply(photo: decoded.seed, on: .standard) else { return }
            // The lines above now read from the look that was really live at the tap.
            phase = .ready(decoded, application.before)
            appliedHere = true
            appliedCount += 1
        } label: {
            MediaActionLabel(title: "Apply to Visuals", systemImage: "wand.and.stars")
        }
        .buttonStyle(.plain)
        .disabled(undo.pending != nil)
        .accessibilityLabel("Apply to visuals")
        .accessibilityHint(undo.pending == nil
                           ? "Sets the visuals' intensity, detail, hue and saturation from the photo"
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
        .accessibilityHint("Puts the visuals back the way they were before the \(undo.medium.isEmpty ? "photo" : undo.medium). A value you changed since stays.")
    }

    /// Reads a newly picked photo. A newer pick cancels the older one's result; the decode runs
    /// detached (two bounded thumbnails) and its temporary copy is removed either way.
    private func load(_ picked: PhotosPickerItem?) {
        // nil is the reset after a failure below, not a user action: nothing to read.
        guard let picked else { return }
        loadTask?.cancel()
        appliedHere = false
        phase = .reading
        MediaLookUndo.shared.showPhoto(nil)
        loadTask = Task {
            var decoded: PhotoSeedDecoder.Decoded?
            if let file = try? await picked.loadTransferable(type: PickedImageFile.self) {
                let url = file.url
                decoded = await Task.detached(priority: .userInitiated) {
                    defer { try? FileManager.default.removeItem(at: url) }
                    return PhotoSeedDecoder.decode(url: url)
                }.value
            }
            guard !Task.isCancelled else { return }
            if let decoded {
                phase = .ready(decoded, VisualLookSnapshot.read(from: .standard))
                MediaLookUndo.shared.showPhoto(decoded.seed)
            } else {
                phase = .failed(PhotoSeedText.unreadable)
                // Clear the selection, or picking the same photo again would change nothing and
                // the error would stay.
                item = nil
            }
        }
    }
}
#endif

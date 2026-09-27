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

    /// "Intensity 1.00 → 0.72" — one line per visual value the photo changes.
    static func change(_ name: String, _ before: Double, _ after: Double, digits: Int = 2) -> String {
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(digits))
        if abs(before - after) < 0.005 { return "\(name) \(before.formatted(style)), unchanged" }
        return "\(name) \(before.formatted(style)) → \(after.formatted(style))"
    }

    /// The four lines of "now → with this photo".
    static func changes(from before: VisualLookSnapshot, to after: VisualLookSnapshot) -> [String] {
        [change("Intensity", before.intensity, after.intensity),
         change("Detail", before.detail, after.detail, digits: 0),
         change("Colour turn", before.hue, after.hue),
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
    @State private var application: MediaSeedApplication?
    @State private var loadTask: Task<Void, Never>?
    @State private var appliedCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if isOpen { content }
        }
        .sensoryFeedback(.success, trigger: appliedCount)
        .onDisappear { loadTask?.cancel() }
    }

    private var header: some View {
        Button {
            isOpen.toggle()
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
        .accessibilityValue(isOpen ? "Shown" : "Hidden")
        .accessibilityHint("Choose a photo; its colour, brightness and contrast can shape the visuals")
    }

    @ViewBuilder
    private var content: some View {
        PhotosPicker(selection: $item, matching: .images) {
            actionLabel("Choose Photo", systemImage: "photo")
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
            ready(decoded, before: before)
        }
    }

    @ViewBuilder
    private func ready(_ decoded: PhotoSeedDecoder.Decoded, before: VisualLookSnapshot) -> some View {
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
        VStack(alignment: .leading, spacing: 2) {
            Text(application == nil ? "With this photo:" : "Applied:")
                .font(EchoelTheme.font(13, .semibold))
            ForEach(PhotoSeedText.changes(from: before, to: after), id: \.self) { line in
                Text(line)
            }
            Text("The colour turn rotates the visual's own colours; it does not paint them the photo's colour.")
                .foregroundStyle(EchoelTheme.dim)
        }
        .font(EchoelTheme.font(13))
        .foregroundStyle(EchoelTheme.text)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)

        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { applyButton(seed); undoButton }
            VStack(alignment: .leading, spacing: 8) { applyButton(seed); undoButton }
        }
    }

    private func applyButton(_ seed: MediaSeed) -> some View {
        Button {
            application = MediaSeedApplication.apply(seed, to: .standard)
            appliedCount += 1
        } label: {
            actionLabel("Apply to Visuals", systemImage: "wand.and.stars")
        }
        .buttonStyle(.plain)
        .disabled(application != nil)
        .accessibilityLabel("Apply to visuals")
        .accessibilityHint(application == nil
                           ? "Sets the visuals' intensity, detail, colour turn and saturation from the photo"
                           : "Already applied. Undo first to apply again.")
    }

    private var undoButton: some View {
        Button {
            application?.undo(on: .standard)
            application = nil
        } label: {
            actionLabel("Undo", systemImage: "arrow.uturn.backward")
        }
        .buttonStyle(.plain)
        .disabled(application == nil)
        .accessibilityLabel("Undo photo look")
        .accessibilityHint("Puts the visuals back the way they were before the photo")
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).font(EchoelTheme.font(13, .semibold))
            Text(title).font(EchoelTheme.font(13, .semibold))
        }
        .foregroundStyle(EchoelTheme.text)
        .padding(.horizontal, 14)
        .frame(minWidth: 92, minHeight: 44)
        .background(RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.fill))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius)
            .strokeBorder(EchoelTheme.border, lineWidth: 1))
        .contentShape(Rectangle())
    }

    /// Reads a newly picked photo. A newer pick cancels the older one's result; the decode runs
    /// detached (two bounded thumbnails) and its temporary copy is removed either way.
    private func load(_ picked: PhotosPickerItem?) {
        loadTask?.cancel()
        application = nil
        guard let picked else { phase = .empty; return }
        phase = .reading
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
            } else {
                phase = .failed(PhotoSeedText.unreadable)
            }
        }
    }
}
#endif

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
// ready (to show "now → with this photo"), never in `body`. Two COLD keys are read in `body` (GMMW
// VV-2): the slider's looks and the donut switch, set by a person in the Field panel — they decide
// whether the Detail line and the word "contrast" are promised (`ThePhotoSeedClaimsOnlyWhatShowsTests`).
//
// ⭐ SIMPLE BY DEFAULT. Closed it is one labelled button. Open it is one photo, four plain
// readouts, three or four "→" lines (Detail only where it can show), one Apply and one Undo —
// every action has a text label, every colour has words beside it, every readout is one
// VoiceOver element with a value.
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

    // E4-41: computed, not stored — a `static let` would freeze the bundle's first locale (E4 law).
    static var unreadable: String { String(localized: "This photo could not be read. Try another photo.") }
    static var reading: String { String(localized: "Reading the photo…") }

    /// "Main colour: hue 212°" or "No main colour".
    static func colour(_ seed: MediaSeed) -> String {
        guard seed.hasDominantColour, seed.hue.isFinite else { return String(localized: "No main colour") }
        return String(localized: "Main colour: hue ") + "\(Int((seed.hue * 360).rounded()) % 360)" + "°"
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
        let head: String = name + " " + from
        if from == to { return head + String(localized: ", unchanged") }
        return head + " → " + to
    }

    /// GMMW VV-2 — whether the Detail a photo's contrast writes can SHOW. The donut renderer draws
    /// `visual.detail` as its band count; the Metal field reads it through Rings only. So it shows
    /// while donuts are the picture or Rings is one of the slider's looks — `LookBlendMap`'s mirror,
    /// not a second copy of it (#416). Both inputs are stored values a person sets, read cold.
    static func detailShows(sliderLooks raw: String, donuts: Bool) -> Bool {
        donuts || LookBlendMap.sequenceReachesDetail(LookBlendMap.sequence(from: raw))
    }

    /// The lines of "now → with this photo", named as the Visual panel names its fields. Detail
    /// only when it can show (VV-2): the photo still WRITES it — add Rings later and it shows, and
    /// Undo takes it back with the rest — but the card does not promise a change nobody can see.
    static func changes(from before: VisualLookSnapshot, to after: VisualLookSnapshot,
                        detailShows: Bool) -> [String] {
        var lines: [String] = [change(String(localized: "Intensity"), before.intensity, after.intensity)]
        if detailShows {
            lines.append(change(String(localized: "Detail"), before.detail, after.detail, digits: 0))
        }
        lines.append(change(String(localized: "Hue"), before.hue, after.hue))
        lines.append(change(String(localized: "Saturation"), before.saturation, after.saturation))
        return lines
    }

    /// The header's spoken hint. Contrast is named only while its one target, Detail, can show.
    static func chooseHint(detailShows: Bool) -> String {
        detailShows
            ? String(localized: "Choose a photo; its colour, brightness and contrast can shape the visuals")
            : String(localized: "Choose a photo; its colour and brightness can shape the visuals")
    }

    /// Apply's spoken hint while nothing blocks it.
    static func applyHint(detailShows: Bool) -> String {
        detailShows
            ? String(localized: "Sets the visuals' intensity, detail, hue and saturation from the photo")
            : String(localized: "Sets the visuals' intensity, hue and saturation from the photo")
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
    /// VV-2: the two cold values that decide whether Detail can show — set by a person in the
    /// Field panel, never by a clock. Same keys and defaults as the Studio's own reads.
    @AppStorage(LookBlendMap.storageKey)
    private var sliderLooksRaw = LookBlendMap.string(from: LookBlendMap.defaultSequence)
    @AppStorage(StudioDefaultKeys.visualSpectralDonuts.key)
    private var spectralDonuts = StudioDefaultKeys.visualSpectralDonuts.value
    private var detailShows: Bool {
        PhotoSeedText.detailShows(sliderLooks: sliderLooksRaw, donuts: spectralDonuts)
    }

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
        let undo = MediaLookUndo.shared
        return Button {
            isOpen.toggle()
            // Collapsed, the photo is not on screen, so it is not "this photo" to the agent
            // (EchoelAI review MED-1). Opened again, the one still read is offered again.
            MediaLookUndo.shared.showPhoto(isOpen ? shownSeed : nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(EchoelTheme.font(12, .semibold))
                Text("Photo to Visuals").font(EchoelTheme.font(13, .semibold))
                // Collapsed, the card still says that ITS look is live (review MED-8).
                if undo.pending != nil, undo.medium == MediaLookUndo.photoMedium {
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
        .accessibilityLabel("Photo to Visuals")
        .accessibilityValue(disclosureValue(undo))
        .accessibilityHint(PhotoSeedText.chooseHint(detailShows: detailShows))
    }

    // E4-41: the spoken state and the spoken Undo texts were interpolated or concatenated literals —
    // Strings, read verbatim on a German phone. Each English seam is a key; `undo.medium` is an
    // identifier, so the spoken word comes from `spokenMedium`. Typed steps, no `+` chain in a ternary.
    private func disclosureValue(_ undo: MediaLookUndo) -> String {
        let state: String = isOpen ? String(localized: "Expanded") : String(localized: "Collapsed")
        let applied: Bool = undo.pending != nil && undo.medium == MediaLookUndo.photoMedium
        return applied ? state + String(localized: ", look applied") : state
    }
    private func undoLabel(_ undo: MediaLookUndo) -> String {
        guard undo.pending != nil else { return String(localized: "Undo") }
        return String(localized: "Undo ") + undo.spokenMedium + String(localized: " look")
    }
    private func undoHint(_ undo: MediaLookUndo) -> String {
        let medium: String = undo.medium.isEmpty ? String(localized: "photo") : undo.spokenMedium
        return String(localized: "Puts the visuals back the way they were before the ") + medium + String(localized: ". A value you changed since stays.")
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
                Text(String(localized: "Brightness") + " " + PhotoSeedText.percent(seed.brightness))
                Text(String(localized: "Saturation") + " " + PhotoSeedText.percent(seed.saturation))
                Text(String(localized: "Contrast") + " " + PhotoSeedText.percent(seed.contrast))
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
            Text(isLive ? String(localized: "Applied:") : String(localized: "With this photo:"))
                .font(EchoelTheme.font(13, .semibold))
            ForEach(PhotoSeedText.changes(from: before, to: after, detailShows: detailShows), id: \.self) { line in
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
        // Why Apply is grey, in sight and not only under VoiceOver (review MED-8). Not shown while the
        // applied look is this photo's own — "Applied:" above already says so.
        if !isLive, let reason = undo.applyBlockedReason {
            Text(reason)
                .font(EchoelTheme.font(13))
                .foregroundStyle(EchoelTheme.dim)
                .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityHint(undo.applyBlockedReason ?? PhotoSeedText.applyHint(detailShows: detailShows))
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
        .accessibilityHint(undoHint(undo))
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
                // Offered to the agent only while the card is OPEN: a read that finishes after the
                // person collapsed the card must not re-publish a picture nobody sees (review
                // repair 2e). Opening the card again offers it (`header`).
                if isOpen { MediaLookUndo.shared.showPhoto(decoded.seed) }
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

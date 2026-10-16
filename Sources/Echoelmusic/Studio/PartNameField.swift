//
//  PartNameField.swift
//  Echoelmusic — Studio (A8: the person names a part)
//
//  WHY THIS EXISTS. The canvas shows each part's name (`ArrangeCanvas.partName`, A1b) — the clip's
//  name — but nothing let a person write it, so "Verse" and "Drop" could not be told apart at a
//  glance (founder 2026-10-16, "Arrangement auf Ableton-Level"). The Part page now opens on a Name
//  field for the selected part, like the Track page's.
//
//  ⚠️ A part plays a CLIP, and a copy plays the same clip (`TimelineRegion.duplicated` keeps
//  `clipID`), so the name belongs to every copy, as their notes do. The field says so when the
//  clip is shared. One writer: `ClipStore.renameClip(id:to:)`.
//  ⚠️ Committed on Return, on focus loss and when the field leaves — never per keystroke, so the
//  canvas does not redraw while typing. An empty name is refused, like a track's.
//
//  NEEDS-FOUNDER-VERIFY (A8): select a part, Part page → Name "Verse", Return → the canvas block
//  reads "Verse"; on a part with a copy, the copy reads "Verse" too and the field says the name is
//  shared; clear the field and leave it → the old name comes back.
//

import SwiftUI

/// The pure half: which clip a part names, how many parts share it, and what is stored.
enum PartName {

    /// The longest name stored — a guard against a pasted page, never a design limit.
    nonisolated static let maxLength = 64

    /// The clip the part `regionID` plays, when the part is on `laneID`. Pure.
    nonisolated static func clipID(of regionID: UUID?, onLane laneID: UUID,
                                   in document: TimelineDocument) -> UUID? {
        guard let regionID, let region = document.regions.first(where: { $0.id == regionID }),
              region.laneID == laneID else { return nil }
        return region.clipID
    }

    /// How many parts in the piece play `clipID` — more than one means the name is shared. Pure.
    nonisolated static func sharingCount(_ clipID: UUID, in document: TimelineDocument) -> Int {
        document.regions.reduce(0) { $0 + ($1.clipID == clipID ? 1 : 0) }
    }

    /// What a typed name stores: trimmed and capped; nil (refused) when nothing is left. Pure.
    nonisolated static func stored(_ typed: String) -> String? {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxLength))
    }
}

/// The Name field for the selected part on a track's Part page. Draws nothing when no part of
/// this track is selected, or its clip is gone.
struct PartNameField: View {
    let laneID: UUID

    @Environment(TimelineStore.self) private var timeline
    @Environment(ClipStore.self) private var clipStore
    @Environment(WorkstationSelection.self) private var selection

    var body: some View {
        if let clipID = PartName.clipID(of: selection.regionID, onLane: laneID, in: timeline.document),
           let clip = clipStore.clip(id: clipID) {
            PartNameEditor(clipID: clipID, stored: clip.name,
                           shared: PartName.sharingCount(clipID, in: timeline.document) > 1)
                .id(clipID)   // a newly selected part starts from its own name
        }
    }
}

/// The field itself: a local, cold draft, written once on commit.
private struct PartNameEditor: View {
    let clipID: UUID
    let stored: String
    let shared: Bool

    @Environment(ClipStore.self) private var clipStore
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Name")
                .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            TextField("Part name", text: $draft)
                .font(EchoelTheme.font(13))
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .focused($focused)
                .onSubmit { commit() }
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .accessibilityLabel("Part name")
            if shared {
                Text("Copies of this part share its name and notes.")
                    .font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            }
        }
        .onAppear { draft = stored }
        .onDisappear { commit() }
    }

    private func commit() {
        guard let name = PartName.stored(draft) else {
            draft = stored
            return
        }
        clipStore.renameClip(id: clipID, to: name)
        draft = name
    }
}

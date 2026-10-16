//
//  EchoelInstanceLine.swift
//  Echoelmusic — Studio (WA4 path 9 follow-up: "this track's Echoel" says what it is set to)
//
//  WHY THIS EXISTS. The Echoel track's device row named the device and opened its editor, and
//  said nothing about the instance — which genre it composes in and which FX character colours
//  it. `EchoelInstanceState` (WA3 slice 2) is the read-only assembly of that state; this line
//  shows the two parts of it a player recognises a sound by, on the track that plays it.
//
//  ⭐ READ-ONLY, AND FROM THE SAME OWNERS. Both values are read through the SAME keys the
//  instrument writes (`StudioDefaultKeys.genre`, `EchoelInstanceState.fxCharacterKey`) and
//  resolved through their TYPES, so a retired raw value shows the default the instrument
//  actually plays — exactly as `EchoelInstanceState.assemble` resolves it. Nothing here writes;
//  the editor is the Sound plate behind "Open".
//  ⚠️ `.auto` repeats the instrument's declared FX default — the same one second default
//  `EchoelInstanceState` names and keeps, because `.auto` is the type's own "defer to the
//  genre" case, not a tuned number.
//
//  ⭐ THE PATCH (Ultraplan-D8, 2026-10-16). The instrument's `currentPatch` is view-private, so it
//  is not read; the line names what the VOICE was last given — `PolySynthVoice.appliedPatch`,
//  the voice's own patch memory, set only by `apply(_:)`. That is the sound that plays, not a
//  guess at what the editor holds. Before the first apply there is no patch fact.
//  ⚠️ NOT THE WHOLE INSTANCE. Mood, rhythm characters and the role mix are left out on purpose —
//  this is a label, not a second editor.
//
//  ⚠️ IT IS ITS OWN FILE BECAUSE THE INSPECTOR OWNS NO PERSISTENCE (its guard bans
//  `@AppStorage` there). This leaf only READS two keys, at selection rate — both change on a
//  picker, a reset or an Open, never on a clock — so it is safe in the Workstation plate.
//

import SwiftUI

struct EchoelInstanceLine: View {

    @AppStorage(StudioDefaultKeys.genre.key) private var genre: MusicStyle = StudioDefaultKeys.genre.value
    @AppStorage(EchoelInstanceState.fxCharacterKey) private var character: FXCharacter = .auto
    /// D8: the voice's patch memory — changes on a patch apply (a preset, an edit, a genre),
    /// never on a clock, and only this leaf reads it.
    @Environment(PolySynthVoice.self) private var synth

    var body: some View {
        // One row where it fits, the two facts stacked where it does not (large type, a narrow
        // phone) — never a truncated genre name.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { genreFact; characterFact; patchFact }
            VStack(alignment: .leading, spacing: 2) { genreFact; characterFact; patchFact }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenInstance)
    }

    /// E4-18: head + name + middle + name through `String(localized:)` — a format key could not be a
    /// catalog literal; the two names come from their types and are not this line's to translate.
    /// Built outside `body` so the `+` chain does not sit in the view's type-check budget.
    private var spokenInstance: String {
        let base = String(localized: "Echoel plays ") + genre.displayName + String(localized: ", FX character ") + character.displayName
        guard let name = patchName else { return base }
        return base + String(localized: ", patch ") + name
    }

    /// The name of the patch the voice was last given, or nil before the first apply (or for a
    /// patch without a name).
    private var patchName: String? {
        guard let name = synth.appliedPatch?.name.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }

    // A2 (founder 2026-10-01): the genre is the Echoel device's STYLE, and the row right above
    // this line says "Style" — one word for one thing on one surface (rule 1).
    private var genreFact: some View { fact("Style", genre.displayName) }
    private var characterFact: some View { fact("FX", character.displayName) }
    /// A patch name is the player's own text and can be long, so unlike the two type names it
    /// truncates at its end instead of holding its width (`fact` is `fixedSize`).
    @ViewBuilder private var patchFact: some View {
        if let name = patchName {
            HStack(spacing: 4) {
                Text("Patch").font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim).fixedSize()
                Text(name).font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.text)
                    .lineLimit(1).truncationMode(.tail)
            }
        }
    }

    // E4-18: `name` is a catalog KEY (two literal callers); `value` is a type's display name.
    private func fact(_ name: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(name).font(EchoelTheme.font(11)).foregroundStyle(EchoelTheme.dim)
            Text(value).font(EchoelTheme.font(12)).foregroundStyle(EchoelTheme.text)
        }
        .fixedSize()
    }
}
